program vt_harness;
{
  Standalone FPC harness that generates Pascal-baseline JSON fixtures
  for the Vortex Tracker II Rust port.

  Faithfully implements key algorithmic functions from trfuncs.pas / AY.pas
  without any GUI, audio or Windows dependencies.

  (c) Original algorithms: S.V.Bulba, 2000-2009
  Harness wrapper: corbym/vtir project

  Build:  fpc -Mdelphi vt_harness.pas
  Usage:  ./vt_harness <test-name>
  Tests:  noise_lfsr | envelopes | pt3_vol | note_tables |
          pattern_basic | pattern_envelope
}
{$mode delphi}
{$H+}

uses SysUtils;

{ ═══════════════════════════════════════════════════════════════════════════
  Constants (from trfuncs.pas)
  ═══════════════════════════════════════════════════════════════════════════ }

const
  MaxPatLen    = 256;
  MaxSamLen    = 64;
  MaxOrnLen    = 255;
  MaxPatNum    = 84;
  MidChan      = 1;
  DefPatLen    = 64;

{ ═══════════════════════════════════════════════════════════════════════════
  Type declarations (mirroring trfuncs.pas exactly)
  ═══════════════════════════════════════════════════════════════════════════ }

type
  TSampleTick = record
    Add_to_Ton                    : SmallInt;
    Ton_Accumulation              : Boolean;
    Amplitude                     : Byte;
    Amplitude_Sliding             : Boolean;
    Amplitude_Slide_Up            : Boolean;
    Envelope_Enabled              : Boolean;
    Envelope_or_Noise_Accumulation: Boolean;
    Add_to_Envelope_or_Noise      : ShortInt;
    { false = sample does NOT mute tone channel  (mixer bit 0 stays 0 → tone on)  }
    { true  = sample mutes tone channel          (mixer bit 0 set   → tone off)   }
    Mixer_Ton                     : Boolean;
    { false = sample does NOT mute noise channel }
    { true  = sample mutes noise channel         }
    Mixer_Noise                   : Boolean;
  end;

  TSample = record
    Length, Loop : Byte;
    Enabled      : Boolean;
    Items        : array[0..MaxSamLen-1] of TSampleTick;
  end;
  PSample = ^TSample;

  TOrnament = record
    Items  : array[0..MaxOrnLen-1] of ShortInt;
    Length : Integer;
    Loop   : Integer;
  end;
  POrnament = ^TOrnament;

  TAdditionalCommand = record
    Number, Delay, Parameter : Byte;
  end;

  TChannelLine = record
    Note               : ShortInt; { 0..95=note, -1=none, -2=sound off }
    Sample             : Byte;     { 0=keep, 1..31=set }
    Ornament           : Byte;
    Volume             : ShortInt; { 0=keep, 1..15=set }
    Envelope           : Byte;     { 0=keep, 1..14=type, 15=off }
    Additional_Command : TAdditionalCommand;
  end;

  TPatternRow = record
    Noise    : Byte;
    Envelope : Word;
    Channel  : array[0..2] of TChannelLine;
  end;

  TPattern = record
    Length : Integer;
    Items  : array[0..MaxPatLen-1] of TPatternRow;
  end;
  PPattern = ^TPattern;

  TPosition = record
    Value  : array[0..255] of Integer;
    Length : Integer;
    Loop   : Integer;
  end;

  TIsChansEntry = record
    Global_Ton, Global_Noise, Global_Envelope : Boolean;
    EnvelopeEnabled                            : Boolean;
    Ornament, Sample, Volume                   : Byte;
  end;

  TModule = record
    Title, Author       : string;
    Ton_Table           : Byte;
    Initial_Delay       : Byte;
    Positions           : TPosition;
    Samples             : array[1..31] of PSample;
    Ornaments           : array[0..15] of POrnament;
    Patterns            : array[-1..MaxPatNum] of PPattern;
    FeaturesLevel       : Integer;
    VortexModule_Header : Boolean;
    IsChans             : array[0..2] of TIsChansEntry;
  end;
  PModule = ^TModule;

{ ─── AY chip state (minimal subset of TSoundChip from AY.pas) ─── }

  TEnvShape = (
    esHold0,     { types 0-3, 9     }
    esHold31,    { types 4-7, 15    }
    esSaw8,      { type 8           }
    esTriangle10,{ type 10          }
    esDecayHold, { type 11          }
    esSaw12,     { type 12          }
    esAttackHold,{ type 13          }
    esTriangle14 { type 14          }
  );

  TAYRegisters = record
    TonA, TonB, TonC          : Word;
    Noise, Mixer              : Byte;
    AmplitudeA, AmplitudeB, AmplitudeC : Byte;
    Envelope                  : Word;
    EnvType                   : Byte;
  end;

  TChipState = record
    AYReg        : TAYRegisters;
    FirstPeriod  : Boolean;
    Ampl         : Integer;
    EnvEnA, EnvEnB, EnvEnC : Boolean;
    Shape        : TEnvShape;
  end;

{ ─── PlVars anonymous inner type ─── }

  TParamsOfChan = record
    SamplePosition, OrnamentPosition   : Byte;
    SoundEnabled                        : Boolean;
    Slide_To_Note, Note                 : Byte;
    Ton_Slide_Delay, Ton_Slide_Count    : ShortInt;
    Ton_Slide_Step, Ton_Slide_Delta     : SmallInt;
    Ton_Slide_Type                      : Integer;
    Current_Ton_Sliding                 : SmallInt;
    OnOff_Delay, OffOn_Delay, Current_OnOff : ShortInt;
    Ton, Ton_Accumulator                : Word;
    Amplitude                           : Byte;
    Current_Amplitude_Sliding           : ShortInt;
    Current_Envelope_Sliding            : ShortInt;
    Current_Noise_Sliding               : ShortInt;
  end;

  TPlVars = record
    CurrentPosition, CurrentPattern, CurrentLine : Integer;
    Env_Base        : SmallInt;
    ParamsOfChan    : array[0..2] of TParamsOfChan;
    Delay, DelayCounter   : ShortInt;
    Cur_Env_Slide         : SmallInt;
    Cur_Env_Delay         : ShortInt;
    Env_Delay             : ShortInt;
    Env_Slide_Add         : SmallInt;
    AddToEnv, AddToNoise  : ShortInt;
    PT3Noise              : Byte;
    IntCnt                : Integer;
  end;

{ ═══════════════════════════════════════════════════════════════════════════
  ZX Spectrum module container  (subset of TSpeccyModule from trfuncs.pas)
  ═══════════════════════════════════════════════════════════════════════════ }

type
  { Minimal subset of Available_Types needed for PrepareZXModule }
  Available_Types = (
    Unknown, VTMFile, STCFile, STPFile, STFFile, PTCFile, PT3File, PT2File,
    PT1File, STXFile, ASCFile, ASCOFile, PSCFile, FLSFile, GTRFile, AYFile,
    ST1File, STCEFile, ST3File, FTCFile, PSMFile, SQTFile, FXMFile
  );

  { Variant record matching the memory layout in trfuncs.pas.
    Only variants 5 (SQT) and 9 (FLS) are used by PrepareZXModule in this
    harness; all others are included to keep the ordinals correct. }
  PSpeccyModule = ^TSpeccyModule;
  TSpeccyModule = packed record
    case integer of
      0: (Index: array[0..65535] of byte);
      5: (SQT_Size, SQT_SamplesPointer, SQT_OrnamentsPointer,
          SQT_PatternsPointer, SQT_PositionsPointer, SQT_LoopPointer: word);
      9: (FLS_PositionsPointer: word;
          FLS_OrnamentsPointer: word;
          FLS_SamplesPointer: word;
          FLS_PatternsPointers: array[1..(65536 - 6) div 6] of packed record
            PatternA, PatternB, PatternC: word;
          end);
  end;

{ ─── PrepareZXModule — exact port from trfuncs.pas ─────────────────────── }
procedure PrepareZXModule(ZXP: PSpeccyModule; var FType: Available_Types;
                          Length: integer);
var
  i, j, k, i1, i2: integer;
  pwrd: PWord;
  p1, p2: pointer;
begin
  case FType of
    FLSFile:
      begin
        i := ZXP^.FLS_OrnamentsPointer - 16;
        if i >= 0 then
          repeat
            i2 := ZXP^.FLS_SamplesPointer + 2 - i;
            if (i2 >= 8) and (i2 < Length) then
            begin
              pwrd := @ZXP^.Index[i2];
              i1 := pwrd^ - i;
              if (i1 >= 8) and (i1 < Length) then
              begin
                pwrd := @ZXP^.Index[i2 - 4];
                i2 := pwrd^ - i;
                if (i2 >= 6) and (i2 < Length) then
                  if i1 - i2 = $20 then
                  begin
                    i2 := ZXP^.FLS_PatternsPointers[1].PatternB - i;
                    if (i2 > 21) and (i2 < Length) then
                    begin
                      i1 := ZXP^.FLS_PatternsPointers[1].PatternA - i;
                      if (i1 > 20) and (i1 < Length) then
                        if ZXP^.Index[i1 - 1] = 0 then
                        begin
                          while (i1 < Length) and (ZXP^.Index[i1] <> 255) do
                          begin
                            repeat
                              case ZXP^.Index[i1] of
                                0..$5f, $80, $81:
                                begin
                                  Inc(i1);
                                  break;
                                end;
                                $82..$8e:
                                  Inc(i1)
                              end;
                              Inc(i1);
                            until i1 >= Length;
                          end;
                          if i1 + 1 = i2 then
                            break;
                        end;
                    end;
                  end;
              end;
            end;
            Dec(i)
          until i < 0;
        if i < 0 then
          FType := Unknown
        else
        begin
          pwrd := pointer(ZXP);
          p1 := @pbyte(pwrd)[ZXP^.FLS_SamplesPointer - i];
          p2 := @pbyte(pwrd)[ZXP^.FLS_PositionsPointer - i + 2];
          repeat
            Dec(pwrd^, i);
            Inc(pwrd);
          until p1 = pwrd;
          Inc(pwrd);
          repeat
            Dec(pwrd^, i);
            Inc(pwrd, 2);
          until p2 = pwrd;
        end;
      end;
    SQTFile:
      begin
        i := ZXP^.SQT_SamplesPointer - 10;
        j := 0;
        k := ZXP^.SQT_PositionsPointer - i;
        while ZXP^.Index[k] <> 0 do
        begin
          if j < ZXP^.Index[k] and $7f then
            j := ZXP^.Index[k] and $7f;
          Inc(k, 2);
          if j < ZXP^.Index[k] and $7f then
            j := ZXP^.Index[k] and $7f;
          Inc(k, 2);
          if j < ZXP^.Index[k] and $7f then
            j := ZXP^.Index[k] and $7f;
          Inc(k, 3);
        end;
        pwrd := @ZXP^.SQT_SamplesPointer;
        for k := 1 to (ZXP^.SQT_PatternsPointer - i + j shl 1) div 2 do
        begin
          Dec(pwrd^, i);
          Inc(pwrd);
        end;
      end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Note tables and volume table  (verbatim from trfuncs.pas constants)
  ═══════════════════════════════════════════════════════════════════════════ }

type
  PT3ToneTable = array[0..95] of Word;

