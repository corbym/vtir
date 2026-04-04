{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit GlbTrn;

{$mode objfpc}{$H+}

interface

uses
 LCLType, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
 StdCtrls, ComCtrls;

type

 { TGlbTrans }

 TGlbTrans = class(TForm)
   GroupBox1: TGroupBox;
   CheckBox4: TCheckBox;
   CheckBox1: TCheckBox;
   CheckBox2: TCheckBox;
   CheckBox3: TCheckBox;
   GroupBox2: TGroupBox;
   UpDown8: TUpDown;
   Edit8: TEdit;
   Label8: TLabel;
   RadioButton1: TRadioButton;
   RadioButton2: TRadioButton;
   Edit2: TEdit;
   UpDown1: TUpDown;
   Button1: TButton;
   Button2: TButton;
   procedure Edit2Change(Sender: TObject);
   procedure Edit2ExitOrDone(Sender: TObject);
   procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure FormShow(Sender: TObject);
   procedure Edit8ExitOrDone(Sender: TObject);
   procedure Button1Click(Sender: TObject);
   procedure Button2Click(Sender: TObject);
 private
   { Private declarations }
 public
   { Public declarations }
 end;

var
 GlbTrans: TGlbTrans;

implementation

uses Main, ChildWin, trfuncs, Languages;

 {$R *.lfm}

procedure TGlbTrans.Edit2ExitOrDone(Sender: TObject);
begin
 Edit2.Text := IntToStr(UpDown1.Position);
end;

procedure TGlbTrans.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 //form is active, so try preview before global actions fires
 case Key of
   VK_RETURN:
    begin
     Button1.Click;
     Key := 0;
    end;
   VK_ESCAPE:
    begin
     Button2.Click;
     Key := 0;
    end;
  end;
end;

procedure TGlbTrans.Edit2Change(Sender: TObject);
begin
 if Edit2.Modified then
   RadioButton2.Checked := True;
end;

procedure TGlbTrans.FormShow(Sender: TObject);
begin
 MainForm.GlueFormToControl(Self, MainForm.TBGlbTrans);
 if MainForm.ActiveChildExists then
   UpDown1.Position := MainForm.ActiveChild.PatNum;
 Edit8.SelectAll;
 Edit8.SetFocus;
end;

procedure TGlbTrans.Edit8ExitOrDone(Sender: TObject);
begin
 Edit8.Text := IntToStr(UpDown8.Position);
end;

procedure TGlbTrans.Button1Click(Sender: TObject);
var
 i: integer;
 Chans: TChansArrayBool;
 CurrentWindow: TChildForm;
begin
 if UpDown8.Position = 0 then
   Exit;
 if not CheckBox1.Checked and not CheckBox2.Checked and not
   CheckBox3.Checked and not CheckBox4.Checked then
   Exit;
 if not MainForm.GetCurrentWindow(CurrentWindow) then
   Exit;
 Chans[0] := CheckBox1.Checked;
 Chans[1] := CheckBox2.Checked;
 Chans[2] := CheckBox3.Checked;

 if RadioButton1.Checked then
  begin
   if CurrentWindow.AcceptCannotUndo(Mes_UndoThisOp) then
     for i := 0 to MaxPatNum do MainForm.TransposeColumns(CurrentWindow, i,
         CheckBox4.Checked, Chans, 0, MaxPatLen - 1, UpDown8.Position, False);
  end
 else
   MainForm.TransposeColumns(CurrentWindow, UpDown1.Position,
     CheckBox4.Checked, Chans, 0, MaxPatLen - 1, UpDown8.Position, True);
end;

procedure TGlbTrans.Button2Click(Sender: TObject);
begin
 Hide;
end;

end.
