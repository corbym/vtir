# Using the Exported TAP File

> This guide walks you through every step needed to take a `.tap` file
> produced by Vortex Tracker II and hear it playing — either in a ZX
> Spectrum emulator on your PC/Mac/Linux machine, or on a real ZX Spectrum
> (48K or 128K) connected to a cassette-tape interface.

---

## What is a TAP file?

A `.tap` file is a byte-for-byte recording of a ZX Spectrum cassette tape
in a standard container format understood by virtually every ZX Spectrum
emulator.  Each *block* in the file represents one segment of tape — either
a 19-byte Spectrum ROM **header** (which describes the name, size and load
address of the following data) or a **data** block containing the actual
bytes that will be loaded into RAM.

---

## What is inside the exported TAP file?

When you export a song as `.tap` from Vortex Tracker II, the file contains
**four blocks** in the following order:

| # | Flag | Type | Content |
|---|------|------|---------|
| 1 | `0x00` | Header | ROM header for the **player** code |
| 2 | `0xFF` | Data | Relocated Z80 machine-code **player** |
| 3 | `0x00` | Header | ROM header for the **PT3 module** data |
| 4 | `0xFF` | Data | The compiled **PT3 song** |

The player is a compact Z80 routine (the VTII PT3 player r.7) that knows
how to drive the AY-3-8910/YM2149F sound chip.  The PT3 data is your song.
Both blocks are *position-independent*: during export they are *relocated*
to the **load address** you specified (default `0xC000`, i.e. 49152).

> **Memory map after loading (default addresses)**
>
> ```
> 0xC000  ←  player code      (approx. 0x500 bytes, varies)
> 0xC???  ←  player variables (a few hundred bytes of zero'd RAM,
>             automatically reserved by the player; NOT in the TAP)
> 0xD???  ←  PT3 module data  (size depends on your song)
> ```
>
> The exact addresses are printed in the TAP header blocks; see step 4 below
> for how to read them.

---

## Part 1 — Using the TAP file in an emulator

### Recommended emulators

| Platform | Emulator | Free? | Download |
|----------|----------|-------|----------|
| Windows | **Fuse for Windows** | ✅ | <https://sourceforge.net/projects/fuse-for-windows/> |
| Windows | **ZXSpin** | ✅ | <http://www.zophar.net/sinclair/zx-spin.html> |
| macOS / Linux | **FUSE** | ✅ | <https://fuse-emulator.sourceforge.net/> |
| Cross-platform | **ZEsarUX** | ✅ | <https://github.com/chernandezba/zesarux> |
| Windows | **Spectaculator** | 💰 | <https://www.spectaculator.com/> |

The steps below use **FUSE** (the most widely available), but the
principles are identical for every emulator.

---

### Step 1 — Start the emulator in 48K mode

Open FUSE.  From the menu choose **Machine → Spectrum 48K** (or select
**48K** in the *Machine* toolbar).

> 128K mode works too, but the ROM BASIC and `LOAD` behaviour differ
> slightly between the two.  48K is simpler for this walkthrough.

---

### Step 2 — Insert the TAP file as a virtual tape

Choose **File → Open** (or drag the `.tap` file onto the FUSE window).
FUSE will recognise the extension and insert the tape automatically.

Alternatively, in some versions of FUSE:

1. **Media → Tape → Open…**
2. Navigate to your `.tap` file and click **Open**.

You should now see the tape counter reset to `000`.

---

### Step 3 — Open the BASIC prompt

The Spectrum ROM starts at the `K` cursor waiting for you to type.  You
should see a blue border with a black screen and the `©` copyright message.

If the emulator is already running a program, press **BREAK** (mapped to
`Shift+Space` in most emulators) to return to BASIC.

---

### Step 4 — Load the player code

Type the following BASIC command and press **ENTER**:

```basic
LOAD "" CODE
```

> **How to type this on a Spectrum keyboard:**
> - `LOAD` — press **J** (the word `LOAD` appears automatically in BASIC).
> - `""` — press **SYMBOL SHIFT + P** twice (produces `"`).
> - `CODE` — press **SYMBOL SHIFT + I** (the keyword `CODE` appears).
> - Press **ENTER**.