const
  PT3NoteTable_PT: PT3ToneTable = (
    $0C22,$0B73,$0ACF,$0A33,$09A1,$0917,$0894,$0819,$07A4,$0737,$06CF,$066D,
    $0611,$05BA,$0567,$051A,$04D0,$048B,$044A,$040C,$03D2,$039B,$0367,$0337,
    $0308,$02DD,$02B4,$028D,$0268,$0246,$0225,$0206,$01E9,$01CE,$01B4,$019B,
    $0184,$016E,$015A,$0146,$0134,$0123,$0112,$0103,$00F5,$00E7,$00DA,$00CE,
    $00C2,$00B7,$00AD,$00A3,$009A,$0091,$0089,$0082,$007A,$0073,$006D,$0067,
    $0061,$005C,$0056,$0052,$004D,$0049,$0045,$0041,$003D,$003A,$0036,$0033,
    $0031,$002E,$002B,$0029,$0027,$0024,$0022,$0020,$001F,$001D,$001B,$001A,
    $0018,$0017,$0016,$0014,$0013,$0012,$0011,$0010,$000F,$000E,$000D,$000C);

  PT3NoteTable_ST: PT3ToneTable = (
    $0EF8,$0E10,$0D60,$0C80,$0BD8,$0B28,$0A88,$09F0,$0960,$08E0,$0858,$07E0,
    $077C,$0708,$06B0,$0640,$05EC,$0594,$0544,$04F8,$04B0,$0470,$042C,$03FD,
    $03BE,$0384,$0358,$0320,$02F6,$02CA,$02A2,$027C,$0258,$0238,$0216,$01F8,
    $01DF,$01C2,$01AC,$0190,$017B,$0165,$0151,$013E,$012C,$011C,$010A,$00FC,
    $00EF,$00E1,$00D6,$00C8,$00BD,$00B2,$00A8,$009F,$0096,$008E,$0085,$007E,
    $0077,$0070,$006B,$0064,$005E,$0059,$0054,$004F,$004B,$0047,$0042,$003F,
    $003B,$0038,$0035,$0032,$002F,$002C,$002A,$0027,$0025,$0023,$0021,$001F,
    $001D,$001C,$001A,$0019,$0017,$0016,$0015,$0013,$0012,$0011,$0010,$000F);

  PT3NoteTable_ASM: PT3ToneTable = (
    $0D10,$0C55,$0BA4,$0AFC,$0A5F,$09CA,$093D,$08B8,$083B,$07C5,$0755,$06EC,
    $0688,$062A,$05D2,$057E,$052F,$04E5,$049E,$045C,$041D,$03E2,$03AB,$0376,
    $0344,$0315,$02E9,$02BF,$0298,$0272,$024F,$022E,$020F,$01F1,$01D5,$01BB,
    $01A2,$018B,$0174,$0160,$014C,$0139,$0128,$0117,$0107,$00F9,$00EB,$00DD,
    $00D1,$00C5,$00BA,$00B0,$00A6,$009D,$0094,$008C,$0084,$007C,$0075,$006F,
    $0069,$0063,$005D,$0058,$0053,$004E,$004A,$0046,$0042,$003E,$003B,$0037,
    $0034,$0031,$002F,$002C,$0029,$0027,$0025,$0023,$0021,$001F,$001D,$001C,
    $001A,$0019,$0017,$0016,$0015,$0014,$0012,$0011,$0010,$000F,$000E,$000D);

  PT3NoteTable_REAL: PT3ToneTable = (
    $0CDA,$0C22,$0B73,$0ACF,$0A33,$09A1,$0917,$0894,$0819,$07A4,$0737,$06CF,
    $066D,$0611,$05BA,$0567,$051A,$04D0,$048B,$044A,$040C,$03D2,$039B,$0367,
    $0337,$0308,$02DD,$02B4,$028D,$0268,$0246,$0225,$0206,$01E9,$01CE,$01B4,
    $019B,$0184,$016E,$015A,$0146,$0134,$0123,$0112,$0103,$00F5,$00E7,$00DA,
    $00CE,$00C2,$00B7,$00AD,$00A3,$009A,$0091,$0089,$0082,$007A,$0073,$006D,
    $0067,$0061,$005C,$0056,$0052,$004D,$0049,$0045,$0041,$003D,$003A,$0036,
    $0033,$0031,$002E,$002B,$0029,$0027,$0024,$0022,$0020,$001F,$001D,$001B,
    $001A,$0018,$0017,$0016,$0014,$0013,$0012,$0011,$0010,$000F,$000E,$000D);

  PT3NoteTable_NATURAL: PT3ToneTable = (
    2880,2700,2560,2400,2304,2160,2025,1920,1800,1728,1620,1536,
    1440,1350,1280,1200,1152,1080,1013, 960, 900, 864, 810, 768,
     720, 675, 640, 600, 576, 540, 506, 480, 450, 432, 405, 384,
     360, 338, 320, 300, 288, 270, 253, 240, 225, 216, 203, 192,
     180, 169, 160, 150, 144, 135, 127, 120, 113, 108, 101,  96,
      90,  84,  80,  75,  72,  68,  63,  60,  56,  54,  51,  48,
      45,  42,  40,  38,  36,  34,  32,  30,  28,  27,  25,  24,
      23,  21,  20,  19,  18,  17,  16,  15,  14,  14,  13,  12);

  PT3_Vol: array[0..15, 0..15] of Byte = (
    ($00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00),
    ($00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01),
    ($00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02),
    ($00,$00,$00,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$03,$03,$03),
    ($00,$00,$01,$01,$01,$01,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04),
    ($00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$04,$05,$05),
    ($00,$00,$01,$01,$02,$02,$02,$03,$03,$04,$04,$04,$05,$05,$06,$06),
    ($00,$00,$01,$01,$02,$02,$03,$03,$04,$04,$05,$05,$06,$06,$07,$07),
    ($00,$01,$01,$02,$02,$03,$03,$04,$04,$05,$05,$06,$06,$07,$07,$08),
    ($00,$01,$01,$02,$02,$03,$04,$04,$05,$05,$06,$07,$07,$08,$08,$09),
    ($00,$01,$01,$02,$03,$03,$04,$05,$05,$06,$07,$07,$08,$09,$09,$0A),
    ($00,$01,$01,$02,$03,$04,$04,$05,$06,$07,$07,$08,$09,$0A,$0A,$0B),
    ($00,$01,$02,$02,$03,$04,$05,$06,$06,$07,$08,$09,$0A,$0A,$0B,$0C),
    ($00,$01,$02,$03,$03,$04,$05,$06,$07,$08,$09,$0A,$0A,$0B,$0C,$0D),
    ($00,$01,$02,$03,$04,$05,$06,$07,$07,$08,$09,$0A,$0B,$0C,$0D,$0E),
    ($00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F));

{ ═══════════════════════════════════════════════════════════════════════════
  Global state
  ═══════════════════════════════════════════════════════════════════════════ }

var
  VTM      : PModule;
  CurChip  : Integer = 1;
  SoundChip: array[1..2] of TChipState;
  PlVars   : array[1..2] of TPlVars;

{ ═══════════════════════════════════════════════════════════════════════════
  AY chip register helpers  (mirrors TSoundChip methods in AY.pas)
  ═══════════════════════════════════════════════════════════════════════════ }

procedure SetMixerRegister(Chip: Integer; Value: Byte);
begin
  SoundChip[Chip].AYReg.Mixer := Value;
end;

procedure SetAmplA(Chip: Integer; Value: Byte);
begin
  SoundChip[Chip].AYReg.AmplitudeA := Value;
  SoundChip[Chip].EnvEnA := (Value and 16) <> 0;
end;

procedure SetAmplB(Chip: Integer; Value: Byte);
begin
  SoundChip[Chip].AYReg.AmplitudeB := Value;
  SoundChip[Chip].EnvEnB := (Value and 16) <> 0;
end;

procedure SetAmplC(Chip: Integer; Value: Byte);
begin
  SoundChip[Chip].AYReg.AmplitudeC := Value;
  SoundChip[Chip].EnvEnC := (Value and 16) <> 0;
end;

procedure SetEnvelopeRegister(Chip: Integer; Value: Byte);
begin
  SoundChip[Chip].AYReg.EnvType := Value;
  SoundChip[Chip].FirstPeriod := True;
  if (Value and 4) = 0 then
    SoundChip[Chip].Ampl := 32
  else
    SoundChip[Chip].Ampl := -1;
  case Value of
    0,1,2,3,9  : SoundChip[Chip].Shape := esHold0;
    4,5,6,7,15 : SoundChip[Chip].Shape := esHold31;
    8           : SoundChip[Chip].Shape := esSaw8;
    10          : SoundChip[Chip].Shape := esTriangle10;
    11          : SoundChip[Chip].Shape := esDecayHold;
    12          : SoundChip[Chip].Shape := esSaw12;
    13          : SoundChip[Chip].Shape := esAttackHold;
    14          : SoundChip[Chip].Shape := esTriangle14;
  else
    SoundChip[Chip].Shape := esHold0;
  end;
end;

{ Step envelope by one AY clock tick — direct port of TSoundChip.Case_EnvType_* }
procedure StepEnvelope(Chip: Integer);
var C: Integer;
begin
  C := Chip;
  case SoundChip[C].Shape of
    esHold0:
      if SoundChip[C].FirstPeriod then
      begin
        Dec(SoundChip[C].Ampl);
        if SoundChip[C].Ampl = 0 then SoundChip[C].FirstPeriod := False;
      end;

    esHold31:
      if SoundChip[C].FirstPeriod then
      begin
        Inc(SoundChip[C].Ampl);
        if SoundChip[C].Ampl = 32 then
        begin
          SoundChip[C].FirstPeriod := False;
          SoundChip[C].Ampl := 0;
        end;
      end;

    esSaw8:
      SoundChip[C].Ampl := (SoundChip[C].Ampl - 1) and 31;

    esTriangle10:
      if SoundChip[C].FirstPeriod then
      begin
        Dec(SoundChip[C].Ampl);
        if SoundChip[C].Ampl < 0 then
        begin
          SoundChip[C].FirstPeriod := False;
          SoundChip[C].Ampl := 0;
        end;
      end
      else
      begin
        Inc(SoundChip[C].Ampl);
        if SoundChip[C].Ampl = 32 then
        begin
          SoundChip[C].FirstPeriod := True;
          SoundChip[C].Ampl := 31;
        end;
      end;

    esDecayHold:
      if SoundChip[C].FirstPeriod then
      begin
        Dec(SoundChip[C].Ampl);
        if SoundChip[C].Ampl < 0 then
        begin
          SoundChip[C].FirstPeriod := False;
          SoundChip[C].Ampl := 31;
        end;
      end;

    esSaw12:
      SoundChip[C].Ampl := (SoundChip[C].Ampl + 1) and 31;

    esAttackHold:
      if SoundChip[C].FirstPeriod then
      begin
        Inc(SoundChip[C].Ampl);
        if SoundChip[C].Ampl = 32 then
        begin
          SoundChip[C].FirstPeriod := False;
          SoundChip[C].Ampl := 31;
        end;
      end;

    esTriangle14:
      if not SoundChip[C].FirstPeriod then
      begin
        Dec(SoundChip[C].Ampl);
        if SoundChip[C].Ampl < 0 then
        begin
          SoundChip[C].FirstPeriod := True;
          SoundChip[C].Ampl := 0;
        end;
      end
      else
      begin
        Inc(SoundChip[C].Ampl);
        if SoundChip[C].Ampl = 32 then
        begin
          SoundChip[C].FirstPeriod := False;
          SoundChip[C].Ampl := 31;
        end;
      end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Pure-Pascal NoiseGenerator
  Replaces the x86 asm in AY.pas.

  The original asm in AY.pas uses two SHLD instructions to extract bits:
    shld edx,eax,16  — shifts edx left 16, the vacated low 16 bits come from
                       the high 16 bits of eax, so bit0(edx) = bit16(eax).
    shld ecx,eax,19  — shifts ecx left 19, the vacated low 19 bits come from
                       the high 19 bits of eax, so bit0(ecx) = bit13(eax).
    xor ecx,edx; and ecx,1  → feedback = bit13(seed) XOR bit16(seed)

  new_seed = ((seed shl 1) AND $1FFFF) OR 1 XOR feedback

  noise_val (used in mixer) = bytes 2-3 of Seed via the packed union:
    Noise.Val = (Seed shr 16) AND $FFFF  =  bit16 of seed (0 or 1 for 17-bit seed)
  ═══════════════════════════════════════════════════════════════════════════ }

