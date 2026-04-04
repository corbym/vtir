{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit Main;

{$mode objfpc}{$H+}

interface

uses
 LCLIntf, LCLType, lazutf8, LMessages, LCLProc, LCLTranslator,
 {$IFDEF Windows}
 Windows,
 {$ENDIF Windows}
 SysUtils, Classes, Graphics, Forms, Controls, Menus,
 StdCtrls, Dialogs, Buttons, Messages, ExtCtrls, ComCtrls,
 ActnList, ImgList, AY, digsoundcode, digsound, trfuncs, Grids, ChildWin,
 Config, Languages, keys, TypInfo, Types, midikbd;

const
 UM_FINALIZEDS = WM_USER + 2;
 UM_MIDINOTE = WM_USER + 3;

 ChannelsAllocationCarouselDef = 15; //Mono/ABC/ACB/BAC
 TracksNOfLinesDef = 11;
 AutoStepValueDef = 1;
 DecTrLinesDef = False;
 DecNoiseDef = False;
 EnvAsNoteDef = True;
 RecalcEnvDef = True;
 BgAllowMIDIDef = False;
 SamAsNoteDef = False;
 OrnAsNoteDef = False;
 TracksHintDef = False;
 SamHintDef = False;
 OrnHintDef = False;
 SamOrnHLinesDef = False;
 NotWarnUndoDef = False;
 LMBToDrawDef = False;

 StdAutoEnvMax = 7;
 StdAutoEnv: array[0..StdAutoEnvMax, 0..1] of integer =
   ((1, 1), (3, 4), (1, 2), (1, 4), (3, 1), (5, 2), (2, 1), (3, 2));

 //Version related constants
 VersionString = '1.0';
 IsBeta = ''; //' beta';
 BetaNumber = ''; //' 32';

 FullVersString: string = 'Vortex Tracker II v' + VersionString + IsBeta + BetaNumber;
 HalfVersString: string = 'Version ' + VersionString + IsBeta + BetaNumber;

type
 TTileMode = (tbHorizontal, tbVertical);

 TChansArrayBool = array [0..2] of boolean;

 //adds extension to SaveDialog filename
 TCheckExtProc = procedure;

 TSetOfByte = set of byte;

 TVolumeControl = class(TGraphicControl)
 private
   FClicked: boolean;
 protected
   procedure SetVol(Value: integer);
 public
   constructor Create(AOwner: TComponent); override;
   procedure VolPaint(Sender: TObject);
   procedure VolMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure VolMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure VolMouseUp(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
 end;

 { TMainForm }

 TMainForm = class(TForm)
  MIZXTSPlayer: TMenuItem;
  MILims: TMenuItem;
  MIZXAYPlayer: TMenuItem;
  MIHierarchy: TMenuItem;
  MITablesCsv: TMenuItem;
  MIOtherHelp: TMenuItem;
   MIHistory: TMenuItem;
   MIManual: TMenuItem;
   MIQuickGuide: TMenuItem;
   MIMaximized: TMenuItem;
   MIRestore1: TMenuItem;
   MIClose1: TMenuItem;
   MergePositions: TAction;
   MIPosLstRedo: TMenuItem;
   MIPosLstUndo: TMenuItem;
   MIPosLstMerge: TMenuItem;
   MIPosLstPaste: TMenuItem;
   MIPosLstCut: TMenuItem;
   MIPosLstCopy: TMenuItem;
   RenumPats: TAction;
   ChangePatLen: TAction;
   ClonePositions: TAction;
   DuplicatePositions: TAction;
   MIRenumPats: TMenuItem;
   MIChnPatLen: TMenuItem;
   MIPosSelectAll: TMenuItem;
   MISelectAll: TMenuItem;
   MITracksSelectAll: TMenuItem;
   MIClonePos: TMenuItem;
   MIDupPos: TMenuItem;
   PackPattern1: TMenuItem;
   Separator10: TMenuItem;
   Separator11: TMenuItem;
   Separator12: TMenuItem;
   Separator13: TMenuItem;
   Separator14: TMenuItem;
   Separator15: TMenuItem;
   Separator6: TMenuItem;
   Separator7: TMenuItem;
   Separator8: TMenuItem;
   Separator9: TMenuItem;
   SplitPattern1: TMenuItem;
   MIPat3: TMenuItem;
   MIPat2: TMenuItem;
   MIPat1: TMenuItem;
   PatJmp3: TAction;
   PatJmp2: TAction;
   PatJmp1: TAction;
   PatJmp0: TAction;
   MIPat0: TMenuItem;
   MIJumpInPat: TMenuItem;
   MITranspose: TMenuItem;
   MISwapLeft: TMenuItem;
   MISwapRight: TMenuItem;
   Separator4: TMenuItem;
   Separator5: TMenuItem;
   SwapChansRight: TAction;
   SwapChansLeft: TAction;
   SeparatorW: TMenuItem;
   NextWindowItem: TMenuItem;
   PrevWindowItem: TMenuItem;
   NextWindow1: TAction;
   PreviousWindow1: TAction;
   Separator3: TMenuItem;
   Workspace: TPanel;
   HScrollBar: TScrollBar;
   VScrollBar: TScrollBar;
   MITransposeD5: TMenuItem;
   MITransposeU5: TMenuItem;
   MITransposeD3: TMenuItem;
   MITransposeU3: TMenuItem;
   TransposeDown5: TAction;
   TransposeUp5: TAction;
   TransposeDown3: TAction;
   TransposeUp3: TAction;
   ToggleMidiVol: TAction;
   ToggleMidiKbd: TAction;
   ConvToWAVMenu: TMenuItem;
   Progress: TProgressBar;
   SaveDialogWAV: TSaveDialog;
   SBCancel: TSpeedButton;
   MidiInTimer: TTimer;
   TBDivMidi: TToolButton;
   TBMidiKbd: TToolButton;
   TBMidiV: TToolButton;
   TBChip: TToolButton;
   TBChans: TToolButton;
   VolumeUp: TAction;
   VolumeDown: TAction;
   ConvToPSGMenu: TMenuItem;
   Octave1: TAction;
   Octave2: TAction;
   Octave3: TAction;
   Octave4: TAction;
   Octave5: TAction;
   Octave6: TAction;
   Octave7: TAction;
   Octave8: TAction;
   AutoPrms: TAction;
   AutoEnvStd: TAction;
   AutoEnv: TAction;
   AutoStep: TAction;
   GlobalTransposition: TAction;
   SaveDialogPSG: TSaveDialog;
   TracksManager: TAction;
   ToggleSamples: TAction;
   Options1: TAction;
   FindWindow1: TAction;
   CloseAll1: TAction;
   Copy2: TMenuItem;
   Cut2: TMenuItem;
   MainMenu1: TMainMenu;
   File1: TMenuItem;
   FileNewItem: TMenuItem;
   FileOpenItem: TMenuItem;
   FileCloseItem: TMenuItem;
   CloseAllItem: TMenuItem;
   FindWindowItem: TMenuItem;
   N10: TMenuItem;
   Paste2: TMenuItem;
   PMGeneral: TPopupMenu;
   Redo3: TMenuItem;
   Separator1: TMenuItem;
   Separator2: TMenuItem;
   TBDivPlay: TToolButton;
   TBDivOpts: TToolButton;
   TBOptions: TToolButton;
   Undo3: TMenuItem;
   VisTimer: TTimer;
   Window1: TMenuItem;
   Help1: TMenuItem;
   N1: TMenuItem;
   FileExitItem: TMenuItem;
   WindowCascadeItem: TMenuItem;
   WindowTileItem: TMenuItem;
   HelpAboutItem: TMenuItem;
   OpenDialogVTM: TOpenDialog;
   FileSaveItem: TMenuItem;
   FileSaveAsItem: TMenuItem;
   Edit1: TMenuItem;
   CutItem: TMenuItem;
   CopyItem: TMenuItem;
   PasteItem: TMenuItem;
   MainStatusBar: TStatusBar;
   ActionList1: TActionList;
   FileNew1: TAction;
   FileSave1: TAction;
   FileExit1: TAction;
   FileOpen1: TAction;
   FileSaveAs1: TAction;
   WindowCascade1: TAction;
   WindowTileHorizontal1: TAction;
   HelpAbout1: TAction;
   FileClose1: TAction;
   WindowTileVertical1: TAction;
   WindowTileItem2: TMenuItem;
   MainToolBar: TToolBar;
   TBOpen: TToolButton;
   TBSave: TToolButton;
   TBDivFile: TToolButton;
   TBCut: TToolButton;
   TBCopy: TToolButton;
   TBPaste: TToolButton;
   TBNew: TToolButton;
   TBDivClpBrd: TToolButton;
   TBCascade: TToolButton;
   TBTileHor: TToolButton;
   TBTileVert: TToolButton;
   ImageList1: TImageList;
   N2: TMenuItem;
   OptionsItem: TMenuItem;
   SaveDialogVTM: TSaveDialog;
   TBDivWin: TToolButton;
   TBPlay: TToolButton;
   Play1: TAction;
   TBStop: TToolButton;
   Stop1: TAction;
   Play2: TMenuItem;
   Play4: TMenuItem;
   Stop2: TMenuItem;
   PMPosList: TPopupMenu;
   Setloopposition1: TMenuItem;
   Deleteposition1: TMenuItem;
   MIAddPos: TMenuItem;
   SetLoopPos: TAction;
   AddPositions: TAction;
   DeletePositions: TAction;
   TBLoop: TToolButton;
   ToggleLooping: TAction;
   Togglelooping1: TMenuItem;
   N3: TMenuItem;
   RFile1: TMenuItem;
   RFile2: TMenuItem;
   RFile3: TMenuItem;
   RFile4: TMenuItem;
   RFile5: TMenuItem;
   RFile6: TMenuItem;
   TBDivLoop: TToolButton;
   ToggleChip: TAction;
   ToggleChanAlloc: TAction;
   TBLoopAll: TToolButton;
   ToggleLoopingAll: TAction;
   TBPlayPos: TToolButton;
   PlayFromPos: TAction;
   Play3: TMenuItem;
   Toggleloopingall1: TMenuItem;
   N4: TMenuItem;
   TracksManagerItem: TMenuItem;
   Globaltransposition1: TMenuItem;
   TBDivChip: TToolButton;
   PlayPat: TAction;
   PlayPatFromLine: TAction;
   TBPlayPatFrom: TToolButton;
   TBPlayPat: TToolButton;
   Playpatternfromstart1: TMenuItem;
   Playpatternfromcurrentline1: TMenuItem;
   Exports1: TMenuItem;
   SaveSNDHMenu: TMenuItem;
   SaveDialogSNDH: TSaveDialog;
   SaveforZXMenu: TMenuItem;
   SaveDialogZXAY: TSaveDialog;
   EditCopy1: TAction;
   EditCut1: TAction;
   EditPaste1: TAction;
   TBDivUndo: TToolButton;
   TBUndo: TToolButton;
   TBRedo: TToolButton;
   Undo: TAction;
   Redo: TAction;
   Undo1: TMenuItem;
   Redo1: TMenuItem;
   TransposeUp1: TAction;
   TransposeDown1: TAction;
   TransposeUp12: TAction;
   TransposeDown12: TAction;
   PMTracks: TPopupMenu;
   MITransposeU1: TMenuItem;
   MITransposeD1: TMenuItem;
   MITransposeU12: TMenuItem;
   MITransposeD12: TMenuItem;
   N5: TMenuItem;
   Undo2: TMenuItem;
   Redo2: TMenuItem;
   N6: TMenuItem;
   Copy1: TMenuItem;
   Cut1: TMenuItem;
   Paste1: TMenuItem;
   N7: TMenuItem;
   TBTracksMngr: TToolButton;
   TBGlbTrans: TToolButton;
   TBDivEdit: TToolButton;
   PMToolBar: TPopupMenu;
   File2: TMenuItem;
   Clipboard1: TMenuItem;
   UndoRedo1: TMenuItem;
   Window2: TMenuItem;
   Play5: TMenuItem;
   Track1: TMenuItem;
   N8: TMenuItem;
   TogglesamplesItem: TMenuItem;
   TBToggleSams: TToolButton;
   N9: TMenuItem;
   ExpandTwice1: TMenuItem;
   ShrinkTwice1: TMenuItem;
   Merge1: TMenuItem;
   procedure ChangePatLenExecute(Sender: TObject);
   procedure DeletePositionsUpdate(Sender: TObject);
   procedure InsertPositionsExecute(Sender: TObject);
   procedure InsertPositionsUpdate(Sender: TObject);
   procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
   procedure ActiveControlChangedHandler(Sender: TObject; LastControl: TControl);
   procedure MIHierarchyClick(Sender: TObject);
   procedure MIHistoryClick(Sender: TObject);
   procedure MILimsClick(Sender: TObject);
   procedure MIManualClick(Sender: TObject);
   procedure MIMaximizedClick(Sender: TObject);
   procedure MIQuickGuideClick(Sender: TObject);
   procedure MIRestore1Click(Sender: TObject);
   procedure MIClose1Click(Sender: TObject);
   procedure MergePositionsExecute(Sender: TObject);
   procedure MergePositionsUpdate(Sender: TObject);
   procedure MIPosSelectAllClick(Sender: TObject);
   procedure MISelectAllClick(Sender: TObject);
   procedure MITablesCsvClick(Sender: TObject);
   procedure MITracksSelectAllClick(Sender: TObject);
   procedure MIZXAYPlayerClick(Sender: TObject);
   procedure MIZXTSPlayerClick(Sender: TObject);
   procedure MouseHook(Sender: TObject; Msg: cardinal);
   procedure FormDestroy(Sender: TObject);
   procedure HScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode;
     var ScrollPos: integer);
   procedure NextWindow1Execute(Sender: TObject);
   procedure PackPattern1Click(Sender: TObject);
   procedure PatJmpExecute(Sender: TObject);
   procedure PreviousWindow1Execute(Sender: TObject);
   procedure RenumPatsExecute(Sender: TObject);
   procedure RenumPatsUpdate(Sender: TObject);
   procedure SplitPattern1Click(Sender: TObject);
   procedure SwapChansExecute(Sender: TObject);
   procedure WindowMenuItemClick(Sender: TObject);
   procedure WorkspaceDblClick(Sender: TObject);
   procedure WorkspaceResize(Sender: TObject);
   procedure VScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode;
     var ScrollPos: integer);
   procedure TransposeDown3Execute(Sender: TObject);
   procedure TransposeDown5Execute(Sender: TObject);
   procedure TransposeUp3Execute(Sender: TObject);
   procedure TBMidiKbdClick(Sender: TObject);
   procedure ToggleMidiVolExecute(Sender: TObject);
   procedure TransposeUp5Execute(Sender: TObject);
   procedure UpdateToggleMidiKbdHint;
   procedure ToggleMidiKbdExecute(Sender: TObject);
   function CheckProgress: boolean;
   procedure InitProgress(const Desc: string; Max: integer);
   procedure FinProgress;
   function IncProgress(Step: integer): boolean;
   procedure ConvToWAVMenuClick(Sender: TObject);
   function GetCurrentWindow(out CW: TChildForm): boolean;

   //call save dialog and ask for overwrite if need
   function GetFileName(SaveDlg: TSaveDialog; CW: TChildForm;
     CheckExt: TCheckExtProc = nil; TwoForTS: boolean = False): boolean;

   procedure AutoPrmsExecute(Sender: TObject);
   procedure AutoEnvStdExecute(Sender: TObject);
   procedure AutoEnvExecute(Sender: TObject);
   procedure AutoStepExecute(Sender: TObject);
   procedure DoTile(TileMode: TTileMode);
   procedure AddWindowListItem(Child: TChildForm);
   procedure CloseAll1Execute(Sender: TObject);
   procedure GlueFormToControl(Frm: TForm; Ctrl: TControl);
   procedure DeleteWindowListItem(Child: TChildForm);
   procedure FileClose1Execute(Sender: TObject);
   procedure FileNew1Execute(Sender: TObject);
   procedure FileOpen1Execute(Sender: TObject);
   procedure FindWindow1Execute(Sender: TObject);
   procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
   procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure HelpAbout1Execute(Sender: TObject);
   procedure FileExit1Execute(Sender: TObject);
   procedure FormCreate(Sender: TObject);
   procedure digsoundfinalize(var Msg: TMessage); message UM_FINALIZEDS;
   procedure MidiInNote(var Msg: TMessage); message UM_MIDINOTE;
   procedure ConvToPSGMenuClick(Sender: TObject);
   procedure MidiInTimerTimer(Sender: TObject);
   procedure OctaveActionExecute(Sender: TObject);
   procedure Options1Execute(Sender: TObject);
   procedure ResizeChilds;
   procedure UpdateChildsTracksHints;
   procedure UpdateChildsSamplesHints;
   procedure UpdateChildsOrnamentsHints;
   procedure InvalidateChildTracks;
   procedure InvalidateChildSamples;
   procedure InvalidateChildOrnaments;
   procedure InvalidateChildTests;
   procedure CommonActionUpdate(Sender: TObject);
   procedure PatternsActionUpdate(Sender: TObject);
   procedure FileSave1Execute(Sender: TObject);
   procedure FileSave1Update(Sender: TObject);
   procedure FileSaveAs1Execute(Sender: TObject);
   procedure SBCancelClick(Sender: TObject);
   procedure MainStatusBarDrawPanel(StatusBar_: TStatusBar;
     Panel: TStatusPanel; const Rect: TRect);
   procedure Stop1Update(Sender: TObject);
   procedure Play1Execute(Sender: TObject);
   procedure StopPlaying;
   procedure Stop1Execute(Sender: TObject);
   procedure SetLoopPosExecute(Sender: TObject);
   procedure SetLoopPosUpdate(Sender: TObject);
   procedure AddPositionsExecute(Sender: TObject);
   procedure AddPositionsUpdate(Sender: TObject);
   procedure CheckValidPositionsSelected(Sender: TObject);
   //action update for delete/change
   procedure DeletePositionsExecute(Sender: TObject);
   procedure ToggleLoopingExecute(Sender: TObject);
   procedure AddFileName(FN: string);
   procedure OpenRecent(n: integer);
   procedure RFileClick(Sender: TObject);

   //Free player vars after stopping playback or before restarting playback in other window
   //if Keep>=0 then keep from 0 to Keep
   procedure FreePlayers(Keep: integer = -1);

   //Disable controls before starting playback
   procedure DisableControls(CheckSecondWindow: boolean = False);

   //Restore controls after stopping playback
   procedure RestoreControls;

   //Stop, start and reroll back to quick apply changes
   procedure StopAndRestart;

   procedure ToggleChipExecute(Sender: TObject);
   procedure ToggleChanMode;
   procedure ToggleChanAllocExecute(Sender: TObject);
   procedure ToggleLoopingAllExecute(Sender: TObject);
   function CanNotLoopAll: boolean;
   procedure PlayFromPosExecute(Sender: TObject);
   procedure SetIntFreqEx(f: integer);
   procedure SetEmulatingChip(aChipType: TChipTypes);
   procedure TracksManagerExecute(Sender: TObject);
   procedure GlobalTranspositionExecute(Sender: TObject);
   procedure SaveOptions;
   procedure LoadOptions;
   procedure UpdateChildHints; //used after shortcuts changed for some actions
   function CreateTwoKeysHintGeneral(key1, key2: TShortcutActions;
     Appendix: string; brackets: boolean = True): string;
   function CreateTwoKeysHint(key1, key2: TShortcutActions): string;
   procedure SetTwoShortacts(Act: TAction; SC1, SC2: TShortcutActions);
   procedure SetMultiShortcuts;
   procedure SetGlobalShortcuts;
   //used if need manually fire actions by shortcut, if fired then Key will set to 0
   procedure RaiseGlobalShortcutActions(var Key: word; Shift: TShiftState);
   //fire actions if its shortcut same as TStringGrid specific keys, which unused in VT II
   procedure CheckSGKeysAndActionsConflicts(var Key: word; Shift: TShiftState;
     OneRow: boolean = False);
   //fire action if Key in specified keys and zero Key to disable default action
   procedure CheckKeysAndActionsConflicts(var Key: word; Shift: TShiftState;
     Keys: TSetOfByte);
   procedure PlayPatExecute(Sender: TObject);
   procedure PlayPatFromLineExecute(Sender: TObject);
   procedure SaveSNDHMenuClick(Sender: TObject);
   procedure SaveforZXMenuClick(Sender: TObject);
   procedure SaveDialogZXAYTypeChange(Sender: TObject);

   //FileExt for SaveAs (from save dialog type index)
   function GetSaveAsFileExt: string;

   //FileExt for ZXAY export (from save or export dialog type index)
   function GetZXAYFileExt: string;

   procedure SaveDialogVTMTypeChange(Sender: TObject);
   {$IFDEF Windows}
   procedure SetPriority(Pr: longword);
   {$ENDIF Windows}
   procedure EditCopy1Update(Sender: TObject);
   procedure EditCut1Update(Sender: TObject);
   procedure EditCut1Execute(Sender: TObject);
   procedure EditCopy1Execute(Sender: TObject);
   procedure EditPaste1Update(Sender: TObject);
   procedure EditPaste1Execute(Sender: TObject);
   procedure UndoUpdate(Sender: TObject);
   procedure UndoExecute(Sender: TObject);
   procedure RedoUpdate(Sender: TObject);
   procedure RedoExecute(Sender: TObject);
   procedure CheckCommandLine;
   procedure SavePT3(ChildWindow: TChildForm; FileName: string; AsText: boolean);
   function AllowSave(const fn: string; TwoForTS: boolean = False): boolean;
   procedure RedrawPlWindow(PW: TChildForm; ps, pat, line: integer);
   procedure TransposeChannel(WorkWin: TChildForm; Pat, Chn, i, Semitones: integer);
   procedure TransposeColumns(WorkWin: TChildForm; Pat: integer;
     Env: boolean; Chans: TChansArrayBool; LFrom, LTo, Semitones: integer;
     MakeUndo: boolean);
   procedure TransposeSelection(Semitones: integer);
   procedure CheckTracksFocused(Sender: TObject);
   procedure TransposeUp1Execute(Sender: TObject);
   procedure TransposeDown1Execute(Sender: TObject);
   procedure TransposeUp12Execute(Sender: TObject);
   procedure TransposeDown12Execute(Sender: TObject);
   procedure PopupMenu3Click(Sender: TObject);
   procedure SetBar(BarNum: integer; Value: boolean);
   procedure ToggleSamplesExecute(Sender: TObject);
   procedure ExpandTwice1Click(Sender: TObject);
   procedure ShrinkTwice1Click(Sender: TObject);
   procedure Merge1Click(Sender: TObject);
   procedure VisTimerTimer(Sender: TObject);
   procedure VolumeDownExecute(Sender: TObject);
   procedure VolumeUpExecute(Sender: TObject);
   //   procedure WindowArrangeAll1Execute(Sender: TObject);
   procedure DoCascade(ai: TChildForm);

   //after Cascade/Tile sorting playing window can be overlapped, activate it
   procedure EnsurePlayingWindowActive;

   procedure WindowCascade1Execute(Sender: TObject);
   //   procedure WindowMinimizeAll1Execute(Sender: TObject);
   procedure WindowTileHorizontal1Execute(Sender: TObject);
   procedure WindowTileVertical1Execute(Sender: TObject);
   procedure SetChannelsAllocation(CA: integer);
 protected
 private
   { Private declarations }
   VolumeControl: TVolumeControl;
   procedure CreateChild(const aFileName: string);
   procedure MaximizeAndCheckCommandLine(Data: PtrInt);
   procedure EnqueueMaximize(Data: PtrInt);
 public
   { Public declarations }
   RecentFiles: array[0..5] of string;
   ChanAlloc: TChansArray;
   LoopAllAllowed: boolean;
   WinCount: integer;
   Childs: TList;
   ActiveChild: TChildForm;
   SoftResize: integer; //if 0 allow Workspace.OnResize
   procedure CalcSBs;
   function Next(Step: integer = 1; PlayingWindow: boolean = False;
     MakeFocused: boolean = True; SkipTS: boolean = False): TChildForm;
   function GetParentFrame(Ctrl: TWinControl): TWinControl;
   function ActiveChildExists: boolean;

   //called async to perform some actions after closing child window
   procedure ChildClosed(Data: PtrInt);

   //Toggle on maximized mode with given child
   procedure MaximizeChild(aChild: TChildForm);

   //Toggle off maximized mode
   procedure RestoreChilds;

   //open FN (without path) or show error message
   procedure TryOpenDocument(FN: string);
 end;

