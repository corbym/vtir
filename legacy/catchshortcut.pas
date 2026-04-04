{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit catchshortcut;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, LCLType;

type

 { TCatchSCFrm }

 TCatchSCFrm = class(TForm)
   Label1: TLabel;
   procedure FormClick(Sender: TObject);
   procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
 private

 public

 end;

var
 CatchSCFrm: TCatchSCFrm;
 CatchedShortcut: TShortCut;

implementation

{$R *.lfm}

{ TCatchSCFrm }

procedure TCatchSCFrm.FormClick(Sender: TObject);
begin
 ModalResult := mrCancel;
end;

procedure TCatchSCFrm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 if Key in [VK_UNKNOWN,
   //shifts
   VK_CONTROL, VK_SHIFT, VK_MENU, VK_LCONTROL, VK_LSHIFT, VK_LMENU,
   VK_RCONTROL, VK_RSHIFT, VK_RMENU, VK_LWIN, VK_RWIN] then
   Exit;
 CatchedShortcut := KeyToShortCut(Key, Shift);
 Key := 0;
 ModalResult := mrOk;
end;

end.