function NoiseGenerator(Seed: LongWord): LongWord;
var
  feedback: LongWord;
begin
  feedback := ((Seed shr 13) xor (Seed shr 16)) and 1;
  Result := (((Seed shl 1) and $0001FFFF) or 1) xor feedback;
end;

function NoiseVal(Seed: LongWord): LongWord;
begin
  { Replicates Noise.Val from the packed-record union in TSoundChip:
    union layout: Seed (LongWord) at offset 0, Val (DWord) at offset 2
    → Val = bytes 2..5 of Seed = (Seed shr 16) for a 17-bit value }
  Result := (Seed shr 16) and $FFFF;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  GetNoteFreq  (verbatim logic from trfuncs.pas)
  ═══════════════════════════════════════════════════════════════════════════ }

function GetNoteFreq(t: Integer; j: Byte): Word;
begin
  if j > 95 then j := 95;
  case t of
    0: Result := PT3NoteTable_PT[j];
    1: Result := PT3NoteTable_ST[j];
    2: Result := PT3NoteTable_ASM[j];
    3: Result := PT3NoteTable_REAL[j];
  else
    Result := PT3NoteTable_NATURAL[j];
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  InitTrackerParameters  (verbatim from trfuncs.pas)
  ═══════════════════════════════════════════════════════════════════════════ }

procedure InitTrackerParameters(All: Boolean);
var
  k: Integer;
begin
  { Reset AY chip state (simplified — we only need register state) }
  SoundChip[CurChip].AYReg := Default(TAYRegisters);
  SetEnvelopeRegister(CurChip, 0);

  PlVars[CurChip].DelayCounter := 1;
  PlVars[CurChip].PT3Noise     := 0;
  PlVars[CurChip].Env_Base     := 0;
  PlVars[CurChip].IntCnt       := 0;

  if All then
    for k := 0 to 2 do
    begin
      VTM.IsChans[k].Sample          := 1;
      VTM.IsChans[k].EnvelopeEnabled := False;
      VTM.IsChans[k].Ornament        := 0;
      VTM.IsChans[k].Volume          := 15;
    end;

  for k := 0 to 2 do
    PlVars[CurChip].ParamsOfChan[k] := Default(TParamsOfChan);

  PlVars[CurChip].CurrentLine := 0;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Pattern_PlayOnlyCurrentLine  (verbatim from trfuncs.pas)
  ═══════════════════════════════════════════════════════════════════════════ }

procedure Pattern_PlayOnlyCurrentLine;
var
  TempMixer: Integer;

  { Nested procedure — accesses TempMixer from enclosing scope }
  procedure GetRegisters(ChNum: Integer);
  var
    j: Byte;
    w: Word;
    gt, gn, ge: Boolean;
  begin
    with PlVars[CurChip].ParamsOfChan[ChNum], VTM^.IsChans[ChNum] do
    begin
      if SoundEnabled then
      begin
        { ── Tone computation ── }
        if (VTM^.Samples[Sample] = nil) or
           (SamplePosition >= VTM^.Samples[Sample]^.Length) then
          Ton := 0
        else
        begin
          Ton := Ton_Accumulator + Word(VTM^.Samples[Sample]^.Items[SamplePosition].Add_to_Ton);
          if VTM^.Samples[Sample]^.Items[SamplePosition].Ton_Accumulation then
            Ton_Accumulator := Ton;
        end;

        { ── Ornament-adjusted note ── }
        if (VTM^.Ornaments[Ornament] = nil) or
           (OrnamentPosition >= VTM^.Ornaments[Ornament]^.Length) then
          j := Note
        else
          j := Note + Byte(VTM^.Ornaments[Ornament]^.Items[OrnamentPosition]);

        if ShortInt(j) < 0 then
          j := 0
        else if j > 95 then
          j := 95;

        w   := GetNoteFreq(VTM^.Ton_Table, j);
        Ton := (Ton + Word(Current_Ton_Sliding) + w) and $0FFF;

        { ── Glissando / tone-slide counter ── }
        if Ton_Slide_Count > 0 then
        begin
          Dec(Ton_Slide_Count);
          if Ton_Slide_Count = 0 then
          begin
            Inc(Current_Ton_Sliding, Ton_Slide_Step);
            Ton_Slide_Count := Ton_Slide_Delay;
            if Ton_Slide_Type = 1 then
              if ((Ton_Slide_Step < 0) and (Current_Ton_Sliding <= Ton_Slide_Delta)) or
                 ((Ton_Slide_Step >= 0) and (Current_Ton_Sliding >= Ton_Slide_Delta)) then
              begin
                Note            := Slide_To_Note;
                Ton_Slide_Count := 0;
                Current_Ton_Sliding := 0;
              end;
          end;
        end;

        { ── Amplitude computation ── }
        if (VTM^.Samples[Sample] = nil) or
           (SamplePosition >= VTM^.Samples[Sample]^.Length) then
          Amplitude := 0
        else
        begin
          Amplitude := VTM^.Samples[Sample]^.Items[SamplePosition].Amplitude;

          if VTM^.Samples[Sample]^.Items[SamplePosition].Amplitude_Sliding then
          begin
            if VTM^.Samples[Sample]^.Items[SamplePosition].Amplitude_Slide_Up then
            begin
              if Current_Amplitude_Sliding < 15 then Inc(Current_Amplitude_Sliding);
            end
            else
              if Current_Amplitude_Sliding > -15 then Dec(Current_Amplitude_Sliding);
          end;

          Inc(Amplitude, Byte(Current_Amplitude_Sliding));
          if ShortInt(Amplitude) < 0 then Amplitude := 0
          else if Amplitude > 15 then Amplitude := 15;

          Amplitude := PT3_Vol[Volume, Amplitude];

          if VTM^.Samples[Sample]^.Items[SamplePosition].Envelope_Enabled and
             EnvelopeEnabled then
            Amplitude := Amplitude or 16;

          { ── Envelope / noise accumulation ── }
          if not VTM^.Samples[Sample]^.Items[SamplePosition].Mixer_Noise then
          begin
            j := Byte(Current_Envelope_Sliding +
                      VTM^.Samples[Sample]^.Items[SamplePosition].Add_to_Envelope_or_Noise);
            if VTM^.Samples[Sample]^.Items[SamplePosition].Envelope_or_Noise_Accumulation then
              Current_Envelope_Sliding := ShortInt(j);
            Inc(PlVars[CurChip].AddToEnv, ShortInt(j));
          end
          else
          begin
            PlVars[CurChip].PT3Noise :=
              Byte(Current_Noise_Sliding +
                   VTM^.Samples[Sample]^.Items[SamplePosition].Add_to_Envelope_or_Noise);
            if VTM^.Samples[Sample]^.Items[SamplePosition].Envelope_or_Noise_Accumulation then
              Current_Noise_Sliding := ShortInt(PlVars[CurChip].PT3Noise);
          end;

          { ── Mixer bits from sample ── }
          if not VTM^.Samples[Sample]^.Items[SamplePosition].Mixer_Ton then
            TempMixer := TempMixer or 8;
          if not VTM^.Samples[Sample]^.Items[SamplePosition].Mixer_Noise then
            TempMixer := TempMixer or $40;
        end;

        { ── Advance sample position ── }
        if VTM^.Samples[Sample] <> nil then
        begin
          Inc(SamplePosition);
          if SamplePosition >= VTM^.Samples[Sample]^.Length then
            SamplePosition := VTM^.Samples[Sample]^.Loop;
        end;

        { ── Advance ornament position ── }
        if VTM^.Ornaments[Ornament] <> nil then
        begin
          Inc(OrnamentPosition);
          if OrnamentPosition >= VTM^.Ornaments[Ornament]^.Length then
            OrnamentPosition := Byte(VTM^.Ornaments[Ornament]^.Loop);
        end;
      end
      else
        Amplitude := 0;

      { ── Always: shift mixer accumulator ── }
      TempMixer := TempMixer shr 1;

      { ── On/Off toggling ── }
      if Current_OnOff > 0 then
      begin
        Dec(Current_OnOff);
        if Current_OnOff = 0 then
        begin
          SoundEnabled := not SoundEnabled;
          if SoundEnabled then
            Current_OnOff := OnOff_Delay
          else
            Current_OnOff := OffOn_Delay;
        end;
      end;

      { ── Early exit for blank pattern -1 ── }
      if PlVars[CurChip].CurrentPattern = -1 then Exit;

      { ── Global channel flags ── }
      gt := VTM^.IsChans[ChNum].Global_Ton;
      gn := VTM^.IsChans[ChNum].Global_Noise;
      ge := VTM^.IsChans[ChNum].Global_Envelope;

      if (VTM^.Samples[Sample] <> nil) and not VTM^.Samples[Sample]^.Enabled then
      begin
        gt := False; gn := False; ge := False;
      end;

      if not gt then TempMixer := TempMixer or 4;
      if not gn then TempMixer := TempMixer or 32;
      if not ge then Amplitude := Amplitude and 15;

      if (not gt or not gn) and (Amplitude and 16 = 0) and (TempMixer and 36 = 36) then
        Amplitude := 0;
    end; { with }
  end; { GetRegisters }

var
  k: Integer;
begin
  Inc(PlVars[CurChip].IntCnt);
  PlVars[CurChip].AddToEnv := 0;
  TempMixer := 0;

  for k := 0 to 2 do
    GetRegisters(k);

  { Push computed values into AY registers }
  SetMixerRegister(CurChip, Byte(TempMixer));

  SoundChip[CurChip].AYReg.TonA := PlVars[CurChip].ParamsOfChan[0].Ton;
  SoundChip[CurChip].AYReg.TonB := PlVars[CurChip].ParamsOfChan[1].Ton;
  SoundChip[CurChip].AYReg.TonC := PlVars[CurChip].ParamsOfChan[2].Ton;

  SetAmplA(CurChip, PlVars[CurChip].ParamsOfChan[0].Amplitude);
  SetAmplB(CurChip, PlVars[CurChip].ParamsOfChan[1].Amplitude);
  SetAmplC(CurChip, PlVars[CurChip].ParamsOfChan[2].Amplitude);

  SoundChip[CurChip].AYReg.Noise :=
    (PlVars[CurChip].PT3Noise + PlVars[CurChip].AddToNoise) and 31;

  SoundChip[CurChip].AYReg.Envelope :=
    Word(Integer(PlVars[CurChip].AddToEnv) +
         PlVars[CurChip].Cur_Env_Slide +
         PlVars[CurChip].Env_Base);

  { ── Envelope slide counter ── }
  if PlVars[CurChip].Cur_Env_Delay > 0 then
  begin
    Dec(PlVars[CurChip].Cur_Env_Delay);
    if PlVars[CurChip].Cur_Env_Delay = 0 then
    begin
      PlVars[CurChip].Cur_Env_Delay := PlVars[CurChip].Env_Delay;
      Inc(PlVars[CurChip].Cur_Env_Slide, PlVars[CurChip].Env_Slide_Add);
    end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Pattern_PlayCurrentLine  (verbatim from trfuncs.pas)
  Returns: 0=rendering, 1=line advanced, 2=pattern ended
  ═══════════════════════════════════════════════════════════════════════════ }