function SwapW(a: word): word; inline;

//search Divider or return Sz
function GetSubStrSz(Divider: char; var Src: PChar; var Sz: integer): integer;

//search CR/LF/CRLF/LFCR or null
function GetStrSz(var Src: PChar): integer;

procedure SetDefault;
procedure ResetPlaying;
procedure CatchAndResetPlaying;

var
 MainForm: TMainForm;
 PatternsFolder, SamplesFolder, OrnamentsFolder: string;
 MaximizedChilds: boolean = False;

implementation

{$R *.lfm}

uses
 About, options, TrkMng, GlbTrn, ExportZX, ExportSNDH, selectts, TglSams, ice,
 digsoundbuf, WinVersion;

type
 TStr4 = array[0..3] of char;

const
 TSData: packed record
     Type1: TStr4;
     Size1: word;
     Type2: TStr4;
     Size2: word;
     TSID: TStr4;
     end
 = (Type1: 'PT3!'; Size1: 0; Type2: 'PT3!'; Size2: 0; TSID: '02TS');

var
 win_x, win_y, win_o: integer; //windows position and offset for cascade sorting

function SwapW(a: word): word; //inline
begin
 Result := Swap(a);
end;

function GetSubStrSz(Divider: char; var Src: PChar; var Sz: integer): integer;
var
 Start: PChar;
begin
 Start := Src;
 while (Sz > 0) and (Src^ <> Divider) do
  begin
   Inc(Src);
   Dec(Sz);
  end;
 Result := Src - Start;
 if Sz > 0 then //skip divider
  begin
   Inc(Src);
   Dec(Sz);
  end;
end;

function GetStrSz(var Src: PChar): integer;
var
 Start: PChar;
 EOL: char;
