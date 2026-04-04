{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit nkeypeeker;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, LCLType;

type

 { TNKChooseFrm }

 TNKChooseFrm = class(TForm)
   LBNKeys: TListBox;
   procedure FormCreate(Sender: TObject);
   procedure LBNKeysClick(Sender: TObject);
   procedure LBNKeysKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
 private

 public

 end;

var
 NKChooseFrm: TNKChooseFrm;

implementation

uses
 keys;

 {$R *.lfm}

 { TNKChooseFrm }

procedure TNKChooseFrm.FormCreate(Sender: TObject);
var
 nks: TNoteKeyCodes;
begin
 for nks := Low(TNoteKeyCodes) to High(TNoteKeyCodes) do
   LBNKeys.Items.Add(NoteKeyCodesDesc[nks]);
end;

procedure TNKChooseFrm.LBNKeysClick(Sender: TObject);
begin
 ModalResult := mrOk;
end;

procedure TNKChooseFrm.LBNKeysKeyDown(Sender: TObject; var Key: word;
 Shift: TShiftState);
begin
 case Key of
   VK_RETURN:
    begin
     ModalResult := mrOk;
     Key := 0;
    end;
   VK_ESCAPE:
    begin
     ModalResult := mrCancel;
     Key := 0;
    end;
  end;
end;

end.