function Pattern_PlayCurrentLine: Integer;

  procedure PatternInterpreter(ChNum: Integer);
  var
    TS, PrNote, Ch, Gls: Integer;
  begin
    Ch := ChNum;
    if PlVars[CurChip].CurrentPattern = -1 then Ch := MidChan;

    with VTM^.Patterns[PlVars[CurChip].CurrentPattern]^.
           Items[PlVars[CurChip].CurrentLine].Channel[ChNum] do
    begin
      TS     := PlVars[CurChip].ParamsOfChan[Ch].Current_Ton_Sliding;
      PrNote := PlVars[CurChip].ParamsOfChan[Ch].Note;

      if Note = -2 then
      begin
        PlVars[CurChip].ParamsOfChan[Ch].SoundEnabled          := False;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Envelope_Sliding := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Count        := 0;
        PlVars[CurChip].ParamsOfChan[Ch].SamplePosition         := 0;
        PlVars[CurChip].ParamsOfChan[Ch].OrnamentPosition       := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Noise_Sliding  := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Amplitude_Sliding := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_OnOff          := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Ton_Sliding    := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Ton_Accumulator        := 0;
      end
      else if Note <> -1 then
      begin
        PlVars[CurChip].ParamsOfChan[Ch].SoundEnabled          := True;
        PlVars[CurChip].ParamsOfChan[Ch].Note                  := Byte(Note);
        PlVars[CurChip].ParamsOfChan[Ch].Current_Envelope_Sliding := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Count        := 0;
        PlVars[CurChip].ParamsOfChan[Ch].SamplePosition         := 0;
        PlVars[CurChip].ParamsOfChan[Ch].OrnamentPosition       := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Noise_Sliding  := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Amplitude_Sliding := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_OnOff          := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Current_Ton_Sliding    := 0;
        PlVars[CurChip].ParamsOfChan[Ch].Ton_Accumulator        := 0;
      end;

      if (Note <> -1) and (Sample <> 0) then
        VTM^.IsChans[Ch].Sample := Sample;

      if not (Envelope in [0, 15]) then
      begin
        VTM^.IsChans[Ch].EnvelopeEnabled := True;
        PlVars[CurChip].Env_Base :=
          SmallInt(VTM^.Patterns[PlVars[CurChip].CurrentPattern]^.
                     Items[PlVars[CurChip].CurrentLine].Envelope);
        SetEnvelopeRegister(CurChip, Envelope);
        VTM^.IsChans[Ch].Ornament := Ornament;
        PlVars[CurChip].ParamsOfChan[Ch].OrnamentPosition := 0;
        PlVars[CurChip].Cur_Env_Slide := 0;
        PlVars[CurChip].Cur_Env_Delay := 0;
      end
      else if Envelope = 15 then
      begin
        VTM^.IsChans[Ch].EnvelopeEnabled := False;
        VTM^.IsChans[Ch].Ornament        := Ornament;
        PlVars[CurChip].ParamsOfChan[Ch].OrnamentPosition := 0;
      end
      else if Ornament <> 0 then
      begin
        VTM^.IsChans[Ch].Ornament := Ornament;
        PlVars[CurChip].ParamsOfChan[Ch].OrnamentPosition := 0;
      end;

      if Volume > 0 then VTM^.IsChans[Ch].Volume := Byte(Volume);

      case Additional_Command.Number of
        1:
          begin
            Gls := Additional_Command.Delay;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Delay := ShortInt(Gls);
            if (Gls = 0) and (VTM^.FeaturesLevel >= 2) then Inc(Gls);
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Count := ShortInt(Gls);
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Step  := Additional_Command.Parameter;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Type  := 0;
            PlVars[CurChip].ParamsOfChan[Ch].Current_OnOff   := 0;
          end;

        2:
          begin
            Gls := Additional_Command.Delay;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Delay := ShortInt(Gls);
            if (Gls = 0) and (VTM^.FeaturesLevel >= 2) then Inc(Gls);
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Count := ShortInt(Gls);
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Step  := -SmallInt(Additional_Command.Parameter);
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Type  := 0;
            PlVars[CurChip].ParamsOfChan[Ch].Current_OnOff   := 0;
          end;

        3:
          if (Note >= 0) or ((Note <> -2) and (VTM^.FeaturesLevel >= 1)) then
          begin
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Delay := Additional_Command.Delay;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Count :=
              PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Delay;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Step  := Additional_Command.Parameter;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Delta :=
              SmallInt(GetNoteFreq(VTM^.Ton_Table,
                                   PlVars[CurChip].ParamsOfChan[Ch].Note)) -
              SmallInt(GetNoteFreq(VTM^.Ton_Table, PrNote));
            PlVars[CurChip].ParamsOfChan[Ch].Slide_To_Note :=
              PlVars[CurChip].ParamsOfChan[Ch].Note;
            PlVars[CurChip].ParamsOfChan[Ch].Note := PrNote;
            if VTM^.FeaturesLevel >= 1 then
              PlVars[CurChip].ParamsOfChan[Ch].Current_Ton_Sliding := TS;
            if PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Delta -
               PlVars[CurChip].ParamsOfChan[Ch].Current_Ton_Sliding < 0 then
              PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Step :=
                -PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Step;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Type  := 1;
            PlVars[CurChip].ParamsOfChan[Ch].Current_OnOff   := 0;
          end;

        4: PlVars[CurChip].ParamsOfChan[Ch].SamplePosition   := Additional_Command.Parameter;
        5: PlVars[CurChip].ParamsOfChan[Ch].OrnamentPosition := Additional_Command.Parameter;

        6:
          begin
            PlVars[CurChip].ParamsOfChan[Ch].OffOn_Delay   :=
              ShortInt(Additional_Command.Parameter and 15);
            PlVars[CurChip].ParamsOfChan[Ch].OnOff_Delay   :=
              ShortInt(Additional_Command.Parameter shr 4);
            PlVars[CurChip].ParamsOfChan[Ch].Current_OnOff :=
              PlVars[CurChip].ParamsOfChan[Ch].OnOff_Delay;
            PlVars[CurChip].ParamsOfChan[Ch].Ton_Slide_Count   := 0;
            PlVars[CurChip].ParamsOfChan[Ch].Current_Ton_Sliding := 0;
          end;

        9:
          begin
            PlVars[CurChip].Env_Delay     := Additional_Command.Delay;
            PlVars[CurChip].Cur_Env_Delay := PlVars[CurChip].Env_Delay;
            PlVars[CurChip].Env_Slide_Add := Additional_Command.Parameter;
          end;

        10:
          begin
            PlVars[CurChip].Env_Delay     := Additional_Command.Delay;
            PlVars[CurChip].Cur_Env_Delay := PlVars[CurChip].Env_Delay;
            PlVars[CurChip].Env_Slide_Add := -SmallInt(Additional_Command.Parameter);
          end;

        11:
          if Additional_Command.Parameter <> 0 then
            PlVars[CurChip].Delay := Additional_Command.Parameter;
      end; { case }
    end; { with }
  end; { PatternInterpreter }

var
  k: Integer;
begin
  Result := 0;

  if PlVars[CurChip].CurrentPattern = -1 then
  begin
    PlVars[CurChip].AddToNoise :=
      VTM^.Patterns[-1]^.Items[PlVars[CurChip].CurrentLine].Noise;
    PatternInterpreter(0);
  end
  else
  begin
    Dec(PlVars[CurChip].DelayCounter);
    if PlVars[CurChip].DelayCounter = 0 then
    begin
      Inc(Result);
      if VTM^.Patterns[PlVars[CurChip].CurrentPattern]^.Length <=
         PlVars[CurChip].CurrentLine then
      begin
        Inc(PlVars[CurChip].DelayCounter);
        Inc(Result);
        Exit; { ← exits WITHOUT calling Pattern_PlayOnlyCurrentLine }
      end;

      PlVars[CurChip].AddToNoise :=
        VTM^.Patterns[PlVars[CurChip].CurrentPattern]^.
          Items[PlVars[CurChip].CurrentLine].Noise;

      for k := 0 to 2 do
        PatternInterpreter(k);

      Inc(PlVars[CurChip].CurrentLine);
      PlVars[CurChip].DelayCounter := PlVars[CurChip].Delay;
    end;
  end;

  Pattern_PlayOnlyCurrentLine; { called in all cases except pattern-end exit }
end;

{ ═══════════════════════════════════════════════════════════════════════════
  JSON helpers
  ═══════════════════════════════════════════════════════════════════════════ }

function JBoolStr(v: Boolean): string; inline;
begin
  if v then Result := 'true' else Result := 'false';
end;

procedure JBool(const s: string; v: Boolean; const sep: string);
begin
  Write(s, ': ', JBoolStr(v), sep);
end;

procedure WriteRegs;
var
  R: TAYRegisters;
begin
  R := SoundChip[CurChip].AYReg;
  Write('{"ton_a":',   R.TonA,
        ',"ton_b":',   R.TonB,
        ',"ton_c":',   R.TonC,
        ',"noise":',   R.Noise,
        ',"mixer":',   R.Mixer,
        ',"ampl_a":',  R.AmplitudeA,
        ',"ampl_b":',  R.AmplitudeB,
        ',"ampl_c":',  R.AmplitudeC,
        ',"envelope":',R.Envelope,
        ',"env_type":',R.EnvType,
        '}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Module builder helpers
  ═══════════════════════════════════════════════════════════════════════════ }

procedure BuildBasicModule(WithEnvelope: Boolean);
{
  4-row pattern, delay=3, tone-only sample (mixer_ton=True, mixer_noise=False).
  Row 0: note C-4 (36) on all 3 channels, sample 1, volume 15.
  Rows 1-3: no note (all channels silent continuation).

  When WithEnvelope=True:
    Row 0 channel A additionally sets envelope type = 8 (sawtooth-down),
    pattern-row Envelope = $0800, sample tick has Envelope_Enabled=True.
}
var
  i, ch: Integer;