begin
 Start := Src;
 while not (Src^ in [#0, #13, #10]) do
   Inc(Src);
 Result := Src - Start;
 if Src^ <> #0 then //skip EOL
  begin
   EOL := Src^;
   Inc(Src);
   if Src^ in ([#13, #10] - [EOL]) then
     Inc(Src);
  end;
end;

function GetFolder(const Folder: string; SubFolders: array of string): string;
var
 SubFolder: string;
begin
 for SubFolder in SubFolders do
  begin
   Result := Folder + SubFolder;
   if DirectoryExists(Result) then
     Exit;
  end;
 Result := Folder;
end;

//Get filename for separated TS-pair
function GetTSFileName(const fn: string; N: integer): string;
var
 Ext: string;
begin
 Ext := ExtractFileExt(fn);
 Result := Copy(fn, 1, Length(fn) - Length(Ext)) + '.' + N.ToString + Ext;
end;

procedure AdjustFormOnDesktop(Frm: TForm);
var
 i: integer;
begin
 //Frm.MakeFullyVisible; не годится, работает с каким-либо монитором, а не со всем рабочим столом
 //подумать еще
 if Frm.Left >= Screen.DesktopLeft + Screen.DesktopWidth - Frm.Width then
  begin
   i := Screen.DesktopLeft + Screen.DesktopWidth - Frm.Width;
   if i < Screen.DesktopLeft then i := Screen.DesktopLeft;
   Frm.Left := i;
  end
 else if Frm.Left < Screen.DesktopLeft then
   Frm.Left := Screen.DesktopLeft;
 if Frm.Top >= Screen.DesktopTop + Screen.DesktopHeight - Frm.Height then
  begin
   i := Screen.DesktopTop + Screen.DesktopHeight - Frm.Height;
   if i < Screen.DesktopTop then i := Screen.DesktopTop;
   Frm.Top := i;
  end
 else if Frm.Top < Screen.DesktopTop then
   Frm.Top := Screen.DesktopTop;
end;

//set form coords near main form's control
procedure TMainForm.GlueFormToControl(Frm: TForm; Ctrl: TControl);
var
 Coords: TPoint;
begin
 if Frm.Position = poDesigned then //already set flag
   Exit;
 with Ctrl, Coords do
  begin
   X := GetSystemMetrics(SM_CXFIXEDFRAME) + 4;
   Y := Height + GetSystemMetrics(SM_CYFIXEDFRAME) + 4;
   Coords := ControlToScreen(Coords);
   Frm.Left := X;
   Frm.Top := Y;
   Frm.Position := poDesigned;
  end;
end;

function TMainForm.GetCurrentWindow(out CW: TChildForm): boolean;
begin
 Result := ActiveChildExists;
 if Result then
   CW := ActiveChild;
end;

function TMainForm.CheckProgress: boolean;
begin
 Result := SBCancel.Tag = 0;
 if not Result then //progressbar is busy (another conversion)
   ShowMessage(Mes_ConvInProgress);
end;

procedure TMainForm.UpdateToggleMidiKbdHint;
var
 SBMidiHint: string;
begin
 SBMidiHint := Mes_MidiHint1 + '|';
 if not ToggleMidiKbd.Checked then
  begin
   if MidiInTimer.Enabled then
     ToggleMidiKbd.Hint := SBMidiHint + Mes_MidiHint2
   else
     ToggleMidiKbd.Hint := SBMidiHint + Mes_MidiHint3;
  end
 else
   ToggleMidiKbd.Hint := SBMidiHint + MidiIn_DevName + ' ' + Mes_MidiHint4;
end;

procedure TMainForm.ToggleMidiVolExecute(Sender: TObject);
begin
 ToggleMidiVol.Checked := not ToggleMidiVol.Checked;
end;

procedure TMainForm.TBMidiKbdClick(Sender: TObject);
begin
 //mask LCL error
 TBMidiKbd.Down := ToggleMidiKbd.Checked;
end;

procedure TMainForm.ToggleMidiKbdExecute(Sender: TObject);
var
 n: integer;
begin
 MidiIn_Close;

 n := MidiIn_DevCnt;
 if n = 0 then //no MIDIIN devices connected
   //just switch off/wait mode
  begin
   MidiInTimer.Enabled := not MidiInTimer.Enabled;
   ToggleMidiKbd.Checked := False;
  end
 else if not ToggleMidiKbd.Checked then //switched off
  begin
   //try to open first device
   ToggleMidiKbd.Tag := 0;
   if MidiIn_Open(ToggleMidiKbd.Tag, '') then
     //opened, start poll and set flag
    begin
     MidiInTimer.Enabled := True;
     ToggleMidiKbd.Checked := True;
    end
   else
     //can't open, just switch off/wait mode
     MidiInTimer.Enabled := not MidiInTimer.Enabled;
  end
 else //already switched on, so try next device or just switch off
  begin
   //next device
   ToggleMidiKbd.Tag := ToggleMidiKbd.Tag + 1;
   if ToggleMidiKbd.Tag >= n then
    begin
     //all devices toggled, switch of and don't poll
     MidiInTimer.Enabled := False;
     ToggleMidiKbd.Checked := False;
    end
   else if MidiIn_Open(ToggleMidiKbd.Tag, '') then
     //opened, start poll
     MidiInTimer.Enabled := True
   else
    begin
     //can't open, just switch off/wait mode
     MidiInTimer.Enabled := not MidiInTimer.Enabled;
     ToggleMidiKbd.Checked := False;
    end;
  end;
 UpdateToggleMidiKbdHint;
end;

procedure TMainForm.InitProgress(const Desc: string; Max: integer);
begin
 Screen.Cursor := crAppStart;
 SBCancel.Tag := 1;
 Progress.Position := 0;
 Progress.Tag := 0; //store real position if exceeded max bound
 Progress.Max := Max;
 MainStatusBar.SimplePanel := False;
 MainStatusBar.Panels.Items[0].Width := MainStatusBar.ClientWidth * 7 div 10;
 MainStatusBar.Panels.Items[0].Text := Desc;
 Progress.Show;
 SBCancel.Show;
end;

procedure TMainForm.FinProgress;
begin
 Progress.Hide;
 SBCancel.Hide;
 SBCancel.Tag := 0;
 MainStatusBar.SimplePanel := True;
 Screen.Cursor := crDefault;
end;

function TMainForm.IncProgress(Step: integer): boolean;
var
 Masg: TMsg;
begin
 Progress.Position := Progress.Position + Step; //can't be greater than max
 Progress.Tag := Progress.Tag + Step; //real position in case of exceeding max
 while PeekMessage(Masg, MainStatusBar.Handle, WM_MOUSEFIRST,
     WM_MOUSELAST, PM_REMOVE) do
  begin
   TranslateMessage(Masg);
   DispatchMessage(Masg);
  end;
 if SBCancel.Tag = 0 then
   Exit(False);
 while PeekMessage(masg, 0, 0, 0, PM_REMOVE) do
   case Masg.message of
     WM_KEYDOWN:
       if Masg.wParam = VK_ESCAPE then
        begin
         SBCancel.Tag := 0;
         Exit(False);
        end;
     WM_TIMER, WM_PAINT, WM_MOUSEMOVE, WM_MOUSELEAVE, WM_MOUSEWHEEL, UM_FINALIZEDS:
      begin
       TranslateMessage(Masg);
       DispatchMessage(Masg);
      end;
    end;
 Result := True;
end;

procedure TMainForm.ConvToWAVMenuClick(Sender: TObject);
var
 CW: TChildForm;
 f: file;
 WBuf: packed array[0..32767] of byte;
 BM: TBufferMaker;
 i, NumberOfSoundChips: integer;
begin
 if not GetCurrentWindow(CW) then
   Exit;

 if not CheckProgress then
   Exit;

 if not GetFileName(SaveDialogWAV, CW) then
   Exit;

 if (CW.TSWindow <> nil) and (CW.TSWindow.VTMP^.Positions.Length <> 0) then
   NumberOfSoundChips := 2
 else
   NumberOfSoundChips := 1;
 with BM do
  begin
   ForPlayback := False; //converter
   SetSynthesizer; //init Synthesizer link
   Calculate_Level_Tables; //level tables with no global volume
   SetLength(Players, NumberOfSoundChips);
   CW.VTMP^.NewPlayer(Players[0]);
   if NumberOfSoundChips > 1 then
     CW.TSWindow.VTMP^.NewPlayer(Players[1]);

   for i := 0 to NumberOfSoundChips - 1 do
     with Players[i]^ do
      begin
       Module_SetDelay;
       Module_SetPosition;
      end;
   InitForAllTypes;
  end;

 with WAVFileHeader, VTOptions do
  begin
   nChannels := NumberOfChannels;
   nSamplesPerSec := SampleRate;
   nBlockAlign := (SampleBit div 8) * NumberOfChannels;
   nAvgBytesPerSec := SampleRate * nBlockAlign;
   FormatSpecific := SampleBit;
   BM.BufferLengthMax := 32768 div nBlockAlign;
   InitProgress(Mes_ConvTo + ' ' + ExtractFileName(SaveDialogWAV.FileName),
     Trunc(CW.TotInts * 1000 * SampleRate / Interrupt_Freq + 0.5));
  end;

  try
   AssignFile(f, SaveDialogWAV.FileName);
   Rewrite(f, 1);
    try
     Seek(f, SizeOf(WAVFileHeader));

     with BM do
       repeat
         MakeBufferTracker(@WBuf);
         BlockWrite(f, WBuf, BufferLength * WAVFileHeader.nBlockAlign);
       until not IncProgress(BufferLength) or Real_End_All;

     with WAVFileHeader do
      begin
       dlen := Progress.Tag * nBlockAlign;
       rlen := SizeOf(WAVFileHeader) + dlen;
      end;

     Seek(f, 0);
     BlockWrite(f, WAVFileHeader, SizeOf(WAVFileHeader));

    finally
     CloseFile(f);
     if not BM.Real_End_All then
       ShowMessage(Mes_ConvAborted);
    end;
  finally;
   FinProgress;
  end;
end;

function TMainForm.GetFileName(SaveDlg: TSaveDialog; CW: TChildForm;
 CheckExt: TCheckExtProc = nil; TwoForTS: boolean = False): boolean;
begin
 if CW.WinFileName <> '' then
  begin
   SaveDlg.FileName := ChangeFileExt(ExtractFileName(CW.WinFileName), '');
   SaveDlg.InitialDir := ExtractFileDir(CW.WinFileName);
  end
 else if (CW.TSWindow <> nil) and (CW.TSWindow.WinFileName <> '') then
  begin
   SaveDlg.FileName := ChangeFileExt(ExtractFileName(CW.TSWindow.WinFileName), '');
   SaveDlg.InitialDir := ExtractFileDir(CW.TSWindow.WinFileName);
  end
 else
  begin
   SaveDlg.FileName := 'VTIIModule' + IntToStr(CW.WinNumber);
   if SaveDlg.InitialDir = '' then
     SaveDlg.InitialDir := OpenDialogVTM.InitialDir;
  end;

 repeat
   if not SaveDlg.Execute then
     Exit(False);
   if CheckExt <> nil then
     CheckExt;
 until AllowSave(SaveDlg.FileName, TwoForTS);

 SaveDlg.InitialDir := ExtractFileDir(SaveDlg.FileName);

 Result := True;
end;

procedure TMainForm.DeleteWindowListItem(Child: TChildForm);
var
 i, j: integer;
begin
 for i := 1 to TSSel.ListBox1.Items.Count - 1 do
   if TSSel.ListBox1.Items.Objects[i] = Child then
    begin
     TSSel.ListBox1.Items.Delete(i);
     for j := 0 to Childs.Count - 1 do
       if TChildForm(Childs.Items[j]) <> Child then
         with TChildForm(Childs.Items[j]) do
           if TSWindow = Child then
            begin
             TSWindow := nil;
             SBTS.Caption := PrepareTSString(SBTS, TSSel.ListBox1.Items[0]);
            end;
     Break;
    end;
 i := Window1.IndexOf(Child.WinMenuItem);
 if i >= 0 then
  begin
   Window1.Delete(i);
   if Childs.Count = 1 then //last window closing
     SeparatorW.Visible := False;
  end;
end;

procedure TMainForm.FileClose1Execute(Sender: TObject);
begin
 if ActiveChildExists then
   ActiveChild.Close;
end;

procedure TMainForm.WindowMenuItemClick(Sender: TObject);
begin
 if Childs.IndexOf(TChildForm((Sender as TMenuItem).Tag)) < 0 then
   Exit;
 TChildForm((Sender as TMenuItem).Tag).SetForeground;
end;

procedure TMainForm.WorkspaceDblClick(Sender: TObject);
begin
 FileOpen1Execute(FileOpen1);
end;

procedure TMainForm.AddWindowListItem(Child: TChildForm);
begin
 TSSel.ListBox1.AddItem(Child.Caption, Child);
 SeparatorW.Visible := True;
 Child.WinMenuItem.Caption := Child.Caption;
 Window1.Add(Child.WinMenuItem);
end;

procedure TMainForm.CloseAll1Execute(Sender: TObject);
var
 i: integer;
begin
 for i := Childs.Count - 1 downto 0 do
   TChildForm(Childs.Items[i]).Close;
end;

procedure TMainForm.CreateChild(const aFileName: string);
var
 VTMP2: PModule;
 Child1, Child2: TChildForm;
begin
 if Childs.Count = 0 then
  begin
   //reset windows position for DoCascade
   win_x := 0;
   win_y := 0;

   //reset childs numbering
   WinCount := 0;
  end;

 VTMP2 := nil;
 Child1 := TChildForm.Create(Workspace);
 if (aFileName = '') or not FileExists(aFileName) then
   Child1.Caption := IntToStr(WinCount) + ': ' + Mes_NewMod
 else if not Child1.LoadTrackerModule(aFileName, VTMP2) then
  begin
   Child1.Close;
   Exit;
  end
 else if VTMP2 <> nil then
  begin
   Child2 := TChildForm.Create(Workspace);
   if not Child2.LoadTrackerModule(aFileName, VTMP2) then
    begin
     Child2.Close;
     Child1.Close;
     Exit;
    end
   else
    begin
     Child1.TSWindow := Child2;
     Child2.TSWindow := Child1;
    end;
  end;

 AddWindowListItem(Child1);
 if VTMP2 <> nil then
  begin
   AddWindowListItem(Child2);
   with TSSel.ListBox1 do
    begin
     Child2.SBTS.Caption := Child2.PrepareTSString(Child2.SBTS, Items[Count - 2]);
     Child1.SBTS.Caption := Child1.PrepareTSString(Child1.SBTS, Items[Count - 1]);
    end;
  end;

 DoCascade(Child1);
 if (VTMP2 <> nil) and not Child1.CanHookTSWindow then
   DoCascade(Child2);

 //DoCascade work with IsSoftRepos<>0, so need to proceed some handlers manually
 CalcSBs;

 Child1.SetForeground;
end;

procedure TMainForm.WorkspaceResize(Sender: TObject);
var
 i: integer;
begin
 if SoftResize <> 0 then
   Exit;
 CalcSBs;
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).UpdateConstraints;
 if ActiveChildExists then
   if ActiveChild.Maximized then
     ActiveChild.Maximize(True)
   else
     ActiveChild.ScrollWorkspace;
end;

procedure TMainForm.HScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode;
 var ScrollPos: integer);
begin
 if ScrollCode in [scLineDown, scLineUp, scEndScroll] then
  begin
   if ScrollPos + HScrollBar.PageSize >= HScrollBar.Max then
     ScrollPos := HScrollBar.Max - HScrollBar.PageSize;
   if ScrollPos <> HScrollBar.Tag then
    begin
     Workspace.ScrollBy(HScrollBar.Tag - ScrollPos, 0);
     HScrollBar.Tag := ScrollPos;
     CalcSBs;
    end;
  end;
end;

procedure TMainForm.NextWindow1Execute(Sender: TObject);
begin
 Next;
end;

procedure TMainForm.PackPattern1Click(Sender: TObject);
var
 PatP, PatN: PPattern;
 PatL, Tempo, PatNL, TempoN: integer;

 procedure GetTempo;
 var
   c: integer;
 begin
   for c := 2 downto 0 do
     with PatP^.Items[PatL].Channel[c].Additional_Command do
       if Number = 11 then
        begin
         Tempo := Parameter;
         Exit;
        end;
 end;

 procedure SearchBackTempo;
 begin
   while PatL >= 0 do
    begin
     GetTempo;
     if Tempo <> 0 then
       Exit;
     Dec(PatL);
    end;
 end;

 function IsRoomForTempo(PatLine: integer): boolean;
 var
   c: integer;
 begin
   for c := 2 downto 0 do
     with PatP^.Items[PatLine].Channel[c].Additional_Command do
       if Number in [0, 11] then
         Exit(True);
   Result := False;
 end;

 procedure SetTempo(Tempo: integer);
 var
   c: integer;
 begin
   TempoN := Tempo;
   //first try update existing command
   for c := 2 downto 0 do
     with PatN^.Items[PatNL].Channel[c].Additional_Command do
       if Number = 11 then
        begin
         Parameter := Tempo;
         Exit;
        end;
   for c := 2 downto 0 do
     with PatN^.Items[PatNL].Channel[c].Additional_Command do
       if Number = 0 then
        begin
         Number := 11;
         Parameter := Tempo;
         Exit;
        end;
 end;

 procedure RemoveTempo;
 var
   c: integer;
 begin
   for c := 2 downto 0 do
     with PatN^.Items[PatNL].Channel[c].Additional_Command do
       if Number = 11 then
        begin
         Number := 0;
         Parameter := 0;
        end;
 end;

var
 Y1, Y2, PosI, TempoO: integer;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild, Tracks do
  begin
   if IsPatternEmpty(VTMP^.Patterns[PatNum]) then
    begin
     ShowMessage(Mes_PackNoNeed);
     Exit;
    end;

   //calc Y selection range
   Y1 := SelY;
   Y2 := ShownFrom - N1OfLines + CursorY;
   if Y1 > Y2 then
    begin
     Y1 := Y2;
     Y2 := SelY;
    end;

   if Y1 = Y2 then
     //if no selection pack whole pattern
    begin
     Y1 := 0;
     Y2 := ShownPattern^.Length - 1;
    end;

   Tempo := 0; //no initial tempo yet

   //go back in pattern till tempo setting special command
   PatP := VTMP^.Patterns[PatNum];
   PatL := Y1 - 1;
   SearchBackTempo;

   if Tempo = 0 then
     //not found, check previous patterns (if current pattern in current position)
     if (PositionNumber < VTMP^.Positions.Length) and
       (VTMP^.Positions.Value[PositionNumber] = PatNum) then
      begin
       PosI := PositionNumber - 1;
       while PosI >= 0 do
        begin
         PatP := VTMP^.Patterns[VTMP^.Positions.Value[PosI]];
         if PatP <> nil then
          begin
           PatL := PatP^.Length - 1;
           SearchBackTempo;
           if Tempo <> 0 then
             Break;
          end;
         Dec(PosI);
        end;
      end;

   if Tempo = 0 then
     //still not found, use module's initial tempo
     Tempo := VTMP^.Initial_Delay;

   New(PatN);
   PatP := VTMP^.Patterns[PatNum];

   PatL := 0;
   while PatL < Y1 do
    begin
     PatN^.Items[PatL] := PatP^.Items[PatL];
     Inc(PatL);
    end;

   TempoN := Tempo;
   PatNL := PatL;
   while PatL < Y2 do
    begin
     //just copy line
     PatN^.Items[PatNL] := PatP^.Items[PatL];
     GetTempo;
     if IsRoomForTempo(PatL) then //can we set tempo in this line?
      begin
       TempoO := TempoN;
       if TempoN <> Tempo then
         SetTempo(Tempo)
       else
         RemoveTempo;
       while (PatL + 1 < Y2) and IsPatternLineEmptyJustTempo(PatP, PatL + 1) and
         (TempoN + Tempo < 256) and IsRoomForTempo(PatL + 2) do
         //count empty lines
        begin
         Inc(PatL);
         GetTempo;
         Inc(TempoN, Tempo);
        end;
       if TempoO <> TempoN then
         SetTempo(TempoN)
       else
         RemoveTempo;
      end;
     Inc(PatNL);
     Inc(PatL);
    end;

   if PatNL = PatL then
    begin
     ShowMessage(Mes_PackCant);
     Dispose(PatN);
     Exit;
    end;

   //copy last line of selection
   PatN^.Items[PatNL] := PatP^.Items[PatL];
   //get exiting tempo
   GetTempo;
   if TempoN <> Tempo then
     SetTempo(Tempo);
   Inc(PatNL);
   Inc(PatL);

   while PatL < PatP^.Length do
    begin
     PatN^.Items[PatNL] := PatP^.Items[PatL];
     Inc(PatNL);
     Inc(PatL);
    end;

   PatN^.Length := PatNL;
   SongChanged := True;
   AddUndo(CAExpandShrinkPattern,{%H-}PtrInt(VTMP^.Patterns[PatNum]), 0, auAutoIdxs);
   VTMP^.Patterns[PatNum] := PatN;
   ChangePattern(PatNum);
  end;
end;

procedure TMainForm.PatJmpExecute(Sender: TObject);
var
 PL: integer;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild, Tracks do
  begin
   ToggleSelection;
   if ShownPattern = nil then
     PL := DefPatLen
   else
     PL := ShownPattern^.Length;
   ShownFrom := (Sender as TAction).Tag * PL div 4; //0,1,2,3 -> 0%,25%,50%,75%
   CursorY := N1OfLines;
   ShowStat;
   Invalidate;
   CalcCaretPos;
   ResetSelection;
  end;
end;

procedure TMainForm.PreviousWindow1Execute(Sender: TObject);
begin
 Next(-1);
end;

procedure TMainForm.RenumPatsExecute(Sender: TObject);
var
 Pats: PPatIndex;
 Poss: TPositions;
 i, j, pat: integer;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
  begin
   //create patterns order index and fill all values with -1
   New(Pats);
   FillChar(Pats^, SizeOf(TPatIndex), 255);

   pat := 0; //initial pattern number

   //reorder used patterns
   for j := 0 to VTMP^.Positions.Length - 1 do
    begin
     i := VTMP^.Positions.Value[j];
     if Pats^[i] < 0 then
      begin
       Pats^[i] := pat;
       Inc(pat);
      end;
     Poss[j] := Pats^[i];
    end;

   //used positions size (each item of integer size)
   j := VTMP^.Positions.Length * SizeOf(integer);

   //check positions list was changed
   if CompareMem(@Poss, @VTMP^.Positions.Value, j) then
    begin
     Dispose(Pats);
     ShowMessage(Mes_PatternsInOrder);
    end
   else
    begin
     SongChanged := True;
     AddUndo(CAReorderPatterns,{%H-}PtrInt(@VTMP^.Positions),{%H-}PtrInt(
       Pats), auAutoIdxs);

     //quick copy positions items
     Move(Poss, VTMP^.Positions.Value, j);

     //fill index for all unused patterns too
     for i := 0 to MaxPatNum do
       if Pats^[i] < 0 then
        begin
         Pats^[i] := pat;
         Inc(pat);
        end;

     //reorder pattern pointers using generated index
     ChangePatternsOrder(Pats);

     //fill positions cells with new values
     RedrawPositions;

     //pattern pointers/numbers was mixed, need update:
     ChangePattern(Pats^[PatNum]);
    end;
  end;
end;

procedure TMainForm.RenumPatsUpdate(Sender: TObject);
begin
 RenumPats.Enabled := ActiveChildExists and
   ((ActiveChild.IsPlayingWindow < 0) or (PlayMode = PMPlayLine)) and
   ActiveChild.SGPositions.Focused and (ActiveChild.VTMP^.Positions.Length > 0);
end;

procedure TMainForm.SplitPattern1Click(Sender: TObject);
var
 L, PL, PN, i, ChangesStart, PosFree, PatI, PosSel: integer;
 EditedOrUsed: array[0..MaxPatNum] of boolean;
 Pat: PPattern;
 Pos: TPositionList;
 Last: boolean;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
  begin
   ValidatePattern2(PatNum);
   PL := VTMP^.Patterns[PatNum]^.Length;
   L := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
   if (PL < 2) or (L <= 0) or (L >= PL) then
    begin
     ShowMessage(Mes_SplitCant);
     Exit;
    end;

   for i := 0 to MaxPatNum do
     EditedOrUsed[i] := not IsPatternEmpty(VTMP^.Patterns[i]);
   EditedOrUsed[PatNum] := True; //source pattern can't be dest
   with VTMP^.Positions do
     for i := 0 to Length - 1 do
       EditedOrUsed[Value[i]] := True;
   PN := -1;
   for i := 0 to MaxPatNum do
     if not EditedOrUsed[i] then
      begin
       PN := i;
       Break;
      end;
   if PN < 0 then
    begin
     ShowMessage(Mes_SplitNoRoom);
     Exit;
    end;

   SongChanged := True;
   ChangesStart := ChangeCount; //store next undo index

   //1st change - new size for source pattern
   AddUndo(CAChangePatternSize, VTMP^.Patterns[PatNum]^.Length, L, auAutoIdxs);

   //create new pattern shadowly (not show yet)
   New(Pat);
   Pat^.Length := VTMP^.Patterns[PatNum]^.Length - L;
   VTMP^.Patterns[PatNum]^.Length := L;
   for i := 0 to Pat^.Length - 1 do
     Pat^.Items[i] := VTMP^.Patterns[PatNum]^.Items[i + L];

   //2nd change - replace dest pattern[PN] with new Pat
   ValidatePattern(PN, VTMP);
   AddUndo(CALoadPattern,{%H-}PtrInt(VTMP^.Patterns[PN]),{%H-}PtrInt(Pat),
     PN, 0, 0, 0);

   //create new position list
   PosFree := 256 - VTMP^.Positions.Length; //number of not used positions
   Last := False; //is last position changed?
   PosSel := SGPositions.Col; //selected position
   Pos.Length := 0;
   Pos.Loop := VTMP^.Positions.Loop;
   for i := 0 to VTMP^.Positions.Length - 1 do
    begin
     PatI := VTMP^.Positions.Value[i];
     Pos.Value[Pos.Length] := PatI;
     Inc(Pos.Length);
     if (PosFree > 0) and (PatI = PatNum) then
       //need to add new pattern while room is exists in list
      begin
       if Pos.Loop >= Pos.Length then
         Inc(Pos.Loop);
       if PosSel >= Pos.Length then
         Inc(PosSel);
       Pos.Value[Pos.Length] := PN;
       Inc(Pos.Length);
       Dec(PosFree);
       Last := i = VTMP^.Positions.Length - 1;
      end;
    end;

   if Pos.Length <> VTMP^.Positions.Length then
    begin
     //3rd change (optional) - new position list
     if Last and (Pos.Length = VTMP^.Positions.Length + 1) then
       //just one position added to the end
       ChangePositionValue(VTMP^.Positions.Length, PN)
     else
      begin
       SongChanged := True;
       AddUndo(CAInsertPosition,{%H-}PtrInt(@VTMP^.Positions), 0, auAutoIdxs);
       for i := 0 to Pos.Length - 1 do
         VTMP^.Positions.Value[i] := Pos.Value[i];
       VTMP^.Positions.Loop := Pos.Loop;
       VTMP^.Positions.Length := Pos.Length;

       //reprepare positions grid
       PositionsChanged;

       //is splited current position?
       if (Pos.Value[PosSel] = PatNum) and (PosSel < 255) and
         (Pos.Value[PosSel + 1] = PN) then
         Inc(PosSel);
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.CurrentPosition := PosSel;
       ShowPosition(PosSel);
      end;
    end;

   if (PositionNumber < VTMP^.Positions.Length) and
     (VTMP^.Positions.Value[PositionNumber] = PN) then
     //new pattern is in selected position, just reselect to redraw pattern
     SelectPosition(PositionNumber)
   else
     //new pattern not in position list, just show it
     ChangePattern(PN);

   //finally group all changes
   GroupLastChanges(ChangesStart);
  end;
end;

procedure TMainForm.SwapChansExecute(Sender: TObject);
var
 X, Y1, Y2, ChFrom, ChTo, i: integer;
 Ch: TChannelLine;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild, Tracks do
  begin
   if ShownPattern = nil then
     Exit;

   //calc left coord of selection
   if CursorX > SelX then
     X := SelX
   else
     X := CursorX;

   //be sure not in envs/noises tracks
   if X < 8 then
     X := 8;

   //calc Y selection range
   Y1 := SelY;
   Y2 := ShownFrom - N1OfLines + CursorY;
   if Y1 > Y2 then
    begin
     Y1 := Y2;
     Y2 := SelY;
    end;

   //calc src chan and set X to note track
   ChFrom := (X - 8) div 14;
   X := ChFrom * 14 + 8;

   //calc dest chan
   ChTo := ChFrom + 1;
   if Sender = SwapChansLeft then
     Inc(ChTo);
   ChTo := ChTo mod 3; //cyclic in tracks of active window only (even if TS)

   //new place and width of selection
   CursorX := ChTo * 14 + 8;
   SelX := CursorX + 12;

   //get real chan idxs since chans can be swapped visually
   ChTo := ChanAlloc[ChTo];
   ChFrom := ChanAlloc[ChFrom];

   SongChanged := True;

   //add undo and setup cursor displacement before and after
   AddUndo(CASwapPattern,{%H-}PtrInt(ShownPattern), 0, PatNum, Y1, ChTo, CursorX);
   with ChangeList[ChangeCount - 1].OldParams.prm.Idx do
    begin
     PatternLine := Y1;
     PatternChan := ChFrom;
     PatternX := X;
    end;

   //now ready to do the action
   for i := Y1 to Y2 do
    begin
     Ch := ShownPattern^.Items[i].Channel[ChFrom];
     ShownPattern^.Items[i].Channel[ChFrom] := ShownPattern^.Items[i].Channel[ChTo];
     ShownPattern^.Items[i].Channel[ChTo] := Ch;
    end;

   RecreateCaret; //new caret width
   CalcCaretPos; //new carret pos
   Tracks.Invalidate; //mark track to be redrawn as soon as possible
  end;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
 i: integer;
begin
 CanClose := True;
 for i := 0 to Childs.Count - 1 do
  begin
   TChildForm(Childs.Items[i]).FormCloseQuery(Sender, CanClose);
   if not CanClose then
     Exit;
  end;
end;

procedure TMainForm.InsertPositionsExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 if (ActiveChild.IsPlayingWindow >= 0) and (PlayMode <> PMPlayLine) then
   Exit;
 ActiveChild.InsertPositions((Sender as TAction).Tag);
end;

procedure TMainForm.ChangePatLenExecute(Sender: TObject);
var
 i, pat, len, ChangesStart: integer;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
  begin
   pat := VTMP^.Positions.Value[SGPositions.Selection.Left];
   if TryStrToInt(InputBox(Mes_SelectedPatLen, Mes_InputPatLen, ''), len) and
     (len > 0) and (len < 256) then
    begin
     ChangesStart := ChangeCount; //store next undo index

     for i := SGPositions.Selection.Left to SGPositions.Selection.Right do
      begin
       pat := VTMP^.Positions.Value[i];
       ValidatePattern2(pat);
       if VTMP^.Patterns[pat]^.Length <> len then
        begin
         SongChanged := True;
         AddUndo(CAChangePatternSize, VTMP^.Patterns[pat]^.Length, len, pat);
         ChangeList[ChangeCount - 1].OldParams.prm.Idx.CurrentPosition := i;
         ChangeList[ChangeCount - 1].NewParams.prm.Idx.CurrentPosition := i;
         VTMP^.Patterns[pat]^.Length := len;
        end;
      end;

     GroupLastChanges(ChangesStart);

     ToglSams.CheckUsedSamples;
     CalcTotLen;
     ChangePattern(PatNum);
     CalculatePos0;
    end;
  end;
end;

procedure TMainForm.DeletePositionsUpdate(Sender: TObject);
begin
 DeletePositions.Enabled := ActiveChildExists and
   ((ActiveChild.IsPlayingWindow < 0) or (PlayMode = PMPlayLine)) and
   ActiveChild.SGPositions.Focused and (ActiveChild.VTMP^.Positions.Length >
   ActiveChild.SGPositions.Col);
end;

procedure TMainForm.InsertPositionsUpdate(Sender: TObject);
begin
 (Sender as TAction).Enabled :=
   ActiveChildExists and ((ActiveChild.IsPlayingWindow < 0) or
   (PlayMode = PMPlayLine)) and ActiveChild.SGPositions.Focused and
   (ActiveChild.VTMP^.Positions.Length < 256) and
   (ActiveChild.VTMP^.Positions.Length > ActiveChild.SGPositions.Col);
end;

procedure TMainForm.ActiveControlChangedHandler(Sender: TObject; LastControl: TControl);
var
 Frame: TWinControl;
begin
 if LastControl is TWinControl then
  begin
   Frame := GetParentFrame(LastControl as TWinControl);
   if Assigned(Frame) then
     (Frame as TChildForm).ActiveControl := LastControl as TWinControl;
  end;
end;

procedure TMainForm.MIHierarchyClick(Sender: TObject);
begin
 TryOpenDocument('Trackers hierarchy.txt');
end;

procedure TMainForm.MIHistoryClick(Sender: TObject);
begin
 TryOpenDocument('History.txt');
end;

procedure TMainForm.MILimsClick(Sender: TObject);
begin
 TryOpenDocument('Trackers limitations.txt');
end;

procedure TMainForm.MIManualClick(Sender: TObject);
begin
 TryOpenDocument('Tracker manual.txt');
end;

procedure TMainForm.MIMaximizedClick(Sender: TObject);
begin
 if MaximizedChilds then
   RestoreChilds
 else if ActiveChildExists then
   MaximizeChild(ActiveChild)
 else
   MaximizeChild(nil);
end;

procedure TMainForm.MIQuickGuideClick(Sender: TObject);
begin
 TryOpenDocument('readme.txt');
end;

procedure TMainForm.MIRestore1Click(Sender: TObject);
begin
 RestoreChilds;
end;

procedure TMainForm.MIClose1Click(Sender: TObject);
begin
 FileClose1.Execute;
end;

procedure TMainForm.MergePositionsExecute(Sender: TObject);
begin
 if ActiveChildExists then
   with ActiveChild do
     if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
       PasteToPositionsList(True);
end;

procedure TMainForm.MergePositionsUpdate(Sender: TObject);
begin
 MergePositions.Enabled := ActiveChildExists and ActiveChild.SGPositions.Focused and
   ((ActiveChild.IsPlayingWindow < 0) or (PlayMode = PMPlayLine));
end;

procedure TMainForm.MIPosSelectAllClick(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.PosSelectAll;
end;

procedure TMainForm.MISelectAllClick(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
   if (ActiveControl is TTestLine) then
     (ActiveControl as TTestLine).SelectAll
   else if (ActiveControl is TSamples) then
     (ActiveControl as TSamples).SelectAll
   else if (ActiveControl is TOrnaments) then
     (ActiveControl as TOrnaments).SelectAll;
end;

procedure TMainForm.MITablesCsvClick(Sender: TObject);
begin
 TryOpenDocument('ToneTables.csv');
end;

procedure TMainForm.MITracksSelectAllClick(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.Tracks.SelectAll;
end;

procedure TMainForm.MIZXAYPlayerClick(Sender: TObject);
begin
 TryOpenDocument('ZXAYPlayer.txt');
end;

procedure TMainForm.MIZXTSPlayerClick(Sender: TObject);
begin
 TryOpenDocument('ZXTSPlayer.txt');
end;

procedure TMainForm.MouseHook(Sender: TObject; Msg: cardinal);
var
 Frame: TWinControl;
begin
 case Msg of
   LM_LBUTTONDOWN, LM_NCLBUTTONDOWN:
    begin
     if not (Sender is TWinControl) then
       Exit;

  {method does not work if user click main menu item apeared infront of some control
  if Sender is TApplication then //bug in LCL
   begin
    if Msg = LM_NCLBUTTONDOWN then //TStringGrid scroll bar
     begin
      Sender := Application.GetControlAtMouse;
      if not (Sender is TStringGrid) then
       Exit;
     end
    else
     Exit;
   end;}

     Frame := GetParentFrame(Sender as TWinControl);
     if not Assigned(Frame) then
       Exit;

     with Frame as TChildForm do
      begin

       //pass flag to FormActivate to don't scroll workspace
       Moving := ctHooked;

       //Controls which not focused by usual mouse clicks
       if (Sender is TTabSheet) or (Sender is TUpDown) or
         (Sender is TPanel) or (Sender is TChildForm){ or
       (Sender is TStringGrid)} then
         SetFocusAtActiveControl;
      end;
    end;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
 Application.RemoveOnUserInputHandler(@MouseHook);
 Screen.RemoveHandlerActiveControlChanged(@ActiveControlChangedHandler);
end;

procedure TMainForm.VScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode;
 var ScrollPos: integer);
begin
 if ScrollCode in [scLineDown, scLineUp, scEndScroll] then
  begin
   if ScrollPos + VScrollBar.PageSize >= VScrollBar.Max then
     ScrollPos := VScrollBar.Max - VScrollBar.PageSize;
   if ScrollPos <> VScrollBar.Tag then
    begin
     Workspace.ScrollBy(0, VScrollBar.Tag - ScrollPos);
     VScrollBar.Tag := ScrollPos;
     CalcSBs;
    end;
  end;
end;

procedure TMainForm.CalcSBs;
var
 i, MinLeft, MinTop, MaxRight, MaxBottom, W, H: integer;
begin
 //setting some properties of ScrollBar results to raising various onsize and
 //positioning handlers, so trying to calc all need and to set it only once
 with Workspace do
  begin
   Inc(SoftResize); //prevent calling OnSize handler until end of this procedure

   if (ControlCount = 0) or MaximizedChilds then
    begin
     HScrollBar.Visible := False;
     VScrollBar.Visible := False;
    end
   else
    begin
     //calc min and max Workspace's controls coords
     MinLeft := Controls[0].Left;
     MinTop := Controls[0].Top;
     MaxRight := Controls[0].Left + Controls[0].Width;
     MaxBottom := Controls[0].Top + Controls[0].Height;
     for i := 1 to ControlCount - 1 do
       with Controls[i] do
        begin
         if Left < MinLeft then MinLeft := Left;
         if Top < MinTop then MinTop := Top;
         if Left + Width > MaxRight then MaxRight := Left + Width;
         if Top + Height > MaxBottom then MaxBottom := Top + Height;
        end;

     //getting workarea size without changing SBs.Visible
     W := Width;
     H := Height;
     if HScrollBar.Visible then
       Inc(H, HScrollBar.Height);
     if VScrollBar.Visible then
       Inc(W, VScrollBar.Width);

     if (MinLeft >= 0) and (MaxRight <= W) and (MinTop >= 0) and (MaxBottom <= H) then
       //is fit to workarea
      begin
       HScrollBar.Visible := False;
       VScrollBar.Visible := False;
      end
     //todo сгруппировать однотипные условия
     else if (MinLeft < 0) and (MinTop >= 0) and (MaxBottom <= H -
       HScrollBar.Height) then
       //is fit to vertical but lefter
      begin
       HScrollBar.Tag := -MinLeft; //HScrollBar.Position copy
       if MaxRight <= W then
         HScrollBar.Max := W - MinLeft
       else
         HScrollBar.Max := MaxRight - MinLeft;
       HScrollBar.PageSize := W;
       HScrollBar.Visible := True;
       VScrollBar.Visible := False;
      end
     else if (MinLeft >= 0) and (MaxRight > W) and (MinTop >= 0) and
       (MaxBottom <= H - HScrollBar.Height) then
       //is fit to vertical but righter
      begin
       HScrollBar.Tag := 0;
       HScrollBar.Max := MaxRight;
       HScrollBar.PageSize := W;
       HScrollBar.Visible := True;
       VScrollBar.Visible := False;
      end
     else if (MinLeft >= 0) and (MaxRight <= W - VScrollBar.Width) and
       (MinTop < 0) then
       //is fit to horizontal but upper
      begin
       VScrollBar.Tag := -MinTop;
       if MaxBottom <= H then
         VScrollBar.Max := H - MinTop
       else
         VScrollBar.Max := MaxBottom - MinTop;
       VScrollBar.PageSize := H;
       HScrollBar.Visible := False;
       VScrollBar.Visible := True;
      end
     else if (MinLeft >= 0) and (MaxRight <= W - VScrollBar.Width) and
       (MinTop >= 0) and (MaxBottom > H) then
       //is fit to horizontal but lower
      begin
       VScrollBar.Tag := 0;
       VScrollBar.Max := MaxBottom;
       VScrollBar.PageSize := H;
       HScrollBar.Visible := False;
       VScrollBar.Visible := True;
      end
     else if (MinLeft < 0) and (MinTop < 0) then
       //is lefter and upper
      begin
       HScrollBar.Tag := -MinLeft;
       if MaxRight <= W - VScrollBar.Width then
         HScrollBar.Max := W - MinLeft - VScrollBar.Width
       else
         HScrollBar.Max := MaxRight - MinLeft;
       HScrollBar.PageSize := W - VScrollBar.Width;
       VScrollBar.Tag := -MinTop;
       if MaxBottom <= H - HScrollBar.Height then
         VScrollBar.Max := H - MinTop - HScrollBar.Height
       else
         VScrollBar.Max := MaxBottom - MinTop;
       VScrollBar.PageSize := H - HScrollBar.Height;
       HScrollBar.Visible := True;
       VScrollBar.Visible := True;
      end
     else if (MinLeft >= 0) and (MaxRight >= W - VScrollBar.Width) and
       (MinTop < 0) then
       //is righter and upper
      begin
       HScrollBar.Tag := 0;
       HScrollBar.Max := MaxRight;
       HScrollBar.PageSize := W - VScrollBar.Width;
       VScrollBar.Tag := -MinTop;
       if MaxBottom <= H - HScrollBar.Height then
         VScrollBar.Max := H - MinTop - HScrollBar.Height
       else
         VScrollBar.Max := MaxBottom - MinTop;
       VScrollBar.PageSize := H - HScrollBar.Height;
       HScrollBar.Visible := True;
       VScrollBar.Visible := True;
      end
     else if (MinLeft >= 0) and (MaxRight >= W - VScrollBar.Width) and
       (MinTop >= 0) and (MaxBottom >= H - HScrollBar.Height) then
       //is righter and lower
      begin
       HScrollBar.Tag := 0;
       HScrollBar.Max := MaxRight;
       HScrollBar.PageSize := W - VScrollBar.Width;
       VScrollBar.Tag := 0;
       VScrollBar.Max := MaxBottom;
       VScrollBar.PageSize := H - HScrollBar.Height;
       HScrollBar.Visible := True;
       VScrollBar.Visible := True;
      end
     else if (MinLeft < 0) and (MinTop >= 0) and
       (MaxBottom >= H - HScrollBar.Height) then
       //is lefter and lower
      begin
       HScrollBar.Tag := -MinLeft;
       if MaxRight <= W - VScrollBar.Width then
         HScrollBar.Max := W - MinLeft - VScrollBar.Width
       else
         HScrollBar.Max := MaxRight - MinLeft;
       HScrollBar.PageSize := W - VScrollBar.Width;
       VScrollBar.Tag := 0;
       VScrollBar.Max := MaxBottom;
       VScrollBar.PageSize := H - HScrollBar.Height;
       HScrollBar.Visible := True;
       VScrollBar.Visible := True;
      end;


     if HScrollBar.Visible then
      begin
       HScrollBar.LargeChange := HScrollBar.PageSize;
       HScrollBar.Position := HScrollBar.Tag;
      end;
     if VScrollBar.Visible then
      begin
       VScrollBar.LargeChange := VScrollBar.PageSize;
       VScrollBar.Position := VScrollBar.Tag;
      end;

    end;
   Dec(SoftResize);
  end;
end;

function TMainForm.Next(Step: integer = 1; PlayingWindow: boolean = False;
 MakeFocused: boolean = True; SkipTS: boolean = False): TChildForm;
var
 iFrom, i: integer;
 From: TChildForm;

 procedure IncW;
 begin
   //-1 (no window) will become 0
   i := (i + Step) mod Childs.Count;
   if i < 0 then Inc(i, Childs.Count);
 end;

begin
 if Childs.Count > 1 then
  begin

   if PlayingWindow then
     From := PlaybackWindow[0]
   else
     From := ActiveChild;
   iFrom := Childs.IndexOf(From);

   i := iFrom;
   IncW;

   //check to don't play TS one more time
   if (PlayingWindow or SkipTS) and (iFrom >= 0) and
     (TChildForm(Childs.Items[iFrom]).TSWindow = TChildForm(Childs.Items[i])) then
     IncW;

   Result := TChildForm(Childs.Items[i]);

   if MakeFocused then
     Result.SetForeground;
  end
 else
   Result := nil;
end;

function TMainForm.GetParentFrame(Ctrl: TWinControl): TWinControl;
begin
 Result := Ctrl;
 if not Assigned(Result) then Exit;
 repeat
   if Result is TChildForm then
     Exit;
   Result := Result.Parent;
 until not Assigned(Result);
end;

function TMainForm.ActiveChildExists: boolean;
begin
 Result := (Childs.Count <> 0) and (Childs.IndexOf(ActiveChild) >= 0);
end;

procedure TMainForm.FileNew1Execute(Sender: TObject);
begin
 CreateChild('');
end;

procedure TMainForm.FileOpen1Execute(Sender: TObject);
var
 i: integer;
begin
 OpenDialogVTM.FileName := ExtractFileName(OpenDialogVTM.FileName);
 if OpenDialogVTM.Execute then
  begin
   OpenDialogVTM.InitialDir := ExtractFilePath(OpenDialogVTM.FileName);
   i := OpenDialogVTM.Files.Count - 1;
   //better to limit number per one open, this is just editor, not player with playlist
   //and too much resources are alocated for each window
   if i > 16 then
     i := 16;
   for i := 0 to i do
     CreateChild(OpenDialogVTM.Files.Strings[i]);
  end;
end;

procedure TMainForm.FindWindow1Execute(Sender: TObject);
var
 SearchedText: string;
 i: integer;
begin
 SearchedText := InputBox(Mes_FindCapt, Mes_FindIntro, '');
 if SearchedText = '' then
   Exit;

 for i := Childs.Count - 1 downto 0 do
   with TChildForm(Childs.Items[i]) do
     if (Pos(SearchedText, ExtractFileName(WinFileName)) <> 0) or
       (Pos(SearchedText, EdTitle.Text) <> 0) or
       (Pos(SearchedText, EdAuthor.Text) <> 0) then
      begin
       //    IsSoftRepos:=True;
       if TSWindow <> nil then
         with TSWindow do
          begin
{       IsSoftRepos:=True;
       if WindowState = wsMinimized then
        WindowState := wsNormal
       else
        Show;
       IsSoftRepos:=False;}
           SetForeground;
          end;
{    if WindowState = wsMinimized then
     WindowState := wsNormal
    else
     Show;
    IsSoftRepos:=False;}
       SetForeground;
       if (i > 0) and (MessageDlg(Mes_FindCont, mtConfirmation, [mbYes, mbNo], 0) <>
         mrYes) then
         Break;
      end;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
 i: integer;
begin
 digsoundthread_stop;
 SaveOptions;
 MidiInTimer.Enabled := False; //after SaveOptions to save correct state
 MidiIn_Close;
 for i := Childs.Count - 1 downto 0 do
   TChildForm(Childs.Items[i]).Close;
end;

procedure TMainForm.HelpAbout1Execute(Sender: TObject);
begin
 AboutBox.ShowModal;
end;

procedure TMainForm.FileExit1Execute(Sender: TObject);
begin
 Close;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
 i: integer;
 Path: string;
begin
 WinCount := 0;
 Childs := TList.Create;
 SoftResize := 0;

 //offset for cascade
 win_o := GetSystemMetrics(SM_CYCAPTION) + 3;

 //progress controls
 Progress.Parent := MainStatusBar;
 SBCancel.Parent := MainStatusBar;

 with VTOptions do
  begin
   //default colors
   GlobalColorWorkspace := clAppWorkspace;
   GlobalColorBgEmpty := clBtnFace;
   TracksColorBg := clWindow;
   TracksColorTxt := clWindowText;
   TracksColorBgHl := cl3DLight;//GetSysColor(COLOR_WINDOW) xor $101010;
   TracksColorBgHlMain := clHighlight;
   TracksColorBgBeyond := clBtnFace;
   TracksColorTxtHlMain := clHighlightText;
   SamplesColorBg := clWindow;
   SamplesColorTxt := clWindowText;
   SamplesColorBgLp := clHighlight;
   SamplesColorTxtLp := clHighlightText;
   SamplesColorBgBeyond := clWindow;
   SamplesColorTxtBeyond := clGrayText;
   SamplesColorBgHl := cl3DLight;
   SamplesColorBgLpHl := clHotLight;
   SamplesColorBgBeyondHl := cl3DLight;
   OrnamentsColorBg := clWindow;
   OrnamentsColorTxt := clWindowText;
   OrnamentsColorBgLp := clHighlight;
   OrnamentsColorTxtLp := clHighlightText;
   OrnamentsColorBgBeyond := clWindow;
   OrnamentsColorTxtBeyond := clGrayText;
   OrnamentsColorBgHl := cl3DLight;
   OrnamentsColorBgLpHl := clHotLight;
   OrnamentsColorBgBeyondHl := cl3DLight;
   TestsColorBg := clWindow;
   TestsColorTxt := clWindowText;

   DetectFeaturesLevel := True;
   DetectModuleHeader := True;
   Lang := '';
   {$IFDEF Windows}
   Priority := NORMAL_PRIORITY_CLASS;
   {$ENDIF Windows}
  end;

 for i := 0 to 5 do RecentFiles[i] := '';
 Enabled := True;
 FileMode := 0;

 Path := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

 OpenDialogVTM.InitialDir := GetFolder(Path, ['Modules', 'Modules for test']);
 PatternsFolder := GetFolder(Path, ['Patterns']);
 SamplesFolder := GetFolder(Path, ['Samples']);
 OrnamentsFolder := GetFolder(Path, ['Ornaments']);

 with VTOptions do
  begin
   ChannelsAllocationCarousel := ChannelsAllocationCarouselDef;
   TracksNOfLines := TracksNOfLinesDef;
   AutoStepValue := AutoStepValueDef;
   NoteTable := DefNoteTable;
   DecTrLines := DecTrLinesDef;
   DecNoise := DecNoiseDef;
   EnvAsNote := EnvAsNoteDef;
   RecalcEnv := RecalcEnvDef;
   BgAllowMIDI := BgAllowMIDIDef;
   SamAsNote := SamAsNoteDef;
   OrnAsNote := OrnAsNoteDef;
   TracksHint := TracksHintDef;
   SamHint := SamHintDef;
   OrnHint := OrnHintDef;
   SamOrnHLines := SamOrnHLinesDef;
   NotWarnUndo := NotWarnUndoDef;
   //default fonts
   TracksFont.Name := 'Courier';
   TracksFont.Size := 12;
   TracksFont.Bold := False;
   SamplesFont := TracksFont;
   SamplesFont.Size := 10;
   OrnamentsFont := TracksFont;
   TestsFont := TracksFont;
  end;

 LoopAllowed := False;
 LoopAllAllowed := False;

 GlobalVolume := GlobalVolumeMax;
 VolumeControl := TVolumeControl.Create(MainToolBar);
 VolumeControl.Parent := MainToolBar;
 VolumeControl.Width := GlobalVolumeMax + 2;
 VolumeControl.Height := 22;
 VolumeControl.Left := TBDivMidi.Left + TBDivMidi.Width;
 VolumeControl.Top := TBDivMidi.Top;

 digsoundNotify := Handle;
 UM_DIGSOUNDNOTIFY := UM_FINALIZEDS;
 MidiIn_Init(Handle, UM_MIDINOTE);
 SetDefault;
 PlaybackBufferMaker.ForPlayback := True;
 LoadOptions;
 DefaultLang := SetDefaultLang(VTOptions.Lang);
 Workspace.Color := VTOptions.GlobalColorWorkspace;
 SetGlobalShortcuts;
 UpdateToggleMidiKbdHint;
 Screen.AddHandlerActiveControlChanged(@ActiveControlChangedHandler);

 //need to translate clicks to frames SetFocus
 Application.AddOnUserInputHandler(@MouseHook);
end;

procedure TMainForm.RedrawPlWindow(PW: TChildForm; ps, pat, line: integer);
begin
 if (ps >= 0) and (PW.SGPositions.Tag = 0) and //not clicked
   (PW.SGPositions.Selection.Left = PW.SGPositions.Selection.Right) then //no selection
   PW.ShowPosition(ps);
 if (PW.PatNum <> pat) or (PW.Tracks.ShownFrom <> line) then
  begin
   PW.ChangePattern(pat, line);
   PW.CalculatePos(line);
  end;
end;

procedure TMainForm.ResizeChilds;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).FullResize;
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).HookTSWindow;
end;

procedure TMainForm.UpdateChildsTracksHints;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).Tracks.ShowHint := VTOptions.TracksHint;
end;

procedure TMainForm.UpdateChildsSamplesHints;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).Samples.ShowHint := VTOptions.SamHint;
end;

