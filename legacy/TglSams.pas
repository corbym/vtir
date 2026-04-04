{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit TglSams;

{$mode objfpc}{$H+}

interface

uses
 LCLType, SysUtils, Variants, Classes, Graphics, Controls, Forms,
 Dialogs, StdCtrls;

type

 { TToglSams }

 TToglSams = class(TForm)
   procedure FormCreate(Sender: TObject);
   procedure CheckBoxClick(Sender: TObject);
   procedure FormHide(Sender: TObject);
   procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure FormShow(Sender: TObject);
 private
   { Private declarations }
 public
   { Public declarations }
   procedure CheckUsedSamples;
   procedure CheckEnabledSamples;
 end;

var
 ToglSams: TToglSams;
 TogSam: array[1..31] of TCheckBox;

implementation

uses Main, ChildWin, trfuncs;

 {$R *.lfm}

procedure TToglSams.FormCreate(Sender: TObject);
var
 i, y, x: integer;
begin
 y := 8;
 x := 8;
 for i := 1 to 31 do
  begin
   TogSam[i] := TCheckBox.Create(Self);
   with TogSam[i] do
    begin
     Parent := Self;
     Top := y;
     Inc(y, Height + 8);
     Left := x;
     if i mod 8 = 0 then
      begin
       Inc(x, 40);
       y := 8;
      end;
     Caption := SampToStr(i);
     Width := 32;
     Tag := i;
     Checked := True;
     OnClick := @CheckBoxClick;
    end;
  end;
 ClientWidth := 4 * 40 + 4;
 ClientHeight := 8 * (TogSam[1].Height + 8) + 8;
end;

procedure TToglSams.CheckBoxClick(Sender: TObject);
var
 CurrentWindow: TChildForm;
 sam: integer;
begin
 if not MainForm.GetCurrentWindow(CurrentWindow) then
   Exit;
 with CurrentWindow do
   if VTMP <> nil then
    begin
     sam := (Sender as TCheckBox).Tag;
     ValidateSample2(sam);
     VTMP^.Samples[sam]^.Enabled := (Sender as TCheckBox).Checked;
    end;
end;

procedure TToglSams.FormHide(Sender: TObject);
var
 i, j: integer;
 sam: PSample;
 VTM: PModule;
begin
 if MainForm.Childs.Count = 0 then
   Exit;
 for i := 0 to MainForm.Childs.Count - 1 do
  begin
   VTM := TChildForm(MainForm.Childs.Items[i]).VTMP;
   if VTM <> nil then
     for j := 1 to 31 do
      begin
       sam := VTM^.Samples[j];
       if sam <> nil then sam^.Enabled := True;
       TogSam[j].Checked := True;
      end;
  end;
end;

procedure TToglSams.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 case Key of
   VK_RETURN, VK_ESCAPE:
    begin
     Hide;
     Key := 0;
    end;
  end;
end;

procedure TToglSams.FormShow(Sender: TObject);
begin
 MainForm.GlueFormToControl(Self, MainForm.TBToggleSams);
 CheckUsedSamples;
end;

procedure TToglSams.CheckUsedSamples;
var
 i, j, k, pat, sam, cnt: integer;
 CurrentWindow: TChildForm;
 PatUsed: array[0..MaxPatNum] of boolean;
begin
 //check for dialog shown
 if not Visible then
   Exit;

 //disable all
 for i := 1 to 31 do
   TogSam[i].Enabled := False;

 //check for module exists
 if MainForm.GetCurrentWindow(CurrentWindow) then
  begin

   //reset "pattern analized" flags
   FillChar(PatUsed, SizeOf(PatUsed), 0);

   cnt := 31; //max number of samples;

   with CurrentWindow, VTMP^, Positions do
     for i := 0 to Length - 1 do
      begin
       pat := Value[i];
       if not PatUsed[pat] then
        begin
         PatUsed[pat] := True; //don't check pattern twice
         if Patterns[pat] <> nil then
           with Patterns[pat]^ do
             for j := 0 to Length - 1 do
               for k := 0 to 2 do
                begin
                 sam := Items[j].Channel[k].Sample;
                 if (sam <> 0) and not TogSam[sam].Enabled then
                  begin
                   TogSam[sam].Enabled := True;
                   Dec(cnt);
                   if cnt = 0 then
                     //all samples used
                     Exit;
                  end;
                end;
        end;
      end;
  end;
end;

procedure TToglSams.CheckEnabledSamples;
var
 i: integer;
 CurrentWindow: TChildForm;
begin
 if MainForm.GetCurrentWindow(CurrentWindow) then
   with CurrentWindow.VTMP^ do
     for i := 1 to 31 do
       TogSam[i].Checked := (Samples[i] = nil) or Samples[i]^.Enabled;
end;

end.