begin
  New(VTM);
  FillChar(VTM^, SizeOf(TModule), 0);

  VTM^.Ton_Table      := 0;          { PT table }
  VTM^.Initial_Delay  := 3;
  VTM^.FeaturesLevel  := 1;          { VT II / PT3.6 behaviour }
  VTM^.VortexModule_Header := True;

  { Position list }
  VTM^.Positions.Length := 1;
  VTM^.Positions.Loop   := 0;
  VTM^.Positions.Value[0] := 0;

  { Default channel state }
  for ch := 0 to 2 do
  begin
    VTM^.IsChans[ch].Global_Ton      := True;
    VTM^.IsChans[ch].Global_Noise    := True;
    VTM^.IsChans[ch].Global_Envelope := True;
    VTM^.IsChans[ch].EnvelopeEnabled := False;
    VTM^.IsChans[ch].Ornament        := 0;
    VTM^.IsChans[ch].Sample          := 1;
    VTM^.IsChans[ch].Volume          := 15;
  end;

  { Ornament 0: single step, zero offset }
  New(VTM^.Ornaments[0]);
  FillChar(VTM^.Ornaments[0]^, SizeOf(TOrnament), 0);
  VTM^.Ornaments[0]^.Length := 1;
  VTM^.Ornaments[0]^.Loop   := 0;

  { Sample 1: 4 ticks, amplitude 15, pure-tone (mixer_ton=True, mixer_noise=False) }
  New(VTM^.Samples[1]);
  FillChar(VTM^.Samples[1]^, SizeOf(TSample), 0);
  VTM^.Samples[1]^.Length  := 4;
  VTM^.Samples[1]^.Loop    := 0;
  VTM^.Samples[1]^.Enabled := True;
  for i := 0 to 3 do
  begin
    VTM^.Samples[1]^.Items[i].Amplitude            := 15;
    VTM^.Samples[1]^.Items[i].Mixer_Ton            := True;   { tone NOT muted }
    VTM^.Samples[1]^.Items[i].Mixer_Noise          := False;  { noise muted    }
    VTM^.Samples[1]^.Items[i].Envelope_Enabled     := WithEnvelope;
  end;

  { Pattern 0: 4 rows }
  New(VTM^.Patterns[0]);
  FillChar(VTM^.Patterns[0]^, SizeOf(TPattern), 0);
  VTM^.Patterns[0]^.Length := 4;

  { Row 0: all channels play C-4 (note 36), sample 1, volume 15 }
  for ch := 0 to 2 do
  begin
    VTM^.Patterns[0]^.Items[0].Channel[ch].Note    := 36;
    VTM^.Patterns[0]^.Items[0].Channel[ch].Sample  := 1;
    VTM^.Patterns[0]^.Items[0].Channel[ch].Volume  := 15;
    VTM^.Patterns[0]^.Items[0].Channel[ch].Ornament  := 0;
    VTM^.Patterns[0]^.Items[0].Channel[ch].Envelope  := 0;
  end;

  if WithEnvelope then
  begin
    { Channel A on row 0 sets envelope type 8 (sawtooth-down) }
    VTM^.Patterns[0]^.Items[0].Channel[0].Envelope := 8;
    { Pattern-row envelope period = 0x0800 }
    VTM^.Patterns[0]^.Items[0].Envelope := $0800;
    VTM^.IsChans[0].EnvelopeEnabled := True;
  end;

  { Rows 1-3: all channels have note=-1 (no note), everything else 0 }
  for i := 1 to 3 do
    for ch := 0 to 2 do
      VTM^.Patterns[0]^.Items[i].Channel[ch].Note := -1;
end;

procedure FreeModule;
begin
  if VTM = nil then Exit;
  Dispose(VTM^.Samples[1]);
  Dispose(VTM^.Ornaments[0]);
  Dispose(VTM^.Patterns[0]);
  Dispose(VTM);
  VTM := nil;
end;

procedure FreeArpeggioModule;
var i: Integer;
begin
  if VTM = nil then Exit;
  for i := 1 to 3 do
    if VTM^.Samples[i] <> nil then Dispose(VTM^.Samples[i]);
  for i := 0 to 2 do
    if VTM^.Ornaments[i] <> nil then Dispose(VTM^.Ornaments[i]);
  if VTM^.Patterns[0] <> nil then Dispose(VTM^.Patterns[0]);
  Dispose(VTM);
  VTM := nil;
end;

{ ─── Module builder: 3-channel arpeggio + noise drum ─────────────────────────
  Mirrors make_arpeggio_module() in the Rust test suite.

  Samples:
    1 – lead tone  (mixer_ton=True, mixer_noise=False, amplitude=14, loop on tick 0)
    2 – bass tone  (mixer_ton=True, mixer_noise=False, amplitude=10, loop on tick 0)
    3 – noise drum (mixer_ton=False, mixer_noise=True, amplitude decays 15→0,
                    add_to_envelope_or_noise=12 sets noise period, loops on tick 7)
  Ornaments:
    0 – default (zero offset, length=1)
    1 – major arpeggio: [0, +4, +7], length=3, loop=0
    2 – minor arpeggio: [0, +3, +7], length=3, loop=0
  Pattern 0 (16 rows):
    Row  0: Ch A C-5 s1 o1 v15, Ch B C-3 s2 o1 v12, Ch C note-0 s3 o0 v15 (drum)
    Row  4: Ch A G-4 s1 o1 v15, Ch B G-3 s2 o1 v12
    Row  8: Ch A A-4 s1 o2 v15, Ch B A-3 s2 o2 v12, Ch C note-0 s3 o0 v15 (drum)
    Row 12: Ch A F-4 s1 o1 v15, Ch B F-3 s2 o1 v12
}
procedure BuildArpeggioModule;
var
  i, ch: Integer;
  DrumAmps: array[0..7] of Byte = (15,13,11,9,7,5,2,0);
begin
  New(VTM);
  FillChar(VTM^, SizeOf(TModule), 0);

  VTM^.Ton_Table           := 0;
  VTM^.Initial_Delay       := 3;
  VTM^.FeaturesLevel       := 1;
  VTM^.VortexModule_Header := True;

  VTM^.Positions.Length    := 1;
  VTM^.Positions.Loop      := 0;
  VTM^.Positions.Value[0]  := 0;

  for ch := 0 to 2 do
  begin
    VTM^.IsChans[ch].Global_Ton      := True;
    VTM^.IsChans[ch].Global_Noise    := True;
    VTM^.IsChans[ch].Global_Envelope := True;
    VTM^.IsChans[ch].EnvelopeEnabled := False;
    VTM^.IsChans[ch].Ornament        := 0;
    VTM^.IsChans[ch].Sample          := 1;
    VTM^.IsChans[ch].Volume          := 15;
  end;

  { ── Ornament 0: single step, zero offset ── }
  New(VTM^.Ornaments[0]);
  FillChar(VTM^.Ornaments[0]^, SizeOf(TOrnament), 0);
  VTM^.Ornaments[0]^.Length := 1;
  VTM^.Ornaments[0]^.Loop   := 0;

  { ── Ornament 1: major arpeggio [0, +4, +7] ── }
  New(VTM^.Ornaments[1]);
  FillChar(VTM^.Ornaments[1]^, SizeOf(TOrnament), 0);
  VTM^.Ornaments[1]^.Length   := 3;
  VTM^.Ornaments[1]^.Loop     := 0;
  VTM^.Ornaments[1]^.Items[0] := 0;
  VTM^.Ornaments[1]^.Items[1] := 4;
  VTM^.Ornaments[1]^.Items[2] := 7;

  { ── Ornament 2: minor arpeggio [0, +3, +7] ── }
  New(VTM^.Ornaments[2]);
  FillChar(VTM^.Ornaments[2]^, SizeOf(TOrnament), 0);
  VTM^.Ornaments[2]^.Length   := 3;
  VTM^.Ornaments[2]^.Loop     := 0;
  VTM^.Ornaments[2]^.Items[0] := 0;
  VTM^.Ornaments[2]^.Items[1] := 3;
  VTM^.Ornaments[2]^.Items[2] := 7;

  { ── Sample 1: lead tone (length=1, loop=0, amplitude=14, tone on) ── }
  New(VTM^.Samples[1]);
  FillChar(VTM^.Samples[1]^, SizeOf(TSample), 0);
  VTM^.Samples[1]^.Length  := 1;
  VTM^.Samples[1]^.Loop    := 0;
  VTM^.Samples[1]^.Enabled := True;
  VTM^.Samples[1]^.Items[0].Amplitude  := 14;
  VTM^.Samples[1]^.Items[0].Mixer_Ton  := True;   { tone NOT muted }
  VTM^.Samples[1]^.Items[0].Mixer_Noise := False; { noise muted }

  { ── Sample 2: bass tone (length=1, loop=0, amplitude=10, tone on) ── }
  New(VTM^.Samples[2]);
  FillChar(VTM^.Samples[2]^, SizeOf(TSample), 0);
  VTM^.Samples[2]^.Length  := 1;
  VTM^.Samples[2]^.Loop    := 0;
  VTM^.Samples[2]^.Enabled := True;
  VTM^.Samples[2]^.Items[0].Amplitude  := 10;
  VTM^.Samples[2]^.Items[0].Mixer_Ton  := True;
  VTM^.Samples[2]^.Items[0].Mixer_Noise := False;

  { ── Sample 3: noise drum (length=8, loop=7, decaying amplitude) ── }
  New(VTM^.Samples[3]);
  FillChar(VTM^.Samples[3]^, SizeOf(TSample), 0);
  VTM^.Samples[3]^.Length  := 8;
  VTM^.Samples[3]^.Loop    := 7;
  VTM^.Samples[3]^.Enabled := True;
  for i := 0 to 7 do
  begin
    VTM^.Samples[3]^.Items[i].Amplitude               := DrumAmps[i];
    VTM^.Samples[3]^.Items[i].Mixer_Ton               := False; { tone muted }
    VTM^.Samples[3]^.Items[i].Mixer_Noise             := True;  { noise NOT muted }
    VTM^.Samples[3]^.Items[i].Add_to_Envelope_or_Noise := 12;  { noise period }
  end;

  { ── Pattern 0: 16 rows ── }
  New(VTM^.Patterns[0]);
  FillChar(VTM^.Patterns[0]^, SizeOf(TPattern), 0);
  VTM^.Patterns[0]^.Length := 16;

  { Rows default to note=-1 (no note) }
  for i := 0 to 15 do
    for ch := 0 to 2 do
      VTM^.Patterns[0]^.Items[i].Channel[ch].Note := -1;

  { Row 0: C major (I) — C-5 / C-3 + drum }
  with VTM^.Patterns[0]^.Items[0] do
  begin
    Channel[0].Note := 48; Channel[0].Sample := 1; Channel[0].Ornament := 1; Channel[0].Volume := 15;
    Channel[1].Note := 24; Channel[1].Sample := 2; Channel[1].Ornament := 1; Channel[1].Volume := 12;
    Channel[2].Note :=  0; Channel[2].Sample := 3; Channel[2].Ornament := 0; Channel[2].Volume := 15;
  end;

  { Row 4: G major (V) — G-4 / G-3 }
  with VTM^.Patterns[0]^.Items[4] do
  begin
    Channel[0].Note := 43; Channel[0].Sample := 1; Channel[0].Ornament := 1; Channel[0].Volume := 15;
    Channel[1].Note := 31; Channel[1].Sample := 2; Channel[1].Ornament := 1; Channel[1].Volume := 12;
  end;

  { Row 8: A minor (vi) — A-4 / A-3 + drum }
  with VTM^.Patterns[0]^.Items[8] do
  begin
    Channel[0].Note := 45; Channel[0].Sample := 1; Channel[0].Ornament := 2; Channel[0].Volume := 15;
    Channel[1].Note := 33; Channel[1].Sample := 2; Channel[1].Ornament := 2; Channel[1].Volume := 12;
    Channel[2].Note :=  0; Channel[2].Sample := 3; Channel[2].Ornament := 0; Channel[2].Volume := 15;
  end;

  { Row 12: F major (IV) — F-4 / F-3 }
  with VTM^.Patterns[0]^.Items[12] do
  begin
    Channel[0].Note := 41; Channel[0].Sample := 1; Channel[0].Ornament := 1; Channel[0].Volume := 15;
    Channel[1].Note := 29; Channel[1].Sample := 2; Channel[1].Ornament := 1; Channel[1].Volume := 12;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: LFSR 200 steps
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunNoiseLFSR;
var
  Seed, NV: LongWord;
  i: Integer;