procedure TMainForm.UpdateChildsOrnamentsHints;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).Ornaments.ShowHint := VTOptions.OrnHint;
end;

procedure TMainForm.InvalidateChildTracks;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
     Tracks.Invalidate;
end;

procedure TMainForm.InvalidateChildSamples;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
     Samples.Invalidate;
end;

procedure TMainForm.InvalidateChildOrnaments;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
     Ornaments.Invalidate;
end;

procedure TMainForm.InvalidateChildTests;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
    begin
     SampleTestLine.Invalidate;
     OrnamentTestLine.Invalidate;
     PatternTestLine.Invalidate;
    end;
end;

procedure TMainForm.Options1Execute(Sender: TObject);
var
 Saved_BufLen_ms, Saved_NumberOfBuffers, Saved_digsoundDevice,
 Saved_FeaturesLevel: integer;
 Saved_VortexModuleHeader: boolean;
 Saved_Shortcuts: TShortcuts;
 Saved_NoteKeys: array[0..255] of shortint;
 VTO: TOptionsSet;
begin
 Saved_VTOptions := VTOptions;
 with OptionsDlg, VTOptions do
  begin
   UDNumLines.Position := TracksNOfLines;
   UDNoteTbl.Position := NoteTable;
   UDAutStpVal.Position := AutoStepValue;
   CBDecTrLines.Checked := DecTrLines;
   CBDecNoise.Checked := DecNoise;
   CBEnvAsNote.Checked := EnvAsNote;
   CBSamAsNote.Checked := SamAsNote;
   CBOrnAsNote.Checked := OrnAsNote;
   CBRecalcEnv.Checked := RecalcEnv;
   CBBgAllowMIDI.Checked := BgAllowMIDI;
   CBTracksHint.Checked := TracksHint;
   CBSamHint.Checked := SamHint;
   CBOrnHint.Checked := OrnHint;
   CBSamOrnHL.Checked := SamOrnHLines;
   CBNotWarnUndo.Checked := NotWarnUndo;
   CBLMBtoDraw.Checked := LMBtoDraw;
   ShowFont(TracksFont, LbTracksFont);
   ShowFont(SamplesFont, LbSamplesFont);
   ShowFont(OrnamentsFont, LbOrnamentsFont);
   ShowFont(TestsFont, LbTestsFont);
   ShowColor(GlobalColorWorkspace, ShGlobalWorkspace);
   ShowColor(GlobalColorBgEmpty, ShGlobalBgEmpty);
   ShowColor(TracksColorTxt, ShTracksTxt);
   ShowColor(TracksColorTxtHlMain, ShTracksTxtHlMain);
   ShowColor(TracksColorBg, ShTracksBg);
   ShowColor(TracksColorBgBeyond, ShTracksBgBynd);
   ShowColor(TracksColorBgHlMain, ShTracksBgHlMain);
   ShowColor(TracksColorBgHl, ShTracksBgHl);
   ShowColor(SamplesColorTxt, ShSamplesTxt);
   ShowColor(SamplesColorTxtLp, ShSamplesTxtLp);
   ShowColor(SamplesColorTxtBeyond, ShSamplesTxtBynd);
   ShowColor(SamplesColorBg, ShSamplesBg);
   ShowColor(SamplesColorBgLp, ShSamplesBgLp);
   ShowColor(SamplesColorBgBeyond, ShSamplesBgBynd);
   ShowColor(SamplesColorBgHl, ShSamplesBgHl);
   ShowColor(SamplesColorBgLpHl, ShSamplesBgLpHl);
   ShowColor(SamplesColorBgBeyondHl, ShSamplesBgBeyondHl);
   ShowColor(OrnamentsColorTxt, ShOrnamentsTxt);
   ShowColor(OrnamentsColorTxtLp, ShOrnamentsTxtLp);
   ShowColor(OrnamentsColorTxtBeyond, ShOrnamentsTxtBynd);
   ShowColor(OrnamentsColorBg, ShOrnamentsBg);
   ShowColor(OrnamentsColorBgLp, ShOrnamentsBgLp);
   ShowColor(OrnamentsColorBgBeyond, ShOrnamentsBgBynd);
   ShowColor(OrnamentsColorBgHl, ShOrnamentsBgHl);
   ShowColor(OrnamentsColorBgLpHl, ShOrnamentsBgLpHl);
   ShowColor(OrnamentsColorBgBeyondHl, ShOrnamentsBgBeyondHl);
   ShowColor(TestsColorTxt, ShTestsTxt);
   ShowColor(TestsColorBg, ShTestsBg);
   ChipSel.ItemIndex := Ord(ChipType) - 1;
   case ChannelsAllocation of
     0: RBcaMono.Checked := True;
     1: RBcaABC.Checked := True;
     2: RBcaACB.Checked := True;
     3: RBcaBAC.Checked := True;
     4: RBcaBCA.Checked := True;
     5: RBcaCAB.Checked := True;
     6: RBcaCBA.Checked := True;
    end;
   CBcaMono.Checked := (ChannelsAllocationCarousel and 1) <> 0;
   CBcaABC.Checked := (ChannelsAllocationCarousel and 2) <> 0;
   CBcaACB.Checked := (ChannelsAllocationCarousel and 4) <> 0;
   CBcaBAC.Checked := (ChannelsAllocationCarousel and 8) <> 0;
   CBcaBCA.Checked := (ChannelsAllocationCarousel and 16) <> 0;
   CBcaCAB.Checked := (ChannelsAllocationCarousel and 32) <> 0;
   CBcaCBA.Checked := (ChannelsAllocationCarousel and 64) <> 0;
   case AY_Freq of
     1773400: ChFreq.ItemIndex := 0;
     1750000: ChFreq.ItemIndex := 1;
     2000000: ChFreq.ItemIndex := 2;
     1000000: ChFreq.ItemIndex := 3;
     3500000: ChFreq.ItemIndex := 4;
   else
    begin
     EdChipFrq.Text := IntToStr(AY_Freq);
     ChFreq.ItemIndex := 5;
    end;
    end;
   case Interrupt_Freq of
     50000: IntSel.ItemIndex := 0;
     48828: IntSel.ItemIndex := 1;
     60000: IntSel.ItemIndex := 2;
     100000: IntSel.ItemIndex := 3;
     200000: IntSel.ItemIndex := 4;
   else
    begin
     EdIntFrq.Text := IntToStr(Interrupt_Freq);
     IntSel.ItemIndex := 5;
    end;
    end;
   if SampleRate = 11025 then
     SR.ItemIndex := 0
   else if SampleRate = 22050 then
     SR.ItemIndex := 1
   else if SampleRate = 44100 then
     SR.ItemIndex := 2
   else if SampleRate = 48000 then
     SR.ItemIndex := 3
   else if SampleRate = 96000 then
     SR.ItemIndex := 4
   else if SampleRate = 192000 then
     SR.ItemIndex := 5;
   BR.ItemIndex := Ord(SampleBit = 16);
   NCh.ItemIndex := Ord(NumberOfChannels = 2);
   Resamp.ItemIndex := Ord(FilterWant);
   LbFIRk.Caption := FiltInfo;
   if DetectFeaturesLevel then
     FeatLevel.ItemIndex := 3
   else
     FeatLevel.ItemIndex := FeaturesLevel;
   if DetectModuleHeader then
     SaveHead.ItemIndex := 2
   else if VortexModuleHeader then
     SaveHead.ItemIndex := 0
   else
     SaveHead.ItemIndex := 1;
   {$IFDEF Windows}
   PriorGrp.ItemIndex := Ord(Priority <> NORMAL_PRIORITY_CLASS);
   {$ENDIF Windows}
   if Lang = '' then
     CBLang.ItemIndex := 0
   else
     CBLang.Text := Lang;
  end;
 Saved_FeaturesLevel := FeaturesLevel;
 Saved_VortexModuleHeader := VortexModuleHeader;
 OptionsDlg.TBBufLen.Position := BufLen_ms;
 Saved_BufLen_ms := BufLen_ms;
 OptionsDlg.TBBufNum.Position := NumberOfBuffers;
 Saved_NumberOfBuffers := NumberOfBuffers;
 Saved_digsoundDevice := digsoundDevice;
 OptionsDlg.CBDevice.Items.Clear;
 digsound_getdevices(OptionsDlg.CBDevice.Items);
 if digsoundDevice < OptionsDlg.CBDevice.Items.Count then
   OptionsDlg.CBDevice.ItemIndex := digsoundDevice;
 Saved_Shortcuts := CustomShortcuts;
 Saved_NoteKeys := NoteKeys;

 if OptionsDlg.ShowModal <> mrOk then
  begin
   VTO := VTOptions; //store changed options to check while rollback
   VTOptions := Saved_VTOptions;

   with VTOptions do
    begin
     if (VTO.TracksFont.Name <> TracksFont.Name) or
       (VTO.TracksFont.Size <> TracksFont.Size) or
       (VTO.TracksFont.Bold <> TracksFont.Bold) or
       (VTO.SamplesFont.Name <> SamplesFont.Name) or
       (VTO.SamplesFont.Size <> SamplesFont.Size) or
       (VTO.SamplesFont.Bold <> SamplesFont.Bold) or
       (VTO.OrnamentsFont.Name <> OrnamentsFont.Name) or
       (VTO.OrnamentsFont.Size <> OrnamentsFont.Size) or
       (VTO.OrnamentsFont.Bold <> OrnamentsFont.Bold) or
       (VTO.TestsFont.Name <> TestsFont.Name) or
       (VTO.TestsFont.Size <> TestsFont.Size) or
       (VTO.TestsFont.Bold <> TestsFont.Bold) then
       ResizeChilds;
     if VTO.TracksHint <> TracksHint then
       UpdateChildsTracksHints;
     if VTO.SamHint <> SamHint then
       UpdateChildsSamplesHints;
     if VTO.OrnHint <> OrnHint then
       UpdateChildsOrnamentsHints;
     Workspace.Color := GlobalColorWorkspace;
     if (VTO.TracksColorTxt <> TracksColorTxt) or
       (VTO.TracksColorBg <> TracksColorBg) or
       (VTO.TracksColorTxtHlMain <> TracksColorTxtHlMain) or
       (VTO.TracksColorBgHlMain <> TracksColorBgHlMain) or
       (VTO.TracksColorBgHl <> TracksColorBgHl) or
       (VTO.TracksColorBgBeyond <> TracksColorBgBeyond) then
       InvalidateChildTracks;
     if (VTO.SamplesColorTxt <> SamplesColorTxt) or
       (VTO.SamplesColorBg <> SamplesColorBg) or
       (VTO.SamplesColorTxtLp <> SamplesColorTxtLp) or
       (VTO.SamplesColorBgLp <> SamplesColorBgLp) or
       (VTO.SamplesColorTxtBeyond <> SamplesColorTxtBeyond) or
       (VTO.SamplesColorBgBeyond <> SamplesColorBgBeyond) or
       (VTO.SamplesColorBgHl <> SamplesColorBgHl) or
       (VTO.SamplesColorBgLpHl <> SamplesColorBgLpHl) or
       (VTO.SamplesColorBgBeyondHl <> SamplesColorBgBeyondHl) or
       (VTO.GlobalColorBgEmpty <> GlobalColorBgEmpty) or
       (VTO.SamOrnHLines <> SamOrnHLines) then
       InvalidateChildSamples;
     if (VTO.OrnamentsColorTxt <> OrnamentsColorTxt) or
       (VTO.OrnamentsColorBg <> OrnamentsColorBg) or
       (VTO.OrnamentsColorTxtLp <> OrnamentsColorTxtLp) or
       (VTO.OrnamentsColorBgLp <> OrnamentsColorBgLp) or
       (VTO.OrnamentsColorTxtBeyond <> OrnamentsColorTxtBeyond) or
       (VTO.OrnamentsColorBgBeyond <> OrnamentsColorBgBeyond) or
       (VTO.OrnamentsColorBgHl <> OrnamentsColorBgHl) or
       (VTO.OrnamentsColorBgLpHl <> OrnamentsColorBgLpHl) or
       (VTO.OrnamentsColorBgBeyondHl <> OrnamentsColorBgBeyondHl) or
       (VTO.GlobalColorBgEmpty <> GlobalColorBgEmpty) or
       (VTO.SamOrnHLines <> SamOrnHLines) then
       InvalidateChildOrnaments;
     if (VTO.TestsColorTxt <> TestsColorTxt) or (VTO.TestsColorBg <> TestsColorBg) then
       InvalidateChildTests;
     if VTO.ChipType <> ChipType then
       SetEmulatingChip(ChipType);
     if VTO.ChannelsAllocation <> ChannelsAllocation then
       SetChannelsAllocation(ChannelsAllocation);
     if VTO.AY_Freq <> AY_Freq then
       Set_Chip_Frq(AY_Freq);
     if VTO.Interrupt_Freq <> Interrupt_Freq then
       SetIntFreqEx(Interrupt_Freq);
     if not digsoundthread_active then
      begin
       if VTO.SampleRate <> SampleRate then
         Set_Sample_Rate(SampleRate);
       if VTO.SampleBit <> SampleBit then
         Set_Sample_Bit(SampleBit);
       if VTO.NumberOfChannels <> NumberOfChannels then
         Set_Stereo(NumberOfChannels);
       if (Saved_BufLen_ms <> BufLen_ms) or (Saved_NumberOfBuffers <>
         NumberOfBuffers) then
         SetBuffers(Saved_BufLen_ms, Saved_NumberOfBuffers);
       digsoundDevice := Saved_digsoundDevice;
      end;
     if VTO.FilterWant <> FilterWant then
       SetFilter(FilterWant);
     {$IFDEF Windows}
     if VTO.Priority <> Priority then
       SetPriority(Priority);
     {$ENDIF Windows}
     if VTO.Lang <> Lang then
       OptionsDlg.UpdateLang;
    end;

   FeaturesLevel := Saved_FeaturesLevel;
   VortexModuleHeader := Saved_VortexModuleHeader;
   CustomShortcuts := Saved_Shortcuts;
   NoteKeys := Saved_NoteKeys;
  end
 else
  begin
   ShortcutsSort; //if set new shortcuts, they must be sorted
   SetGlobalShortcuts;
  end;
end;

procedure TMainForm.SavePT3(ChildWindow: TChildForm; FileName: string; AsText: boolean);
var
 PT3: TSpeccyModule;
 Size: integer;
 f: file;
 CW: TChildForm;
begin
 if (ChildWindow.TSWindow <> nil) and (ChildWindow.WinNumber >
   ChildWindow.TSWindow.WinNumber) then
   //save first if created earlier in TS-pair
   CW := ChildWindow.TSWindow
 else
   CW := ChildWindow;
 if not AsText then
  begin
   if not VTM2PT3(@PT3, CW.VTMP, Size) then
    begin
     Application.MessageBox(pansichar(Mes_CantCompileTooBig), pansichar(FileName));
     Exit;
    end;
   AssignFile(f, FileName);
   Rewrite(f, 1);
    try
     BlockWrite(f, PT3, Size);
     if CW.TSWindow <> nil then
      begin
       TSData.Size1 := Size;
       if not VTM2PT3(@PT3, CW.TSWindow.VTMP, Size) then
        begin
         Application.MessageBox(pansichar(Mes_CantCompileTooBig), pansichar(FileName));
         Exit;
        end;
       BlockWrite(f, PT3, Size);
       TSData.Size2 := Size;
       BlockWrite(f, TSData, SizeOf(TSData));
      end;
    finally
     CloseFile(f);
    end;
  end
 else
  begin
   VTM2TextFile(FileName, CW.VTMP, False);
   if CW.TSWindow <> nil then
     VTM2TextFile(FileName, CW.TSWindow.VTMP, True);
  end;
 CW.SavedAsText := AsText;
 CW.SongChanged := False;
 CW.SetFileName(FileName);
 if CW.TSWindow <> nil then
  begin
   CW.TSWindow.SavedAsText := AsText;
   CW.TSWindow.SongChanged := False;
   CW.TSWindow.SetFileName(FileName);
  end;
 AddFileName(FileName);
end;

procedure TMainForm.CommonActionUpdate(Sender: TObject);
begin
 if Sender is TAction then
   with Sender as TAction do
     Enabled := Childs.Count <> 0;
end;

procedure TMainForm.PatternsActionUpdate(Sender: TObject);
begin
 (Sender as TAction).Enabled :=
   ActiveChildExists and (ActiveChild.EditorPages.ActivePageIndex = piTracks) and
   ActiveChild.Tracks.Enabled;
end;

procedure TMainForm.FileSave1Execute(Sender: TObject);
begin
 if ActiveChildExists then
   ActiveChild.SaveModule;
end;

procedure TMainForm.FileSaveAs1Execute(Sender: TObject);
begin
 if ActiveChildExists then
   ActiveChild.SaveModuleAs;
end;

procedure TMainForm.SBCancelClick(Sender: TObject);
begin
 SBCancel.Tag := 0;
end;

procedure TMainForm.MainStatusBarDrawPanel(StatusBar_: TStatusBar;
 Panel: TStatusPanel; const Rect: TRect);
var
 aRect: TRect;
begin
 if Panel = MainStatusBar.Panels[1] then
  begin
   SBCancel.Top := Rect.Top + (Rect.Height - SBCancel.Height) div 2;
   SBCancel.Left := Rect.Left;
   aRect := Rect;
   Inc(aRect.Left, SBCancel.Width + 2);
   Progress.BoundsRect := aRect;
  end;
end;

procedure TMainForm.FileSave1Update(Sender: TObject);
begin
 FileSave1.Enabled := ActiveChildExists and (ActiveChild.SongChanged or
   ((ActiveChild.TSWindow <> nil) and ActiveChild.TSWindow.SongChanged));
end;

function TMainForm.GetSaveAsFileExt: string;
begin
 if SaveDialogVTM.FilterIndex = 1 then
   Result := 'txt'
 else
   Result := 'pt3';
end;

procedure TMainForm.SaveDialogVTMTypeChange(Sender: TObject);
begin
 SaveDialogVTM.DefaultExt := GetSaveAsFileExt;
end;

procedure TMainForm.Stop1Update(Sender: TObject);
begin
 Stop1.Enabled := (Childs.Count <> 0) and IsPlaying;
