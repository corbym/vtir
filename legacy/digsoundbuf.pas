{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit digsoundbuf;

{$mode ObjFPC}{$H+}
{$ASMMODE intel}

interface

uses
 Classes, SysUtils, trfuncs, AY, ChildWin;

type
 TFilt_K = array of integer;

 TBufferMaker = object
   //Purpose: if True then global VisParams will be used,
   //otherwise can be used for conversions, etc
   ForPlayback: boolean;

   Players: array of PPlayer;

   //Digital sound buffering related
   IntFlag: boolean;
   Tik: packed record
     case integer of
       0: (Lo: word;
         Hi: word);
       1: (Re: integer);
     end;
   Current_Tik: longword;
   Number_Of_Tiks: packed record
     case boolean of
       False: (lo: longword;
         hi: longword);
       True: (re: int64);
     end;

   //Other
   Real_End_All: boolean;
   LineReady: boolean;

   Synthesizer: procedure(Buf: pointer) of object;

   //todo implementation->private
   //Digital sound buffering related
   PrevLeft, PrevRight: integer;
   LevelL, LevelR, Left_Chan, Right_Chan: integer;
   Left_Chan1, Right_Chan1: integer;
   Tick_Counter: packed record
     case integer of
       0: (Lo: word;
         Hi: word);
       1: (Re: integer);
     end;

   //Panning
   Levels: TLevels;

   //FIR-filter
   Filt_XL, Filt_XR: TFilt_K;
   Filt_I: integer;

   //One buffer size and current pos in it
   BufferLengthMax, BufferLength: integer;

   procedure InitFilter;
   function ApplyFilter(Lev: integer; var Filt_X: TFilt_K): integer;

   procedure Synthesizer_Stereo16(Buf: pointer);
   procedure Synthesizer_Stereo8(Buf: pointer);
   procedure Synthesizer_Mono16(Buf: pointer);
   procedure Synthesizer_Mono8(Buf: pointer);
   procedure SynthesizerZX50(Buf: pointer);
   procedure SetSynthesizer;

   procedure InitSoundChipEmulation;
   procedure InitForAllTypes;

   procedure Calculate_Level_Tables;

   procedure Reset;

   procedure MakeBufferTracker(Buf: pointer);

   //checks if need to fill VisParams, then increments ticks
   procedure visualisation_check;

 end;

procedure SetPlaybackBufferLength;
procedure SetBuffers(len, num: integer);
procedure Set_Sample_Rate(SR: integer);
procedure Set_Sample_Bit(SB: integer);
procedure Set_Stereo(St: integer);
procedure Set_Chip_Frq(Fr: integer);
procedure Set_Player_Frq(Fr: integer);
procedure SetFilter(Filt: boolean);

//copy parameters required to redraw position list and pattern at current state,
//and also to init main params of editor after stopping playing
procedure visualisation_fill;

//initialize visualisation indexes
procedure visualisation_reset;

function Calculate_Channels_Allocation_Indexes: string;

const
 GlobalVolumeMax = 64;

 //Wave-file header
 WAVFileHeader: record
     rId: array[0..3] of char;
     rLen: longint;
     wId: array[0..3] of char;
     fId: array[0..3] of char;
     fLen: longint;
     wFormatTag: word;
     nChannels: word;
     nSamplesPerSec: longint;
     nAvgBytesPerSec: longint;
     nBlockAlign: word;
     FormatSpecific: word;
     dId: array[0..3] of char;
     dLen: longint;
     end
 =
   (rId: 'RIFF'; rLen: 0; wId: 'WAVE'; fId: 'fmt '; fLen: 16; wFormatTag: 1;
   nChannels: 2; nSamplesPerSec: 44100; nAvgBytesPerSec: 176400;
   nBlockAlign: 4; FormatSpecific: 16; dId: 'data'; dlen: 0);

var
 //FIR-filter
 Filt_M: integer;
 IsFilt: integer = 1;

 //Playback visualisation and current play pos params
 VisParams: array of array [0..MaxNumberOfSoundChips - 1] of TVisParams;
 VisPosMax, VisTicksStep, VisTicksMax: DWORD;

 //Playback volume [0..GlobalVolumeMax]
 GlobalVolume: integer;

 PlaybackBufferMaker: TBufferMaker;
 PlaybackWindow: array [0..MaxNumberOfSoundChips - 1] of TChildForm;

implementation

uses
 digsoundcode, options, Languages;

type
 //Digital sound buffer sample items and pointers to it
 TS16 = packed record
   Left: smallint;
   Right: smallint;
 end;
 PS16 = ^TS16; //16 bits Stereo

 TS8 = packed record
   Left: byte;
   Right: byte;
 end;
 PS8 = ^TS8; //16 bits Stereo
 TM16 = smallint;
 PM16 = ^TM16; //16 bits Mono
 TM8 = byte;
 PM8 = ^TM8; //8 bits Stereo

var
 //AY emu calculated consts for buffer maker
 Delay_in_tiks: DWORD;
 AY_Tiks_In_Interrupt: longword;

 //FIR-filter
 Filt_K: TFilt_K;

 //Playback visualisation and current play pos params
 VisPos, VisTicks, VisTicksPoint: DWORD;

 //Panning
 Index_AL, Index_AR, Index_BL, Index_BR, Index_CL, Index_CR: byte;

function Interpolator16(l1, l0, ofs: integer): integer; inline;
begin
 Result := (l1 - l0) * ofs div 65536 + l0;
 if Result > 32767 then
   Result := 32767
 else if Result < -32768 then
   Result := -32768;
end;

function Interpolator8(l1, l0, ofs: integer): integer; inline;
begin
 Result := (l1 - l0) * ofs div 65536 + l0 + 128;
 if Result > 255 then
   Result := 255
 else if Result < 0 then
   Result := 0;
end;

function Averager16(l, n: integer): integer; inline;
begin
 Result := l div n;
 if Result > 32767 then
   Result := 32767
 else if Result < -32768 then
   Result := -32768;
end;

function Averager8(l, n: integer): integer; inline;
begin
 Result := 128 + l div n;
 if Result > 255 then
   Result := 255
 else if Result < 0 then
   Result := 0;
end;

//sorry for assembler, I can't make effective qword procedure on pascal...
function TBufferMaker.ApplyFilter(Lev: integer; var Filt_X: TFilt_K): integer;
(*
{$ifdef cpu32} cpu32 assembler variant was not adapted to function of object
begin
asm
        push    ebx
        push    esi
        push    edi
        add     esp,-8
        mov     ecx,Filt_M
        mov     edi,Filt_K
//        lea     esi,edi+ecx*4
        lea     esi,edi[ecx*4] //FPC
        mov     ebx,[edx]
        mov     ecx,Filt_I
        mov     [ebx+ecx*4],eax
        imul    dword ptr [edi]
        mov     [esp],eax
        mov     [esp+4],edx
@lp:    dec     ecx
        jns     @gz
        mov     ecx,Filt_M
//        sets    al
//        dec     eax


@gz:    mov     eax,[ebx+ecx*4]
        add     edi,4
        imul    dword ptr [edi]
        add     [esp],eax
        adc     [esp+4],edx
        cmp     edi,esi
        jnz     @lp
        mov     Filt_I,ecx
        pop     eax
        pop     edx
        pop     edi
        pop     esi
        pop     ebx
        test    edx,edx
        jns     @nm
        add     eax,0FFFFFFh
        adc     edx,0
@nm:    shrd    eax,edx,24
end;
{$else} *)
var
 Res: int64;
 j: integer;
begin
 Filt_X[Filt_I] := Lev;
 Res := int64(Lev) * int64(Filt_K[0]);
 for j := 1 to Filt_M do
  begin
   if Filt_I > 0 then
     Dec(Filt_I)
   else
     Filt_I := Filt_M;
   Inc(Res, int64(Filt_X[Filt_I]) * int64(Filt_K[j]));
  end;
 Result := Res div $1000000;
 //{$endif}
end;

procedure TBufferMaker.Synthesizer_Stereo16(Buf: pointer);
var
 i: integer;
begin
 repeat
   LevelL := 0;
   LevelR := 0;
   if Tick_Counter.Re >= Tik.Re then
    begin
     repeat
       if IsFilt > 0 then
        begin
         i := Tik.Re - Tick_Counter.Re + 65536;
         PS16(Buf)[BufferLength].Left := Interpolator16(Left_Chan, PrevLeft, i);
         PS16(Buf)[BufferLength].Right := Interpolator16(Right_Chan, PrevRight, i);
        end
       else
        begin
         PS16(Buf)[BufferLength].Left := Averager16(Left_Chan1, Tick_Counter.Hi);
         PS16(Buf)[BufferLength].Right := Averager16(Right_Chan1, Tick_Counter.Hi);
        end;
       Inc(Tik.Re, integer(Delay_In_Tiks));
       visualisation_check;
       Inc(BufferLength);
       if BufferLength = BufferLengthMax then
        begin
         if Current_Tik < Number_Of_Tiks.Hi then
           IntFlag := True;
         Exit;
        end;
     until Tick_Counter.Re < Tik.Re; //simple upsampler
     Dec(Tik.Re, Tick_Counter.Re);
     Left_Chan1 := 0;
     Right_Chan1 := 0;
     Tick_Counter.Re := 0;
    end;

   for i := 0 to Length(Players) - 1 do
     with Players[i]^ do
      begin
       SoundChip.Synthesizer_Logic_Q;
       SoundChip.Synthesizer_Mixer_Q(LevelL, LevelR, Levels);
      end;

   if IsFilt >= 0 then
    begin
     i := Filt_I;
     LevelL := ApplyFilter(LevelL, Filt_XL);
     Filt_I := i;
     LevelR := ApplyFilter(LevelR, Filt_XR);
    end;

   PrevLeft := Left_Chan;
   Left_Chan := LevelL;
   Inc(Left_Chan1, LevelL);
   PrevRight := Right_Chan;
   Right_Chan := LevelR;
   Inc(Right_Chan1, LevelR);

   Inc(Current_Tik);
   Inc(Tick_Counter.Hi);
 until Current_Tik >= Number_Of_Tiks.Hi;
 Number_Of_Tiks.Hi := 0;
 Current_Tik := 0;
end;

procedure TBufferMaker.Synthesizer_Stereo8(Buf: pointer);
var
 i: integer;
begin
 repeat
   LevelL := 0;
   LevelR := 0;
   if Tick_Counter.Re >= Tik.Re then
    begin
     repeat
       if IsFilt > 0 then
        begin
         i := Tik.Re - Tick_Counter.Re + 65536;
         PS8(Buf)[BufferLength].Left := Interpolator8(Left_Chan, PrevLeft, i);
         PS8(Buf)[BufferLength].Right := Interpolator8(Right_Chan, PrevRight, i);
        end
       else
        begin
         PS8(Buf)[BufferLength].Left := Averager8(Left_Chan1, Tick_Counter.Hi);
         PS8(Buf)[BufferLength].Right := Averager8(Right_Chan1, Tick_Counter.Hi);
        end;
       Inc(Tik.Re, integer(Delay_In_Tiks));
       visualisation_check;
       Inc(BufferLength);
       if BufferLength = BufferLengthMax then
        begin
         if Current_Tik < Number_Of_Tiks.Hi then
           IntFlag := True;
         Exit;
        end
     until Tick_Counter.Re < Tik.Re; //simple upsampler
     Dec(Tik.Re, Tick_Counter.Re);
     Left_Chan1 := 0;
     Right_Chan1 := 0;
     Tick_Counter.Re := 0;
    end;

   for i := 0 to Length(Players) - 1 do
     with Players[i]^ do
      begin
       SoundChip.Synthesizer_Logic_Q;
       SoundChip.Synthesizer_Mixer_Q(LevelL, LevelR, Levels);
      end;

   if IsFilt >= 0 then
    begin
     i := Filt_I;
     LevelL := ApplyFilter(LevelL, Filt_XL);
     Filt_I := i;
     LevelR := ApplyFilter(LevelR, Filt_XR);
    end;

   PrevLeft := Left_Chan;
   Left_Chan := LevelL;
   Inc(Left_Chan1, LevelL);
   PrevRight := Right_Chan;
   Right_Chan := LevelR;
   Inc(Right_Chan1, LevelR);

   Inc(Current_Tik);
   Inc(Tick_Counter.Hi);
 until Current_Tik >= Number_Of_Tiks.Hi;
 Number_Of_Tiks.hi := 0;
 Current_Tik := 0;
end;

procedure TBufferMaker.Synthesizer_Mono16(Buf: pointer);
var
 i: integer;
begin
 repeat
   LevelL := 0;
   if Tick_Counter.Re >= Tik.Re then
    begin
     repeat
       if IsFilt > 0 then
         PM16(Buf)[BufferLength] :=
           Interpolator16(Left_Chan, PrevLeft, Tik.Re - Tick_Counter.Re + 65536)
       else
         PM16(Buf)[BufferLength] := Averager16(Left_Chan1, Tick_Counter.Hi);
       Inc(Tik.Re, integer(Delay_In_Tiks));
       visualisation_check;
       Inc(BufferLength);
       if BufferLength = BufferLengthMax then
        begin
         if Current_Tik < Number_Of_Tiks.Hi then
           IntFlag := True;
         exit;
        end
     until Tick_Counter.Re < Tik.Re; //simple upsampler
     Dec(Tik.Re, Tick_Counter.Re);
     Left_Chan1 := 0;
     Tick_Counter.Re := 0;
    end;

   for i := 0 to Length(Players) - 1 do
     with Players[i]^ do
      begin
       SoundChip.Synthesizer_Logic_Q;
       SoundChip.Synthesizer_Mixer_Q_Mono(LevelL, Levels);
      end;

   if IsFilt >= 0 then
     LevelL := ApplyFilter(LevelL, Filt_XL);

   PrevLeft := Left_Chan;
   Left_Chan := LevelL;
   Inc(Left_Chan1, LevelL);

   Inc(Current_Tik);
   Inc(Tick_Counter.Hi);
 until Current_Tik >= Number_Of_Tiks.Hi;
 Number_Of_Tiks.hi := 0;
 Current_Tik := 0;
end;

procedure TBufferMaker.Synthesizer_Mono8(Buf: pointer);
var
 i: integer;
begin
 repeat
   LevelL := 0;
   if Tick_Counter.Re >= Tik.Re then
    begin
     repeat
       if IsFilt > 0 then
         PM8(Buf)[BufferLength] :=
           Interpolator8(Left_Chan, PrevLeft, Tik.Re - Tick_Counter.Re + 65536)
       else
         PM8(Buf)[BufferLength] := Averager8(Left_Chan1, Tick_Counter.Hi);
       Inc(Tik.Re, integer(Delay_In_Tiks));
       visualisation_check;
       Inc(BufferLength);
       if BufferLength = BufferLengthMax then
        begin
         if Current_Tik < Number_Of_Tiks.Hi then
           IntFlag := True;
         exit;
        end
     until Tick_Counter.Re < Tik.Re; //simple upsampler
     Dec(Tik.Re, Tick_Counter.Re);
     Left_Chan1 := 0;
     Tick_Counter.Re := 0;
    end;

   for i := 0 to Length(Players) - 1 do
     with Players[i]^ do
      begin
       SoundChip.Synthesizer_Logic_Q;
       SoundChip.Synthesizer_Mixer_Q_Mono(LevelL, Levels);
      end;

   if IsFilt >= 0 then
     LevelL := ApplyFilter(LevelL, Filt_XL);

   PrevLeft := Left_Chan;
   Left_Chan := LevelL;
   Inc(Left_Chan1, LevelL);

   Inc(Current_Tik);
   Inc(Tick_Counter.Hi);
 until Current_Tik >= Number_Of_Tiks.Hi;
 Number_Of_Tiks.Hi := 0;
 Current_Tik := 0;
end;

procedure TBufferMaker.Reset;
var
 i: integer;
begin
 for i := 0 to Length(Players) - 1 do
   Players[i]^.SoundChip.Reset;
 Number_Of_Tiks.Re := 0;
 Current_Tik := 0;
end;

procedure TBufferMaker.InitSoundChipEmulation;
begin
 PrevLeft := 0;
 PrevRight := 0;
 Left_Chan := 0;
 Right_Chan := 0;
 Left_Chan1 := 0;
 Right_Chan1 := 0;
 Tick_Counter.Re := 0;
 Tik.Re := Delay_In_Tiks;
 IntFlag := False;
end;

procedure TBufferMaker.SynthesizerZX50(Buf: pointer);
begin
 if not IntFlag then
   Number_Of_Tiks.hi := AY_Tiks_In_Interrupt
 else
   IntFlag := False;
 Synthesizer(Buf);
end;

procedure TBufferMaker.MakeBufferTracker(Buf: pointer);
var
 i: integer;
begin
 BufferLength := 0;
 if IntFlag then
   SynthesizerZX50(Buf);
 if IntFlag then
   Exit;
 if LineReady then
  begin
   LineReady := False;
   SynthesizerZX50(Buf);
  end;
 while not Real_End_All and (BufferLength < BufferLengthMax) do
  begin
   Real_End_All := True;
   for i := 0 to Length(Players) - 1 do
     with Players[i]^ do
      begin
       Get_Registers(ForPlayback);
       Real_End_All := Real_End_All and Real_End;
      end;
   if not Real_End_All then
     SynthesizerZX50(Buf);
  end;
end;

procedure SetPlaybackBufferLength;
begin
 with PlaybackBufferMaker do
  begin
   BufferLengthMax := BufLen_ms * VTOptions.SampleRate div 1000;
   VisPosMax := round(BufferLengthMax * NumberOfBuffers / VisTicksStep) + 1;
   VisTicksMax := VisTicksStep * VisPosMax;
   SetLength(VisParams, VisPosMax);
  end;
end;

procedure SetBuffers(len, num: integer);
begin
 if digsoundthread_active then
   Exit;
 if (num < 2) or (num > 10) then
   Exit;
 if (len < 5) or (len > 2000) then
   Exit;
 BufLen_ms := len;
 NumberOfBuffers := num;
 SetPlaybackBufferLength;
end;

procedure Set_Sample_Rate(SR: integer);
begin
 if IsPlaying then exit;
 if not ((SR >= 8000) and (SR < 300000)) then exit;
 VTOptions.SampleRate := SR;
 VisTicksStep := round(SR / 100);
 SetPlaybackBufferLength;
 Delay_In_Tiks := round(8192 / SR * VTOptions.AY_Freq);
 SetFilter(VTOptions.FilterWant);
end;

procedure TBufferMaker.SetSynthesizer;
begin
 if VTOptions.NumberOfChannels = 2 then
  begin
   if VTOptions.SampleBit = 8 then
     Synthesizer := @Synthesizer_Stereo8
   else
     Synthesizer := @Synthesizer_Stereo16;
  end
 else if VTOptions.SampleBit = 8 then
   Synthesizer := @Synthesizer_Mono8
 else
   Synthesizer := @Synthesizer_Mono16;
end;

procedure Set_Sample_Bit(SB: integer);
begin
 if IsPlaying then
   Exit;
 VTOptions.SampleBit := SB;
 with PlaybackBufferMaker do
  begin
   SetSynthesizer;
   Calculate_Level_Tables;
  end;
end;

procedure Set_Stereo(St: integer);
begin
 if IsPlaying then
   Exit;
 VTOptions.NumberOfChannels := St;
 with PlaybackBufferMaker do
  begin
   SetSynthesizer;
   Calculate_Level_Tables;
  end;
end;

procedure Set_Chip_Frq(Fr: integer);
begin
 if (Fr >= 1000000) and (Fr <= 3546800) then
  begin
   digsoundloop_catch;
    try
     VTOptions.AY_Freq := Fr;
     Delay_In_Tiks := round(8192 / VTOptions.SampleRate * Fr);
     PlaybackBufferMaker.Tik.Re := Delay_In_Tiks;
     AY_Tiks_In_Interrupt := round(Fr / (VTOptions.Interrupt_Freq / 1000 * 8));
     SetFilter(VTOptions.FilterWant);
    finally
     digsoundloop_release;
    end;
  end;
end;

procedure Set_Player_Frq(Fr: integer);
begin
 if (Fr >= 1000) and (Fr <= 2000000) then
  begin
   digsoundloop_catch;
    try
     VTOptions.Interrupt_Freq := Fr;
     AY_Tiks_In_Interrupt := trunc(VTOptions.AY_Freq / (Fr / 1000 * 8) + 0.5);
    finally
     digsoundloop_release;
    end;
  end;
end;

procedure CalcFiltKoefs;
const
 MaxF = 9200;
var
 i: integer;
 K, F, C, i2, Filt_M2: double;
 FKt: array of double;
begin
 //Work range [0..MaxF)
 //Range [MaxF..SampleRate / 2) is easy cut-off from 0 to -53 dB
 //Cut-off range is [SampleRate / 2.. AY_Freq div 8 / 2] (-53 dB)
 //for Ay_Freq = 1773400 Hz:
(*
Полезная область - 0..11083,75 Гц (10)
221675->44100 - 67 (коэффициентов)
221675->48000 - 57
221675->96000 - 20
221675->110000 - 17

Полезная область - 0..10076,14 (11)
221675->22050 - 771

Полезная область - 0..9236,46 (12)
221675->22050 - 409

Полезная область - 0..8525,96 (13)
221675->22050 - 293
*)
 IsFilt := 0;
 C := 22050;
 if VTOptions.SampleRate >= 44100 then
  begin
   C := VTOptions.SampleRate / 2;
   Inc(IsFilt);
  end;
 Filt_M := round(3.3 / (C - MaxF) * (VTOptions.AY_Freq div 8));
 if VTOptions.AY_Freq * Filt_M > 3500000 * 50 then //90% of usage for my Celeron 850 MHz
  begin
   Filt_M := round(3500000 * 50 / VTOptions.AY_Freq);
   IsFilt := 0;
  end;
 C := Pi * (MaxF + C) / (VTOptions.AY_Freq div 8);
 SetLength(FKt, Filt_M);
 Filt_M2 := (Filt_M - 1) / 2;
 K := 0;
 for i := 0 to Filt_M - 1 do
  begin
   i2 := i - Filt_M2;
   if i2 = 0 then
     F := C
   else
     F := sin(C * i2) / i2 * (0.54 + 0.46 * cos(2 * Pi / Filt_M * i2));
   FKt[i] := F;
   K := K + F;
  end;
 SetLength(Filt_K, Filt_M);
 for i := 0 to Filt_M - 1 do
   Filt_K[i] := round(FKt[i] / K * $1000000);
 FiltInfo := Mes_FIR + ' (' + IntToStr(Filt_M) + ' ' + Mes_PTS + ')';
 if IsFilt = 0 then FiltInfo := FiltInfo + ' + ' + LowerCase(Mes_Averager);
 Dec(Filt_M);
end;

procedure TBufferMaker.InitFilter;
begin
 if IsFilt < 0 then
  begin
   Filt_XL := nil;
   Filt_XR := nil;
  end
 else
  begin
   SetLength(Filt_XL, Filt_M + 1);
   SetLength(Filt_XR, Filt_M + 1);
   FillChar(Filt_XL[0], (Filt_M + 1) * 4, 0);
   FillChar(Filt_XR[0], (Filt_M + 1) * 4, 0);
   Filt_I := 0;
  end;
end;

procedure SetFilter(Filt: boolean);
begin
 digsoundloop_catch;
  try
   VTOptions.FilterWant := Filt;
   if not Filt or (VTOptions.SampleRate >= VTOptions.AY_Freq div 8) then
    begin
     IsFilt := -1;
     Filt_K := nil;
     PlaybackBufferMaker.InitFilter;
     FiltInfo := Mes_Averager;
    end
   else
    begin
     CalcFiltKoefs;
     PlaybackBufferMaker.InitFilter;
    end;
  finally
   digsoundloop_release;
  end;
end;

procedure TBufferMaker.InitForAllTypes;
var
 i: integer;
begin
 Reset;
 for i := Length(Players) - 1 downto 0 do
   with Players[i]^ do
    begin
     InitPlayerVars;
     Real_End := False;
    end;
 Real_End_All := False;
 LineReady := False;
 InitFilter;
 if ForPlayback then
   visualisation_reset;
 InitSoundChipEmulation;
end;

procedure TBufferMaker.Calculate_Level_Tables;
var
 i, b, l, r: integer;
 Index_A, Index_B, Index_C: integer;
 k: real;
begin
 if VTOptions.NumberOfChannels = 2 then
  begin
   Index_A := Index_AL;
   Index_B := Index_BL;
   Index_C := Index_CL;
   l := (Index_AL + Index_BL + Index_CL) * 2;
   r := (Index_AR + Index_BR + Index_CR) * 2;
   if l < r then
     l := r;
  end
 else
  begin
   Index_A := Index_AL + Index_AR;
   Index_B := Index_BL + Index_BR;
   Index_C := Index_CL + Index_CR;
   l := (Index_A + Index_B + Index_C) * 2;
  end;
 if l = 0 then
   Inc(l);
 if VTOptions.SampleBit = 8 then
   r := 127
 else
   r := 32767;
 if ForPlayback then
   //use volume for playback only
   k := exp(GlobalVolume * ln(2) / GlobalVolumeMax) - 1
 else
   k := 1;
 with Levels do
   case VTOptions.ChipType of
     AY_Chip:
       for i := 0 to 15 do
        begin
         b := trunc(Index_A / l * Amplitudes_AY[i] / 65535 * r * k + 0.5);
         Level_AL[i * 2] := b;
         Level_AL[i * 2 + 1] := b;
         b := trunc(Index_AR / l * Amplitudes_AY[i] / 65535 * r * k + 0.5);
         Level_AR[i * 2] := b;
         Level_AR[i * 2 + 1] := b;
         b := trunc(Index_B / l * Amplitudes_AY[i] / 65535 * r * k + 0.5);
         Level_BL[i * 2] := b;
         Level_BL[i * 2 + 1] := b;
         b := trunc(Index_BR / l * Amplitudes_AY[i] / 65535 * r * k + 0.5);
         Level_BR[i * 2] := b;
         Level_BR[i * 2 + 1] := b;
         b := trunc(Index_C / l * Amplitudes_AY[i] / 65535 * r * k + 0.5);
         Level_CL[i * 2] := b;
         Level_CL[i * 2 + 1] := b;
         b := trunc(Index_CR / l * Amplitudes_AY[i] / 65535 * r * k + 0.5);
         Level_CR[i * 2] := b;
         Level_CR[i * 2 + 1] := b;
        end;
     YM_Chip:
       for i := 0 to 31 do
        begin
         Level_AL[i] := trunc(Index_A / l * Amplitudes_YM[i] / 65535 * r * k + 0.5);
         Level_AR[i] := trunc(Index_AR / l * Amplitudes_YM[i] / 65535 * r * k + 0.5);
         Level_BL[i] := trunc(Index_B / l * Amplitudes_YM[i] / 65535 * r * k + 0.5);
         Level_BR[i] := trunc(Index_BR / l * Amplitudes_YM[i] / 65535 * r * k + 0.5);
         Level_CL[i] := trunc(Index_C / l * Amplitudes_YM[i] / 65535 * r * k + 0.5);
         Level_CR[i] := trunc(Index_CR / l * Amplitudes_YM[i] / 65535 * r * k + 0.5);
        end;
    end;
end;

function Calculate_Channels_Allocation_Indexes: string;
var
 Echo: integer;
begin
 //prepare panning coeffs
 case VTOptions.ChipType of
   AY_Chip:
     Echo := 85
 else
   Echo := 13;
  end;
 case VTOptions.ChannelsAllocation of
   0:
    begin
     MidChan := 0;
     Result := 'Mono';
     Index_AL := 255;
     Index_AR := 255;
     Index_BL := 255;
     Index_BR := 255;
     Index_CL := 255;
     Index_CR := 255;
    end;
   1:
    begin
     MidChan := 1;
     Result := 'ABC';
     Index_AL := 255;
     Index_AR := Echo;
     Index_BL := 170;
     Index_BR := 170;
     Index_CL := Echo;
     Index_CR := 255;
    end;
   2:
    begin
     MidChan := 2;
     Result := 'ACB';
     Index_AL := 255;
     Index_AR := Echo;
     Index_CL := 170;
     Index_CR := 170;
     Index_BL := Echo;
     Index_BR := 255;
    end;
   3:
    begin
     MidChan := 0;
     Result := 'BAC';
     Index_BL := 255;
     Index_BR := Echo;
     Index_AL := 170;
     Index_AR := 170;
     Index_CL := Echo;
     Index_CR := 255;
    end;
   4:
    begin
     MidChan := 2;
     Result := 'BCA';
     Index_BL := 255;
     Index_BR := Echo;
     Index_CL := 170;
     Index_CR := 170;
     Index_AL := Echo;
     Index_AR := 255;
    end;
   5:
    begin
     MidChan := 0;
     Result := 'CAB';
     Index_CL := 255;
     Index_CR := Echo;
     Index_AL := 170;
     Index_AR := 170;
     Index_BL := Echo;
     Index_BR := 255;
    end;
   6:
    begin
     MidChan := 1;
     Result := 'CBA';
     Index_CL := 255;
     Index_CR := Echo;
     Index_BL := 170;
     Index_BR := 170;
     Index_AL := Echo;
     Index_AR := 255;
    end;
 else
   Result := '???';
  end;
end;

procedure TBufferMaker.visualisation_check;
begin
 if not ForPlayback then //exit if just converter
   Exit;
 if VisTicks = VisTicksPoint then
   visualisation_fill;
 Inc(VisTicks);
end;

procedure visualisation_fill;
var
 i, j: integer;
begin
 with PlaybackBufferMaker do
   for i := 0 to Length(Players) - 1 do
     with Players[i]^, VisParams[VisPos][i] do
      begin
       Pos := CurrentPosition;
       Pat := CurrentPattern;
       Lin := CurrentLine - 1; //always points to next line while playing current one
       EnvP := EnvP_Base;
       for j := 0 to 2 do
         with Chs[j], Chans[j] do
          begin
           Nt := Note;
           Smp := Sample;
           EnvT := EnvelopeEnabled;
           Orn := Ornament;
           Vol := Volume;
          end;
      end;
 Inc(VisPos);
 if VisPos >= VisPosMax then
   VisPos := 0;
 Inc(VisTicksPoint, VisTicksStep);
end;

procedure visualisation_reset;
begin
 VisPos := 0;
 VisTicksPoint := 0;
 VisTicks := 0;
end;

end.