begin
  Seed := $FFFF;
  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "noise_lfsr",');
  WriteLn('  "initial_seed": ', Seed, ',');
  WriteLn('  "steps": [');
  for i := 1 to 200 do
  begin
    Seed := NoiseGenerator(Seed);
    NV   := NoiseVal(Seed);
    Write('    {"seed":', Seed, ',"noise_val":', NV, '}');
    if i < 200 then WriteLn(',') else WriteLn;
  end;
  WriteLn('  ]');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: all 8 envelope shapes, 64 steps each
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunEnvelopes;
const
  { (register_value, name) pairs — one representative per shape }
  TestRegs: array[0..7] of Byte  = (0, 4, 8, 10, 11, 12, 13, 14);
  TestNames: array[0..7] of string = (
    'Hold0', 'Hold31', 'Saw8', 'Triangle10',
    'DecayHold', 'Saw12', 'AttackHold', 'Triangle14');
var
  s, i: Integer;
begin
  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "envelope_shapes",');
  WriteLn('  "shapes": [');
  for s := 0 to 7 do
  begin
    SetEnvelopeRegister(1, TestRegs[s]);
    Write('    {"register_value":', TestRegs[s],
          ',"name":"', TestNames[s],
          '","initial_ampl":', SoundChip[1].Ampl,
          ',"steps":[');
    for i := 1 to 64 do
    begin
      StepEnvelope(1);
      Write('{"ampl":', SoundChip[1].Ampl,
            ',"first_period":', JBoolStr(SoundChip[1].FirstPeriod), '}');
      if i < 64 then Write(',');
    end;
    Write(']}');
    if s < 7 then WriteLn(',') else WriteLn;
  end;
  WriteLn('  ]');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: PT3_Vol 16×16 table
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunPT3Vol;
var
  r, c: Integer;
begin
  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "pt3_vol",');
  WriteLn('  "table": [');
  for r := 0 to 15 do
  begin
    Write('    [');
    for c := 0 to 15 do
    begin
      Write(PT3_Vol[r, c]);
      if c < 15 then Write(',');
    end;
    Write(']');
    if r < 15 then WriteLn(',') else WriteLn;
  end;
  WriteLn('  ]');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: all 5 note tables (96 entries each)
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunNoteTables;

  procedure DumpTable(const Name: string; const T: PT3ToneTable; Last: Boolean);
  var j: Integer;
  begin
    Write('    "', Name, '": [');
    for j := 0 to 95 do
    begin
      Write(T[j]);
      if j < 95 then Write(',');
    end;
    Write(']');
    if not Last then WriteLn(',') else WriteLn;
  end;
begin
  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "note_tables",');
  WriteLn('  "tables": {');
  DumpTable('PT',      PT3NoteTable_PT,      False);
  DumpTable('ST',      PT3NoteTable_ST,      False);
  DumpTable('ASM',     PT3NoteTable_ASM,     False);
  DumpTable('REAL',    PT3NoteTable_REAL,    False);
  DumpTable('NATURAL', PT3NoteTable_NATURAL, True);
  WriteLn('  }');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: Pattern_PlayCurrentLine — 4-row pattern, delay=3, run 20 ticks
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunPatternPlay(WithEnvelope: Boolean; const TestName: string);
var
  tick, res: Integer;
begin
  BuildBasicModule(WithEnvelope);

  CurChip := 1;
  PlVars[CurChip] := Default(TPlVars);
  PlVars[CurChip].Delay          := VTM^.Initial_Delay;
  PlVars[CurChip].CurrentPattern := VTM^.Positions.Value[0];
  PlVars[CurChip].CurrentLine    := 0;

  InitTrackerParameters(True);

  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "', TestName, '",');
  WriteLn('  "delay": ', VTM^.Initial_Delay, ',');
  WriteLn('  "ticks": [');

  for tick := 0 to 19 do
  begin
    res := Pattern_PlayCurrentLine;
    Write('    {"tick":', tick,
          ',"result":', res,
          ',"current_line":', PlVars[CurChip].CurrentLine,
          ',"delay_counter":', PlVars[CurChip].DelayCounter,
          ',"regs":');
    WriteRegs;
    Write('}');
    if tick < 19 then WriteLn(',') else WriteLn;
  end;

  WriteLn('  ]');
  WriteLn('}');

  FreeModule;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: Pattern_PlayCurrentLine — 16-row arpeggio+drum, delay=3, 54 ticks
  (covers 1 complete 16-row pass: 16 rows × 3 ticks + 6 extra = 54)
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunPatternArpeggio;
const
  NumTicks = 54;
var
  tick, res: Integer;
begin
  BuildArpeggioModule;

  CurChip := 1;
  PlVars[CurChip] := Default(TPlVars);
  PlVars[CurChip].Delay          := VTM^.Initial_Delay;
  PlVars[CurChip].CurrentPattern := VTM^.Positions.Value[0];
  PlVars[CurChip].CurrentLine    := 0;

  InitTrackerParameters(True);

  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "pattern_arpeggio",');
  WriteLn('  "delay": ', VTM^.Initial_Delay, ',');
  WriteLn('  "ticks": [');

  for tick := 0 to NumTicks - 1 do
  begin
    res := Pattern_PlayCurrentLine;
    Write('    {"tick":', tick,
          ',"result":', res,
          ',"current_line":', PlVars[CurChip].CurrentLine,
          ',"delay_counter":', PlVars[CurChip].DelayCounter,
          ',"regs":');
    WriteRegs;
    Write('}');
    if tick < NumTicks - 1 then WriteLn(',') else WriteLn;
  end;

  WriteLn('  ]');
  WriteLn('}');

  FreeArpeggioModule;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Test: Calculate_Level_Tables (from digsoundbuf.pas)

  Computes stereo AY and YM level tables for the default panning preset
  (A=255/13, B=170/170, C=13/255) with k=1 (GlobalVolume = GlobalVolumeMax)
  and 16-bit sample output.

  The formula is:
    b := trunc(Index / l * Amplitudes[i] / 65535 * r * k + 0.5)

  where l = max(sum_L, sum_R) * 2  for stereo mode.
  ═══════════════════════════════════════════════════════════════════════════ }

procedure RunLevelTables;
const
  { Amplitude tables (from AY.pas, (c) Hacker KAY) }
  Amplitudes_AY: array[0..15] of LongWord = (
    0, 836, 1212, 1773, 2619, 3875, 5397, 8823, 10392, 16706, 23339,
    29292, 36969, 46421, 55195, 65535);
  Amplitudes_YM: array[0..31] of LongWord = (
    0, 0, $F8, $1C2, $29E, $33A, $3F2, $4D7, $610, $77F, $90A, $A42,
    $C3B, $EC2, $1137, $13A7, $1750, $1BF9, $20DF, $2596, $2C9D, $3579,
    $3E55, $4768, $54FF, $6624, $773B, $883F, $A1DA, $C0FC, $E094, $FFFF);

  { Default stereo panning (ChanAllocDef = 1, "ABC" preset) }
  Index_AL = 255; Index_AR = 13;
  Index_BL = 170; Index_BR = 170;
  Index_CL = 13;  Index_CR = 255;
  R        = 32767; { 16-bit max }

  procedure WriteTable(const Values: array of Integer; Count: Integer);
  var j: Integer;
  begin
    Write('[');
    for j := 0 to Count - 1 do
    begin
      Write(Values[j]);
      if j < Count - 1 then Write(',');
    end;
    Write(']');
  end;

  procedure EmitCase(const Name, ChipName: string; IsYM: Boolean);
  var
    i, b, L_val: Integer;
    k: Real;
    AL, AR, BL, BR, CL, CR: array[0..31] of Integer;
  begin
    { Stereo: l = max(sum_L, sum_R) * 2 }
    L_val := (Index_AL + Index_BL + Index_CL) * 2;
    if (Index_AR + Index_BR + Index_CR) * 2 > L_val then
      L_val := (Index_AR + Index_BR + Index_CR) * 2;

    k := 1.0; { GlobalVolume = GlobalVolumeMax }

    if not IsYM then
    begin
      for i := 0 to 15 do
      begin
        b := Trunc(Index_AL / L_val * Amplitudes_AY[i] / 65535 * R * k + 0.5);
        AL[i * 2] := b; AL[i * 2 + 1] := b;
        b := Trunc(Index_AR / L_val * Amplitudes_AY[i] / 65535 * R * k + 0.5);
        AR[i * 2] := b; AR[i * 2 + 1] := b;
        b := Trunc(Index_BL / L_val * Amplitudes_AY[i] / 65535 * R * k + 0.5);
        BL[i * 2] := b; BL[i * 2 + 1] := b;
        b := Trunc(Index_BR / L_val * Amplitudes_AY[i] / 65535 * R * k + 0.5);
        BR[i * 2] := b; BR[i * 2 + 1] := b;
        b := Trunc(Index_CL / L_val * Amplitudes_AY[i] / 65535 * R * k + 0.5);
        CL[i * 2] := b; CL[i * 2 + 1] := b;
        b := Trunc(Index_CR / L_val * Amplitudes_AY[i] / 65535 * R * k + 0.5);
        CR[i * 2] := b; CR[i * 2 + 1] := b;
      end;
      WriteLn('    {');
      WriteLn('      "name": "', Name, '",');
      WriteLn('      "chip": "', ChipName, '",');
      WriteLn('      "num_channels": 2,');
      WriteLn('      "sample_bit": 16,');
      WriteLn('      "index_al": ', Index_AL, ', "index_ar": ', Index_AR, ',');
      WriteLn('      "index_bl": ', Index_BL, ', "index_br": ', Index_BR, ',');
      WriteLn('      "index_cl": ', Index_CL, ', "index_cr": ', Index_CR, ',');
      WriteLn('      "l": ', L_val, ',');
      Write('      "al": '); WriteTable(AL, 32); WriteLn(',');
      Write('      "ar": '); WriteTable(AR, 32); WriteLn(',');
      Write('      "bl": '); WriteTable(BL, 32); WriteLn(',');
      Write('      "br": '); WriteTable(BR, 32); WriteLn(',');
      Write('      "cl": '); WriteTable(CL, 32); WriteLn(',');
      Write('      "cr": '); WriteTable(CR, 32); WriteLn;
      Write('    }');
    end
    else
    begin
      for i := 0 to 31 do
      begin
        AL[i] := Trunc(Index_AL / L_val * Amplitudes_YM[i] / 65535 * R * k + 0.5);
        AR[i] := Trunc(Index_AR / L_val * Amplitudes_YM[i] / 65535 * R * k + 0.5);
        BL[i] := Trunc(Index_BL / L_val * Amplitudes_YM[i] / 65535 * R * k + 0.5);
        BR[i] := Trunc(Index_BR / L_val * Amplitudes_YM[i] / 65535 * R * k + 0.5);
        CL[i] := Trunc(Index_CL / L_val * Amplitudes_YM[i] / 65535 * R * k + 0.5);
        CR[i] := Trunc(Index_CR / L_val * Amplitudes_YM[i] / 65535 * R * k + 0.5);
      end;
      WriteLn('    {');
      WriteLn('      "name": "', Name, '",');
      WriteLn('      "chip": "', ChipName, '",');
      WriteLn('      "num_channels": 2,');
      WriteLn('      "sample_bit": 16,');
      WriteLn('      "index_al": ', Index_AL, ', "index_ar": ', Index_AR, ',');
      WriteLn('      "index_bl": ', Index_BL, ', "index_br": ', Index_BR, ',');
      WriteLn('      "index_cl": ', Index_CL, ', "index_cr": ', Index_CR, ',');
      WriteLn('      "l": ', L_val, ',');
      Write('      "al": '); WriteTable(AL, 32); WriteLn(',');
      Write('      "ar": '); WriteTable(AR, 32); WriteLn(',');
      Write('      "bl": '); WriteTable(BL, 32); WriteLn(',');
      Write('      "br": '); WriteTable(BR, 32); WriteLn(',');
      Write('      "cl": '); WriteTable(CL, 32); WriteLn(',');
      Write('      "cr": '); WriteTable(CR, 32); WriteLn;
      Write('    }');
    end;
  end;