end;

procedure TMainForm.Play1Execute(Sender: TObject);
var
 i: integer;
 CW: TChildForm;
begin
 if not GetCurrentWindow(CW) then
   Exit;
 if CW.VTMP^.Positions.Length <= 0 then
   Exit;
 if IsPlaying then
  begin
   digsoundthread_stop;
   RestoreControls;
  end;
 PlayMode := PMPlayModule;
 DisableControls(True);
 CW.Tracks.AbortSelection;
 for i := 0 to Length(PlaybackBufferMaker.Players) - 1 do
   with PlaybackBufferMaker.Players[i]^ do
    begin
     Module_SetDelay;
     Module_SetPosition;
    end;
 PlaybackBufferMaker.InitForAllTypes;
 if not digsoundthread_start2(True) then
  begin
   RestoreControls;
   Exit;
  end;
 VisTimer.Enabled := True;
end;

procedure TMainForm.PlayFromPosExecute(Sender: TObject);
var
 CW: TChildForm;
begin
 if not GetCurrentWindow(CW) then
   Exit;
 if CW.VTMP^.Positions.Length <= 0 then
   Exit;
 if IsPlaying then
  begin
   digsoundthread_stop;
   RestoreControls;
  end;
 PlayMode := PMPlayModule;
 DisableControls(True);
 CW.Tracks.AbortSelection;
 CW.RerollToLine;
 if not digsoundthread_start2(True) then
  begin
   RestoreControls;
   Exit;
  end;
 VisTimer.Enabled := True;
end;

procedure TMainForm.PlayPatExecute(Sender: TObject);
var
 CW: TChildForm;
begin
 //todo если pattern совпадает с выделенной позицией, сделать reroll (можно с учётом TSWindow как в VT 2.6)
 if not GetCurrentWindow(CW) then
   Exit;
 if IsPlaying then
  begin
   digsoundthread_stop;
   RestoreControls;
  end;
 PlayMode := PMPlayPattern;
 DisableControls;
 with CW, VTMP^ do
  begin
   ValidatePattern2(PatNum);
   Tracks.AbortSelection;
   with PlaybackBufferMaker.Players[0]^ do
    begin
     Module_SetDelay;
     CurrentPosition := -1;
     Module_SetPattern(PatNum);
    end;
  end;
 PlaybackBufferMaker.InitForAllTypes;
 if not digsoundthread_start2(True) then
  begin
   RestoreControls;
   Exit;
  end;
 VisTimer.Enabled := True;
end;

procedure TMainForm.PlayPatFromLineExecute(Sender: TObject);
var
 CW: TChildForm;
begin
 //todo если pattern совпадает с выделенной позицией, сделать reroll (можно с учётом TSWindow как в VT 2.6)
 if not GetCurrentWindow(CW) then
   Exit;
 if IsPlaying then
  begin
   digsoundthread_stop;
   RestoreControls;
  end;
 CW.ValidatePattern2(CW.PatNum);
 CW.RestartPlayingPatternLine(False);
end;

procedure TMainForm.StopPlaying;
begin
 VisTimer.Enabled := False;
 digsoundthread_stop;
 RestoreControls;
end;

procedure TMainForm.Stop1Execute(Sender: TObject);
var
 CW: TChildForm;
begin
 if not IsPlaying then
   Exit;
 StopPlaying;
 if not GetCurrentWindow(CW) then
   Exit;
 if (CW = PlaybackWindow[0]) or ((Length(PlaybackBufferMaker.Players) > 1) and
   (CW = PlaybackWindow[1])) then
   if (CW.EditorPages.ActivePageIndex = 0) and CW.Tracks.CanSetFocus then
    begin
     CW.Tracks.ResetSelection;
     CW.Tracks.SetFocus;
    end;
end;

procedure TMainForm.SetLoopPosExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
  begin
   if (SGPositions.Col < VTMP^.Positions.Length) and
     (SGPositions.Col <> VTMP^.Positions.Loop) then
     SetLoopPos(SGPositions.Col);
   InputPNumber := 0;
  end;
end;

procedure TMainForm.SetLoopPosUpdate(Sender: TObject);
begin
 SetLoopPos.Enabled := ActiveChildExists and ActiveChild.SGPositions.Focused and
   (ActiveChild.VTMP^.Positions.Length > ActiveChild.SGPositions.Col);
end;

procedure TMainForm.AddPositionsExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 if (ActiveChild.IsPlayingWindow >= 0) and (PlayMode <> PMPlayLine) then
   Exit;
 if ActiveChild.VTMP^.Positions.Length > ActiveChild.SGPositions.Col then
   //selected used part of position list, just insert new positions
   ActiveChild.InsertPositions(0)
 else
   //selected empty cell, fill positions till it
   ActiveChild.FillPositions;
end;

procedure TMainForm.AddPositionsUpdate(Sender: TObject);
begin
 AddPositions.Enabled := ActiveChildExists and
   ((ActiveChild.IsPlayingWindow < 0) or (PlayMode = PMPlayLine)) and
   ActiveChild.SGPositions.Focused and (ActiveChild.VTMP^.Positions.Length < 256);
end;

procedure TMainForm.DeletePositionsExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 if (ActiveChild.IsPlayingWindow >= 0) and (PlayMode <> PMPlayLine) then
   Exit;
 ActiveChild.DeletePositions;
end;

procedure TMainForm.CheckValidPositionsSelected(Sender: TObject);
begin
 (Sender as TAction).Enabled :=
   ActiveChildExists and ActiveChild.SGPositions.Focused and
   (ActiveChild.VTMP^.Positions.Length > ActiveChild.SGPositions.Col);
end;

procedure TMainForm.ToggleLoopingExecute(Sender: TObject);
begin
 LoopAllowed := not LoopAllowed;
 if LoopAllowed then
  begin
   LoopAllAllowed := False;
   ToggleLoopingAll.Checked := False;
  end;
 ToggleLooping.Checked := LoopAllowed;
end;

procedure TMainForm.ToggleLoopingAllExecute(Sender: TObject);
begin
 LoopAllAllowed := not LoopAllAllowed;
 if LoopAllAllowed then
  begin
   LoopAllowed := False;
   ToggleLooping.Checked := False;
  end;
 ToggleLoopingAll.Checked := LoopAllAllowed;
end;

function TMainForm.CanNotLoopAll: boolean;
begin
 Result := not LoopAllAllowed or //loop among windows not selected
   (Childs.Count > 2) or //can switch to next window
   ((Childs.Count = 2) and (TChildForm(Childs.Items[0]).TSWindow = nil)) or
   //non TS-pair, so can switch too
   (Childs.Count <= 0); //can't be, but... safety check
end;

procedure TMainForm.AddFileName(FN: string);
var
 i, j: integer;
 FN1: string;
begin
 FN1 := AnsiUpperCase(FN);
 for i := 0 to 4 do
   if AnsiUpperCase(RecentFiles[i]) = FN1 then
    begin
     for j := i to 4 do
       RecentFiles[j] := RecentFiles[j + 1];
     Break;
    end;
 for i := 4 downto 0 do
   RecentFiles[i + 1] := RecentFiles[i];
 RecentFiles[0] := FN;
 j := File1.IndexOf(RFile1);
 for i := 0 to 5 do
   if RecentFiles[i] <> '' then
    begin
     File1.Items[j + i].Caption :=
       IntToStr(i + 1) + ' ' + RecentFiles[i];
     File1.Items[j + i].Visible := True;
    end
   else
     File1.Items[j + i].Visible := False;
 File1.Items[j + 6].Visible := File1.Items[j].Visible;
end;

procedure TMainForm.OpenRecent(n: integer);
begin
 if (RecentFiles[n] <> '') and FileExists(RecentFiles[n]) then
  begin
   OpenDialogVTM.InitialDir := ExtractFilePath(RecentFiles[n]);
   OpenDialogVTM.FileName := RecentFiles[n];
   CreateChild(RecentFiles[n]);
  end;
end;

procedure TMainForm.RFileClick(Sender: TObject);
begin
 OpenRecent((Sender as TMenuItem).Tag);
end;

procedure TMainForm.digsoundfinalize(var Msg: TMessage);
var
 TS: TChildForm;
begin
 TS := PlaybackWindow[0];
 digsoundthread_free;
 //todo thread уже остановлен, а digsoundthread_free в начале "останавливает" опять
 RestoreControls;
 if LoopAllAllowed and (Childs.Count > 1) and (Childs.IndexOf(TS) >= 0) then
  begin
   Next(1, True);
   //check if active window is other (some modal dialog does not allow to focus next)
   if TS <> ActiveChild then
     Play1Execute(nil);
  end;
end;

procedure TMainForm.MidiInNote(var Msg: TMessage);
var
 CW: TChildForm;
 Key: word;
begin
 if not VTOptions.BgAllowMIDI and //work in background disabled in options
   not Application.Active then
   Exit;
 if not GetCurrentWindow(CW) then
   Exit;
 Key := Msg.lParam;
 with CW do
   if (Msg.wParam = NoteOff) or ((Msg.wParam = NoteOn) and (Hi(Key) = 0)) then
     //Note with velocity 0 (like in VT 2.6)
    begin
     Key := Key and $7F or $8000; //clear velocity and set Midi flag
     if (Self.WindowState <> wsMinimized) and //main window not minimized
       //      (WindowState <> wsMinimized) and //current child window not minimized
       (ActiveControl = Tracks) and
       //works even if application unfocused (useful for virtual midi keyboards running at same PC)
       Tracks.Enabled then //can be disabled if some modes playing
       TracksKeyUp(Self, Key, [])
     else if EditorPages.ActivePage = SamplesSheet then
       SampleTestLine.TestLineKeyUp(Self, Key, [])
     else if EditorPages.ActivePage = OrnamentsSheet then
       OrnamentTestLine.TestLineKeyUp(Self, Key, [])
     else
       PatternTestLine.TestLineKeyUp(Self, Key, []);
    end
   else //NoteOn
    begin
     Key := Key or $8000; //set Midi flag
     if (Self.WindowState <> wsMinimized) and
       //      (WindowState <> wsMinimized) and
       ((ActiveControl = Tracks) and Tracks.Enabled) or
       ((ActiveControl = Samples) and SBSamAsNotes.Down) or
       ((ActiveControl = Ornaments) and SBOrnAsNotes.Down) then
      begin
       if ActiveControl = Tracks then
         TracksKeyDown(Self, Key, [])
       else if ActiveControl = Samples then
         SamplesKeyDown(Self, Key, [])
       else
         OrnamentsKeyDown(Self, Key, []);
      end
     else if EditorPages.ActivePage = SamplesSheet then
       SampleTestLine.TestLineKeyDown(Self, Key, [])
     else if EditorPages.ActivePage = OrnamentsSheet then
       OrnamentTestLine.TestLineKeyDown(Self, Key, [])
     else
       PatternTestLine.TestLineKeyDown(Self, Key, []);
    end;
end;

procedure TMainForm.ConvToPSGMenuClick(Sender: TObject);
var
 CW: TChildForm;
begin
 if not GetCurrentWindow(CW) then
   Exit;

 if (CW.TSWindow <> nil) and (CW.WinNumber > CW.TSWindow.WinNumber) then
   //convert first if created earlier in TS-pair
   CW := CW.TSWindow;

 if not GetFileName(SaveDialogPSG, CW, nil, CW.TSWindow <> nil) then
   Exit;

 if CW.TSWindow = nil then
   VTM2PSG(SaveDialogPSG.FileName, CW.VTMP)
 else
  begin
   VTM2PSG(GetTSFileName(SaveDialogPSG.FileName, 1), CW.VTMP);
   VTM2PSG(GetTSFileName(SaveDialogPSG.FileName, 2), CW.TSWindow.VTMP);
  end;
end;

procedure TMainForm.MidiInTimerTimer(Sender: TObject);
begin
 ToggleMidiKbd.Checked := MidiIn_Ensure;
 if ToggleMidiKbd.Checked then
  begin
   ToggleMidiKbd.Tag := MidiIn_DevNum;
   if ToggleMidiKbd.Tag < 0 then //prevent "deadlock" when manually switching devices
     ToggleMidiKbd.Tag := 0;
  end;
 UpdateToggleMidiKbdHint;
end;

procedure TMainForm.OctaveActionExecute(Sender: TObject);
var
 o: integer;
begin
 if not ActiveChildExists then
   Exit;
 o := (Sender as TAction).Tag;
 with ActiveChild do
  begin
   UDOctave.Position := o;
   PatternTestLine.TestOct := o;
   UDSamOctave.Position := o;
   SampleTestLine.TestOct := o;
   UDOrnOctave.Position := o;
   OrnamentTestLine.TestOct := o;
  end;
end;

procedure TMainForm.StopAndRestart;
begin
 if not IsPlaying then
   Exit;
 if PlayMode <> PMPlayModule then
   Exit;
 digsoundloop_catch;
  try
   PlaybackWindow[0].RerollToLine;
   ResetPlaying;
  finally
   digsoundloop_release;
  end;
end;

procedure TMainForm.ToggleChipExecute(Sender: TObject);
begin
 if VTOptions.ChipType = AY_Chip then
  begin
   VTOptions.ChipType := YM_Chip;
   ToggleChip.Caption := 'YM';
  end
 else
  begin
   VTOptions.ChipType := AY_Chip;
   ToggleChip.Caption := 'AY';
  end;
 if VTOptions.ChannelsAllocation in [0..6] then
   SetChannelsAllocation(VTOptions.ChannelsAllocation)
 else
   PlaybackBufferMaker.Calculate_Level_Tables;
 StopAndRestart;
end;

procedure TMainForm.ToggleChanMode;
var
 i: integer;
begin
 for i := 0 to 6 do //no more than 7 items in carousel
  begin
   Inc(VTOptions.ChannelsAllocation);
   if VTOptions.ChannelsAllocation > 6 then
     VTOptions.ChannelsAllocation := 0;
   if (VTOptions.ChannelsAllocationCarousel and
     (1 shl VTOptions.ChannelsAllocation)) <> 0 then
     Break;
  end;
 SetChannelsAllocation(VTOptions.ChannelsAllocation);
end;

procedure TMainForm.ToggleChanAllocExecute(Sender: TObject);
begin
 ToggleChanMode;
 StopAndRestart;
end;

procedure TMainForm.FreePlayers(Keep: integer = -1);
var
 i: integer;
begin
 for i := Length(PlaybackBufferMaker.Players) - 1 downto 0 do
  begin
   if i = Keep then
     Break;
   with PlaybackWindow[i] do
     VTMP^.FreePlayer(PlaybackBufferMaker.Players[i]);
  end;
 SetLength(PlaybackBufferMaker.Players, Keep + 1);
end;

procedure TMainForm.DisableControls(CheckSecondWindow: boolean = False);
var
 i, NumberOfSoundChips: integer;
 CW: TChildForm;
begin
 if not GetCurrentWindow(CW) then
   Exit;
 OptionsDlg.PlayStarts;
 CW.PlayStarts;
 CW.BringToFrontBoth;
 CW.ScrollWorkspace;
 if CheckSecondWindow and (CW.TSWindow <> nil) and
   (CW.TSWindow.VTMP^.Positions.Length <> 0) then
  begin
   CW.TSWindow.PlayStarts;
   NumberOfSoundChips := 2;
  end
 else
   NumberOfSoundChips := 1;
 with PlaybackBufferMaker do
  begin
   SetLength(Players, NumberOfSoundChips);
   PlaybackWindow[0] := CW;
   if NumberOfSoundChips = 2 then
     PlaybackWindow[1] := CW.TSWindow;
   for i := 0 to NumberOfSoundChips - 1 do
     PlaybackWindow[i].VTMP^.NewPlayer(Players[i]);
  end;
end;

procedure TMainForm.RestoreControls;
var
 i: integer;
begin
 VisTimer.Enabled := False;
 OptionsDlg.PlayStops;
 for i := 0 to Length(PlaybackBufferMaker.Players) - 1 do
   with PlaybackWindow[i] do
    begin
     EdPat.Enabled := True;
     UDPat.Enabled := True;
     if PlayMode in [PMPlayModule, PMPlayPattern] then
       Tracks.CursorY := Tracks.N1OfLines;
     Tracks.Enabled := True;
     SBTS.Enabled := True;
    end;
 FreePlayers;
end;

procedure TMainForm.SetChannelsAllocation(CA: integer);
var
 i, c, p, n: integer;
 PrevAlloc: array[0..2] of integer;
begin
 VTOptions.ChannelsAllocation := CA;

 ToggleChanAlloc.Caption := Calculate_Channels_Allocation_Indexes;

 PlaybackBufferMaker.Calculate_Level_Tables;

 //update visualisation in tracks
 Move(ChanAlloc, PrevAlloc, SizeOf(PrevAlloc));
 case CA of
   2: begin
     ChanAlloc[0] := 0;
     ChanAlloc[1] := 2;
     ChanAlloc[2] := 1;
    end; //ACB
   3: begin
     ChanAlloc[0] := 1;
     ChanAlloc[1] := 0;
     ChanAlloc[2] := 2;
    end; //BAC
   4: begin
     ChanAlloc[0] := 1;
     ChanAlloc[1] := 2;
     ChanAlloc[2] := 0;
    end; //BCA
   5: begin
     ChanAlloc[0] := 2;
     ChanAlloc[1] := 0;
     ChanAlloc[2] := 1;
    end; //CAB
   6: begin
     ChanAlloc[0] := 2;
     ChanAlloc[1] := 1;
     ChanAlloc[2] := 0;
    end; //CBA
 else //all other show as ABC
  begin
   ChanAlloc[0] := 0;
   ChanAlloc[1] := 1;
   ChanAlloc[2] := 2;
  end;
  end;
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
    begin
     if Tracks.CursorX >= 8 then
      begin
       c := (Tracks.CursorX - 8) div 14;
       p := PrevAlloc[c];
       n := 0;
       while (n < 2) and (ChanAlloc[n] <> p) do Inc(n);
       Inc(Tracks.CursorX, (n - c) * 14);
      end;
     ResetChanAlloc;
    end;
end;

procedure SetDefault;
var
 IsPl: boolean;
begin
 IsPl := digsoundthread_active;
 Set_Player_Frq(Interrupt_FreqDef);
 if not IsPl then Set_Sample_Rate(SampleRateDef);
 Set_Chip_Frq(AY_FreqDef);
 if not IsPl then
  begin
   Set_Sample_Bit(SampleBitDef);
   Set_Stereo(NumOfChanDef);
   SetBuffers(BufLen_msDef, NumberOfBuffersDef);
   digsoundDevice := digsoundDeviceDef;
   digsoundDeviceName := digsoundDeviceNameDef;
  end;
 MainForm.SetChannelsAllocation(ChanAllocDef);
 VTOptions.ChipType := YM_Chip;
 SetFilter(True);
 PlaybackBufferMaker.Calculate_Level_Tables;
end;

procedure ResetPlaying;
begin
 digsound_reset;
 visualisation_reset;
end;

procedure CatchAndResetPlaying;
begin
 digsoundloop_catch;
 ResetPlaying;
end;

procedure TMainForm.SetIntFreqEx(f: integer);
var
 i: integer;
begin
 Set_Player_Frq(f);
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
     ReCalcTimes;
end;

procedure TMainForm.ToggleSamplesExecute(Sender: TObject);
begin
 ToglSams.Visible := not ToglSams.Visible;
end;

procedure TMainForm.TracksManagerExecute(Sender: TObject);
begin
 TrMng.Visible := not TrMng.Visible;
end;

procedure TMainForm.GlobalTranspositionExecute(Sender: TObject);
begin
 GlbTrans.Visible := not GlbTrans.Visible;
end;

procedure TMainForm.SetEmulatingChip(aChipType: TChipTypes);
begin
 VTOptions.ChipType := aChipType;
 if aChipType = AY_Chip then
   ToggleChip.Caption := 'AY'
 else
   ToggleChip.Caption := 'YM';
 PlaybackBufferMaker.Calculate_Level_Tables;
end;

procedure TMainForm.SaveOptions;

 procedure SaveDW(const Nm: string; const Vl: integer);
 begin
   OptionsWrite(Nm, IntToStr(Vl));
 end;

 procedure SaveStr(const Nm: string; const Vl: string);
 begin
   OptionsWrite(Nm, Vl);
 end;

 procedure SaveFont(const Nm: string; const Vl: TVTFont);
 begin
   SaveStr(Nm + 'FontName', Vl.Name);
   SaveDW(Nm + 'FontSize', Vl.Size);
   SaveDW(Nm + 'FontBold', Ord(Vl.Bold));
 end;

var
 i: integer;
 Act: TShortcutActions;
 s: string;
begin
 {$IFDEF Windows}
 SetPriority(0);
 {$ENDIF Windows}
 if OptionsInit(True) then
  try
   SaveDW('BufLen_ms', BufLen_ms);
   SaveDW('NumberOfBuffers', NumberOfBuffers);
   SaveDW('digsoundDevice', digsoundDevice);
   SaveStr('digsoundDeviceName', digsoundDeviceName);
   SaveDW('FeaturesLevel', FeaturesLevel);
   SaveDW('VortexModuleHeader', Ord(VortexModuleHeader));
   SaveDW('MaximizedChilds', Ord(MaximizedChilds));
   for i := 0 to 5 do
     SaveStr(PChar('Recent' + IntToStr(i)), RecentFiles[i]);
   i := 0;
   if LoopAllowed then
     i := 1
   else if LoopAllAllowed then
     i := 2;
   SaveDW('LoopMode', i);
   SaveDW('GlobalVolume', GlobalVolume);
   with VTOptions do
    begin
     SaveDW('ChannelsAllocation', ChannelsAllocation);
     SaveDW('ChannelsAllocationCarousel', ChannelsAllocationCarousel);
     SaveDW('ChipType', Ord(ChipType));
     SaveDW('AY_Freq', AY_Freq);
     SaveDW('Interrupt_Freq', Interrupt_Freq);
     SaveDW('SampleRate', SampleRate);
     SaveDW('SampleBit', SampleBit);
     SaveDW('NumberOfChannels', NumberOfChannels);
     SaveDW('Filter', Ord(FilterWant));
     SaveDW('TracksNOfLines', TracksNOfLines);
     SaveDW('NoteTable', NoteTable);
     SaveDW('AutoStepValue', AutoStepValue);
     SaveDW('DecTrLines', Ord(DecTrLines));
     SaveDW('DecNoise', Ord(DecNoise));
     SaveDW('EnvAsNote', Ord(EnvAsNote));
     SaveDW('RecalcEnv', Ord(RecalcEnv));
     SaveDW('BgAllowMIDI', Ord(BgAllowMIDI));
     SaveDW('SamAsNote', Ord(SamAsNote));
     SaveDW('OrnAsNote', Ord(OrnAsNote));
     SaveDW('TracksHint', Ord(TracksHint));
     SaveDW('SamHint', Ord(SamHint));
     SaveDW('OrnHint', Ord(OrnHint));
     SaveDW('SamOrnHLines', Ord(SamOrnHLines));
     SaveDW('NotWarnUndo', Ord(NotWarnUndo));
     SaveDW('LMBToDraw', Ord(LMBToDraw));
     SaveDW('DetectFeaturesLevel', Ord(DetectFeaturesLevel));
     SaveDW('DetectModuleHeader', Ord(DetectModuleHeader));
     {$IFDEF Windows}
     SaveDW('Priority', Priority);
     {$ENDIF Windows}
     SaveStr('Lang', Lang);
     SaveFont('Tracks', TracksFont);
     SaveFont('Samples', SamplesFont);
     SaveFont('Ornaments', OrnamentsFont);
     SaveFont('Tests', TestsFont);
     SaveDW('MidiKbd', Ord(MidiInTimer.Enabled));
     s := MidiIn_DevName;
     if s <> '' then
       SaveStr('MidiKbdName', s);
     SaveDW('MidiKbdVol', Ord(ToggleMidiVol.Checked));
     SaveStr('ModulesFolder', OpenDialogVTM.InitialDir);
     SaveStr('PatternsFolder', PatternsFolder);
     SaveStr('SamplesFolder', SamplesFolder);
     SaveStr('OrnamentsFolder', OrnamentsFolder);
    end;
   SaveDW('WindowMaximized', Ord(WindowState = wsMaximized));

   //Specially for Znahar
   if WindowState <> wsMaximized then
    begin
     SaveDW('WindowX', Left);
     SaveDW('WindowY', Top);
     SaveDW('WindowWidth', Width);
     SaveDW('WindowHeight', Height);
    end
   else
    begin
     SaveDW('WindowX', RestoredLeft);
     SaveDW('WindowY', RestoredTop);
     SaveDW('WindowWidth', RestoredWidth);
     SaveDW('WindowHeight', RestoredHeight);
    end;

   SaveDW('Filtering', Ord(IsFilt));
   SaveDW('FilterQ', Filt_M);
   with VTOptions do
    begin
     SaveDW('GlobalColorWorkspace', GlobalColorWorkspace);
     SaveDW('GlobalColorBgEmpty', GlobalColorBgEmpty);
     SaveDW('TracksColorBg', TracksColorBg);
     SaveDW('TracksColorTxt', TracksColorTxt);
     SaveDW('TracksColorBgHl', TracksColorBgHl);
     SaveDW('TracksColorBgHlMain', TracksColorBgHlMain);
     SaveDW('TracksColorBgBeyond', TracksColorBgBeyond);
     SaveDW('TracksColorTxtHlMain', TracksColorTxtHlMain);
     SaveDW('SamplesColorBg', SamplesColorBg);
     SaveDW('SamplesColorTxt', SamplesColorTxt);
     SaveDW('SamplesColorBgLp', SamplesColorBgLp);
     SaveDW('SamplesColorTxtLp', SamplesColorTxtLp);
     SaveDW('SamplesColorBgBeyond', SamplesColorBgBeyond);
     SaveDW('SamplesColorTxtBeyond', SamplesColorTxtBeyond);
     SaveDW('SamplesColorBgHl', SamplesColorBgHl);
     SaveDW('SamplesColorBgLpHl', SamplesColorBgLpHl);
     SaveDW('SamplesColorBgBeyondHl', SamplesColorBgBeyondHl);
     SaveDW('OrnamentsColorBg', OrnamentsColorBg);
     SaveDW('OrnamentsColorTxt', OrnamentsColorTxt);
     SaveDW('OrnamentsColorBgLp', OrnamentsColorBgLp);
     SaveDW('OrnamentsColorTxtLp', OrnamentsColorTxtLp);
     SaveDW('OrnamentsColorBgBeyond', OrnamentsColorBgBeyond);
     SaveDW('OrnamentsColorTxtBeyond', OrnamentsColorTxtBeyond);
     SaveDW('OrnamentsColorBgHl', OrnamentsColorBgHl);
     SaveDW('OrnamentsColorBgLpHl', OrnamentsColorBgLpHl);
     SaveDW('OrnamentsColorBgBeyondHl', OrnamentsColorBgBeyondHl);
     SaveDW('TestsColorBg', TestsColorBg);
     SaveDW('TestsColorTxt', TestsColorTxt);
    end;

   //specially for Znahar
   for i := 0 to 5 do
     SaveDW(PChar('ToolBar' + IntToStr(i)), Ord(PMToolBar.Items[i].Checked));

   //Shortcuts
   for Act := Low(TShortcutActions) to High(TShortcutActions) do
     SaveStr(GetEnumName(TypeInfo(TShortcutActions), Ord(Act)),
       ShortCutToTextRaw(CustomShortcuts[Act]){%H-});

   //Note keys
   for i := 1 to 255 do
    begin
     s := {%H-}ShortCutToTextRaw(i);
     if s = '' then
       Continue;
     s := StringReplace(s, '=', 'Equal', [rfReplaceAll]);
     SaveStr('NoteKey' + s, GetEnumName(TypeInfo(TNoteKeyCodes), NoteKeys[i]));
    end;

  finally
   OptionsDone;
  end;
