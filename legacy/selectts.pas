{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit selectts;

{$MODE Delphi}

interface

uses
 SysUtils, Variants, Classes, Graphics, Controls, Forms,
 Dialogs, StdCtrls;

type
 TTSSel = class(TForm)
   ListBox1: TListBox;
   procedure FormCreate(Sender: TObject);
   procedure ListBox1MouseUp(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure ListBox1KeyPress(Sender: TObject; var Key: char);
 private
   { Private declarations }
 public
   { Public declarations }
 end;

var
 TSSel: TTSSel;

implementation

uses
 Languages;

 {$R *.lfm}

procedure TTSSel.FormCreate(Sender: TObject);
begin
 ListBox1.Items.AddObject(Mes_No2ndChip, nil);
 ListBox1.ItemIndex := 0;
end;

procedure TTSSel.ListBox1MouseUp(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 ModalResult := mrOk;
end;

procedure TTSSel.ListBox1KeyPress(Sender: TObject; var Key: char);
begin
 case Key of
   #13: ModalResult := mrOk;
   #27: ModalResult := mrCancel;
  end;
end;

end.