begin
  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "level_tables",');
  WriteLn('  "cases": [');
  EmitCase('ay_stereo_default', 'AY', False);
  WriteLn(',');
  EmitCase('ym_stereo_default', 'YM', True);
  WriteLn;
  WriteLn('  ]');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Song timing helpers (GetModuleTime, GetPositionTime, GetPositionTimeEx,
  GetTimeParams) — ported from trfuncs.pas
  ═══════════════════════════════════════════════════════════════════════════ }

{ ── Forward declarations ─────────────────────────────────────────── }

function GetModuleTime(VTM: PModule): integer; forward;
function GetPositionTime(VTM: PModule; Pos: integer; var PosDelay: integer): integer; forward;
function GetPositionTimeEx(VTM: PModule; Pos, PosDelay, Line: integer): integer; forward;
procedure GetTimeParams(VTM: PModule; Time: integer; var Pos, Line: integer); forward;

{ ── Implementations (exact copies from trfuncs.pas) ─────────────── }

function GetModuleTime(VTM: PModule): integer;
var
 i, j, k, d, p: integer;
begin
 Result := 0;
 d := VTM^.Initial_Delay;
 for i := 0 to VTM^.Positions.Length - 1 do
  begin
   p := VTM^.Positions.Value[i];
   if VTM^.Patterns[p] = nil then
     Inc(Result, d * DefPatLen)
   else
     for j := 0 to VTM^.Patterns[p]^.Length - 1 do
      begin
       for k := 2 downto 0 do
         with VTM^.Patterns[p]^.Items[j].Channel[k].Additional_Command do
           if (Number = 11) and (Parameter <> 0) then
            begin
             d := Parameter;
             break;
            end;
       Inc(Result, d);
      end;
  end;
end;

function GetPositionTime(VTM: PModule; Pos: integer; var PosDelay: integer): integer;
var
 i, j, k, d, p: integer;
begin
 Result := 0;
 d := VTM^.Initial_Delay;
 for i := 0 to Pos - 1 do
  begin
   p := VTM^.Positions.Value[i];
   if VTM^.Patterns[p] = nil then
     Inc(Result, d * DefPatLen)
   else
     for j := 0 to VTM^.Patterns[p]^.Length - 1 do
      begin
       for k := 2 downto 0 do
         with VTM^.Patterns[p]^.Items[j].Channel[k].Additional_Command do
           if (Number = 11) and (Parameter <> 0) then
            begin
             d := Parameter;
             Break;
            end;
       Inc(Result, d);
      end;
  end;
 PosDelay := d;
end;

function GetPositionTimeEx(VTM: PModule; Pos, PosDelay, Line: integer): integer;
var
 j, k, p: integer;
begin
 Result := 0;
 p := VTM^.Positions.Value[Pos];
 if VTM^.Patterns[p] = nil then
   Inc(Result, PosDelay * Line)
 else
   for j := 0 to Line - 1 do
    begin
     for k := 2 downto 0 do
       with VTM^.Patterns[p]^.Items[j].Channel[k].Additional_Command do
         if (Number = 11) and (Parameter <> 0) then
          begin
           PosDelay := Parameter;
           Break;
          end;
     Inc(Result, PosDelay);
    end;
end;

procedure GetTimeParams(VTM: PModule; Time: integer; var Pos, Line: integer);
var
 i, j, k, d, p, ct, tmp: integer;
begin
 Pos := -1;
 Line := 0;
 d := VTM^.Initial_Delay;
 ct := 0;
 for i := 0 to VTM^.Positions.Length - 1 do
  begin
   p := VTM^.Positions.Value[i];
   if VTM^.Patterns[p] = nil then
    begin
     tmp := d * DefPatLen;
     if ct + tmp < Time then
       Inc(ct, tmp)
     else
      begin
       Pos := i;
       Line := (Time - ct) div d;
       Exit;
      end;
    end
   else
     for j := 0 to VTM^.Patterns[p]^.Length - 1 do
      begin
       if ct >= Time then
        begin
         Pos := i;
         Line := j;
         Exit;
        end;
       for k := 2 downto 0 do
         with VTM^.Patterns[p]^.Items[j].Channel[k].Additional_Command do
           if (Number = 11) and (Parameter <> 0) then
            begin
             d := Parameter;
             Break;
            end;
       Inc(ct, d);
      end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  PrepareZXModule test runners
  ═══════════════════════════════════════════════════════════════════════════ }

procedure SetW(ZXP: PSpeccyModule; Offset: integer; Value: word); inline;
{ Write a 16-bit value as two little-endian bytes into the module byte array. }
begin
  ZXP^.Index[Offset]     := Value and $FF;
  ZXP^.Index[Offset + 1] := (Value shr 8) and $FF;
end;

procedure RunPrepareZXSQT;
{ Constructs a minimal SQT binary with ZX-absolute pointer values (load base
  BASE = 0x8000), calls PrepareZXModule, and emits the rebased word values as
  a JSON fixture.

  File layout (64 bytes total):
    offset  0- 1  SQT_Size              = 0x0000
    offset  2- 3  SQT_SamplesPointer    = BASE+10  (→ file-rel 10 after rebase)
    offset  4- 5  SQT_OrnamentsPointer  = BASE+50  (→ 50)
    offset  6- 7  SQT_PatternsPointer   = BASE+22  (→ 22)
    offset  8- 9  SQT_PositionsPointer  = BASE+30  (→ 30)
    offset 10-11  SQT_LoopPointer       = BASE+30  (→ 30)
    offset 12-21  "sample" pointer table (5 entries × 2 bytes, each BASE+$500 → 0x0500=1280)
    offset 22-29  pattern pointer table (j+1=4 entries; BASE+$100..BASE+$400 → $100..$400)
    offset 30-37  position entry (chan C=2, chan B=1, chan A=3, delay=6) + terminator

  j = max(2,1,3) = 3 → rebase count = (22 + 3*2)/2 = 14 words starting at offset 2.
  Expected words_after[0..14] = [0, 10, 50, 22, 30, 30, 1280, 1280, 1280, 1280, 1280, 256, 512, 768, 1024]
}
var
  ZXP: PSpeccyModule;
  FType: Available_Types;
  BASE: word;
  i: integer;
begin
  BASE := $8000;
  New(ZXP);
  FillChar(ZXP^, SizeOf(ZXP^), 0);

  { SQT header — use SetW so each 16-bit ZX-absolute value is stored correctly }
  SetW(ZXP,  0, 0);               { SQT_Size (not a pointer, left as 0) }
  SetW(ZXP,  2, BASE + 10);       { SQT_SamplesPointer  → i = BASE+10-10 = BASE }
  SetW(ZXP,  4, BASE + 50);       { SQT_OrnamentsPointer }
  SetW(ZXP,  6, BASE + 22);       { SQT_PatternsPointer }
  SetW(ZXP,  8, BASE + 30);       { SQT_PositionsPointer }
  SetW(ZXP, 10, BASE + 30);       { SQT_LoopPointer }

  { "sample" pointer table at offsets 12-21 (5 entries × 2 bytes) }
  for i := 0 to 4 do
    SetW(ZXP, 12 + i * 2, BASE + $0500);

  { Pattern pointer table at offsets 22-29 (4 entries for PatChan 0..3) }
  SetW(ZXP, 22, BASE + $0100);
  SetW(ZXP, 24, BASE + $0200);
  SetW(ZXP, 26, BASE + $0300);
  SetW(ZXP, 28, BASE + $0400);

  { Position entry at offset 30: chan_C=2, chan_B=1, chan_A=3, delay=6 + terminator }
  ZXP^.Index[30] := $02; ZXP^.Index[31] := $00;  { chan C PatChanNumber=2 }
  ZXP^.Index[32] := $01; ZXP^.Index[33] := $10;  { chan B PatChanNumber=1 }
  ZXP^.Index[34] := $03; ZXP^.Index[35] := $20;  { chan A PatChanNumber=3 }
  ZXP^.Index[36] := $06;                           { delay }
  ZXP^.Index[37] := $00;                           { terminator }

  FType := SQTFile;
  PrepareZXModule(ZXP, FType, 64);

  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "prepare_zx_sqt",');
  WriteLn('  "load_base": ', BASE, ',');
  if FType = SQTFile then WriteLn('  "ftype_unchanged": true,')
                     else WriteLn('  "ftype_unchanged": false,');
  Write(  '  "words_after": [');
  { words at offsets 0, 2, 4, ..., 28 (15 words) }
  for i := 0 to 14 do
  begin
    if i > 0 then Write(', ');
    Write(PWord(@ZXP^.Index[i * 2])^);
  end;
  WriteLn(']');
  WriteLn('}');

  Dispose(ZXP);
end;