end;

//for async call after all DoOnResize/DoOnChangeBounds events
procedure TMainForm.MaximizeAndCheckCommandLine(Data: PtrInt);
begin
 if Data <> 0 then
   WindowState := wsMaximized;
 CheckCommandLine;
end;

//LCL many times call DoOnResize/DoOnChangeBounds,
//so we need to skip all again before maximizing,
//and we need CheckCommandLine after maximizing too
//(to place opened modules on bigger workspac)
procedure TMainForm.EnqueueMaximize(Data: PtrInt);
begin
 Application.QueueAsyncCall(@MaximizeAndCheckCommandLine, Data);
end;

procedure TMainForm.ChildClosed(Data: PtrInt);
begin
 CalcSBs;
 if ({%H-}Pointer(Data) <> nil) and (Childs.IndexOf({%H-}Pointer(Data)) >= 0) then
   TChildForm(Data).SetForeground;
end;

procedure TMainForm.MaximizeChild(aChild: TChildForm);
var
 i: integer;
begin
 MaximizedChilds := True;
 MIMaximized.Checked := True;
 CalcSBs;
 if aChild = nil then
   Exit;
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).UpdateConstraints;
 aChild.Maximize;
 for i := 0 to Childs.Count - 1 do
   if (TChildForm(Childs.Items[i]) <> aChild) and
     (TChildForm(Childs.Items[i]) <> aChild.TSWindow) then
     TChildForm(Childs.Items[i]).Restore;
end;

procedure TMainForm.RestoreChilds;
var
 i: integer;
begin
 MaximizedChilds := False;
 MIRestore1.Visible := False;
 MIClose1.Visible := False;
 MIMaximized.Checked := False;
 for i := 0 to Childs.Count - 1 do
   TChildForm(Childs.Items[i]).Restore;
 CalcSBs;
end;

procedure TMainForm.TryOpenDocument(FN: string);
var
 p, e: string;
begin
 e := ExtractFileExt(FN);
 p := ExtractFilePath(GetProcessFileName) + 'Documentation' + PathDelim +
   ExtractFileName(FN);
 SetLength(p, Length(p) - Length(e));
 FN := p + '.' + OptionsDlg.Get_Language + e;
 if not FileExists(FN) then
   FN := p + e;
 if not OpenDocument(FN) then
   ShowMessage(Mes_CantOpen + ' ' + FN);
end;

procedure TMainForm.LoadOptions;

 function GetDW(const Nm: string; out Vl: integer): boolean;
 var
   s: string;
 begin
   Result := OptionsRead(Nm, s) and TryStrToInt(s, Vl);
 end;

 function GetStr(const Nm: string; out Vl: string): boolean;
 begin
   Result := OptionsRead(Nm, Vl);
 end;

 procedure GetFont(const Nm: string; var Vl: TVTFont);
 var
   s: string;
   v: integer;
 begin
   if GetStr(Nm + 'FontName', s) then
     Vl.Name := s;
   if GetDW(Nm + 'FontSize', v) then
     Vl.Size := v;
   if GetDW(Nm + 'FontBold', v) then
     Vl.Bold := v <> 0;
 end;

 procedure GetColor(const Nm: string; var Vl: TColor);
 var
   v: integer;
 begin
   if GetDW(Nm, v) then
     Vl := v;
 end;

 procedure GetInt(const Nm: string; var Vl: integer);
 var
   v: integer;
 begin
   if GetDW(Nm, v) then
     Vl := v;
 end;

 procedure GetBool(const Nm: string; var Vl: boolean);
 var
   v: integer;
 begin
   if GetDW(Nm, v) then
     Vl := v <> 0;
 end;

var
 s, n: string;
 i, v: integer;
 SzSet, PsSet: boolean;
 Act: TShortcutActions;
 NeedMaximizing: PtrInt;
begin
 NeedMaximizing := 0;
 if OptionsInit(False) then
  begin
   {$IFDEF Windows}
   if GetDW('Priority', v) then
     SetPriority(v);
   {$ENDIF Windows}
   GetInt('FeaturesLevel', FeaturesLevel);
   GetBool('VortexModuleHeader', VortexModuleHeader);

   GetBool('MaximizedChilds', MaximizedChilds);
   MIMaximized.Checked := MaximizedChilds;

   if GetDW('BufLen_ms', v) then
     if (v <> BufLen_ms) then
       SetBuffers(v, NumberOfBuffers);
   if GetDW('NumberOfBuffers', v) then
     if (v <> NumberOfBuffers) then
       SetBuffers(BufLen_ms, v);
   if GetDW('digsoundDevice', v) then
     if GetStr('digsoundDeviceName', s) then
       Set_WODevice(v, s);
   for i := 5 downto 0 do
     if GetStr(PChar('Recent' + IntToStr(i)), s) then
       AddFileName(s);
   if GetDW('LoopMode', v) then
     case v of
       1: ToggleLooping.Execute;
       2: ToggleLoopingAll.Execute
      end;
   if GetDW('GlobalVolume', v) then
     VolumeControl.SetVol(v);
   with VTOptions do
    begin
     if GetDW('ChipType', v) then
       if v in [1, 2] then
         SetEmulatingChip(TChipTypes(v));
     if GetDW('ChannelsAllocation', v) then
       if v <> ChannelsAllocation then
         SetChannelsAllocation(v);
     if GetDW('AY_Freq', v) then
       if v <> AY_Freq then
         Set_Chip_Frq(v);
     if GetDW('Interrupt_Freq', v) then
       if v <> Interrupt_Freq then
         SetIntFreqEx(v);
     if GetDW('SampleRate', v) then
       if v <> SampleRate then
         Set_Sample_Rate(v);
     if GetDW('SampleBit', v) then
       if v <> SampleBit then
         Set_Sample_Bit(v);
     if GetDW('NumberOfChannels', v) then
       if v <> NumberOfChannels then
         Set_Stereo(v);
     GetBool('DetectFeaturesLevel', DetectFeaturesLevel);
     GetBool('DetectModuleHeader', DetectModuleHeader);
     GetInt('ChannelsAllocationCarousel', ChannelsAllocationCarousel);
     GetInt('TracksNOfLines', TracksNOfLines);
     GetInt('NoteTable', NoteTable);
     GetInt('AutoStepValue', AutoStepValue);
     GetBool('DecTrLines', DecTrLines);
     GetBool('DecNoise', DecNoise);
     GetBool('EnvAsNote', EnvAsNote);
     GetBool('RecalcEnv', RecalcEnv);
     GetBool('BgAllowMIDI', BgAllowMIDI);
     GetBool('SamAsNote', SamAsNote);
     GetBool('OrnAsNote', OrnAsNote);
     GetBool('TracksHint', TracksHint);
     GetBool('SamHint', SamHint);
     GetBool('OrnHint', OrnHint);
     GetBool('SamOrnHLines', SamOrnHLines);
     GetBool('NotWarnUndo', NotWarnUndo);
     GetBool('LMBToDraw', LMBToDraw);
     GetFont('Tracks', TracksFont);
     GetFont('Samples', SamplesFont);
     GetFont('Ornaments', OrnamentsFont);
     GetFont('Tests', TestsFont);
     if GetDW('MidiKbd', v) then
       MidiInTimer.Enabled := v <> 0;
     if GetStr('MidiKbdName', s) then
       MidiIn_DevName(s);
     if GetDW('MidiKbdVol', v) then
       ToggleMidiVol.Checked := v <> 0;
     if GetStr('ModulesFolder', s) then
       OpenDialogVTM.InitialDir := s;
     if GetStr('PatternsFolder', s) then
       PatternsFolder := s;
     if GetStr('SamplesFolder', s) then
       SamplesFolder := s;
     if GetStr('OrnamentsFolder', s) then
       OrnamentsFolder := s;
     if GetStr('Lang', s) then
       Lang := s;
    end;

   //Specially for Znahar
   PsSet := False;
   SzSet := False; //flags if no set position and size
   if GetDW('WindowX', v) then
    begin
     Left := v;
     PsSet := True;
    end;
   if GetDW('WindowY', v) then
    begin
     Top := v;
     PsSet := True;
    end;
   if GetDW('WindowWidth', v) then
    begin
     Width := v;
     SzSet := True;
    end;
   if GetDW('WindowHeight', v) then
    begin
     Height := v;
     SzSet := True;
    end;
   if PsSet and not SzSet then
     Position := poDefaultSizeOnly //turn off auto pos
   else if not PsSet and SzSet then
     Position := poDefaultPosOnly //turn off auto size
   else if PsSet and SzSet then
     Position := poDesigned; //turn off auto pos and size
   if PsSet or SzSet then
     AdjustFormOnDesktop(Self); //check form visibility on desktop
   if (RestoredLeft <> Left) or (RestoredTop <> Top) then
     DoOnChangeBounds;
   //only one method to update read only RestoredLeft and RestoredTop
   if (RestoredWidth <> Width) or (RestoredHeight <> Height) then
     DoOnResize; //only one method to update read only RestoredWidth and RestoredHeight
   if GetDW('WindowMaximized', v) then
     if v <> 0 then
       NeedMaximizing := 1;

   if GetDW('Filter', v) then
     SetFilter(v <> 0);
   with VTOptions do
    begin
     GetColor('GlobalColorWorkspace', GlobalColorWorkspace);
     GetColor('GlobalColorBgEmpty', GlobalColorBgEmpty);
     GetColor('TracksColorBg', TracksColorBg);
     GetColor('TracksColorTxt', TracksColorTxt);
     GetColor('TracksColorBgHl', TracksColorBgHl);
     GetColor('TracksColorBgHlMain', TracksColorBgHlMain);
     GetColor('TracksColorBgBeyond', TracksColorBgBeyond);
     GetColor('TracksColorTxtHlMain', TracksColorTxtHlMain);
     GetColor('SamplesColorBg', SamplesColorBg);
     GetColor('SamplesColorTxt', SamplesColorTxt);
     GetColor('SamplesColorBgLp', SamplesColorBgLp);
     GetColor('SamplesColorTxtLp', SamplesColorTxtLp);
     GetColor('SamplesColorBgBeyond', SamplesColorBgBeyond);
     GetColor('SamplesColorTxtBeyond', SamplesColorTxtBeyond);
     GetColor('SamplesColorBgHl', SamplesColorBgHl);
     GetColor('SamplesColorBgLpHl', SamplesColorBgLpHl);
     GetColor('SamplesColorBgBeyondHl', SamplesColorBgBeyondHl);
     GetColor('OrnamentsColorBg', OrnamentsColorBg);
     GetColor('OrnamentsColorTxt', OrnamentsColorTxt);
     GetColor('OrnamentsColorBgLp', OrnamentsColorBgLp);
     GetColor('OrnamentsColorTxtLp', OrnamentsColorTxtLp);
     GetColor('OrnamentsColorBgBeyond', OrnamentsColorBgBeyond);
     GetColor('OrnamentsColorTxtBeyond', OrnamentsColorTxtBeyond);
     GetColor('OrnamentsColorBgHl', OrnamentsColorBgHl);
     GetColor('OrnamentsColorBgLpHl', OrnamentsColorBgLpHl);
     GetColor('OrnamentsColorBgBeyondHl', OrnamentsColorBgBeyondHl);
     GetColor('TestsColorBg', TestsColorBg);
     GetColor('TestsColorTxt', TestsColorTxt);
    end;

   //specially for Znahar
   for i := 0 to 5 do
     if GetDW(PChar('ToolBar' + IntToStr(i)), v) then
       SetBar(i, v <> 0);

   //Shortcuts
   for Act := Low(TShortcutActions) to High(TShortcutActions) do
     if GetStr(GetEnumName(TypeInfo(TShortcutActions), Ord(Act)), s) then
       CustomShortcuts[Act] := {%H-}TextToShortCutRaw(s);
   ShortcutsSort;

   //Note keys
   for i := 1 to 255 do
    begin
     n := {%H-}ShortCutToTextRaw(i);
     if n = '' then
       Continue;
     n := StringReplace(n, '=', 'Equal', [rfReplaceAll]);
     if GetStr('NoteKey' + n, s) then
      begin
       NoteKeys[i] := GetEnumValue(TypeInfo(TNoteKeyCodes), s);
       if NoteKeys[i] < 0 then //can be error if manually edited cfg-file
         NoteKeys[i] := 0;
      end;
    end;

   OptionsDone;
  end;
 //DoOnResize and DoOnChangeBounds work through QueueAsyncCall, but we need
 //to Maximize after them otherwise RestoredLeft/RestoredTop/
 //RestoredWidth/RestoredHeight will not be updated.
 //EnqueueMaximize also call CheckCommandLine, so we need it even if not maximized
 Application.QueueAsyncCall(@EnqueueMaximize, NeedMaximizing);
end;

procedure TMainForm.UpdateChildHints;
var
 i: integer;
begin
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
     UpdateHints;
end;

function TMainForm.CreateTwoKeysHintGeneral(key1, key2: TShortcutActions;
 Appendix: string; brackets: boolean = True): string;
var
 k1, k2, s: string;
begin
 if CustomShortcuts[key1] <> 0 then
   k1 := {%H-}ShortCutToText{Raw}(CustomShortcuts[key1])
 else
   k1 := '';
 if CustomShortcuts[key2] <> 0 then
   k2 := {%H-}ShortCutToText{Raw}(CustomShortcuts[key2])
 else
   k2 := '';
 if (k1 <> '') and (k2 <> '') then
   s := '/'
 else
   s := '';
 Result := k1 + s + k2;
 if Appendix <> '' then
   if Result <> '' then
     Result += ' ' + Mes_Or + ' ' + Appendix
   else
     Result := Appendix;
 if brackets and (Result <> '') then
   Result := ' (' + Result + ')';
end;

function TMainForm.CreateTwoKeysHint(key1, key2: TShortcutActions): string;
var
 k1, k2, b1, b2, o: string;
begin
 if CustomShortcuts[key2] <> 0 then
   k1 := {%H-}ShortCutToText(CustomShortcuts[key2]) + ' ' + Mes_HintWhenEdit
 else
   k1 := '';
 if CustomShortcuts[key1] <> 0 then
   k2 := {%H-}ShortCutToText(CustomShortcuts[key1])
 else
   k2 := '';
 if (k1 <> '') or (k2 <> '') then
  begin
   b1 := ' (';
   b2 := ')';
  end
 else
  begin
   b1 := '';
   b2 := '';
  end;
 if (k1 <> '') and (k2 <> '') then
   o := ' ' + Mes_Or + ' '
 else
   o := '';
 Result := b1 + k1 + o + k2 + b2;
end;

procedure TMainForm.SetTwoShortacts(Act: TAction; SC1, SC2: TShortcutActions);
begin
 with Act do
  begin
   ShortCut := CustomShortcuts[SC1];
   SecondaryShortCuts.Clear;
   if CustomShortcuts[SC2] <> 0 then
     SecondaryShortCuts.Add(ShortCutToText{Raw}(CustomShortcuts[SC2]){%H-});
  end;
end;

procedure TMainForm.SetMultiShortcuts;
begin
 SetTwoShortacts(FileClose1, SCA_FileClose, SCA_FileClose2);
 SetTwoShortacts(NextWindow1, SCA_WindowNext, SCA_WindowNext2);
 SetTwoShortacts(PreviousWindow1, SCA_WindowPrev, SCA_WindowPrev2);
end;

procedure TMainForm.SetGlobalShortcuts;
begin
 FileNew1.ShortCut := CustomShortcuts[SCA_FileNew];
 FileOpen1.ShortCut := CustomShortcuts[SCA_FileOpen];
 FileSave1.ShortCut := CustomShortcuts[SCA_FileSave];
 FileSaveAs1.ShortCut := CustomShortcuts[SCA_FileSaveAs];
 SaveSNDHMenu.ShortCut := CustomShortcuts[SCA_FileExportSNDH];
 SaveforZXMenu.ShortCut := CustomShortcuts[SCA_FileExportZX];
 ConvToPSGMenu.ShortCut := CustomShortcuts[SCA_FileExportPSG];
 ConvToWAVMenu.ShortCut := CustomShortcuts[SCA_FileExportWAV];
 Options1.ShortCut := CustomShortcuts[SCA_FileOptions];
 FileExit1.ShortCut := CustomShortcuts[SCA_FileExit];
 Stop1.ShortCut := CustomShortcuts[SCA_PlayStop];
 PlayFromPos.ShortCut := CustomShortcuts[SCA_PlayPlay];
 Play1.ShortCut := CustomShortcuts[SCA_PlayFromStart];
 PlayPatFromLine.ShortCut := CustomShortcuts[SCA_PlayPattern];
 PlayPat.ShortCut := CustomShortcuts[SCA_PlayPatternFromStart];
 ToggleLooping.ShortCut := CustomShortcuts[SCA_PlayToggleLoop];
 ToggleLoopingAll.ShortCut := CustomShortcuts[SCA_PlayToggleLoopAll];
 ToggleSamples.ShortCut := CustomShortcuts[SCA_PlayToggleSamples];
 Undo.ShortCut := CustomShortcuts[SCA_EditUndo];
 Redo.ShortCut := CustomShortcuts[SCA_EditRedo];
 EditCut1.ShortCut := CustomShortcuts[SCA_EditCut];
 EditCopy1.ShortCut := CustomShortcuts[SCA_EditCopy];
 EditPaste1.ShortCut := CustomShortcuts[SCA_EditPaste];
 TracksManager.ShortCut := CustomShortcuts[SCA_EditTracksManager];
 GlobalTransposition.ShortCut := CustomShortcuts[SCA_EditGlobalTransposition];
 WindowCascade1.ShortCut := CustomShortcuts[SCA_WindowCascade];
 WindowTileHorizontal1.ShortCut := CustomShortcuts[SCA_WindowTileH];
 WindowTileVertical1.ShortCut := CustomShortcuts[SCA_WindowTileV];
 MIMaximized.ShortCut := CustomShortcuts[SCA_WindowMaximized];
 //WindowMinimizeAll1.ShortCut:=CustomShortcuts[SCA_WindowMinAll];
 //WindowArrangeAll1.ShortCut:=CustomShortcuts[SCA_WindowArrAll];
 FindWindow1.ShortCut := CustomShortcuts[SCA_WindowFind];

 CloseAll1.ShortCut := CustomShortcuts[SCA_WindowCloseAll];
 HelpAbout1.ShortCut := CustomShortcuts[SCA_HelpAbout];
 MIQuickGuide.ShortCut := CustomShortcuts[SCA_HelpGuide];
 MIManual.ShortCut := CustomShortcuts[SCA_HelpManual];
 ToggleChip.ShortCut := CustomShortcuts[SCA_ChipType];
 ToggleChanAlloc.ShortCut := CustomShortcuts[SCA_ChipChans];

 ToggleMidiKbd.ShortCut := CustomShortcuts[SCA_MidiToggle];
 ToggleMidiVol.ShortCut := CustomShortcuts[SCA_MidiVolume];

 VolumeUp.ShortCut := CustomShortcuts[SCA_VolumeUp];
 VolumeDown.ShortCut := CustomShortcuts[SCA_VolumeDown];
 VolumeControl.Hint := Mes_HintVolCtrl + CreateTwoKeysHintGeneral(
   SCA_VolumeUp, SCA_VolumeDown, Mes_HintMouseWheel);

 AutoStep.ShortCut := CustomShortcuts[SCA_EditorAutoStep];
 AutoStep.Hint := Mes_HintTglAutStp + CreateTwoKeysHint(
   SCA_EditorAutoStep, SCA_PatternAutoStep);

 AutoEnv.ShortCut := CustomShortcuts[SCA_EditorAutoEnv];
 AutoEnv.Hint := Mes_HintTglAutEnv + CreateTwoKeysHint(SCA_EditorAutoEnv,
   SCA_PatternAutoEnv);

 AutoEnvStd.ShortCut := CustomShortcuts[SCA_EditorAutoEnvStd];

 AutoPrms.ShortCut := CustomShortcuts[SCA_EditorAutoPrms];
 AutoPrms.Hint := Mes_HintTglPrm + CreateTwoKeysHint(SCA_EditorAutoPrms,
   SCA_PatternAutoPrms);

 Octave1.ShortCut := CustomShortcuts[SCA_Octave1];
 Octave2.ShortCut := CustomShortcuts[SCA_Octave2];
 Octave3.ShortCut := CustomShortcuts[SCA_Octave3];
 Octave4.ShortCut := CustomShortcuts[SCA_Octave4];
 Octave5.ShortCut := CustomShortcuts[SCA_Octave5];
 Octave6.ShortCut := CustomShortcuts[SCA_Octave6];
 Octave7.ShortCut := CustomShortcuts[SCA_Octave7];
 Octave8.ShortCut := CustomShortcuts[SCA_Octave8];

 SetLoopPos.ShortCut := CustomShortcuts[SCA_PosListSetLoop];
 AddPositions.ShortCut := CustomShortcuts[SCA_PosListAdd];
 DuplicatePositions.ShortCut := CustomShortcuts[SCA_PosListDup];
 ClonePositions.ShortCut := CustomShortcuts[SCA_PosListClone];
 DeletePositions.ShortCut := CustomShortcuts[SCA_PosListDelete];
 ChangePatLen.ShortCut := CustomShortcuts[SCA_PosListPatLens];
 RenumPats.ShortCut := CustomShortcuts[SCA_PosListRenumPats];

 Merge1.ShortCut := CustomShortcuts[SCA_PatternMerge];
 MITracksSelectAll.ShortCut := CustomShortcuts[SCA_PatternSelectAll];
 MergePositions.ShortCut := CustomShortcuts[SCA_PosListMerge];
 MIPosSelectAll.ShortCut := CustomShortcuts[SCA_PosListSelectAll];

 TransposeUp1.ShortCut := CustomShortcuts[SCA_PatternTransposeUp1];
 TransposeDown1.ShortCut := CustomShortcuts[SCA_PatternTransposeDown1];
 TransposeUp3.ShortCut := CustomShortcuts[SCA_PatternTransposeUp3];
 TransposeDown3.ShortCut := CustomShortcuts[SCA_PatternTransposeDown3];
 TransposeUp5.ShortCut := CustomShortcuts[SCA_PatternTransposeUp5];
 TransposeDown5.ShortCut := CustomShortcuts[SCA_PatternTransposeDown5];
 TransposeUp12.ShortCut := CustomShortcuts[SCA_PatternTransposeUp12];
 TransposeDown12.ShortCut := CustomShortcuts[SCA_PatternTransposeDown12];
 PatJmp0.ShortCut := CustomShortcuts[SCA_PatternJumpQuarter1];
 PatJmp1.ShortCut := CustomShortcuts[SCA_PatternJumpQuarter2];
 PatJmp2.ShortCut := CustomShortcuts[SCA_PatternJumpQuarter3];
 PatJmp3.ShortCut := CustomShortcuts[SCA_PatternJumpQuarter4];
 SwapChansLeft.ShortCut := CustomShortcuts[SCA_PatternSwapLeft];
 SwapChansRight.ShortCut := CustomShortcuts[SCA_PatternSwapRight];
 ExpandTwice1.ShortCut := CustomShortcuts[SCA_PatternExpand];
 ShrinkTwice1.ShortCut := CustomShortcuts[SCA_PatternShrink];
 SplitPattern1.ShortCut := CustomShortcuts[SCA_PatternSplit];
 PackPattern1.ShortCut := CustomShortcuts[SCA_PatternPack];

 SetMultiShortcuts;

 UpdateChildHints;
