{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit midikbd;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, MMSystem, LCLType, LCLIntf;

const
 NoteOn = $90;
 NoteOff = $80;

//set callback window handle and message (call before MidiIn_Open or MidiIn_Ensure)
procedure MidiIn_Init(WHND: THandle; WMSG: integer);

//return current number of available MidiIn devices
function MidiIn_DevCnt: longword; inline;

//return name of MidiIn device; if empty then device is not available for the moment
function MidiIn_DevName(DevNum: longword): string;

//return name of last used MidiIn device; if empty then device was not opened yet
function MidiIn_DevName: string;

//manually set name of last used MidiIn device for further using in MidiIn_Ensure
procedure MidiIn_DevName(const aName: string);

//if DevName <> '' then try open by name, otherwise open by DevNum
function MidiIn_Open(DevNum: longword; const DevName: string): boolean;

//close if opened
procedure MidiIn_Close;

//ensure avail; if not then reopen or open 1st device
//return True if opened
function MidiIn_Ensure: boolean;

//return current device number by its name or -1 if error
function MidiIn_DevNum: integer;

implementation

var
 hMidiDevice: HMIDIIN = 0;
 nMidiDevice: string = '';
 wMidiDevice: THandle;
 mMidiDevice: integer;

procedure MidiIn_Init(WHND: THandle; WMSG: integer);
begin
 wMidiDevice := WHND;
 mMidiDevice := WMSG;
end;

function MidiIn_DevCnt: longword;
begin
 Result := midiInGetNumDevs;
end;

function MidiIn_DevName(DevNum: longword): string;
var
 incaps: MIDIINCAPS;
begin
 if (DevNum >= midiInGetNumDevs) or
   (midiInGetDevCaps(DevNum, @incaps, SizeOf(MIDIINCAPS)) <> MMSYSERR_NOERROR) then
   Result := ''
 else
   Result := incaps.szPname;
end;

function MidiIn_DevName: string;
begin
 Result := nMidiDevice;
end;

procedure MidiIn_DevName(const aName: string);
begin
 nMidiDevice := aName;
end;

procedure MidiInProc(hMidiIn: HMIDIIN; wMsg: UINT; dwInstance: DWORD;
 dwParam1: DWORD; dwParam2: DWORD); stdcall;
begin
 if (dwInstance = 0) and (wMsg = MIM_DATA) and (hMidiIn = hMidiDevice) then
   if dwParam1 and $f0 in [NoteOn, NoteOff] then //status byte
     PostMessage(wMidiDevice, mMidiDevice, dwParam1 and $f0, dwParam1 shr 8 and $7F7F);
 //lo byte pitch, hi byte velocity
end;

function MidiIn_Open(DevNum: longword; const DevName: string): boolean;
var
 Dev: longword;
 hMidDev: HMIDIIN;
 Nam: string;
begin
 if hMidiDevice <> 0 then
   MidiIn_Close;

 if DevName = '' then
   Dev := DevNum
 else
  begin
   Dev := 0;
   repeat
     Nam := MidiIn_DevName(Dev);
     Result := Nam = DevName;
     if Result or (Nam = '') then
       Break;
     Inc(Dev);
   until False;
   if not Result then
     Dev := DevNum;
  end;

 if midiInOpen(@hMidDev, Dev, {%H-}PtrInt(@MidiInProc), 0, CALLBACK_FUNCTION) <>
   MMSYSERR_NOERROR then
   Exit(False);

 if midiInStart(hMidDev) <> MMSYSERR_NOERROR then
  begin
   midiInClose(hMidDev);
   Exit(False);
  end;

 hMidiDevice := hMidDev;
 nMidiDevice := MidiIn_DevName(Dev);
 Result := True;
end;

procedure MidiIn_Close;
begin
 if hMidiDevice <> 0 then
  begin
   midiInStop(hMidiDevice);
   midiInClose(hMidiDevice);
   hMidiDevice := 0;
  end;
end;

function MidiIn_Ensure: boolean;
var
 Dev, TheDev: longword;
 Nam: string;
begin
 if hMidiDevice = 0 then
   //open last used (by name) or 1st device
   MidiIn_Open(0, nMidiDevice)
 else
   //check if opened device is still present
  begin
   Dev := 0;
   repeat
     Nam := MidiIn_DevName(Dev);
     if Nam = '' then //device list is gone, prev name not found
      begin
       //open 1st device
       MidiIn_Open(0, '');
       Break;
      end;
     if Nam = nMidiDevice then //found device with same name
      begin
       if (midiInGetID(hMidiDevice, @TheDev) = MMSYSERR_NOERROR) and
         (Dev = TheDev) then //totally same device
        begin
         //seems no way to ensure running after quick midi keyboard reconnection:
         //midiInStop and midiInStart both ignored
         //so, user must reconect keyboard slower, then MidiIn_Ensure recalled
         Break;
        end;
      end;
     Inc(Dev);
   until False;
  end;
 Result := hMidiDevice <> 0;
end;

function MidiIn_DevNum: integer;
var
 TheDev: longword;
begin
 if (hMidiDevice <> 0) and (midiInGetID(hMidiDevice, @TheDev) = MMSYSERR_NOERROR) then
   Result := TheDev
 else
   Result := -1;
end;

end.