procedure RunPrepareZXFLS;
{ Constructs a minimal FLS binary with ZX-absolute pointer values (load base
  BASE = 0x8000), calls PrepareZXModule, and emits the rebased word values as
  a JSON fixture.

  File layout (80 bytes total):
    offset  0- 1  FLS_PositionsPointer            = BASE+28  (→ 28)
    offset  2- 3  FLS_OrnamentsPointer             = BASE+16  (→ 16)  [i = BASE+16-16 = BASE]
    offset  4- 5  FLS_SamplesPointer               = BASE+20  (→ 20)
    offset  6- 7  FLS_PatternsPointers[1].PatternA = BASE+31  (→ 31)
    offset  8- 9  FLS_PatternsPointers[1].PatternB = BASE+33  (→ 33)
    offset 10-11  FLS_PatternsPointers[1].PatternC = BASE+40  (→ 40)
    offset 12-13  (arbitrary pointer)              = BASE+80  (→ 80)
    offset 14-15  (arbitrary pointer)              = BASE+90  (→ 90)
    offset 16-17  orn_data ptr 1                   = BASE+44  (→ 44)
    offset 18-19  orn_data ptr 2                   = BASE+28  (→ 28)  [i1-i2=32 check]
    offset 20-21  sample 1 loop/extra bytes        = 0x0000   (skipped by rebase)
    offset 22-23  sample 1 tick_ptr                = BASE+60  (→ 60)  [i1=60]
    offset 24-25  sample 2 loop/extra bytes        = 0x0000   (skipped)
    offset 26-27  sample 2 tick_ptr                = BASE+64  (→ 64)
    offset 28     initial_delay = 2                           (positions data, unchanged)
    offset 29     pattern entry = 1
    offset 30     terminator = 0  [byte-before-patA validation check]
    offset 31     0x01  (pattern A: one note byte, in 0..$5F)
    offset 32     0xFF  (pattern A: terminator)
    offset 33     0xFF  (pattern B: terminator)
    offset 40     0xFF  (pattern C: terminator)
    offsets 44-75 ornament 1 data (32 zero bytes)

  Validation with i = BASE:
    i2 = FLS_SamplesPointer+2-BASE = 22;  word@22=BASE+60 → i1=60 ✓
    word@(i2-4=18)=BASE+28 → i2_new=28;  i1-i2_new=32 ✓
    patA-BASE=31>20, patB-BASE=33>21, Index[30]=0
    pattern walk from 31: Index[31]=$01 (note→Inc), Index[32]=$FF → i1=32; 32+1=33=patB ✓

  First rebase loop:  words at offsets 0,2,4,6,8,10,12,14,16,18  (p1 = @Index[20])
  Inc(pwrd) skips loop/extra word at 20-21.
  Second rebase loop: words at offsets 22, 26  (p2 = @Index[30])

  Expected words_after[0..14] = [28,16,20,31,33,40,80,90,44,28, 0,60, 0,64, 258]
    (offset 28 word = delay<<0 | pattern<<8 = 2 | (1<<8) = 258, unchanged)
}
var
  ZXP: PSpeccyModule;
  FType: Available_Types;
  BASE: word;
  i: integer;
begin
  BASE := $8000;
  New(ZXP);
  FillChar(ZXP^, SizeOf(ZXP^), 0);

  { FLS header — use SetW for each ZX-absolute pointer word }
  SetW(ZXP,  0, BASE + 28);   { FLS_PositionsPointer }
  SetW(ZXP,  2, BASE + 16);   { FLS_OrnamentsPointer → i = BASE+16-16 = BASE }
  SetW(ZXP,  4, BASE + 20);   { FLS_SamplesPointer }

  { Pattern 1 pointer triplet }
  SetW(ZXP,  6, BASE + 31);   { PatternA }
  SetW(ZXP,  8, BASE + 33);   { PatternB }
  SetW(ZXP, 10, BASE + 40);   { PatternC }

  { Arbitrary filler pointers (in the first rebase-loop range) }
  SetW(ZXP, 12, BASE + 80);
  SetW(ZXP, 14, BASE + 90);

  { Ornament pointer table starting at offset 16 }
  SetW(ZXP, 16, BASE + 44);   { orn data ptr 1 }
  SetW(ZXP, 18, BASE + 28);   { orn data ptr 2 — used for i1-i2=32 validation }

  { Sample table: 2 entries × 4 bytes (loop/extra + tick_ptr) }
  ZXP^.Index[20] := 0; ZXP^.Index[21] := 0;  { sample 1 loop, extra (not a pointer) }
  SetW(ZXP, 22, BASE + 60);   { sample 1 tick_ptr }
  ZXP^.Index[24] := 0; ZXP^.Index[25] := 0;  { sample 2 loop, extra (not a pointer) }
  SetW(ZXP, 26, BASE + 64);   { sample 2 tick_ptr }

  { Positions data (offset 28) }
  ZXP^.Index[28] := 2;    { initial_delay }
  ZXP^.Index[29] := 1;    { position entry (pattern index 1) }
  ZXP^.Index[30] := 0;    { terminator — also the byte-before-patA check in validation }

  { Pattern A data (offset 31) }
  ZXP^.Index[31] := $01;  { one note byte (in range 0..$5F) }
  ZXP^.Index[32] := $FF;  { terminator }

  { Pattern B data (offset 33) }
  ZXP^.Index[33] := $FF;  { terminator }

  { Pattern C data (offset 40) }
  ZXP^.Index[40] := $FF;  { terminator }

  { Ornament 1 data at offset 44 (32 bytes, already zeroed by FillChar) }

  FType := FLSFile;
  PrepareZXModule(ZXP, FType, 80);

  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "prepare_zx_fls",');
  WriteLn('  "load_base": ', BASE, ',');
  if FType = FLSFile then WriteLn('  "ftype_unchanged": true,')
                     else WriteLn('  "ftype_unchanged": false,');
  Write(  '  "words_after": [');
  { words at offsets 0, 2, 4, ..., 28 (15 words) }
  for i := 0 to 14 do
  begin
    if i > 0 then Write(', ');
    Write(PWord(@ZXP^.Index[i * 2])^);
  end;
  WriteLn(']');
  WriteLn('}');

  Dispose(ZXP);
end;

{ ── Test runner ──────────────────────────────────────────────────── }

procedure RunSongTiming;
{ Builds a two-position test module:
    initial_delay = 3
    position 0 → pattern 0: 4 rows, no delay changes
    position 1 → pattern 1: 3 rows, row 1 ch 0 has delay command (cmd=11, param=5)
  Then exercises all four timing helpers and emits a JSON fixture. }
var
  M: TModule;
  Pat0, Pat1: TPattern;
  PPat0, PPat1: PPattern;
  Pos, Line, PosDelay, Ticks: integer;
  i: integer;
begin
  FillChar(M, SizeOf(M), 0);
  M.Initial_Delay := 3;
  M.Positions.Length := 2;
  M.Positions.Value[0] := 0;
  M.Positions.Value[1] := 1;

  { Pattern 0: 4 rows, all empty (no delay commands) }
  FillChar(Pat0, SizeOf(Pat0), 0);
  Pat0.Length := 4;
  for i := 0 to 3 do
  begin
    Pat0.Items[i].Channel[0].Note := -1;
    Pat0.Items[i].Channel[1].Note := -1;
    Pat0.Items[i].Channel[2].Note := -1;
  end;
  PPat0 := @Pat0;
  M.Patterns[0] := PPat0;

  { Pattern 1: 3 rows; row 1 channel 0 has a delay-change command }
  FillChar(Pat1, SizeOf(Pat1), 0);
  Pat1.Length := 3;
  for i := 0 to 2 do
  begin
    Pat1.Items[i].Channel[0].Note := -1;
    Pat1.Items[i].Channel[1].Note := -1;
    Pat1.Items[i].Channel[2].Note := -1;
  end;
  Pat1.Items[1].Channel[0].Additional_Command.Number    := 11;
  Pat1.Items[1].Channel[0].Additional_Command.Parameter := 5;
  PPat1 := @Pat1;
  M.Patterns[1] := PPat1;

  WriteLn('{');
  WriteLn('  "generator": "vt_pascal_harness",');
  WriteLn('  "test": "song_timing",');
  WriteLn('  "comment": "Two-position module: initial_delay=3, pattern 0 has 4 rows (no delay changes), pattern 1 has 3 rows with a delay-change command (cmd=11, parameter=5) on row 1 channel 0.",');

  { ── get_module_time ─────────────────────────────────────────────── }
  WriteLn('  "module_time": ', GetModuleTime(@M), ',');

  { ── get_position_time (pos 0, 1, 2) ─────────────────────────────── }
  WriteLn('  "position_times": [');
  for i := 0 to 2 do
  begin
    PosDelay := M.Initial_Delay;
    Ticks := GetPositionTime(@M, i, PosDelay);
    Write('    { "pos": ', i, ', "ticks": ', Ticks, ', "delay_at_pos": ', PosDelay, ' }');
    if i < 2 then WriteLn(',') else WriteLn;
  end;
  WriteLn('  ],');

  { ── get_position_time_ex ─────────────────────────────────────────── }
  WriteLn('  "position_times_ex": [');
  { (pos=0, pos_delay=3, line=2) }
  WriteLn('    { "pos": 0, "pos_delay": 3, "line": 2, "ticks": ', GetPositionTimeEx(@M, 0, 3, 2), ' },');
  { (pos=1, pos_delay=3, line=2) }
  WriteLn('    { "pos": 1, "pos_delay": 3, "line": 2, "ticks": ', GetPositionTimeEx(@M, 1, 3, 2), ' },');
  { (pos=1, pos_delay=3, line=3) -- full pattern 1 }
  WriteLn('    { "pos": 1, "pos_delay": 3, "line": 3, "ticks": ', GetPositionTimeEx(@M, 1, 3, 3), ' }');
  WriteLn('  ],');

  { ── get_time_params ──────────────────────────────────────────────── }
  WriteLn('  "time_params": [');
  { Manual inlining since FPC doesn't support nested procedures easily }
  GetTimeParams(@M, 0,  Pos, Line); Write('    { "time": 0,  "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 3,  Pos, Line); Write('    { "time": 3,  "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 6,  Pos, Line); Write('    { "time": 6,  "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 9,  Pos, Line); Write('    { "time": 9,  "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 12, Pos, Line); Write('    { "time": 12, "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 15, Pos, Line); Write('    { "time": 15, "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 20, Pos, Line); Write('    { "time": 20, "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 24, Pos, Line); Write('    { "time": 24, "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' },');
  GetTimeParams(@M, 25, Pos, Line); Write('    { "time": 25, "found": '); if Pos<>-1 then Write('true') else Write('false'); WriteLn(', "pos": ', Pos, ', "line": ', Line, ' }');
  WriteLn('  ]');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════════════════
  Main
  ═══════════════════════════════════════════════════════════════════════════ }

var
  Cmd: string;
begin
  if ParamCount < 1 then
  begin
    WriteLn(StdErr, 'Usage: vt_harness <test>');
    WriteLn(StdErr, 'Tests: noise_lfsr | envelopes | pt3_vol | note_tables |');
    WriteLn(StdErr, '       pattern_basic | pattern_envelope | pattern_arpeggio |');
    WriteLn(StdErr, '       level_tables | song_timing |');
    WriteLn(StdErr, '       prepare_zx_sqt | prepare_zx_fls');
    Halt(1);
  end;

  Cmd := LowerCase(ParamStr(1));

  if      Cmd = 'noise_lfsr'        then RunNoiseLFSR
  else if Cmd = 'envelopes'         then RunEnvelopes
  else if Cmd = 'pt3_vol'           then RunPT3Vol
  else if Cmd = 'note_tables'       then RunNoteTables
  else if Cmd = 'pattern_basic'     then RunPatternPlay(False, 'pattern_basic')
  else if Cmd = 'pattern_envelope'  then RunPatternPlay(True,  'pattern_envelope')
  else if Cmd = 'pattern_arpeggio'  then RunPatternArpeggio
  else if Cmd = 'level_tables'      then RunLevelTables
  else if Cmd = 'song_timing'       then RunSongTiming
  else if Cmd = 'prepare_zx_sqt'   then RunPrepareZXSQT
  else if Cmd = 'prepare_zx_fls'   then RunPrepareZXFLS
  else
  begin
    WriteLn(StdErr, 'Unknown test: ', Cmd);
    Halt(1);
  end;
end.