end;

procedure TMainForm.RaiseGlobalShortcutActions(var Key: word; Shift: TShiftState);
var
 i: integer;
 sc: TShortCut;
 AtLeastOne: boolean;
begin
 AtLeastOne := False; //allow several actions to fire
 sc := KeyToShortCut(Key, Shift);
 for i := 0 to ActionList1.ActionCount - 1 do
   with ActionList1.Actions[i] as TAction do
     if Enabled and (ShortCut = sc) then
      begin
       Execute;
       AtLeastOne := True;
      end;
 if AtLeastOne then
   Key := 0;
end;

procedure TMainForm.CheckSGKeysAndActionsConflicts(var Key: word;
 Shift: TShiftState; OneRow: boolean = False);
begin
 //TCustomStringGrid use Esc to hide editor (even if no editor used)
 if (Key = VK_ESCAPE) and (Shift = []) or
   //One row grids reselect same cell on Up/Down (no need such behaviour)
   //Also we no need any cursor control except left/right
   (OneRow and (Key in [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT, VK_HOME, VK_END])) then
   RaiseGlobalShortcutActions(Key, Shift);
end;

procedure TMainForm.CheckKeysAndActionsConflicts(var Key: word;
 Shift: TShiftState; Keys: TSetOfByte);
begin
 if Key in Keys then
  begin
   RaiseGlobalShortcutActions(Key, Shift);
   Key := 0;
  end;
end;

procedure CheckExtSNDH;
var
 s: string;
begin
 with MainForm.SaveDialogSNDH do
  begin
   s := LowerCase(ExtractFileExt(FileName));
   if s = '.snd' then
     FileName := FileName + 'h'
   else if s <> '.sndh' then
     FileName := FileName + '.sndh';
  end;
end;

procedure TMainForm.SaveSNDHMenuClick(Sender: TObject);
var
 rslt: TICEPackerResult;

 procedure SaveResult(const Buf);
 var
   f: file;
 begin
   AssignFile(f, SaveDialogSNDH.FileName);
   Rewrite(f, 1);
    try
     BlockWrite(f, Buf, rslt.ArchiveSize);
    finally;
     CloseFile(f);
    end;
 end;

const
 TITL: array[0..3] of char = 'TITL';
 COMM: array[0..3] of char = 'COMM';
 CONV: array[0..3] of char = 'CONV';
 YEAR: array[0..3] of char = 'YEAR';
 TIME: array[0..3] of char = 'TIME';
var
 sndhplsz, sndhhdrsz: integer;
 Size, i, j: integer;
 w: word;
 CurrentWindow: TChildForm;
 s: string;
 rs: TResourceStream;
 ms: TMemoryStream;
 packedbuf: array of byte;
begin
 if not GetCurrentWindow(CurrentWindow) then
   Exit;

 if ExpSNDHDlg.ShowModal <> mrOk then
   Exit;

 if not GetFileName(SaveDialogSNDH, CurrentWindow, @CheckExtSNDH) then
   Exit;

 rs := TResourceStream.Create(HInstance, 'SNDHPLAYER', 'SNDH');
  try
   sndhplsz := rs.Size;

   ms := TMemoryStream.Create;
    try
     //set the maximum possible size
     ms.Size := sndhplsz + //empty header and player
       5 * 4 + 2 + //5 long and 1 short tag
       33 * 2 + //2 NT-strings for title and author
       Length(FullVersString) + 1 + //info about converter
       +5 + //NT-string for year
       +5 + //NT-string for player frequency
       +2 + //time length
       +1 + //1 byte for EVEN
       +65536 + //PT3 max size
       +256; //failsafe reserve

     ms.CopyFrom(rs, 16);

     sndhhdrsz := 10; //minimal size of required tags
     with CurrentWindow do
      begin
       i := Length(VTMP^.Title);
       if i <> 0 then
        begin
         Inc(sndhhdrsz, 4 + i + 1);
         ms.WriteBuffer(TITL, 4);
         ms.WriteBuffer(VTMP^.Title[1], i + 1);
        end;
       i := Length(VTMP^.Author);
       if i <> 0 then
        begin
         Inc(sndhhdrsz, 4 + i + 1);
         ms.WriteBuffer(COMM, 4);
         ms.WriteBuffer(VTMP^.Author[1], i + 1);
        end;
       ms.WriteBuffer(CONV, 4);
       i := Length(FullVersString) + 1;
       Inc(sndhhdrsz, i);
       ms.WriteBuffer(FullVersString[1], i);
       if ExpSNDHYear <> 0 then
        begin
         s := IntToStr(ExpSNDHYear);
         i := Length(s);
         Inc(sndhhdrsz, i + 5);
         ms.WriteBuffer(YEAR, 4);
         ms.WriteBuffer(s[1], i + 1);
        end;
       j := round(VTOptions.Interrupt_Freq / 1000);
       s := 'TC' + IntToStr(j);
       i := Length(s) + 1;
       Inc(sndhhdrsz, i);
       ms.WriteBuffer(s[1], i);
       ms.WriteBuffer(TIME, 4);
       i := round(TotInts / j);
       if i > 65535 then i := 65535;
       ms.WriteWord(SwapW(i));
       if (sndhhdrsz and 1) <> 0 then //EVEN due sndhv21.txt
        begin
         Inc(sndhhdrsz);
         i := 0;
         ms.WriteByte(i);
        end;
       ms.CopyFrom(rs, sndhplsz - 16);
       if not VTM2PT3(ms.Memory + ms.Position, CurrentWindow.VTMP, Size) then
        begin
         Application.MessageBox(pansichar(Mes_CantCompileTooBig),
           pansichar(SaveDialogSNDH.FileName));
         Exit;
        end;
      end;
     rslt.ArchiveSize := ms.Position + Size; //unpacked size
     i := -2;
     for j := 0 to 2 do
      begin
       Inc(i, 4);
       rs.Seek(i, soBeginning);
       w := Swap(rs.ReadWord);
       Inc(w, sndhhdrsz);
       ms.Seek(2 + j * 4, soBeginning);
       ms.WriteWord(Swap(w));
      end;
     if ExpSNDHDlg.CBNonPacked.Checked then
       SaveResult(ms.Memory^)
     else
      begin
       SetLength(packedbuf, rslt.ArchiveSize * 2 + 12); //twice + ICE-header
       rslt := ice_packer(@packedbuf[0], Length(packedbuf), ms.Memory,
         rslt.ArchiveSize);
       if rslt.ArchiveSize <= 12 then //only header or error
        begin
         s := Mes_IceErr + ': ';
         case rslt.ErrorCode of
           ICE_NOERROR: s += Mes_IceErrEmpty;
           ICE_UNPACKABLETOOLONG: s += Mes_IceErrUnpkbl + ' ' +
               rslt.ErrorPos.ToString + '.';
           ICE_NOROOM: s += Mes_IceErrBufSmall + ' ' + rslt.ErrorPos.ToString + '.';
          end;
         ShowMessage(s);
        end
       else
         SaveResult(packedbuf[0]);
      end;
    finally
     ms.Free;
    end;
  finally
   rs.Free;
  end;
end;

procedure CheckExtZXAY;
begin
 with MainForm, SaveDialogZXAY do
   FileName := ChangeFileExt(FileName, '.' + GetZXAYFileExt);
end;

procedure TMainForm.SaveforZXMenuClick(Sender: TObject);
var
 s: string;
 PT3_1, PT3_2: TSpeccyModule;
 i, t, j, k: integer;
 rs: TResourceStream;
 fs: TFileStream;
 pl: array of byte;
 hobetahdr: packed record
   case boolean of
     False: (Name: array[0..7] of char;
       Typ: char;
       Start, Leng, SectLeng, CheckSum: word);
     True: (Ind: array[0..16] of byte);
    end;
 SCLHdr: packed record
   case boolean of
     False: (SCL: array[0..7] of char;
       NBlk: byte;
       Name1: array[0..7] of char;
       Typ1: char;
       Start1, Leng1: word;
       Sect1: byte;
       Name2: array[0..7] of char;
       Typ2: char;
       Start2, Leng2: word;
       Sect2: byte;);
     True: (Ind: array[0..36] of byte);
    end;
 TAPHdr: packed record
   case boolean of
     False: (Sz: word;
       Flag, Typ: byte;
       Name: array[0..9] of char;
       Leng, Start, Trash: word;
       Sum: byte);
     True: (Ind: array[0..20] of byte);
    end;
 AYFileHeader: TAYFileHeader;
 SongStructure: TSongStructure;
 AYSongData: TSongData;
 AYPoints: TPoints;
 CW: TChildForm;
begin
 if not GetCurrentWindow(CW) then
   Exit;

 if (CW.TSWindow <> nil) and (CW.WinNumber > CW.TSWindow.WinNumber) then
   //save first if created earlier in TS-pair
   CW := CW.TSWindow;

 if not VTM2PT3(@PT3_1, CW.VTMP, ZXModSize1) then
  begin
   Application.MessageBox(pansichar(Mes_CantCompileTooBig), pansichar(CW.Caption));
   Exit;
  end;
 ZXModSize2 := 0;
 if (CW.TSWindow <> nil) and not VTM2PT3(@PT3_2, CW.TSWindow.VTMP, ZXModSize2) then
  begin
   Application.MessageBox(pansichar(Mes_CantCompileTooBig), pansichar(
     CW.TSWindow.Caption));
   Exit;
  end;

 if CW.TSWindow = nil then
   rs := TResourceStream.Create(HInstance, 'ZXAYPLAYER', 'ZXAY')
 else
   rs := TResourceStream.Create(HInstance, 'ZXTSPLAYER', 'ZXTS');
  try
   zxplsz := rs.ReadWord;
   zxdtsz := rs.ReadWord;

   if ExpDlg.ShowModal <> mrOk then
     Exit;

   SaveDialogZXAY.FilterIndex := ExpDlg.RadioGroup1.ItemIndex + 1;
   SaveDialogZXAY.DefaultExt := GetZXAYFileExt;

   if not GetFileName(SaveDialogZXAY, CW, @CheckExtZXAY) then
     Exit;

   if SaveDialogZXAY.FilterIndex in [1..5] then
     ExpDlg.RadioGroup1.ItemIndex := SaveDialogZXAY.FilterIndex - 1;

   t := ExpDlg.RadioGroup1.ItemIndex;
   if t <> 1 then
    begin
     if ZXModSize1 + ZXModSize2 + zxplsz + zxdtsz > 65536 then
      begin
       Application.MessageBox(pansichar(Mes_SizeTooBig), pansichar(Mes_CantExport));
       Exit;
      end;
     SetLength(pl, zxplsz);
     rs.ReadBuffer(pl[0], zxplsz);
     repeat
       i := rs.ReadWord;
       if i >= zxplsz - 1 then
         break;
       Inc(PWord(@pl[i])^, ZXCompAddr);
     until False;
     repeat
       i := rs.ReadWord;
       if i >= zxplsz then
         break;
       Inc(pbyte(@pl[i])^, ZXCompAddr);
     until False;
     repeat
       i := rs.ReadWord;
       if i >= zxplsz then
         break;
       pbyte(@pl[i])^ := (rs.ReadWord + ZXCompAddr) shr 8;
     until False;
     if ExpDlg.LoopChk.Checked then pl[10] := pl[10] or 1;
    end;
  finally
   rs.Free;
  end;
 fs := TFileStream.Create(SaveDialogZXAY.FileName, fmCreate);
  try
   i := ZXModSize1;
   case t of
     0, 1:
      begin
       Inc(i, ZXModSize2);
       if t = 0 then
         Inc(i, zxplsz + zxdtsz)
       else if CW.TSWindow <> nil then
         Inc(i, SizeOf(TSData));
       with hobetahdr do
        begin
         Name := '        ';
         s := ExtractFileName(SaveDialogZXAY.FileName);
         j := Length(s) - 3;
         if j > 8 then j := 8;
         if j > 0 then Move(s[1], Name, j);
         if t = 0 then
           Typ := 'C'
         else
           Typ := 'm';
         Start := ZXCompAddr;
         Leng := i;
         SectLeng := i and $FF00;
         if i and 255 <> 0 then Inc(SectLeng, $100);
         if SectLeng = 0 then
          begin
           Application.MessageBox(pansichar(Mes_HobetaSizeTooBig),
             pansichar(Mes_CantExport));
           Exit;
          end;
         k := 0;
         for j := 0 to 14 do
           Inc(k, Ind[j]);
         CheckSum := k * 257 + 105;
        end;
       fs.WriteBuffer(hobetahdr, sizeof(hobetahdr));
      end;
     2:
      begin
       with AYFileHeader do
        begin
         FileID := $5941585A;
         TypeID := $4C554D45;
         FileVersion := 0;
         PlayerVersion := 0;
         PSpecialPlayer := 0;
         j := 8 + SizeOf(TSongStructure) + SizeOf(TSongData) +
           SizeOf(TPoints) + Length(CW.VTMP^.Title) + 1;
         PAuthor := SwapW(j);
         Inc(j, Length(CW.VTMP^.Author) + 1 - 2);
         PMisc := SwapW(j);
         NumOfSongs := 0;
         FirstSong := 0;
         PSongsStructure := $200;
        end;
       fs.WriteBuffer(AYFileHeader, SizeOf(TAYFileHeader));
       with SongStructure do
        begin
         PSongName := SwapW(4 + SizeOf(TSongData) + SizeOf(TPoints));
         PSongData := $200;
        end;
       fs.WriteBuffer(SongStructure, SizeOf(TSongStructure));

       with AYSongData do
        begin
         ChanA := 0;
         ChanB := 1;
         ChanC := 2;
         Noise := 3;
         j := CW.TotInts;
         if (CW.TSWindow <> nil) and (CW.TSWindow.TotInts > j) then
           j := CW.TSWindow.TotInts;
         if j > 65535 then SongLength := 65535
         else
           SongLength := SwapW(j);
         FadeLength := 0;
         if CW.TSWindow = nil then
          begin
           HiReg := 0;
           LoReg := 0;
          end
         else
          begin
           j := ZXCompAddr + zxplsz + zxdtsz + ZXModSize1;
           HiReg := j shr 8;
           LoReg := j;
          end;
         PPoints := $400;
         PAddresses := $800;
        end;
       fs.WriteBuffer(AYSongData, SizeOf(TSongData));
       with AYPoints do
        begin
         Stek := SwapW(ZXCompAddr);
         Init := SwapW(ZXCompAddr);
         Inter := SwapW(ZXCompAddr + 5);
         Adr1 := SwapW(ZXCompAddr);
         Len1 := Swap(zxplsz);
         j := 10 + Length(CW.VTMP^.Title) + Length(CW.VTMP^.Author) +
           Length(FullVersString) + 3;
         Offs1 := SwapW(j);
         Adr2 := SwapW(ZXCompAddr + zxplsz + zxdtsz);
         Len2 := SwapW(ZXModSize1 + ZXModSize2);
         Offs2 := SwapW(j - 6 + zxplsz);
         Zero := 0;
        end;
       fs.WriteBuffer(AYPoints, SizeOf(TPoints));
       j := Length(CW.VTMP^.Title);
       if j <> 0 then
         fs.WriteBuffer(CW.VTMP^.Title[1], j + 1)
       else
         fs.WriteByte(j);
       j := Length(CW.VTMP^.Author);
       if j <> 0 then
         fs.WriteBuffer(CW.VTMP^.Author[1], j + 1)
       else
         fs.WriteByte(j);
       fs.WriteBuffer(FullVersString[1], Length(FullVersString) + 1);
      end;
     3:
      begin
       with SCLHdr do
        begin
         SCL := 'SINCLAIR';
         NBlk := 2;
         if CW.TSWindow <> nil then
           Name1 := 'tsplayer'
         else
           Name1 := 'vtplayer';
         Typ1 := 'C';
         Start1 := ZXCompAddr;
         Leng1 := zxplsz;
         Sect1 := zxplsz shr 8;
         if zxplsz and 255 <> 0 then Inc(Sect1);
         Name2 := '        ';
         s := ExtractFileName(SaveDialogZXAY.FileName);
         j := Length(s) - 4;
         if j > 8 then j := 8;
         if j > 0 then Move(s[1], Name2, j);
         Typ2 := 'C';
         Start2 := ZXCompAddr + zxplsz + zxdtsz;
         Leng2 := ZXModSize1 + ZXModSize2;
         Sect2 := Leng2 shr 8;
         if Leng2 and 255 <> 0 then Inc(Sect2);
         k := 0;
         for j := 0 to sizeof(SCLHdr) - 1 do Inc(k, Ind[j]);
        end;
       fs.WriteBuffer(SCLHdr, sizeof(SCLHdr));
       for j := 0 to zxplsz - 1 do Inc(k, pl[j]);
       for j := 0 to ZXModSize1 - 1 do Inc(k, PT3_1.Index[j]);
       if CW.TSWindow <> nil then
         for j := 0 to ZXModSize2 - 1 do Inc(k, PT3_2.Index[j]);
      end;
     4:
      begin
       with TAPHdr do
        begin
         Sz := 19;
         Flag := 0;
         Typ := 3;
         if CW.TSWindow <> nil then
           Name := 'tsplayer  '
         else
           Name := 'vtplayer  ';
         Leng := zxplsz;
         Start := ZXCompAddr;
         Trash := 32768;
         k := 0;
         for j := 2 to 19 do k := k xor Ind[j];
         Sum := k;
         fs.WriteBuffer(TAPHdr, 21);
         Sz := 2 + zxplsz;
         Flag := 255;
        end;
       fs.WriteBuffer(TAPHdr, 3);
      end;
    end;
   if t <> 1 then
     fs.WriteBuffer(pl[0], zxplsz);
   case t of
     4:
      begin
       with TAPHdr do
        begin
         k := 255;
         for j := 0 to zxplsz - 1 do k := k xor pl[j];
         fs.WriteByte(k);
         Sz := 19;
         Flag := 0;
         Typ := 3;
         Name := '          ';
         Leng := ZXModSize1 + ZXModSize2;
         Start := ZXCompAddr + zxplsz + zxdtsz;
         Trash := 32768;
         s := ExtractFileName(SaveDialogZXAY.FileName);
         j := Length(s) - 4;
         if j > 10 then j := 10;
         if j > 0 then Move(s[1], Name, j);
         k := 0;
         for j := 2 to 19 do k := k xor Ind[j];
         Sum := k;
         fs.WriteBuffer(TAPHdr, 21);
         Sz := 2 + ZXModSize1 + ZXModSize2;
         Flag := 255;
        end;
       fs.WriteBuffer(TAPHdr, 3);
      end;
     3:
      begin
       j := zxplsz mod 256;
       if j <> 0 then
        begin
         j := 256 - j;
         FillChar(pl[0], j, 0);
         fs.WriteBuffer(pl[0], j);
        end;
      end;
     0:
      begin
       if zxdtsz > zxplsz then SetLength(pl, zxdtsz);
       FillChar(pl[0], zxdtsz, 0);
       fs.WriteBuffer(pl[0], zxdtsz);
      end;
    end;
   fs.WriteBuffer(PT3_1, ZXModSize1);
   if CW.TSWindow <> nil then
     fs.WriteBuffer(PT3_2, ZXModSize2);
   case t of
     4:
      begin
       k := 255;
       for j := 0 to ZXModSize1 - 1 do k := k xor PT3_1.Index[j];
       if CW.TSWindow <> nil then
         for j := 0 to ZXModSize2 - 1 do k := k xor PT3_2.Index[j];
       fs.WriteByte(k);
      end;
     3:
      begin
       j := (ZXModSize1 + ZXModSize2) mod 256;
       if j <> 0 then
        begin
         j := 256 - j;
         FillChar(pl[0], j, 0);
         fs.WriteBuffer(pl[0], j);
        end;
       fs.WriteDWord(k);
      end;
     0..1:
      begin
       if (t = 1) and (CW.TSWindow <> nil) then
        begin
         TSData.Size1 := ZXModSize1;
         TSData.Size2 := ZXModSize2;
         fs.WriteBuffer(TSData, SizeOf(TSData));
        end;
       with hobetahdr do
         if SectLeng <> i then
          begin
           FillChar(PT3_1, SectLeng - i, 0);
           fs.WriteBuffer(PT3_1, SectLeng - i);
          end;
      end;
    end;
  finally
   fs.Free;
  end;
end;

function TMainForm.GetZXAYFileExt: string;
var
 i: integer;
begin
 i := SaveDialogZXAY.FilterIndex - 1;
 if not (i in [0..4]) then
   i := ExpDlg.RadioGroup1.ItemIndex;
 case i of
   0: Result := '$c';
   1: Result := '$m';
   2: Result := 'ay';
   3: Result := 'scl';
 else
   Result := 'tap';
  end;
end;

procedure TMainForm.SaveDialogZXAYTypeChange(Sender: TObject);
begin
 SaveDialogZXAY.DefaultExt := GetZXAYFileExt;
end;

{$IFDEF Windows}
procedure TMainForm.SetPriority(Pr: longword);
var
 HMyProcess: HANDLE;
begin
 if Pr <> 0 then
   VTOptions.Priority := Pr
 else
   Pr := NORMAL_PRIORITY_CLASS;
 HMyProcess := GetCurrentProcess;
 SetPriorityClass(HMyProcess, Pr);
end;
{$ENDIF Windows}

function CanCopy(Cut: boolean = False): boolean;
begin
 Result := MainForm.ActiveChildExists;
 if Result then
   with MainForm.ActiveChild do
     if Assigned(ActiveControl) then
      begin
       Result := ActiveControl is TCustomEdit;
       if Result then
         Result := (ActiveControl as TCustomEdit).SelLength > 0
       else
        begin
         Result := (ActiveControl is TTracks) or
           ((ActiveControl = SGPositions) and (SGPositions.Col <
           VTMP^.Positions.Length));
         if Result then
           Result := not Cut or (IsPlayingWindow < 0) or (PlayMode = PMPlayLine)
         else
           Result := (ActiveControl is TSamples) or
             (ActiveControl is TOrnaments) or (ActiveControl is TTestLine);
        end;
      end;
end;

