{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit AY;

{$mode objfpc}{$H+}
{$ASMMODE intel}

interface

uses LCLIntf, SysUtils;

const
 //Amplitude tables of sound chips
 { (c)Hacker KAY }
 Amplitudes_AY: array[0..15] of word =
   (0, 836, 1212, 1773, 2619, 3875, 5397, 8823, 10392, 16706, 23339,
   29292, 36969, 46421, 55195, 65535);
{ (c)V_Soft
 Amplitudes_AY:array[0..15]of Word=
    (0, 513, 828, 1239, 1923, 3238, 4926, 9110, 10344, 17876, 24682,
    30442, 38844, 47270, 56402, 65535);}
{ (c)Lion17
 Amplitudes_YM:array[0..31]of Word=
    (0,  30,  190,  286, 375, 470, 560, 664, 866, 1130, 1515, 1803, 2253,
    2848, 3351, 3862, 4844, 6058, 7290, 8559, 10474, 12878, 15297, 17787,
    21500, 26172, 30866, 35676, 42664, 50986, 58842, 65535);}
 { (c)Hacker KAY }
 Amplitudes_YM: array[0..31] of word =
   (0, 0, $F8, $1C2, $29E, $33A, $3F2, $4D7, $610, $77F, $90A, $A42,
   $C3B, $EC2, $1137, $13A7, $1750, $1BF9, $20DF, $2596, $2C9D, $3579,
   $3E55, $4768, $54FF, $6624, $773B, $883F, $A1DA, $C0FC, $E094, $FFFF);

 //Default mixer parameters
 SampleRateDef = 48000;
 SampleBitDef = 16;
 AY_FreqDef = 1773400;
 MaxTStatesDef = 69888;
 Interrupt_FreqDef = 50000;
 NumOfChanDef = 2;
 ChanAllocDef = 1;
 NumberOfBuffersDef = 3;
 BufLen_msDef = 200;

 FiltInfo: string = '';

type
 TRegisterAY = packed record
   case integer of
     0: (Index: array[0..15] of byte);
     1: (TonA, TonB, TonC: word;
       Noise: byte;
       Mixer: byte;
       AmplitudeA, AmplitudeB, AmplitudeC: byte;
       Envelope: word;
       EnvType: byte);
 end;

 //Available soundchips
 TChipTypes = (No_Chip, AY_Chip, YM_Chip);

 //Panning
 TLevels = record
   Level_AR, Level_AL,
   Level_BR, Level_BL,
   Level_CR, Level_CL: array[0..31] of integer;
 end;

 TSoundChip = object
   RegisterAY: TRegisterAY;
   First_Period: boolean;
   Ampl: integer;
   Ton_Counter_A, Ton_Counter_B, Ton_Counter_C, Noise_Counter: packed record
     case integer of
       0: (Lo: word;
         Hi: word);
       1: (Re: longword);
     end;
   Envelope_Counter: packed record
     case integer of
       0: (Lo: dword;
         Hi: dword);
       1: (Re: int64);
     end;
   Ton_A, Ton_B, Ton_C: integer;
   Noise: packed record
     case boolean of
       True: (Seed: longword);
       False: (Low: word;
         Val: dword);
     end;
   Case_EnvType: procedure of object;
   Ton_EnA, Ton_EnB, Ton_EnC, Noise_EnA, Noise_EnB, Noise_EnC: boolean;
   Envelope_EnA, Envelope_EnB, Envelope_EnC: boolean;
   procedure Case_EnvType_0_3__9;
   procedure Case_EnvType_4_7__15;
   procedure Case_EnvType_8;
   procedure Case_EnvType_10;
   procedure Case_EnvType_11;
   procedure Case_EnvType_12;
   procedure Case_EnvType_13;
   procedure Case_EnvType_14;
   procedure Synthesizer_Logic_Q;
   procedure SetMixerRegister(Value: byte);
   procedure SetEnvelopeRegister(Value: byte);
   procedure SetAmplA(Value: byte);
   procedure SetAmplB(Value: byte);
   procedure SetAmplC(Value: byte);
   procedure SetAYRegister(Num: integer; Value: byte);
   procedure SetAYRegisterFast(Num: integer; Value: byte);
   procedure Synthesizer_Mixer_Q(var LevelL, LevelR: integer; const Levels: TLevels);
   procedure Synthesizer_Mixer_Q_Mono(var Level: integer; const Levels: TLevels);
   procedure Reset;
 end;

implementation

uses
 Main, trfuncs, options;

procedure TSoundChip.Case_EnvType_0_3__9;
begin
 if First_Period then
  begin
   Dec(Ampl);
   if Ampl = 0 then First_Period := False;
  end;
end;

procedure TSoundChip.Case_EnvType_4_7__15;
begin
 if First_Period then
  begin
   Inc(Ampl);
   if Ampl = 32 then
    begin
     First_Period := False;
     Ampl := 0;
    end;
  end;
end;

procedure TSoundChip.Case_EnvType_8;
begin
 Ampl := (Ampl - 1) and 31;
end;

procedure TSoundChip.Case_EnvType_10;
begin
 if First_Period then
  begin
   Dec(Ampl);
   if Ampl < 0 then
    begin
     First_Period := False;
     Ampl := 0;
    end;
  end
 else
  begin
   Inc(Ampl);
   if Ampl = 32 then
    begin
     First_Period := True;
     Ampl := 31;
    end;
  end;
end;

procedure TSoundChip.Case_EnvType_11;
begin
 if First_Period then
  begin
   Dec(Ampl);
   if Ampl < 0 then
    begin
     First_Period := False;
     Ampl := 31;
    end;
  end;
end;

procedure TSoundChip.Case_EnvType_12;
begin
 Ampl := (Ampl + 1) and 31;
end;

procedure TSoundChip.Case_EnvType_13;
begin
 if First_Period then
  begin
   Inc(Ampl);
   if Ampl = 32 then
    begin
     First_Period := False;
     Ampl := 31;
    end;
  end;
end;

procedure TSoundChip.Case_EnvType_14;
begin
 if not First_Period then
  begin
   Dec(Ampl);
   if Ampl < 0 then
    begin
     First_Period := True;
     Ampl := 0;
    end;
  end
 else
  begin
   Inc(Ampl);
   if Ampl = 32 then
    begin
     First_Period := False;
     Ampl := 31;
    end;
  end;
end;

function NoiseGenerator(Seed: integer): integer;
begin
 {$ifdef cpu32}
asm
 shld edx,eax,16
 shld ecx,eax,19
 xor ecx,edx
 and ecx,1
 add eax,eax
 and eax,$1ffff
 inc eax
 xor eax,ecx
end;
 {$else}
 Result := (((Seed shl 1) or 1) xor ((Seed shr 16) xor (Seed shr 13) and 1)) and $1ffff;
 {$endif}
end;

procedure TSoundChip.Synthesizer_Logic_Q;
begin
 Inc(Ton_Counter_A.Hi);
 if Ton_Counter_A.Hi >= RegisterAY.TonA then
  begin
   Ton_Counter_A.Hi := 0;
   Ton_A := Ton_A xor 1;
  end;
 Inc(Ton_Counter_B.Hi);
 if Ton_Counter_B.Hi >= RegisterAY.TonB then
  begin
   Ton_Counter_B.Hi := 0;
   Ton_B := Ton_B xor 1;
  end;
 Inc(Ton_Counter_C.Hi);
 if Ton_Counter_C.Hi >= RegisterAY.TonC then
  begin
   Ton_Counter_C.Hi := 0;
   Ton_C := Ton_C xor 1;
  end;
 Inc(Noise_Counter.Hi);
 if (Noise_Counter.Hi and 1 = 0) and (Noise_Counter.Hi >= RegisterAY.Noise shl 1) then
  begin
   Noise_Counter.Hi := 0;
   Noise.Seed := NoiseGenerator(Noise.Seed);
  end;
 if Envelope_Counter.Hi = 0 then Case_EnvType;
 Inc(Envelope_Counter.Hi);
 if Envelope_Counter.Hi >= RegisterAY.Envelope then
   Envelope_Counter.Hi := 0;
end;

procedure TSoundChip.SetMixerRegister(Value: byte);
begin
 RegisterAY.Mixer := Value;
 Ton_EnA := (Value and 1) = 0;
 Noise_EnA := (Value and 8) = 0;
 Ton_EnB := (Value and 2) = 0;
 Noise_EnB := (Value and 16) = 0;
 Ton_EnC := (Value and 4) = 0;
 Noise_EnC := (Value and 32) = 0;
end;

procedure TSoundChip.SetEnvelopeRegister(Value: byte);
begin
 Envelope_Counter.Hi := 0;
 First_Period := True;
 if (Value and 4) = 0 then
   ampl := 32
 else
   ampl := -1;
 RegisterAY.EnvType := Value;
 case Value of
   0..3, 9: Case_EnvType := @Case_EnvType_0_3__9;
   4..7, 15: Case_EnvType := @Case_EnvType_4_7__15;
   8: Case_EnvType := @Case_EnvType_8;
   10: Case_EnvType := @Case_EnvType_10;
   11: Case_EnvType := @Case_EnvType_11;
   12: Case_EnvType := @Case_EnvType_12;
   13: Case_EnvType := @Case_EnvType_13;
   14: Case_EnvType := @Case_EnvType_14;
  end;
end;

procedure TSoundChip.SetAmplA(Value: byte);
begin
 RegisterAY.AmplitudeA := Value;
 Envelope_EnA := (Value and 16) = 0;
end;

procedure TSoundChip.SetAmplB(Value: byte);
begin
 RegisterAY.AmplitudeB := Value;
 Envelope_EnB := (Value and 16) = 0;
end;

procedure TSoundChip.SetAmplC(Value: byte);
begin
 RegisterAY.AmplitudeC := Value;
 Envelope_EnC := (Value and 16) = 0;
end;

procedure TSoundChip.SetAYRegister(Num: integer; Value: byte);
begin
 case Num of
   13:
     SetEnvelopeRegister(Value and 15);
   1, 3, 5:
     RegisterAY.Index[Num] := Value and 15;
   6:
     RegisterAY.Noise := Value and 31;
   7: SetMixerRegister(Value and 63);
   8: SetAmplA(Value and 31);
   9: SetAmplB(Value and 31);
   10: SetAmplC(Value and 31);
   0, 2, 4, 11, 12:
     RegisterAY.Index[Num] := Value;
  end;
end;

procedure TSoundChip.SetAYRegisterFast(Num: integer; Value: byte);
begin
 case Num of
   13:
     SetEnvelopeRegister(Value);
   1, 3, 5:
     RegisterAY.Index[Num] := Value;
   6:
     RegisterAY.Noise := Value;
   7: SetMixerRegister(Value);
   8: SetAmplA(Value);
   9: SetAmplB(Value);
   10: SetAmplC(Value);
   0, 2, 4, 11, 12:
     RegisterAY.Index[Num] := Value;
  end;
end;

procedure TSoundChip.Synthesizer_Mixer_Q(var LevelL, LevelR: integer; const Levels: TLevels);
var
 k: integer;
begin
 k := 1;
 if Ton_EnA then k := Ton_A;
 if Noise_EnA then k := k and Noise.Val;
 if k <> 0 then
  begin
   if Envelope_EnA then
    begin
     Inc(LevelL, Levels.Level_AL[RegisterAY.AmplitudeA * 2 + 1]);
     Inc(LevelR, Levels.Level_AR[RegisterAY.AmplitudeA * 2 + 1]);
    end
   else
    begin
     Inc(LevelL, Levels.Level_AL[Ampl]);
     Inc(LevelR, Levels.Level_AR[Ampl]);
    end;
  end;

 k := 1;
 if Ton_EnB then k := Ton_B;
 if Noise_EnB then k := k and Noise.Val;
 if k <> 0 then
   if Envelope_EnB then
    begin
     Inc(LevelL, Levels.Level_BL[RegisterAY.AmplitudeB * 2 + 1]);
     Inc(LevelR, Levels.Level_BR[RegisterAY.AmplitudeB * 2 + 1]);
    end
   else
    begin
     Inc(LevelL, Levels.Level_BL[Ampl]);
     Inc(LevelR, Levels.Level_BR[Ampl]);
    end;

 k := 1;
 if Ton_EnC then k := Ton_C;
 if Noise_EnC then k := k and Noise.Val;
 if k <> 0 then
   if Envelope_EnC then
    begin
     Inc(LevelL, Levels.Level_CL[RegisterAY.AmplitudeC * 2 + 1]);
     Inc(LevelR, Levels.Level_CR[RegisterAY.AmplitudeC * 2 + 1]);
    end
   else
    begin
     Inc(LevelL, Levels.Level_CL[Ampl]);
     Inc(LevelR, Levels.Level_CR[Ampl]);
    end;
end;

procedure TSoundChip.Synthesizer_Mixer_Q_Mono(var Level: integer; const Levels: TLevels);
var
 k: integer;
begin
 k := 1;
 if Ton_EnA then k := Ton_A;
 if Noise_EnA then k := k and Noise.Val;
 if k <> 0 then
   if Envelope_EnA then
     Inc(Level, Levels.Level_AL[RegisterAY.AmplitudeA * 2 + 1])
   else
     Inc(Level, Levels.Level_AL[Ampl]);

 k := 1;
 if Ton_EnB then k := Ton_B;
 if Noise_EnB then k := k and Noise.Val;
 if k <> 0 then
   if Envelope_EnB then
     Inc(Level, Levels.Level_BL[RegisterAY.AmplitudeB * 2 + 1])
   else
     Inc(Level, Levels.Level_BL[Ampl]);

 k := 1;
 if Ton_EnC then k := Ton_C;
 if Noise_EnC then k := k and Noise.Val;
 if k <> 0 then
   if Envelope_EnC then
     Inc(Level, Levels.Level_CL[RegisterAY.AmplitudeC * 2 + 1])
   else
     Inc(Level, Levels.Level_CL[Ampl]);
end;

procedure TSoundChip.Reset;
begin
 FillChar(RegisterAY, 14, 0);
 SetEnvelopeRegister(0);
 SetMixerRegister(0);
 SetAmplA(0);
 SetAmplB(0);
 SetAmplC(0);
 First_Period := False;
 Ampl := 0;
 Envelope_Counter.Re := 0;
 Ton_Counter_A.Re := 0;
 Ton_Counter_B.Re := 0;
 Ton_Counter_C.Re := 0;
 Noise_Counter.Re := 0;
 Ton_A := 0;
 Ton_B := 0;
 Ton_C := 0;
 Noise.Seed := $ffff;
 Noise.Val := 0;
end;

end.