The emulator will now search the virtual tape for the first header block.
It will find the **vtplayer** header, print `Program: vtplayer`, and then
read the player machine code into RAM starting at `0xC000` (49152).

> In FUSE you may need to enable **Auto-load** (`Options → Tape → Auto-play
> tape on LOAD`), or press **Play** in the tape browser window, or press
> `F8` to start tape playback manually.

Wait a few seconds (or press `F8` again after the header loads if the tape
pauses).  The border will flash with loading colours and then return to the
`K` cursor.

---

### Step 5 — Load the PT3 music data

Type the same command again and press **ENTER**:

```basic
LOAD "" CODE
```

This time the tape will serve block 3 (the PT3 header, named after your
song) and then block 4 (the raw PT3 bytes), loading the song into memory
at the address immediately after the player variables area.

The border flashes again, then returns to the `K` cursor.

---

### Step 6 — Initialise the player

Type the following BASIC command and press **ENTER**:

```basic
RANDOMIZE USR 49152
```

> `RANDOMIZE USR` is typed as a single keyword: press **T** for `RANDOMIZE`
> and then **SYMBOL SHIFT + L** for `USR`.  Then type `49152`.

`49152` is `0xC000` — the address where the player was loaded.  `USR` calls
that address as a Z80 machine-code subroutine.  The player **init** routine
runs, sets up its internal state (reads the PT3 header, initialises the
pattern pointer, etc.) and returns immediately.

> At this point the music **does not yet play**.  The player is initialised
> but silent.  Playback requires the interrupt handler (see Step 7).

---

### Step 7 — Wire the interrupt and start playback

The VTII player has two entry points:

| Offset from `load_addr` | Purpose |
|-------------------------|---------|
| `+0` (i.e. `0xC000`) | **Init** — call once; sets up player state, then returns |
| `+5` (i.e. `0xC005`) | **Play** — call once per 50 Hz frame; updates AY registers |

The Play entry point (`load_addr + 5`) must be called 50 times per second
(once per TV frame on a 50 Hz Spectrum).  The simplest way is to redirect
the Z80 Mode 1 interrupt to call it.

The standard technique in ZX Spectrum BASIC is:

```basic
10  RANDOMIZE USR 49152
20  POKE 23672, 255: POKE 23673, 255: POKE 23674, 255
30  OUT 254, 0
40  GOTO 40
```

However, the *cleanest* self-contained approach is to write a short machine-
code trampoline that redirects the interrupt.  A minimal example that works
on a 48K Spectrum:

```z80
; At address 65280 (0xFF00) — set up IM 2 interrupt vector table
; The table occupies 257 bytes at 0xFF00; all entries point to 0xFFFF.
; At 0xFFFF put a JP to the player's play entry.

LD HL, 65280     ; 0xFF00
LD B, 0          ; 256 times
FILL_LOOP:
  LD (HL), 255   ; table entries all = 0xFF
  INC HL
  DJNZ FILL_LOOP
LD (HL), 255     ; byte 257 also = 0xFF
; Now write the JP at 0xFFFF
LD HL, 49157     ; load_addr + 5 = 0xC005, the play entry
LD (65535), 0xC3 ; JP opcode
LD (65536), L    ; lo byte of play address (can't directly address 65536,
LD (65535+1), L  ; use: LD (65536) is done via LD A; LD (65535),A etc.)
```

> In practice, most people type the opcodes directly with `POKE` statements
> or use a short BASIC + machine-code loader.  Ready-made interrupt-wiring
> routines are available in the ZX Spectrum community (search for
> "IM 2 interrupt setup ZX Spectrum BASIC").

**Simpler option**: some music players and demo-tools for the Spectrum
provide a BASIC stub that does all of this.  The `.ay` export format (see
[File Formats](file-formats.md)) is easier to use in emulators because
emulators parse the Init/Play addresses directly from the file and call
them automatically — no BASIC needed.

---

### Step 8 — Hear the music

Once the interrupt is wired and the BASIC `GOTO` loop is running, the
Spectrum's Z80 will execute the Play entry 50 times per second, updating
the AY chip registers.  The emulator will render these register writes as
audio — you should hear your song playing.

---

## Part 2 — Using the TAP file on a real ZX Spectrum

### What you need