procedure TMainForm.EditCopy1Update(Sender: TObject);
begin
 EditCopy1.Enabled := CanCopy;
end;

procedure TMainForm.EditCut1Update(Sender: TObject);
begin
 EditCut1.Enabled := CanCopy(True);
end;

procedure TMainForm.EditPaste1Update(Sender: TObject);
var
 R: boolean;
begin
 R := ActiveChildExists;
 if R then
   with ActiveChild do
     if Assigned(ActiveControl) then
      begin
       R := (ActiveControl is TTracks) or (ActiveControl = SGPositions);
       if R then
         R := (IsPlayingWindow < 0) or (PlayMode = PMPlayLine)
       else
         R := (ActiveControl is TCustomEdit) or (ActiveControl is TSamples) or
           (ActiveControl is TOrnaments) or (ActiveControl is TTestLine);
      end;
 EditPaste1.Enabled := R;
end;

function GetCopyControl(out CT: integer; out WC: TWinControl): boolean;
begin
 Result := (MainForm.Childs.Count <> 0) and Assigned(MainForm.ActiveControl);
 if Result then
  begin
   CT := -1;
   WC := MainForm.ActiveControl;
   if WC is TCustomEdit then CT := 0;
   if CT < 0 then
    begin
     Result := WC is TTracks;
     if Result then CT := 1;
    end;
   if CT < 0 then
    begin
     Result := WC is TSamples;
     if Result then CT := 2;
    end;
   if CT < 0 then
    begin
     Result := WC is TOrnaments;
     if Result then CT := 3;
    end;
   if CT < 0 then
    begin
     Result := WC is TTestLine;
     if Result then CT := 4;
    end;
   if CT < 0 then
    begin
     Result := MainForm.ActiveChildExists and
       (MainForm.ActiveChild.ActiveControl = MainForm.ActiveChild.SGPositions);
     if Result then CT := 5;
    end;
  end;
end;

procedure TMainForm.EditCut1Execute(Sender: TObject);
var
 CtrlType: integer;
 WC: TWinControl;
begin
 if GetCopyControl(CtrlType, WC) then
   case CtrlType of
     0: (WC as TCustomEdit).CutToClipboard;
     1: (WC as TTracks).CutToClipboard;
     2: (WC as TSamples).CutToClipboard;
     3: (WC as TOrnaments).CutToClipboard;
     4: (WC as TTestLine).CutToClipboard;
     5:
      begin
       (WC as TStringGrid).CopyToClipboard(True);
       WC := GetParentFrame(WC);
       if Assigned(WC) then
         (WC as TChildForm).DeletePositions;
      end;
    end;
end;

procedure TMainForm.EditCopy1Execute(Sender: TObject);
var
 CtrlType: integer;
 WC: TWinControl;
begin
 if GetCopyControl(CtrlType, WC) then
   case CtrlType of
     0: (WC as TCustomEdit).CopyToClipboard;
     1: (WC as TTracks).CopyToClipboard;
     2: (WC as TSamples).CopyToClipboard;
     3: (WC as TOrnaments).CopyToClipboard;
     4: (WC as TTestLine).CopyToClipboard;
     5: (WC as TStringGrid).CopyToClipboard(True);
    end;
end;

procedure TMainForm.EditPaste1Execute(Sender: TObject);
var
 CtrlType: integer;
 WC: TWinControl;
begin
 if GetCopyControl(CtrlType, WC) then
   case CtrlType of
     0: (WC as TCustomEdit).PasteFromClipboard;
     1: (WC as TTracks).PasteFromClipboard(False);
     2: (WC as TSamples).PasteFromClipboard;
     3: (WC as TOrnaments).PasteFromClipboard;
     4: (WC as TTestLine).PasteFromClipboard;
     5: if ActiveChildExists then
         ActiveChild.PasteToPositionsList;
    end;
end;

procedure TMainForm.UndoUpdate(Sender: TObject);
begin
 Undo.Enabled := ActiveChildExists and (ActiveChild.ChangeCount > 0);
end;

procedure TMainForm.UndoExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.DoUndo(True);
end;

procedure TMainForm.RedoUpdate(Sender: TObject);
begin
 Redo.Enabled := ActiveChildExists and (ActiveChild.ChangeCount <
   ActiveChild.ChangeTop);
end;

procedure TMainForm.RedoExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.DoUndo(False);
end;

procedure TMainForm.CheckCommandLine;
var
 i: integer;
begin
 i := ParamCount;
 if i = 0 then
   Exit;
 for i := 1 to i do
   CreateChild(ExpandFileName(ParamStr(i)));
end;

function TMainForm.AllowSave(const fn: string; TwoForTS: boolean = False): boolean;
begin
 if not TwoForTS then
   Result := not FileExists(fn) or
     (MessageDlg(Mes_File + ' ''' + fn + ''' ' + Mes_ExistOvr,
     mtConfirmation, [mbYes, mbNo], 0) = mrYes)
 else
  begin
   Result := AllowSave(GetTSFileName(fn, 1));
   if Result then
     Result := AllowSave(GetTSFileName(fn, 2));
  end;
end;

procedure TMainForm.TransposeChannel(WorkWin: TChildForm;
 Pat, Chn, i, Semitones: integer);
var
 j: integer;
begin
 if WorkWin.VTMP^.Patterns[Pat]^.Items[i].Channel[Chn].Note >= 0 then
  begin
   j := WorkWin.VTMP^.Patterns[Pat]^.Items[i].Channel[Chn].Note + Semitones;
   if (j >= 96) or (j < 0) then exit;
   WorkWin.VTMP^.Patterns[Pat]^.Items[i].Channel[Chn].Note := j;
  end;
end;

procedure TMainForm.TransposeColumns(WorkWin: TChildForm; Pat: integer;
 Env: boolean; Chans: TChansArrayBool; LFrom, LTo, Semitones: integer;
 MakeUndo: boolean);
var
 // stk:real;
 i, e, n{,PLen}: integer;
 f: boolean;
begin
 if Semitones = 0 then
   Exit;
 with WorkWin do
  begin
   if VTMP^.Patterns[Pat] = nil then
     Exit;
   f := Env or Chans[0] or Chans[1] or Chans[2];
   if not f then
     Exit;
   //  PLen := VTMP^.Patterns[Pat]^.Length;
   //  if LTo >= PLen then LTo := PLen - 1;
   //Work with all pattern lines even if it greater then pattern length
   if LTo >= MaxPatLen then LTo := MaxPatLen - 1;
   if LFrom > LTo then
     Exit;
   SongChanged := True;
   if MakeUndo then
    begin
     if Env then
      begin
       i := 0;
       n := -1;
      end
     else if Chans[0] then
      begin
       i := 8;
       n := 0;
      end
     else if Chans[1] then
      begin
       i := 22;
       n := 1;
      end
     else if Chans[2] then
      begin
       i := 36;
       n := 2;
      end;
     AddUndo(CATransposePattern,{%H-}PtrInt(VTMP^.Patterns[Pat]), 0, Pat, LFrom, n, i);
    end;
   if Chans[0] then
     for i := LFrom to LTo do
       TransposeChannel(WorkWin, Pat, 0, i, Semitones);
   if Chans[1] then
     for i := LFrom to LTo do
       TransposeChannel(WorkWin, Pat, 1, i, Semitones);
   if Chans[2] then
     for i := LFrom to LTo do
       TransposeChannel(WorkWin, Pat, 2, i, Semitones);
   if Env then
    begin
     //    stk := exp(-Semitones / 12 * ln(2));
     for i := LFrom to LTo do
      begin
       //      e := VTMP^.Patterns[Pat]^.Items[i].Envelope;
       //    if e <> 0 then
        begin
         n := EnvP2Note(VTMP^.Patterns[Pat], i, VTMP^.Ton_Table);
{        if n < 0 then
         begin
          e := round(e * stk);
          if (e >= 0) and (e < $10000) then VTMP^.Patterns[Pat]^.Items[i].Envelope := e;
         end
        else}
         if n >= 0 then
          begin
           Inc(n, Semitones);
           if n in [0..95 + 12] then
             Note2EnvP(VTMP^.Patterns[Pat], i, n, VTMP^.Ton_Table, e,
               VTMP^.Patterns[Pat]^.Items[i].Envelope);
          end;
        end;
      end;
    end;
   if PatNum = Pat then
     Tracks.Invalidate;
  end;
end;

procedure TMainForm.TransposeSelection(Semitones: integer);
var
 X1, X2, Y1, Y2: integer;
 Chans: TChansArrayBool;
begin
 if Semitones = 0 then
   Exit;
 if not ActiveChildExists then
   Exit;
 with ActiveChild.Tracks do
  begin
   X2 := CursorX;
   X1 := SelX;
   if X1 > X2 then
    begin
     X1 := X2;
     X2 := SelX;
    end;
   Y1 := SelY;
   Y2 := ShownFrom - N1OfLines + CursorY;
   if Y1 > Y2 then
    begin
     Y1 := Y2;
     Y2 := SelY;
    end;
   Chans[ChanAlloc[0]] := (X1 <= 8) and (X2 >= 8);
   Chans[ChanAlloc[1]] := (X1 <= 22) and (X2 >= 22);
   Chans[ChanAlloc[2]] := (X1 <= 36) and (X2 >= 36);
   TransposeColumns(ActiveChild, ActiveChild.PatNum,
     X1 <= 3, Chans, Y1, Y2, Semitones, True);
  end;
end;

procedure TMainForm.CheckTracksFocused(Sender: TObject);
begin
 (Sender as TAction).Enabled :=
   ActiveChildExists and ActiveChild.Tracks.Enabled and ActiveChild.Tracks.Focused;
end;

procedure TMainForm.TransposeUp1Execute(Sender: TObject);
begin
 TransposeSelection(1);
end;

procedure TMainForm.TransposeDown1Execute(Sender: TObject);
begin
 TransposeSelection(-1);
end;

procedure TMainForm.TransposeUp3Execute(Sender: TObject);
begin
 TransposeSelection(3);
end;

procedure TMainForm.TransposeDown3Execute(Sender: TObject);
begin
 TransposeSelection(-3);
end;

procedure TMainForm.TransposeUp5Execute(Sender: TObject);
begin
 TransposeSelection(5);
end;

procedure TMainForm.TransposeDown5Execute(Sender: TObject);
begin
 TransposeSelection(-5);
end;

procedure TMainForm.TransposeUp12Execute(Sender: TObject);
begin
 TransposeSelection(12);
end;

procedure TMainForm.TransposeDown12Execute(Sender: TObject);
begin
 TransposeSelection(-12);
end;

//specially for Znahar
procedure TMainForm.SetBar(BarNum: integer; Value: boolean);
begin
 PMToolBar.Items[BarNum].Checked := Value;
 case BarNum of
   0:
    begin
     TBNew.Visible := Value;
     TBOpen.Visible := Value;
     TBSave.Visible := Value;
     TBDivFile.Visible := Value;
     TBOptions.Visible := Value;
     TBDivOpts.Visible := Value;
    end;
   1:
    begin
     TBCut.Visible := Value;
     TBCopy.Visible := Value;
     TBPaste.Visible := Value;
     TBDivClpBrd.Visible := Value;
    end;
   2:
    begin
     TBUndo.Visible := Value;
     TBRedo.Visible := Value;
     TBDivUndo.Visible := Value;
    end;
   3:
    begin
     TBCascade.Visible := Value;
     TBTileHor.Visible := Value;
     TBTileVert.Visible := Value;
     TBDivWin.Visible := Value;
    end;
   4:
    begin
     TBStop.Visible := Value;
     TBPlayPos.Visible := Value;
     TBPlay.Visible := Value;
     TBPlayPatFrom.Visible := Value;
     TBPlayPat.Visible := Value;
     TBDivPlay.Visible := Value;
     TBLoop.Visible := Value;
     TBLoopAll.Visible := Value;
     TBToggleSams.Visible := Value;
     TBDivLoop.Visible := Value;
    end;
   5:
    begin
     TBTracksMngr.Visible := Value;
     TBGlbTrans.Visible := Value;
     TBDivEdit.Visible := Value;
    end;
  end;
end;

procedure TMainForm.PopupMenu3Click(Sender: TObject);
begin
 SetBar((Sender as TMenuItem).Tag, not (Sender as TMenuItem).Checked);
end;

procedure TMainForm.ExpandTwice1Click(Sender: TObject);
var
 PL, NL, i: integer;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
  begin
   if VTMP^.Patterns[PatNum] = nil then
     PL := DefPatLen
   else
     PL := VTMP^.Patterns[PatNum]^.Length;
   NL := PL * 2;
   if NL <= MaxPatLen then
    begin
     SongChanged := True;
     ValidatePattern2(PatNum);
     AddUndo(CAExpandShrinkPattern,{%H-}PtrInt(VTMP^.Patterns[PatNum]), 0, auAutoIdxs);
     VTMP^.Patterns[PatNum]^.Length := NL;
     UDPatLen.Position := NL;
     for i := PL - 1 downto 0 do
      begin
       with VTMP^.Patterns[PatNum]^.Items[i * 2 + 1] do
        begin
         Envelope := 0;
         Noise := 0;
         Channel[0] := EmptyChannelLine;
         Channel[1] := EmptyChannelLine;
         Channel[2] := EmptyChannelLine;
        end;
       VTMP^.Patterns[PatNum]^.Items[i * 2] := VTMP^.Patterns[PatNum]^.Items[i];
      end;
     CheckTracksAfterSizeChanged(NL);
    end
   else
     ShowMessage(Mes_ExpPatNotice1 + ' ' + IntToStr(MaxPatLen div 2) +
       ' ' + Mes_ExpPatNotice2);
  end;
end;

procedure TMainForm.ShrinkTwice1Click(Sender: TObject);
var
 PL, NL, i: integer;
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
  begin
   if VTMP^.Patterns[PatNum] = nil then
     PL := DefPatLen
   else
     PL := VTMP^.Patterns[PatNum]^.Length;
   NL := PL div 2;
   if NL > 0 then
    begin
     SongChanged := True;
     ValidatePattern2(PatNum);
     AddUndo(CAExpandShrinkPattern,{%H-}PtrInt(VTMP^.Patterns[PatNum]), 0, auAutoIdxs);
     VTMP^.Patterns[PatNum]^.Length := NL;
     UDPatLen.Position := NL;
     for i := 1 to NL - 1 do
       VTMP^.Patterns[PatNum]^.Items[i] := VTMP^.Patterns[PatNum]^.Items[i * 2];
     for i := NL to MaxPatLen - 1 do
       with VTMP^.Patterns[PatNum]^.Items[i] do
        begin
         Envelope := 0;
         Noise := 0;
         Channel[0] := EmptyChannelLine;
         Channel[1] := EmptyChannelLine;
         Channel[2] := EmptyChannelLine;
        end;
     CheckTracksAfterSizeChanged(NL);
    end
   else
     ShowMessage(Mes_ShrPatNotice);
  end;
end;

procedure TMainForm.Merge1Click(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.Tracks.PasteFromClipboard(True);
end;

procedure TMainForm.VisTimerTimer(Sender: TObject);
var
 CurVisPos: int64;
 i, j: integer;
begin
 if IsPlaying and (PlayMode in [PMPlayModule, PMPlayPattern]) and
   digsound_gotposition(CurVisPos) then
  begin
   CurVisPos := CurVisPos mod VisTicksMax div VisTicksStep;
   for i := 0 to Length(PlaybackBufferMaker.Players) - 1 do
     with PlaybackWindow[i].VTMP^, VisParams[CurVisPos][i] do
      begin
       RedrawPlWindow(PlaybackWindow[i], Pos, Pat, Lin);
       Saves.EnvP := EnvP;
       for j := 0 to 2 do
         with Chs[j] do
          begin
           Saves.Chns[j].Nt := Nt;
           Saves.Chns[j].Smp := Smp;
           Saves.Chns[j].EnvT := EnvT;
           Saves.Chns[j].Orn := Orn;
           Saves.Chns[j].Vol := Vol;
          end;
      end;
  end;
end;

procedure TMainForm.VolumeDownExecute(Sender: TObject);
begin
 VolumeControl.SetVol(GlobalVolume - 1);
end;

procedure TMainForm.VolumeUpExecute(Sender: TObject);
begin
 VolumeControl.SetVol(GlobalVolume + 1);
end;

procedure TMainForm.DoTile(TileMode: TTileMode);
var
 j, i, h, w: integer;
begin
 if Childs.Count = 0 then
   Exit;

 RestoreChilds;

 h := Workspace.Height;
 if HScrollBar.Visible then
   Inc(h, HScrollBar.Height);
 w := Workspace.Width;
 if VScrollBar.Visible then
   Inc(w, VScrollBar.Width);

 j := 0;

 if TileMode = TTileMode.tbVertical then
  begin
   for i := 0 to Childs.Count - 1 do
     with TChildForm(Childs.Items[i]) do
      begin
       if CanHookTSWindow and (TSWindow.WinNumber < WinNumber) then
         //already moved
         Continue;
       Inc(IsSoftRepos); //skip recalculations to make it later
       Left := (j and $7FFF);
       //to avoid raising range checking error in LCL move messages sender
       Top := 0;
       if CanHookTSWindow then
        begin
         HookTSWindow;
         j += TSWindow.Width - ChildFrameWidth;
        end;
       j += Width - ChildFrameWidth; //allow overlapping per border width
       Dec(IsSoftRepos);
      end;
   if j > w then
     h -= HScrollBar.Height;
  end
 else
  begin
   h := h div 2;
   for i := 0 to Childs.Count - 1 do
     with TChildForm(Childs.Items[i]) do
      begin
       if CanHookTSWindow and (TSWindow.WinNumber < WinNumber) then
         Continue;
       Inc(IsSoftRepos);
       Left := 0;
       Top := (h * j and $7FFF);
       //to avoid raising range checking error in LCL move messages sender
       HookTSWindow;
       j += 1;
       Dec(IsSoftRepos);
      end;
   h += ChildFrameWidth;
  end;
 for i := 0 to Childs.Count - 1 do
   with TChildForm(Childs.Items[i]) do
    begin
     Inc(IsSoftRepos);
     Height := h;
     SetNOfLines;
     Dec(IsSoftRepos);
    end;
 CalcSBs;
 EnsurePlayingWindowActive;
 if ActiveChildExists then
   ActiveChild.ScrollWorkspace;
end;

procedure TMainForm.AutoStepExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.ToggleAutoStep;
end;

procedure TMainForm.AutoEnvExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.ToggleAutoEnv;
end;

procedure TMainForm.AutoEnvStdExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 ActiveChild.ToggleStdAutoEnv;
end;

procedure TMainForm.AutoPrmsExecute(Sender: TObject);
begin
 if not ActiveChildExists then
   Exit;
 with ActiveChild do
   SBAutoPars.Down := not SBAutoPars.Down;
end;

procedure TMainForm.WindowTileHorizontal1Execute(Sender: TObject);
begin
 DoTile(tbHorizontal);
end;

procedure TMainForm.WindowTileVertical1Execute(Sender: TObject);
begin
 DoTile(tbVertical);
end;

{procedure TMainForm.WindowArrangeAll1Execute(Sender: TObject);
begin
ArrangeIcons;
end;}

procedure TMainForm.DoCascade(ai: TChildForm);
var
 maxx, h, w: integer;
begin
 if ai.CanHookTSWindow and (ai.TSWindow.WinNumber < ai.WinNumber) then
   Exit;

 h := Workspace.Height;
 if HScrollBar.Visible then
   Inc(h, HScrollBar.Height);
 w := Workspace.Width;
 if VScrollBar.Visible then
   Inc(w, VScrollBar.Width);

 if win_y * win_o + ai.Height >= h then
   win_y := 0;
 if ai.CanHookTSWindow then
   maxx := win_x * win_o + ai.Width + ai.TSWindow.Width
 else
   maxx := win_x * win_o + ai.Width;
 if maxx >= w then
   win_x := 0;
 Inc(ai.IsSoftRepos);
 ai.Left := win_x * win_o;
 ai.Top := win_y * win_o;
 ai.HookTSWindow;
 Dec(ai.IsSoftRepos);

 ai.BringToFront;
 if ai.TSWindow <> nil then
   ai.TSWindow.BringToFront;

 win_x += 1;
 win_y += 1;
end;

procedure TMainForm.EnsurePlayingWindowActive;
var
 i: integer;
begin
 if not IsPlaying then
   Exit;
 for i := 0 to Length(PlaybackBufferMaker.Players) - 1 do
   if PlaybackWindow[i] = ActiveChild then
     Exit;
 PlaybackWindow[0].SetForeground;
end;

//Cascade sorting
procedure TMainForm.WindowCascade1Execute(Sender: TObject);
var
 i: integer;
begin
 if Childs.Count = 0 then
   Exit;

 RestoreChilds;

 win_x := 0;
 win_y := 0;
 for i := 0 to Childs.Count - 1 do
   DoCascade(TChildForm(Childs.Items[i]));

 CalcSBs;
 EnsurePlayingWindowActive;
 if ActiveChildExists then
  begin
   ActiveChild.BringToFrontBoth;
   ActiveChild.ScrollWorkspace;
  end;
end;

(*procedure TMainForm.WindowMinimizeAll1Execute(Sender: TObject);
var
  I: Integer;
begin
  { Must be done backwards through the Childs.Items array }
  for I := Childs.Count - 1 downto 0 do
    Childs.Items[I].WindowState := wsMinimized;
end;*)

procedure TMainForm.FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
begin
 VolumeControl.SetVol(GlobalVolume - 1);
 Handled := True;
end;

procedure TMainForm.FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
begin
 VolumeControl.SetVol(GlobalVolume + 1);
 Handled := True;
end;

procedure TVolumeControl.VolMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 if [ssLeft] = Shift then
  begin
   FClicked := True;
   SetVol(X);
  end;
end;

procedure TVolumeControl.VolMouseMove(Sender: TObject; Shift: TShiftState;
 X, Y: integer);
begin
 if FClicked and ([ssLeft] = Shift) then
   SetVol(X);
end;

procedure TVolumeControl.VolMouseUp(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 FClicked := False;
end;

constructor TVolumeControl.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 FClicked := False;
 OnPaint := @VolPaint;
 OnMouseDown := @VolMouseDown;
 OnMouseMove := @VolMouseMove;
 OnMouseUp := @VolMouseUp;
end;

procedure TVolumeControl.SetVol(Value: integer);
begin
 if Value < 0 then
   Value := 0
 else if Value > GlobalVolumeMax then
   Value := GlobalVolumeMax;
 if GlobalVolume <> Value then
  begin
   GlobalVolume := Value;
   PlaybackBufferMaker.Calculate_Level_Tables;
   Invalidate;
  end;
end;

procedure TVolumeControl.VolPaint(Sender: TObject);
var
 i, c, h0, h1, h2, k1, k2, k3, w: integer;
 c1, c2, c3: TColor;
begin
 Canvas.Brush.Color := clBtnShadow;
 Canvas.FrameRect(Rect(0, 4, Width, Height - 4));
 Canvas.Brush.Color := clBtnFace;
 Canvas.FillRect(Rect(1, 5, Width - 1, Height - 5));
 k3 := Height - 10;
 k1 := k3 div 3;
 k2 := k1 * 2;
 w := 2;
 for i := 1 to GlobalVolume do
   if i mod 3 = 1 then
    begin
     c := i div (GlobalVolumeMax div 8);
     case c of
       0..5:
        begin
         c1 := TColor($00ff00);
         c2 := TColor($00c000);
         c3 := TColor($008000);
        end;
       6:
        begin
         c1 := TColor($00ffff);
         c2 := TColor($00c0c0);
         c3 := TColor($008080);
        end;
     else
      begin
       c1 := TColor($0080ff);
       c2 := TColor($0060c0);
       c3 := TColor($004080);
      end;
      end;
     h0 := Trunc((k3 - 1) * (1 - (i - 1) / (GlobalVolumeMax - 1))) + 5;
     h1 := k3 - (k3 - k1) * i div GlobalVolumeMax + 5;
     h2 := k3 - (k3 - k2) * i div GlobalVolumeMax + 5;
     if i = GlobalVolume then
       w := 1;
     Canvas.GradientFill(Rect(i, h0, i + w, h1), c3, c2, gdVertical);
     Canvas.GradientFill(Rect(i, h1, i + w, h2), c2, c1, gdVertical);
     Canvas.GradientFill(Rect(i, h2, i + w, k3 + 5), c1, c2, gdVertical);
    end;
end;

end.
