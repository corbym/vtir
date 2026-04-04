{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit About;

{$mode objfpc}{$H+}

interface

uses
 Classes, Graphics, Forms, Controls, StdCtrls, Buttons, ExtCtrls;

type

 { TAboutBox }

 TAboutBox = class(TForm)
   Label4: TLabel;
   Label5: TLabel;
   Panel1: TPanel;
   OKButton: TButton;
   ProgramIcon: TImage;
   ProductName: TLabel;
   Version: TLabel;
   Copyright: TLabel;
   Comments: TLabel;
   Label1: TLabel;
   Label3: TLabel;
   Label2: TLabel;
   procedure FormCreate(Sender: TObject);
 private
   { Private declarations }
 public
   { Public declarations }
 end;

var
 AboutBox: TAboutBox;

implementation

{$R *.lfm}

uses Main;

procedure TAboutBox.FormCreate(Sender: TObject);
begin
 Version.Caption := HalfVersString;
end;

end.
 
