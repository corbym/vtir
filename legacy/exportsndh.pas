{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit ExportSNDH;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

 { TExpSNDHDlg }

 TExpSNDHDlg = class(TForm)
   BtOK: TButton;
   Button2: TButton;
   CBNonPacked: TCheckBox;
   EdYear: TEdit;
   LbYear: TLabel;
   procedure EdYearChange(Sender: TObject);
   procedure FormShow(Sender: TObject);
   procedure CheckAll;
 private

 public

 end;

var
 ExpSNDHDlg: TExpSNDHDlg;
 ExpSNDHYear: longint;

implementation

{$R *.lfm}

{ TExpSNDHDlg }

procedure TExpSNDHDlg.FormShow(Sender: TObject);
begin
 EdYear.Clear;
 CheckAll;
end;

procedure TExpSNDHDlg.EdYearChange(Sender: TObject);
begin
 if EdYear.Modified then
   CheckAll;
end;

procedure TExpSNDHDlg.CheckAll;
var
 s: string;
begin
 s := Trim(EdYear.Text);
 if s = '' then
   ExpSNDHYear := 0;
 BtOK.Enabled := (s = '') or (TryStrToInt(s, ExpSNDHYear) and
   (ExpSNDHYear >= 1985) and (ExpSNDHYear <= CurrentYear));
end;

end.
