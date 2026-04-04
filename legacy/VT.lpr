{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

program VT;

{$mode objfpc}{$H+}

uses
 Forms, Interfaces,
 Main, ChildWin, About, trfuncs, options, TrkMng, GlbTrn, ExportZX, FXMImport,
 selectts, TglSams, Config, WinVersion, Languages, digsound, digsoundcode, AY,
 keys, catchshortcut, nkeypeeker, ice, ExportSNDH, digsoundbuf, midikbd;

{$R SNDH\SNDH.rc}
{$R ZXAYHOBETA\ZX.rc}
{$R *.res}

begin
 Application.Initialize;
 Application.CreateForm(TMainForm, MainForm);
 Application.CreateForm(TAboutBox, AboutBox);
 Application.CreateForm(TOptionsDlg, OptionsDlg);
 Application.CreateForm(TTrMng, TrMng);
 Application.CreateForm(TGlbTrans, GlbTrans);
 Application.CreateForm(TExpDlg, ExpDlg);
 Application.CreateForm(TFXMParams, FXMParams);
 Application.CreateForm(TTSSel, TSSel);
 Application.CreateForm(TToglSams, ToglSams);
 Application.CreateForm(TCatchSCFrm, CatchSCFrm);
 Application.CreateForm(TNKChooseFrm, NKChooseFrm);
 Application.CreateForm(TExpSNDHDlg, ExpSNDHDlg);
 Application.Run;
end.