- A ZX Spectrum 48K or 128K (any variant: rubber key, toastrack, +2, +2A, +3)
- A cassette-tape interface cable (**EAR** socket on the Spectrum)
- A computer or phone with software that can play back `.tap` files as audio
- OR a cassette tape duplicated from the `.tap` audio, played on a real tape deck

### Converting the TAP to audio

The Spectrum's cassette interface uses audio tones.  You must convert the
`.tap` binary to an audio file (WAV or MP3) and then play it into the
Spectrum's **EAR** socket.

Recommended tools:

| Tool | Platform | Notes |
|------|----------|-------|
| **PlayTZX / Tapir** | Windows | Plays `.tap`/`.tzx` directly as audio |
| **tapir** (CLI) | Linux / macOS | `tapir myfile.tap` plays to speaker |
| **tzxduino / PZX2Audio** | Cross-platform | GUI conversion tools |
| **TZXTool** | Windows | Converts `.tap` → WAV |
| **fuse-utils `tape2wav`** | Linux | `tape2wav myfile.tap output.wav` |

Generate a WAV at **44100 Hz, 16-bit mono**.  Do not apply any audio
compression or EQ — the signal is frequency-modulated and any processing
will corrupt it.

### Loading on the Spectrum

1. Connect the computer's **headphone out** to the Spectrum's **EAR** socket
   using a 3.5 mm mono cable (or stereo-to-mono adapter).
2. Set the computer's output volume to about **70%** — too loud or too quiet
   both cause load errors.  Adjust until the border loads cleanly.
3. At the Spectrum's BASIC prompt type `LOAD "" CODE` and press **ENTER**.
4. Start playing the audio file on the computer.
5. The Spectrum border will flash with loading colours.
6. Once block 1 (player) has loaded, the border returns to the default
   colour.  **Do not stop the audio**.  Type `LOAD "" CODE` again — or, if
   you have a tape with both blocks recorded sequentially, just wait; the
   Spectrum will automatically pick up block 3.
7. After both blocks are loaded, wire the interrupt and call `USR 49152` as
   described in Steps 6–7 of Part 1.

> **Tip:** If the load fails with a red border (checksum error), try
> lowering the playback volume slightly and retrying from block 1.

### Saving to real cassette tape

If you want a physical tape:

1. Use any of the TAP-to-audio tools above to produce a WAV.
2. Connect the computer's headphone out to the **MIC** socket on a tape
   recorder.
3. Press **Record** on the tape recorder and **Play** on the computer.
4. To load back: use the tape deck's **EAR** output connected to the
   Spectrum's **EAR** socket as above.

---

## Why use `.tap` instead of `.ay`?

| Scenario | Best format |
|----------|-------------|
| Playing in a ZX Spectrum emulator with a dedicated AY player | **`.ay`** |
| Sharing a tune on real ZX Spectrum hardware or a real tape | **`.tap`** |
| Including a tune inside a Spectrum demo or game | **`.tap`** or **`.scl`** |
| Developing / debugging with a BASIC interpreter | **`.tap`** |

The `.ay` format is far easier to use in emulators (FUSE, ZEsarUX, ZXSpin)
because the emulator calls Init and Play automatically.  Use `.tap` when
you specifically need the tape-loading experience or real hardware
compatibility.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `R Tape loading error` on load | Volume too high/low, cable problem, or corrupt `.tap` | Adjust volume; verify the `.tap` with the VTIR test suite |
| Music plays for one frame then stops | Play entry (`USR 49157`) is not being called by the interrupt | Set up the IM 2 vector as described in Step 7 |
| Silence after `RANDOMIZE USR 49152` | Only Init was called; Play has not run | Add the interrupt wiring (Step 7) |
| Wrong pitch / garbled sound | Player was loaded at a different address than the PT3 expects | Re-export; the default `0xC000` is safest |
| `L` error after `RANDOMIZE USR` | The player init crashed (jumped to an invalid address) | Re-export and check that the load address does not overlap other RAM |

---

## Further reading

- [File Formats](file-formats.md) — binary layout of `.tap`, `.ay`, `.scl`
  and all other supported formats
- [AY State Machine](ay-state-machine.md) — how the AY chip emulator works
  and what the player does each interrupt
- [Tracker Songs & Fixtures](tracker-songs.md) — example songs and test
  fixtures included in the repository
