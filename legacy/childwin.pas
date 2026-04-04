{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit ChildWin;

{$mode objfpc}{$H+}

interface

uses
 LCLIntf, LCLType, LCLProc, Classes, Graphics, Forms, Controls, StdCtrls,
 SysUtils, ComCtrls, Grids, Menus, Buttons, ExtCtrls, Dialogs, lazutf8,
 LMessages, Clipbrd, Types, Math, trfuncs, digsound, digsoundcode, AY,
 WinVersion;

const
 //editor tabsheet page indexes
 piTracks = 0;
 piSamples = 1;
 piOrnaments = 2;
 piTables = 3;
 piOptions = 4;

 //add undo consts
 auAutoIdxs = -2; //auto fill cursor coords to Idx params

 //child frame borders widths
 SizeBorderWidth = 3;
 ChildFrameWidth = 1;

type
 TTracks = class(TPanel)
 protected
   procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
   procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
 public
   CelW, CelH: integer;
   CursorX, CursorY, SelX, SelY: integer;
   ShownFrom, NOfLines, N1OfLines: integer;
   HLStep: integer;
   DigN: integer; //digits number in lines numeration
   ShownPattern: PPattern;
   CaretSize: integer;
   KeyPressed: integer;
   Clicked: boolean;
   ParWind: TFrame;
   constructor Create(AOwner: TComponent); override;
   procedure SetNOfLines(Keep: boolean = True);
   function SetFont: boolean;
   procedure ResetSelection; //just reset variables
   procedure ToggleSelection; //show/hide selection
   procedure AbortSelection; //toggle and reset
   procedure SelectAll;
   procedure RedrawTracks;
   procedure RecreateCaret;
   procedure CreateMyCaret;
   procedure CalcCaretPos;
   procedure CopyToClipboard;
   procedure CutToClipboard;
   procedure PasteFromClipboard(Merge: boolean);
   procedure ClearSelection;
   procedure DoHint;
   procedure TracksPaint(Sender: TObject);
 end;

 TTestLine = class(TPanel)
 protected
   FTestOct: integer;
   procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
   procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
 public
   CelW, CelH: integer;
   CursorX, SelX: integer;
   BigCaret: boolean;
   KeyPressed: integer;
   Clicked: boolean;
   LineIndex: integer; //line number in dummy pattern -1
   ParWind: TFrame;
   constructor Create(AOwner: TComponent); override;
   procedure SetFont;
   procedure RedrawTestLine;
   procedure ResetSelection; //just reset variables
   procedure ToggleSelection; //show/hide selection
   procedure AbortSelection; //toggle and reset
   procedure SelectAll;
   procedure RecreateCaret;
   procedure CreateMyCaret;
   procedure CalcCaretPos;
   procedure TestLineMoveCursorMouse(X, Y: integer; Sel, Mv, ButRight: boolean);
   procedure TestLineMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure TestLineMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure TestLineKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure TestLineKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure TestLinePaint(Sender: TObject);
   procedure CopyToClipboard;
   procedure CutToClipboard;
   procedure PasteFromClipboard;
   procedure ClearSelection;
   procedure SetTestOct(Oct: integer);
   property TestOct: integer read FTestOct write SetTestOct;
 end;

 TSamples = class(TPanel)
 protected
   procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
   procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
 public
   InputSNumber, CelW, CelH: integer;
   CursorX, CursorY, SelX, SelY: integer;
   ShownFrom, NOfLines: integer;
   ShownSample: PSample;
   CaretSize: integer;
   ClickedX, //-1 if edit area was not clicked, otherwise X coord where was clicking
   ClickedChangesStart: integer; //next change index in undo list
   ParWind: TFrame;
   constructor Create(AOwner: TComponent); override;
   procedure SetNOfLines;
   procedure SetFont;
   procedure ResetSelection; //just reset variables
   procedure ToggleSelection; //show/hide selection
   procedure AbortSelection; //toggle and reset
   procedure SelectAll;
   procedure RedrawSamples;
   procedure RecreateCaret;
   procedure DoHint;
   procedure CreateMyCaret;
   procedure CalcCaretPos;
   procedure SamplesPaint(Sender: TObject);
   procedure CopyToClipboard;
   procedure CutToClipboard;
   procedure PasteSampleToSample(var ns: PChar);
   procedure PasteRegDumpToSample(var ns: PChar; Chan: integer);
   procedure PastePatternToSample(var ns: PChar);
   procedure PasteOrnamentToSample(var ns: PChar);
   procedure PasteFromClipboard;
   procedure ClearSelection;
 end;

 TOrnaments = class(TPanel)
 protected
   procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
   procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
 public
   InputONumber, CelW, CelH: integer;
   CursorX, CursorY, SelI: integer;
   ShownFrom, NOfLines, OrnNRow, OrnNCol: integer;
   ShownOrnament: POrnament;
   Clicked: boolean;
   ParWind: TFrame;
   constructor Create(AOwner: TComponent); override;
   procedure SetNOfLines;
   procedure SetFont;
   procedure ResetSelection; //just reset variables
   procedure ToggleSelection; //show/hide selection
   procedure AbortSelection; //toggle and reset
   procedure SelectAll;
   procedure RedrawOrnaments;
   procedure CalcCaretPos;
   procedure DoHint;
   procedure OrnamentsPaint(Sender: TObject);
   procedure CopyToClipboard;
   procedure CutToClipboard;
   procedure PasteOrnamentToOrnament(var ns: PChar);
   procedure PasteRegDumpToOrnament(var ns: PChar; Chan: integer);
   procedure PastePatternToOrnament(var ns: PChar);
   procedure PasteFromClipboard;
   procedure ClearSelection;
 end;

 TChangeAction = (CALoadPattern, CALoadSample, CAUnrollSample, CARenderSample,
   CARecalcSample, CALoadOrnament, CAOrGen, CARenderOrnament,
   CAInsertPatternFromClipboard, CAInsertSampleFromClipboard,
   CAInsertOrnamentFromClipboard, CAChangeNote, CAChangeEnvelopePeriod,
   CAChangeNoise, CAChangeSample, CAChangeEnvelopeType, CAChangeOrnament,
   CAChangeVolume, CAChangeSpecialCommandNumber, CAChangeSpecialCommandDelay,
   CAChangeSpecialCommandParameter, CAChangeSpeed, CAChangePatternSize,
   CAChangeSampleSize, CAChangeSampleLoop, CAChangeOrnamentSize,
   CAChangeOrnamentLoop, CAChangeOrnamentValue, CAChangeSampleValue,
   CAInsertPosition, CADeletePosition,
   CAChangePositionListLoop, CAChangePositionValue, CAReorderPatterns,
   CAChangeToneTable, CAChangeFeatures, CAChangeHeader, CAChangeAuthor, CAChangeTitle,
   CAPatternInsertLine, CAPatternDeleteLine, CAPatternClearLine, CAPatternClearSelection,
   CATransposePattern, CATracksManagerCopy, CAExpandShrinkPattern, CASwapPattern,
   CASampleInsertLine, CASampleDeleteLine, CASampleClearSelection,
   CAOrnamentInsertLine, CAOrnamentDeleteLine, CAOrnamentClearSelection);

 TChangeActionSet = set of TChangeAction;

const
 //changes that are undesirable during playback
 PlaybackBewaredChanges: TChangeActionSet =
   [CAInsertPosition, CADeletePosition, CAReorderPatterns];

type
 TChangeParams1 = record //for storing state of first (or single) changed parameter
   case TChangeAction of
     CAChangeNote: (Note: integer);
     CAChangeEnvelopePeriod: (EnvelopePeriod: integer);
     CAChangeNoise: (Noise: integer);
     CAChangeSample: (SampleNum: integer);
     CAChangeEnvelopeType: (EnvelopeType: integer);
     CAChangeOrnament: (OrnamentNum: integer);
     CAChangeVolume: (Volume: integer);
     CAChangeSpecialCommandNumber: (SCNumber: integer);
     CAChangeSpecialCommandDelay: (SCDelay: integer);
     CAChangeSpecialCommandParameter: (SCParameter: integer);
     CAChangeSpeed: (Speed: integer);
     CAChangePatternSize, CAChangeSampleSize, CAChangeOrnamentSize: (Size: integer);
     CAChangeSampleLoop, CAChangeOrnamentLoop, CAChangePositionListLoop: (Loop: integer);
     CAChangeOrnamentValue, CAChangePositionValue: (Value: integer);
     CAChangeToneTable: (Table: integer);
     CAChangeFeatures: (NewFeatures: integer);
     CAChangeHeader: (NewHeader: integer);
 end;

 TChangeParams2 = record
     //for storing state of second changed parameter for some change actions
   case TChangeAction of
     CAChangePositionValue: (PositionListLen: integer);
     CAChangeSampleSize, CAChangeOrnamentSize: (PrevLoop: integer);
 end;

 TChangeIdxes = record
   case TChangeAction of
     CAChangeSampleLoop: (SampleLine, SampleCursorX: integer);
     CAChangeOrnamentLoop: (OrnamentLine: integer);
     CAChangePatternSize: (CurrentPosition, PatternLine, PatternChan, PatternX: integer);
 end;

 TChangeParams = record
   One: TChangeParams1;
   Two: TChangeParams2;
   Idx: TChangeIdxes;
 end;

 PChangeParameters = ^TChangeParameters;
 TChangeParameters = record
   case boolean of
     True: (str: packed array[0..32] of char);
     False: (prm: TChangeParams);
 end;

 TChangeListItem = record
   Action: TChangeAction;
   Ptr: record
     case TChangeAction of
       CALoadPattern, CAInsertPatternFromClipboard, CAPatternInsertLine,
       CAPatternDeleteLine,
       CAPatternClearLine, CAPatternClearSelection, CATransposePattern,
       CATracksManagerCopy,
       CAExpandShrinkPattern, CASwapPattern: (Pattern: PPattern);
       CADeletePosition, CAInsertPosition, CAReorderPatterns:
       (PositionList: PPositionList);
       CALoadOrnament, CAOrGen, CARenderOrnament, CAOrnamentInsertLine,
       CAOrnamentDeleteLine,
       CAOrnamentClearSelection, CAInsertOrnamentFromClipboard: (Ornament: POrnament);
       CALoadSample, CAUnrollSample, CARenderSample, CARecalcSample,
       CASampleInsertLine, CASampleDeleteLine, CASampleClearSelection,
       CAInsertSampleFromClipboard: (Sample: PSample);
       CAChangeSampleValue: (SampleLineValues: PSampleTick);
     end;
   ComParams: record
     case TChangeAction of
       CAChangeSampleLoop: (CurrentSample: integer);
       CAChangeOrnamentLoop: (CurrentOrnament: integer);
       CAChangePatternSize: (CurrentPattern: integer);
       CAReorderPatterns: (PatternsIndex: PPatIndex);
     end;
   OldParams, NewParams: TChangeParameters;
   Grouped: boolean;
 end;

 TChannelControls = record
   Mute, MuteT, MuteN, MuteE, Solo: TSpeedButton;
 end;

 //target of moving with left button clicked
 TClickedTarget = (ctNone, ctHooked, ctMove, ctSizeN, ctSizeS);

 { TChildForm }

 TChildForm = class(TFrame)
   EdOrnOctave: TEdit;
   EdSamOctave: TEdit;
   Header: TPanel;
   LbOrnOctave: TLabel;
   LbSamOctave: TLabel;
   SBClose: TSpeedButton;
   BvEnv: TBevel;
   BvNoise: TBevel;
   BvChanA: TBevel;
   BvChanB: TBevel;
   BvChanC: TBevel;
   MTable: TMemo;
   EditorPages: TPageControl;
   PnSamsTop: TPanel;
   PnSamsRight: TPanel;
   PnOrnsTop: TPanel;
   PnOrnsRight: TPanel;
   SBAutoCmd: TSpeedButton;
   SBAutoVol: TSpeedButton;
   SBMax: TSpeedButton;
   SBDecTrLines: TSpeedButton;
   SBEnvAsNote: TSpeedButton;
   SBDecNoise: TSpeedButton;
   SBAutoPars: TSpeedButton;
   SBAutoSmp: TSpeedButton;
   SBAutoEnvT: TSpeedButton;
   SBAutoOrn: TSpeedButton;
   SBOrnAsNotes: TSpeedButton;
   SBSamAsNotes: TSpeedButton;
   SBSamRecalc: TSpeedButton;
   SBPositions: TScrollBar;
   SGTable: TStringGrid;
   SBTableAsList: TSpeedButton;
   SBTableAsDec: TSpeedButton;
   SBUnrollSample: TSpeedButton;
   TablesTab: TTabSheet;
   Timings: TPanel;
   PatternsSheet: TTabSheet;
   EdTitle: TEdit;
   EdAuthor: TEdit;
   SBSoloA: TSpeedButton;
   SBSoloB: TSpeedButton;
   SBSoloC: TSpeedButton;
   SGPositions: TStringGrid;
   SamplesSheet: TTabSheet;
   OrnamentsSheet: TTabSheet;
   EdOctave: TEdit;
   UDOctave: TUpDown;
   SBMuteAN: TSpeedButton;
   SBMuteAT: TSpeedButton;
   SBMuteAE: TSpeedButton;
   SBMuteA: TSpeedButton;
   SBMuteB: TSpeedButton;
   SBMuteBT: TSpeedButton;
   SBMuteBN: TSpeedButton;
   SBMuteBE: TSpeedButton;
   SBMuteC: TSpeedButton;
   SBMuteCT: TSpeedButton;
   SBMuteCN: TSpeedButton;
   SBMuteCE: TSpeedButton;
   OptTab: TTabSheet;
   GBFeatures: TRadioGroup;
   GBHeader: TRadioGroup;
   EdSample: TEdit;
   UDOrnOctave: TUpDown;
   UDSamOctave: TUpDown;
   UDSample: TUpDown;
   EdSamLen: TEdit;
   UDSamLen: TUpDown;
   LbSamLen: TLabel;
   LbSamLoop: TLabel;
   EdSamLoop: TEdit;
   UDSamLoop: TUpDown;
   EdOrn: TEdit;
   EdOrnLoop: TEdit;
   UDOrn: TUpDown;
   UDOrnLoop: TUpDown;
   EdOrnLen: TEdit;
   UDOrnLen: TUpDown;
   LbOrnLen: TLabel;
   LbOrnLoop: TLabel;
   SBAutoEnv: TSpeedButton;
   SBAutoEnvDigit1: TSpeedButton;
   SBAutoEnvStd: TSpeedButton;
   SBAutoEnvDigit2: TSpeedButton;
   UDAutoStep: TUpDown;
   EdAutoStep: TEdit;
   SBLoadOrn: TSpeedButton;
   SBSaveOrn: TSpeedButton;
   SBOrGen: TSpeedButton;
   SaveTextDlg: TSaveDialog;
   LoadTextDlg: TOpenDialog;
   SBAutoStep: TSpeedButton;
   SBSaveSam: TSpeedButton;
   SBLoadSam: TSpeedButton;
   LbBy: TLabel;
   LbTime: TLabel;
   LbTimeDiv: TLabel;
   LbTotTime: TLabel;
   LbTicks: TLabel;
   LbTicksDiv: TLabel;
   LbTotTicks: TLabel;
   SBTS: TSpeedButton;
   UDPat: TUpDown;
   EdPat: TEdit;
   EdPatLen: TEdit;
   UDPatLen: TUpDown;
   SBLoadPat: TSpeedButton;
   SBSavePat: TSpeedButton;
   SBAutoHL: TSpeedButton;
   EdAutoHL: TEdit;
   UDAutoHL: TUpDown;
   EdTable: TEdit;
   UDTable: TUpDown;
   EdSpeed: TEdit;
   UDSpeed: TUpDown;
   procedure ChildFormPaint(Sender: TObject);
   procedure EdOctaveChange(Sender: TObject);
   procedure EdOrnOctaveChange(Sender: TObject);
   procedure EdOrnOctaveExitOrDone(Sender: TObject);
   procedure EdSamOctaveChange(Sender: TObject);
   procedure EdSamOctaveExitOrDone(Sender: TObject);
   procedure FrameMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure HeaderDblClick(Sender: TObject);
   procedure InvalidateSizeFrame;
   procedure FrameEnter(Sender: TObject);
   procedure FrameExit(Sender: TObject);
   procedure HeaderMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure HeaderMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure HeaderMouseUp(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure EditorPagesResize(Sender: TObject);
   procedure SBCloseClick(Sender: TObject);
   procedure EdAutoStepChange(Sender: TObject);
   procedure EdAutoHLChange(Sender: TObject);
   procedure Edit17ExitOrDone(Sender: TObject);
   procedure FormCreate(Sender: TObject);
   procedure RemoveConstraints;
   procedure SBMaxClick(Sender: TObject);
   procedure SBOrnAsNotesClick(Sender: TObject);
   procedure SBPositionsScroll(Sender: TObject; ScrollCode: TScrollCode;
     var ScrollPos: integer);
   procedure SBSamAsNotesClick(Sender: TObject);
   procedure SGPositionsSelection(Sender: TObject; aCol, aRow: integer);
   procedure SGPositionsTopLeftChanged(Sender: TObject);
   procedure UDOctaveChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure UDOrnOctaveChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure UDSamOctaveChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure UpdateConstraints;
   procedure CalcSize;
   procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure EditorPagesChange(Sender: TObject);
   procedure SBAutoStepClick(Sender: TObject);
   procedure SBDecNoiseClick(Sender: TObject);
   procedure SBDecTrLinesClick(Sender: TObject);
   procedure SBEnvAsNoteClick(Sender: TObject);
   procedure SBTableAsClick(Sender: TObject);
   procedure SGPositionsEnter(Sender: TObject);
   procedure SGPositionsExit(Sender: TObject);
   procedure SGPositionsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure SGPositionsMouseUp(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure CheckAutoPrmsUp;
   procedure FrameKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure SGTableKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure SomeAutoParameterClick(Sender: TObject);
   procedure SBUnrollSampleClick(Sender: TObject);
   procedure TracksMoveCursorMouse(X, Y: integer; Sel, Mv, ButRight: boolean);
   procedure TracksKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure SamplesMoveCursorMouse(X, Y: integer; Sel, Mv: boolean; Shift: TShiftState);
   procedure SamplesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure OrnamentsMoveCursorMouse(X, Y: integer; Sel, Mv: boolean;
     Shift: TShiftState);
   procedure OrnamentsKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure TracksMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure SamplesMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure OrnamentsMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure SamplesContextPopup(Sender: TObject; MousePos: TPoint;
     var Handled: boolean);
   procedure FormDestroy(Sender: TObject);
   function LoadTrackerModule(aFileName: string; var VTMP2: PModule): boolean;
   procedure TracksMouseWheelDown(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure TracksMouseWheelUp(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);

   //for Pat<>nil retrieves ornament/instrument and open in corresp. tab
   procedure ShowSelectedInstrument(Pat: PPattern; Line, CursorX: integer);

   procedure TracksDblClick(Sender: TObject);
   procedure TestLineDblClick(Sender: TObject);
   procedure SamplesMouseWheelDown(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure SamplesMouseWheelUp(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure OrnamentsMouseWheelDown(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure OrnamentsMouseWheelUp(Sender: TObject; Shift: TShiftState;
     MousePos: TPoint; var Handled: boolean);
   procedure UDAutoStepClick(Sender: TObject; Button: TUDBtnType);
   procedure ValidatePattern2(pat: integer);
   procedure TracksKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure SGPositionsSelectCell(Sender: TObject; ACol, ARow: integer;
     var CanSelect: boolean);
   procedure SGPositionsKeyPress(Sender: TObject; var Key: char);
   procedure Edit2ExitOrDone(Sender: TObject);
   procedure PosRemoveSelection;
   //remove multi selection (several cells could be selected)
   procedure SGPositionsMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: integer);
   procedure EdTitleChange(Sender: TObject);
   procedure EdAuthorChange(Sender: TObject);
   procedure RestartPlayingPos(Pos: integer);

   //Line >= 0 - usual pattern line index
   //Line < 0 - fake pattern for test line inverted line index
   procedure RestartPlayingLine(Line: integer);

   procedure RestartPlayingPatternLine(Enter: boolean);
   procedure UDPatChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure EdPatChange(Sender: TObject);
   procedure Edit6ExitOrDone(Sender: TObject);
   procedure EdSpeedChange(Sender: TObject);
   procedure UDSpeedChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure UDTableChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure Edit7ExitOrDone(Sender: TObject);
   procedure EdTableChange(Sender: TObject);
   procedure Edit8ExitOrDone(Sender: TObject);
   procedure UDPatLenChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure CheckTracksAfterSizeChanged(NL: integer);
   procedure ChangePatternLength(NL: integer);
   procedure EdOctaveExitOrDone(Sender: TObject);
   procedure ToggleMute(C: integer);
   procedure ApplyMuteT(C: integer);
   procedure ApplyMuteN(C: integer);
   procedure ApplyMuteE(C: integer);
   procedure ApplyMutes;
   procedure ApplySolo(C: integer);
   procedure SBMuteClick(Sender: TObject);
   procedure SBMuteTClick(Sender: TObject);
   procedure SBMuteNClick(Sender: TObject);
   procedure SBMuteEClick(Sender: TObject);
   procedure SBSoloClick(Sender: TObject);
   procedure ResetChanAlloc;
   procedure GBFeaturesClick(Sender: TObject);
   procedure GBHeaderClick(Sender: TObject);
   procedure RerollToPos(Pos: integer);
   procedure RerollToInt(Int_: integer);
   procedure RerollToLine;
   procedure RerollToPatternLine;
   procedure CreateTracks;
   procedure CreateSamples;
   procedure CreateOrnaments;
   procedure EdSampleChange(Sender: TObject);
   procedure EdSampleExitOrDone(Sender: TObject);
   procedure UDSampleChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure Edit9ExitOrDone(Sender: TObject);
   procedure UDSamLenChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure ChangeSample(n: integer);
   procedure ChangeSampleLength(NL: integer);
   procedure ChangeSampleLoop(NL: integer);
   procedure ValidateSample2(sam: integer);
   procedure ChangeOrnament(n: integer);
   procedure ChangeOrnamentLength(NL: integer);
   procedure ChangeOrnamentLoop(NL: integer);
   procedure ValidateOrnament(orn: integer);
   procedure ChangeNote(Pat, Line, Chan, Note: integer);
   procedure UpdatePatternTestLine(Pat, Line, Chan, CursorX, n: integer);
   procedure ChangeTracks(Pat, Line, Chan, CursorX, n: integer;
     Keyboard: boolean; CanUpdateTestLine: boolean = True);
   procedure Edit10ExitOrDone(Sender: TObject);
   procedure UDSamLoopChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);

   //Disable controls which wouldn't edit during playback
   procedure PlayStarts;

   //Calculate and show duration from module start up to selected position
   //(both seconds and ticks)
   procedure CalculatePos0;

   //Add duration from start of selected position to desired line of
   //its pattern to CalculatePos0's duration and show result
   procedure CalculatePos(Line: integer);

   procedure ShowStat;
   procedure CalcTotLen;
   procedure ReCalcTimes;
   procedure ShowAllTots;
   procedure SetInitDelay(nd: integer);
   procedure SetTitle(const ttl: string);
   procedure SetAuthor(const aut: string);

   //correct envelope periods after changing note table
   procedure UpdateEnvelopes(PrevNTNum: integer);

   procedure SetTable(nt: integer);

   //show tone table number and values
   procedure FillToneTableControls;

   //little description for selected note table
   procedure UpdateToneTableHints;

   procedure SamplesVolMouse(x, y: integer);
   procedure TracksMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure SamplesMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure OrnamentsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
   procedure CreateTestLines;
   procedure UDOrnChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure EdOrnChange(Sender: TObject);
   procedure EdOrnExitOrDone(Sender: TObject);
   procedure UDOrnLoopChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure EdOrnLoopExitOrDone(Sender: TObject);
   procedure UDOrnLenChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure EdOrnLenExitOrDone(Sender: TObject);
   procedure ToggleAutoEnv;
   procedure ToggleStdAutoEnv;
   procedure DoAutoEnv(i, j, k: integer);
   procedure DoAutoPrms(i, j, k: integer);
   procedure SBAutoEnvClick(Sender: TObject);
   procedure SBAutoEnvDigit1Click(Sender: TObject);
   procedure SBAutoEnvDigit2Click(Sender: TObject);
   procedure SGPositionsKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   procedure Edit14ExitOrDone(Sender: TObject);
   function DoStep(i: integer; StepForward: boolean): boolean;
   procedure SBSaveOrnClick(Sender: TObject);
   procedure SBLoadOrnClick(Sender: TObject);
   procedure LoadOrnament(FN: string);
   procedure LoadSample(FN: string);
   procedure LoadPattern(FN: string);
   procedure SBOrGenClick(Sender: TObject);
   procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);

   //User has been selected pattern by mouse clicking or via keyboard
   //or by selecting position
   procedure SelectPattern(aPat: integer);

   //Prepare pattern to show and use
   procedure ChangePattern(aPat: integer; FromLine: integer = 0);

   //User has been selected position cell by mouse clicking or via keyboard
   //Cell can be ouside playing order (Pos >= VTMP^.Positions.Length)
   procedure SelectPosition(aPos: integer);

   //Just store new posisition number and visualize its cell
   procedure ShowPosition(aPos: integer);

   //just set positions grid cells vith positions array values
   procedure RedrawPositions(From: integer = 0);

   //redraw positions cells, update progress bar and recalc total time
   procedure PositionsChanged(Since: integer = 0);

   //just check pos list length and set SBPositions.Max
   procedure SBPositionsUpdateMax;

   //insert positions after selected cell with new patterns
   //Modes: 0 - add; 1 - dupicate; 2 - clone
   procedure InsertPositions(Mode: integer);

   //delete selected positions
   procedure DeletePositions;

   //set pattern 'value' in position 'pos' and redraw tracks
   procedure ChangePositionValue(pos, Value: integer);

   //reorder pattern pointers using index
   procedure ChangePatternsOrder(Idx: PPatIndex; Reverse: boolean = False);

   //call GetFreeEmptyPattern and if got then prepare for adding to position list
   procedure GetFreeEmptyPattern2(var Used: TPatFlags; var DefPat: integer;
     DefLen: integer);

   //add positions to the end of list till selected cell
   procedure FillPositions;

   //paste clipboard numbers to SGPositions
   procedure PasteToPositionsList(Merge: boolean = False);

   procedure ToggleAutoStep;
   procedure SBSaveSamClick(Sender: TObject);
   procedure SBLoadSamClick(Sender: TObject);
   procedure SBLoadPatClick(Sender: TObject);
   procedure SBSavePatClick(Sender: TObject);
   procedure UDAutoHLChangingEx(Sender: TObject; var AllowChange: boolean;
     NewValue: smallint; Direction: TUpDownDirection);
   procedure AutoHLCheckClick(Sender: TObject);
   procedure CalcHLStep;
   procedure ChangeHLStep(NewStep: integer);
   procedure UDAutoHLClick(Sender: TObject; Button: TUDBtnType);
   procedure SetLoopPos(lp: integer);

   //OldP,NewP - parameter's values before and after changes
   //For some action OldP and NewP are pointers to old and new values
   //Idx - indexes in array/view/etc (if IdxN = auAutoIdxs, autodetect all Idxes)
   procedure AddUndo(CA: TChangeAction; OldP, NewP: PtrInt;
     IdxN: integer = -1; IdxX: integer = -1; IdxY: integer = -1; IdxZ: integer = -1);

   procedure DoUndo(Undo: boolean);

   //kill Undo list (True - all items, False - just after current item to the last one
   procedure DisposeUndo(All: boolean);

   procedure GroupLastChanges(From: integer); //group last edit actions for one step undo
   procedure SetFileName(aFileName: string);
   procedure SaveModule;
   procedure SaveModuleAs;
   procedure BringToFrontBoth; //bring to front and check if need to do same with TS-pair
   procedure ScrollWorkspace; //ensure that child in visible area of parent workspace
   procedure FormActivate(Sender: TObject);
   procedure GoToTime(Time: integer);
   procedure SinchronizeModules;
   function PrepareTSString(aTSBut: TSpeedButton; const s: string): string;
   procedure SBTSClick(Sender: TObject);
   procedure SetToolsPattern;
   procedure EdPatLenKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   function CanHookTSWindow: boolean;
   procedure HookTSWindow(Move: boolean = True);
   procedure DoMove; //message handler
   procedure DoResize; //message handler
   procedure SetNOfLines;
   //calculate number of lines  for current Height (for autosizable controls)
   procedure CheckTSString; //check TS string fitting on TS button
   procedure FullResize; //recalculate all sizes
   procedure ResizeTracksWidth; //recalculate tracks width
   function AcceptCannotUndo(const Op: string): boolean;
   procedure UpdateHints;

   //check if window playing itself or as ts-pair
   //if Result >= 0 then it is PlaybackWindow index
   function IsPlayingWindow: integer;

   //check if window exists in PlaybackWindow array
   //if Result >= 0 then it is PlaybackWindow index
   function IsPlaybackWindow: integer;

   //redraw sample or ornament (tlSamples or tlOrnaments)
   procedure BaseNoteChanged(tlIdx: integer);

   //translate message from (MIDI) keyboard to note and volume for
   //sample or ornament)
   function KeyToNote(var Key: word; Shift: TShiftState; out Note, Volu: integer;
     TL: TTestLine; OctaveToNote: boolean): boolean;

   //retrieve note from sample or ornament testline (tlSamples or tlOrnaments)
   //as base for "Shift as note" mode, return C-4 if absent
   function GetBaseNote(tlIdx: integer): integer;

   //update current sample tone shifts for new note
   procedure RecalcSample(NewNote: integer);

 protected
   procedure WMWindowPosChanged(var Message: TLMWindowPosChanged);
     message LM_WINDOWPOSCHANGED;
 private
   { Private declarations }
   FCaption: string;
 public
   { Public declarations }
   Tracks: TTracks;
   PatternTestLine, SampleTestLine, OrnamentTestLine: TTestLine;
   Samples: TSamples;
   Ornaments: TOrnaments;
   VTMP: PModule;
   PatNum, //selected and shown pattern
   SamNum, OrnNum: integer;
   SongChanged: boolean;
   InputPNumber, //field to store digits pressed by user (reset cyclically)
   PositionNumber, //selected and shown position
   PosBegin, //result of CalculatePos0
   PosDelay, //current Delay after CalculatePos0, used by CalculatePos()
   TotInts, LineInts: integer;
   AutoEnv, AutoStep: boolean;
   AutoEnv0, AutoEnv1, StdAutoEnvIndex: integer;
   ChangeCount, ChangeTop: integer;
   UndoWorking: boolean;
   ChangeList: array of TChangeListItem;
   ChannelControls: array[0..2] of TChannelControls;
   WinNumber: integer;
   WinFileName: string;
   SavedAsText: boolean;
   TSWindow: TChildForm;
   IsSinchronizing: boolean;
   IsSoftRepos: integer; //0 if Height, Width, Left or Top are set by user (not in code)
   ActiveControl: TWinControl;
   WinMenuItem: TMenuItem; //pointer to MainMenu->Window's item
   Moving: TClickedTarget; //for left mouse clicked at header or size border
   dX, dY: integer; //where header or size borders were clicked
   PosVisibleCols, //TStringGrid.VisibleColCount is not so exact for us

   //avoiding onselection handler called twice after correcting selection
   PosReselection: integer;

   Maximized: boolean; //is maximized child window?
   HeightBeforeMax, LeftBeforeMax, TopBeforeMax: integer;
   //child window size before maximizing
   constructor Create(TheOwner: TComponent); override;
   destructor Destroy; override;
   procedure Close;
   procedure SetForeground;
   function Active: boolean;
   procedure MoveWnd(DeltaX, DeltaY: integer);
   function SetHeight(Value: integer): boolean;
   procedure CheckCaptionFitting;
   procedure SetCaption(const aCapt: string);
   property Caption: string read FCaption write SetCaption;
   procedure SetFocusAtActiveControl;
   procedure PosSelectAll; //SBPositions->select all filled cells

   //maximize window or remaximize (after workspace resized)
   procedure Maximize(Remaximize: boolean = False);

   procedure Restore; //restore window
 end;

implementation

uses Main, options, selectts, TglSams, GlbTrn, TrkMng, keys, digsoundbuf, Languages;

 {$R *.lfm}

var
 MinWidth: integer; //minimal window width to fit all content

//extending noise "sign" bit (if need to use it as signed value)
function Nse(n: integer): shortint; inline;
begin
 if n and $10 = 0 then
   Nse := n and $F
 else
   Nse := n or $F0;
end;

//extending tone "sign" bit (if need to use it as signed value)
function Tne(n: integer): smallint; inline;
begin
 if n and $800 = 0 then
   Tne := n and $7FF
 else
   Tne := n or $F000;
end;

procedure CanvasInvertRect(C: TCanvas; const R: TRect);
var
 N: TColor;
begin
 N := C.Brush.Color;
 C.Pen.Color := clWhite;
 C.Brush.Color := clWhite;
 C.Pen.Width := 1;
 C.Pen.Mode := pmXor;
 C.Rectangle(Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1));
 C.Pen.Style := psDot;
 C.Pen.Cosmetic := False;
 C.Line(R.Right - 1, R.Bottom - 1, R.Left, R.Bottom - 1);
 C.Line(R.Right - 1, R.Bottom - 1, R.Right - 1, R.Top);
 C.Line(R.Left, R.Top, R.Right - 1, R.Top);
 C.Line(R.Left, R.Top, R.Left, R.Bottom - 1);
 C.Pen.Style := psSolid;
 C.Pen.Cosmetic := True;
 C.Pen.Mode := pmCopy;
 C.Rectangle(Rect(0, 0, 0, 0)); //update pen.mode
 C.Brush.Color := N;
 //  C.DrawFocusRect(R);
end;

 {//решение проблемы в gtk2
// https://forum.lazarus.freepascal.org/index.php?topic=27653.0
var
  _Pen:TPen;
procedure CanvasInvertRect(C: TCanvas; const R: TRect; AColor: TColor);
var
  X: integer;
  AM: TAntialiasingMode;
begin



  if not Assigned(_Pen) then
    _Pen:= TPen.Create;

  AM:= C.AntialiasingMode;
  _Pen.Assign(C.Pen);

  X:= (R.Left+R.Right) div 2;
  C.Pen.Mode:= pmNotXor;
  C.Pen.Style:= psSolid;
  C.Pen.Color:= AColor;
  C.AntialiasingMode:= amOff;
  C.Pen.EndCap:= pecFlat;
  C.Pen.Width:= R.Right-R.Left;

  C.MoveTo(X, R.Top);
  C.LineTo(X, R.Bottom);

  C.Pen.Assign(_Pen);
  C.AntialiasingMode:= AM;
  C.Rectangle(0, 0, 0, 0); //apply pen
end;}


procedure TChildForm.FormCreate(Sender: TObject);
var
 i: integer;
 t: TTextStyle;
begin
 //prevent rising various handlers or
 //some changes in FormCreate to be recorded to Undo list
 IsSoftRepos := 1;
 IsSinchronizing := True;
 UndoWorking := True;
 PosReselection := 1;
 Maximized := False;

 WinMenuItem := TMenuItem.Create(MainForm.Window1);
 WinMenuItem.RadioItem := True;
 WinMenuItem.GroupIndex := 1;
 WinMenuItem.Tag := PtrInt(Self);
 WinMenuItem.OnClick := @MainForm.WindowMenuItemClick;

 ActiveControl := nil;

 // Header.Top := ChildFrameWidth + SizeBorderWidth;
 EditorPages.Left := ChildFrameWidth;
 OnPaint := @ChildFormPaint;

 TSWindow := nil;
 WinFileName := '';
 SavedAsText := True;
 Moving := ctNone; //header ot size borders not clicked

 ChangeCount := 0;
 ChangeTop := 0;
 SetLength(ChangeList, 64);
 SaveTextDlg.InitialDir := ExtractFilePath(ParamStr(0));

 NewVTMP(VTMP);

 VTMP^.Ton_Table := VTOptions.NoteTable;
 FillToneTableControls;
 UpdateToneTableHints;

 SBSamAsNotes.Down := VTOptions.SamAsNote;
 SBOrnAsNotes.Down := VTOptions.OrnAsNote;

 UDPat.Max := MaxPatNum;
 UDPatLen.Max := MaxPatLen;
 UDAutoStep.Max := MaxPatLen;
 UDAutoStep.Min := -MaxPatLen;
 UDAutoStep.Position := VTOptions.AutoStepValue;
 UDAutoHL.Max := DefPatLen;
 UDSamLen.Max := MaxSamLen;
 UDSamLoop.Max := 1;
 UDOrnLen.Max := MaxOrnLen;
 UDOrnLoop.Max := 1;
 GBFeatures.ItemIndex := FeaturesLevel;
 GBHeader.ItemIndex := Ord(not VortexModuleHeader);

 PosVisibleCols := SGPositions.VisibleColCount; //just fail-safe, acually set in calcsize

 t := SGPositions.DefaultTextStyle;
 t.Alignment := taCenter;
 SGPositions.DefaultTextStyle := t;
 for i := 0 to 255 do
   SGPositions.Cells[i, 0] := '...';

 t := SGTable.DefaultTextStyle;
 t.Alignment := taCenter;
 SGTable.DefaultTextStyle := t;

 //creating and positioning test lines
 CreateTestLines;
 PatternTestLine.Top := SBAutoPars.Top + SBAutoPars.Height + 1;
 PatternTestLine.Left := SBAutoPars.Left;
 PatternTestLine.PopupMenu := MainForm.PMGeneral;
 PatternTestLine.Hint := Mes_HintTestPat;
 SampleTestLine.Top := EdSample.Top;
 SampleTestLine.Left := SBSamRecalc.Left + SBSamRecalc.Width + 4;
 SampleTestLine.TabOrder := 6;
 SampleTestLine.PopupMenu := MainForm.PMGeneral;
 SampleTestLine.Hint := Mes_HintTestSam;
 OrnamentTestLine.Top := EdOrn.Top;
 OrnamentTestLine.Left := SBOrnAsNotes.Left + SBOrnAsNotes.Width + 4;
 OrnamentTestLine.TabOrder := 6;
 OrnamentTestLine.PopupMenu := MainForm.PMGeneral;
 OrnamentTestLine.Hint := Mes_HintTestOrn;

 //creating and positioning tracks
 CreateTracks;
 Tracks.Left := EdTitle.Left;
 Tracks.Top := SBDecTrLines.Top + SBDecTrLines.Height + 4;
 Tracks.PopupMenu := MainForm.PMTracks;

 //creating and hooking samples to sizable PnSamsTop
 CreateSamples;
 Samples.AnchorSideLeft.Control := PnSamsTop;
 Samples.AnchorSideLeft.Side := asrTop;
 Samples.AnchorSideTop.Control := PnSamsTop;
 Samples.AnchorSideTop.Side := asrBottom;
 Samples.BorderSpacing.Top := PnSamsTop.Left;
 Samples.PopupMenu := MainForm.PMGeneral;

 //hooking samples right panel
 PnSamsRight.AnchorSideLeft.Control := Samples;
 PnSamsRight.AnchorSideLeft.Side := asrBottom;
 PnSamsRight.BorderSpacing.Left := PnSamsTop.Left;
 PnSamsRight.AnchorSideTop.Control := Samples;
 PnSamsRight.AnchorSideTop.Side := asrTop;

 //creating and hooking ornaments to sizable PnOrnsTop
 CreateOrnaments;
 Ornaments.AnchorSideLeft.Control := PnOrnsTop;
 Ornaments.AnchorSideLeft.Side := asrTop;
 Ornaments.AnchorSideTop.Control := PnOrnsTop;
 Ornaments.AnchorSideTop.Side := asrBottom;
 Ornaments.BorderSpacing.Top := PnOrnsTop.Left;
 Ornaments.PopupMenu := MainForm.PMGeneral;

 //hooking ornaments right panel
 PnOrnsRight.AnchorSideLeft.Control := Ornaments;
 PnOrnsRight.AnchorSideLeft.Side := asrBottom;
 PnOrnsRight.BorderSpacing.Left := PnOrnsTop.Left;
 PnOrnsRight.AnchorSideTop.Control := Ornaments;
 PnOrnsRight.AnchorSideTop.Side := asrTop;

 MinWidth := EdAuthor.Width + EdAuthor.Left + Tracks.Left;

 //initialize hints for some controls without associated actions (due dynamic shortcuts)
 UpdateHints;

 //initialaze vars
 ChangePattern(0);
 ChangeSample(1);
 ChangeOrnament(1);
 PositionNumber := 0;
 PosBegin := 0;
 LineInts := 0;
 PosDelay := VTMP^.Initial_Delay;
 TotInts := 0;
 AutoEnv := False;
 StdAutoEnvIndex := 0;
 AutoEnv0 := 1;
 AutoEnv1 := 1;
 AutoStep := False;
 ChannelControls[0].Mute := SBMuteA;
 ChannelControls[0].MuteT := SBMuteAT;
 ChannelControls[0].MuteN := SBMuteAN;
 ChannelControls[0].MuteE := SBMuteAE;
 ChannelControls[0].Solo := SBSoloA;
 ChannelControls[1].Mute := SBMuteB;
 ChannelControls[1].MuteT := SBMuteBT;
 ChannelControls[1].MuteN := SBMuteBN;
 ChannelControls[1].MuteE := SBMuteBE;
 ChannelControls[1].Solo := SBSoloB;
 ChannelControls[2].Mute := SBMuteC;
 ChannelControls[2].MuteT := SBMuteCT;
 ChannelControls[2].MuteN := SBMuteCN;
 ChannelControls[2].MuteE := SBMuteCE;
 ChannelControls[2].Solo := SBSoloC;
 SongChanged := False;

 //to block leave frame with cursor keys
 OnKeyDown := @FrameKeyDown;

 //After set Parent various handlers starting called in LCL,
 //but it need here for GetTextWidth, GetTextSize, etc
 Parent := TWinControl(Sender);

 FullResize;

 IsSoftRepos := 0;
 PosReselection := 0;

 IsSinchronizing := False;
 UndoWorking := False;

 //controls handle wmsetfocus while creating and copy hints to status bar, so reset it
 MainForm.MainStatusBar.SimpleText := '';

 Inc(MainForm.WinCount);
 WinNumber := MainForm.WinCount;
 Name := 'Child' + WinNumber.ToString;
 MainForm.Childs.Add(Self);
end;

procedure TChildForm.RemoveConstraints;
begin
 //reset window constraints
 Constraints.MinWidth := 0;
 Constraints.MaxWidth := 0;
 Constraints.MinHeight := 0;
 Constraints.MaxHeight := 0;
end;

procedure TChildForm.SBMaxClick(Sender: TObject);
begin
 MainForm.MaximizeChild(Self);
end;

procedure TChildForm.SBOrnAsNotesClick(Sender: TObject);
begin
 Ornaments.Invalidate;
end;

procedure TChildForm.SBPositionsScroll(Sender: TObject; ScrollCode: TScrollCode;
 var ScrollPos: integer);
begin
 if ScrollCode in [scLineUp, scLineDown, scPageUp, scPageDown, scTrack,
   scTop, scBottom] then
  begin
   if (ScrollCode = scLineDown) and (SGPositions.LeftCol >= ScrollPos) then
     //max used position reached, show unused
    begin
     ScrollPos := SGPositions.LeftCol;
     if (ScrollPos + 1 < VTMP^.Positions.Length) and
       (ScrollPos + PosVisibleCols < 256) then
       //at least one used pos must be visible
       Inc(ScrollPos);
    end;
   SGPositions.LeftCol := ScrollPos;
  end;
end;

procedure TChildForm.SBSamAsNotesClick(Sender: TObject);
begin
 with Samples do
  begin
   //correct selection
   if SBSamAsNotes.Down then
    begin
     if SelX in [4, 5] then
       SelX := 4;
     if CursorX in [4, 5] then
       CursorX := 4;
    end
   else if (CursorX = 4) and (SelX = 4) then //select both tone sign and shift cols
     CursorX := 5;

   if CursorX in [4..5] then
     //move and transform carret
    begin
     CalcCaretPos;
     RecreateCaret;
    end;

   //redraw and toggle selection
   Invalidate;
  end;
end;

procedure TChildForm.SGPositionsSelection(Sender: TObject; aCol, aRow: integer);
var
 aSel: TGridRect;
begin
 if PosReselection <> 0 then //don't handle if self selected
   Exit;
 Inc(PosReselection);
 aSel := SGPositions.Selection;
 if (aSel.Left < VTMP^.Positions.Length) and (aSel.Right >= VTMP^.Positions.Length) then
   //truncate selection at used/unused border
  begin
   aSel.Right := VTMP^.Positions.Length - 1;
   SGPositions.Selection := aSel;
  end
 else if aSel.Left >= VTMP^.Positions.Length then
   //only one cell can be selected in unused area
   PosRemoveSelection;
 Dec(PosReselection);
end;

procedure TChildForm.SGPositionsTopLeftChanged(Sender: TObject);
begin
 SBPositions.Position := SGPositions.LeftCol;
end;

procedure UDAnOctaveChangingEx(TL: TTestLine; var AllowChange: boolean;
 NewValue: smallint);
begin
 AllowChange := NewValue in [1..8]; //octave number to change
 if AllowChange then
   TL.TestOct := NewValue;
end;

procedure TChildForm.UDOctaveChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 UDAnOctaveChangingEx(PatternTestLine, AllowChange, NewValue);
end;

procedure TChildForm.UDOrnOctaveChangingEx(Sender: TObject;
 var AllowChange: boolean; NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 UDAnOctaveChangingEx(OrnamentTestLine, AllowChange, NewValue);
end;

procedure TChildForm.UDSamOctaveChangingEx(Sender: TObject;
 var AllowChange: boolean; NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 UDAnOctaveChangingEx(SampleTestLine, AllowChange, NewValue);
end;

procedure TChildForm.UpdateConstraints;
var
 i: integer;
begin
 RemoveConstraints;

 //fixed width
 Constraints.MinWidth := Width;
 Constraints.MaxWidth := Width;
 //at least 3 lines in track editor
 Constraints.MinHeight := Height - Tracks.ClientHeight + Tracks.CelH * 3;
 //  - GetSystemMetrics(SM_CYSIZEFRAME)*2 - GetSystemMetrics(SM_CYCAPTION); //LCL bug correction
 i := MainForm.Workspace.Height;
 if Height > i then
   Constraints.MaxHeight := Height
 else
   Constraints.MaxHeight := i;
end;

procedure TChildForm.CalcSize;
var
 i, w: integer;
begin
 RemoveConstraints;

 if Maximized then
  begin
   Header.Height := 0;
   Header.Top := 0;
  end
 else
  begin
   //apply new header height if system theme is changed
   Header.Height := GetSystemMetrics(SM_CYCAPTION);
   Header.Top := ChildFrameWidth + SizeBorderWidth;
  end;

 //remove some anchors
 EditorPages.Anchors := [akLeft, akTop];

 //calculating PatternsSheet client width (=EditorPages client width in Lazarus)
 i := Max(MinWidth, Tracks.Width + Tracks.Left * 2);
 i := Max(i, Samples.Width + Samples.Left * 3 + PnSamsRight.Width);
 i := Max(i, PatternTestLine.Left + PatternTestLine.Width + Tracks.Left);

 //correcting SGPositions client width to fit ceil number of cells
 SGPositions.ClientWidth := (i - SGPositions.Width + SGPositions.ClientWidth -
   //2 side borders
   Tracks.Left * 2 //2 side gap
   ) div SGPositions.DefaultColWidth * SGPositions.DefaultColWidth;
 //truncating partial ceil

 PosVisibleCols := SGPositions.ClientWidth div SGPositions.DefaultColWidth;

 SBPositions.PageSize := PosVisibleCols;
 SBPositions.LargeChange := PosVisibleCols;
 SBPositions.Position := SGPositions.LeftCol;

 //centering SGPositions
 SGPositions.Left := (i - SGPositions.Width) div 2;

 //set margin for SGPositions depending of test line height
 SGPositions.Top := Max(EdPatLen.Top + EdPatLen.Height + 4,
   PatternTestLine.Top + PatternTestLine.Height + 4);

 //set margin for Tracks
 Tracks.Top := {SGPositions.Top + SGPositions.Height} SBDecTrLines.Top +
   SBDecTrLines.Height + {8}4;

 //set auto parameters buttons pos and width
 w := Max(PatternTestLine.Width, i - SBAutoPars.Left - Tracks.Left);
 SBAutoPars.Width := w - SBAutoCmd.Width * 5;
 if SBAutoPars.Width >= SBAutoPars.Canvas.TextWidth(Mes_AutParFull) + 2 then
   SBAutoPars.Caption := Mes_AutParFull
 else if SBAutoPars.Width >= SBAutoPars.Canvas.TextWidth(Mes_AutParMid) + 2 then
   SBAutoPars.Caption := Mes_AutParMid
 else
   SBAutoPars.Caption := Mes_AutParSmall;

 //align options
 GBHeader.Width := i - GBHeader.Left - GBFeatures.Left;

 Inc(IsSoftRepos); //disable DoResize and DoMove handlers

 //setting EditorPages client width
 EditorPages.ClientWidth := i;

 //time info panel left coord
 Timings.Left := i - Timings.Width - Tracks.Left;

 //TS button width
 SBTS.Width := Timings.Left - 2 - Tracks.Left;

 //allign title/author
 EdTitle.Width := (i - LbBy.Width - 2 - Tracks.Left * 2) div 2;
 LbBy.Left := EdTitle.Left + EdTitle.Width + 1;
 EdAuthor.Width := EdTitle.Width;
 EdAuthor.Left := i - EdAuthor.Width - Tracks.Left;

 //calculating EditorPages client height
 EditorPages.ClientHeight := Tracks.Top + Tracks.Height + Tracks.Left;

 //call onresize handlers
 Samples.SetNOfLines;
 Ornaments.SetNOfLines;

 //setting ChildForm size rect and size constraints,
 Width := EditorPages.Left + EditorPages.Width + ChildFrameWidth;
 Height := EditorPages.Top + EditorPages.Height + ChildFrameWidth + SizeBorderWidth;

 UpdateConstraints;

 //anchoring all side of page control to enable its resizing
 EditorPages.Anchors := [akLeft, akRight, akTop, akBottom];

 Dec(IsSoftRepos);

 CheckCaptionFitting;
 CheckTSString;
 ResetChanAlloc;

 if Maximized then
   Maximize(True);
end;

procedure TChildForm.FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
begin
 MainForm.FormMouseWheelDown(Sender, Shift, MousePos, Handled);
end;

procedure TChildForm.FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
begin
 MainForm.FormMouseWheelUp(Sender, Shift, MousePos, Handled);
end;

procedure TChildForm.EditorPagesChange(Sender: TObject);
begin
 if EditorPages.ActivePage.CanSetFocus then
   //mask LCL error, bugreport created
   EditorPages.ActivePage.SetFocus;
end;

procedure TChildForm.SBAutoStepClick(Sender: TObject);
begin
 ToggleAutoStep;
end;

procedure TChildForm.SBDecNoiseClick(Sender: TObject);
begin
 Tracks.Invalidate;
end;

procedure TChildForm.SBDecTrLinesClick(Sender: TObject);
begin
 Tracks.DigN := 3 + Ord(SBDecTrLines.Down);
 ResizeTracksWidth;
 HookTSWindow;
end;

procedure TChildForm.SBEnvAsNoteClick(Sender: TObject);
begin
 with Tracks do
  begin
   //correct selection
   if SBEnvAsNote.Down then
    begin
     if SelX <= 3 then
       SelX := 0;
     if CursorX <= 3 then
       CursorX := 0;
    end
   else if (CursorX = 0) and (SelX = 0) then //select all EnvP cols
     CursorX := 3;

   if not Enabled then
     //when playing Tracks not enabled and has no selection
     ResetSelection
   else if CursorX in [0..3] then
     //move and transform carret
    begin
     CalcCaretPos;
     RecreateCaret;
    end;

   //redraw and toggle selection
   Invalidate;
  end;
end;

procedure TChildForm.SBTableAsClick(Sender: TObject);
begin
 FillToneTableControls;
end;

procedure TChildForm.SGPositionsEnter(Sender: TObject);
begin
 if SGPositions.Tag > 1 then //not clicked before
   SGPositions.Tag := 0; //reset "moved with pushed" button flag
end;

procedure TChildForm.SGPositionsExit(Sender: TObject);
begin
 SGPositions.Tag := 0; //reset "moved with pushed" button flag
end;

procedure TChildForm.SGPositionsMouseMove(Sender: TObject; Shift: TShiftState;
 X, Y: integer);
begin
 if SGPositions.Tag = 1 then //if pushed button then do signal
   SGPositions.Tag := 2;
end;

procedure TChildForm.SGPositionsMouseUp(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 //if was moving with pushed button
 SGPositions.Tag := 0;
end;

procedure TChildForm.CheckAutoPrmsUp;
begin
 if not SBAutoSmp.Down and not SBAutoEnvT.Down and not SBAutoOrn.Down and
   not SBAutoVol.Down and not SBAutoCmd.Down then
   SBAutoPars.Down := False;
end;

procedure TChildForm.FrameKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 //block leave control by arrow keys
 MainForm.CheckKeysAndActionsConflicts(Key, Shift, [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]);
end;

procedure TChildForm.SGTableKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 MainForm.CheckSGKeysAndActionsConflicts(Key, Shift);
end;

procedure TChildForm.SomeAutoParameterClick(Sender: TObject);
begin
 if (Sender as TSpeedButton).Down then
   SBAutoPars.Down := True
 else
   CheckAutoPrmsUp;
end;

procedure TChildForm.SBUnrollSampleClick(Sender: TObject);

//todo move to trfuncs?
 function SameTicks(t1, t2: TSampleTick): boolean;
 begin
   with t1 do
    begin
     if not Envelope_Enabled and not t2.Envelope_Enabled and
       (Amplitude = 0) and (t2.Amplitude = 0) then
       //both ticks are silent
       Exit(True);

     Result := not ((Mixer_Ton <> t2.Mixer_Ton) or
       (Mixer_Noise <> t2.Mixer_Noise) or (Envelope_Enabled <> t2.Envelope_Enabled) or
       (Ton_Accumulation <> t2.Ton_Accumulation) or
       (Mixer_Ton and (Add_to_Ton <> t2.Add_to_Ton)) or
       (Envelope_or_Noise_Accumulation <> t2.Envelope_or_Noise_Accumulation) or
       (Add_to_Envelope_or_Noise <> t2.Add_to_Envelope_or_Noise) or
       (Amplitude_Sliding <> t2.Amplitude_Sliding) or
       (Amplitude_Sliding and (Amplitude_Slide_Up <> t2.Amplitude_Slide_Up)) or
       (Amplitude <> t2.Amplitude));
    end;
 end;

var
 Sam: PSample;
 V, T, N, i, LineFrom, LineTo: integer;
 same: boolean;
begin
 if VTMP^.Samples[SamNum] = nil then
   Exit;

 New(Sam);
 Sam^.Loop := MaxSamLen - 1;
 Sam^.Length := MaxSamLen;
 Sam^.Enabled := True;
 FillChar(Sam^.Items, SizeOf(Sam^.Items), 0);

 LineFrom := 0;
 LineTo := 0;
 V := 0;
 T := 0;
 N := 0;
 while LineTo < MaxSamLen do
   with VTMP^.Samples[SamNum]^, Items[LineFrom] do
    begin
     if Amplitude_Sliding then
       if Amplitude_Slide_Up then
        begin
         Inc(V);
         if V > 15 then V := 15;
        end
       else
        begin
         Dec(V);
         if V < -15 then V := -15;
        end;
     i := Amplitude + V;
     if i > 15 then
       i := 15
     else if i < 0 then
       i := 0;
     Sam^.Items[LineTo].Amplitude := i;
     i := Add_to_Ton + T;
     Sam^.Items[LineTo].Add_to_Ton := i mod $1000;
     if Ton_Accumulation then
       T := i;
     i := Add_to_Envelope_or_Noise + N;
     if Mixer_Noise then //for noise 5-bit are enough
      begin
       Sam^.Items[LineTo].Add_to_Envelope_or_Noise := i and $f;
       if i and $10 <> 0 then
         Sam^.Items[LineTo].Add_to_Envelope_or_Noise :=
           Sam^.Items[LineTo].Add_to_Envelope_or_Noise or shortint($f0);
      end
     //for envelope -10..0F is too small, therefore stop sliding if exceed
     else if i > 15 then
       Sam^.Items[LineTo].Add_to_Envelope_or_Noise := 15
     else if i > -16 then
       Sam^.Items[LineTo].Add_to_Envelope_or_Noise := i
     else
       Sam^.Items[LineTo].Add_to_Envelope_or_Noise := -16;
     if Envelope_or_Noise_Accumulation then
       N := i;
     Sam^.Items[LineTo].Mixer_Ton := Mixer_Ton;
     Sam^.Items[LineTo].Mixer_Noise := Mixer_Noise;
     Sam^.Items[LineTo].Envelope_Enabled := Envelope_Enabled;
     Inc(LineFrom);
     Inc(LineTo);
     if LineFrom = Length then
      begin
       if LineTo > LineFrom then //at least 2 loops are ready
         //check if last 2 loops are same
        begin
         same := True;
         for i := LineTo - Length + Loop to LineTo - 1 do
           if not SameTicks(Sam^.Items[i - Length + Loop], Sam^.Items[i]) then
            begin
             same := False;
             Break;
            end;
         if same then //remove last loop and break
          begin
           Dec(LineTo, Length - Loop);
           Sam^.Loop := LineTo - Length + Loop;
           Break;
          end;
        end;
       LineFrom := Loop;
      end;
    end;

 if Sam^.Loop < LineTo - 1 then
   //if all ticks in loop are same we can replace it by one line
  begin
   same := True;
   for i := Sam^.Loop to LineTo - 2 do
     if not SameTicks(Sam^.Items[i], Sam^.Items[LineTo - 1]) then
      begin
       same := False;
       Break;
      end;
   if same then
     LineTo := Sam^.Loop + 1;
  end;

 if LineTo = Sam^.Loop + 1 then
   //additional optimization for 1 line loop
  begin
   while (LineTo > 1) and SameTicks(Sam^.Items[LineTo - 2], Sam^.Items[LineTo - 1]) do
     //remove duplicated line at end
     Dec(LineTo);
   Sam^.Loop := LineTo - 1;
  end;

 Sam^.Length := LineTo;

 same := LineTo = VTMP^.Samples[SamNum]^.Length;
 if same then
   for i := 0 to LineTo - 1 do
     if not SameTicks(Sam^.Items[i], VTMP^.Samples[SamNum]^.Items[i]) then
      begin
       same := False;
       Break;
      end;

 if same then
  begin
   Dispose(Sam);
   Exit;
  end;

 if LineTo < MaxSamLen then
   FillChar(Sam^.Items[LineTo], SizeOf(TSampleTick) * (MaxSamLen - LineTo), 0);

 SongChanged := True;
 AddUndo(CAUnrollSample,{%H-}PtrInt(VTMP^.Samples[SamNum]),{%H-}PtrInt(Sam), auAutoIdxs);
 ChangeSample(SamNum);
 with ChangeList[ChangeCount - 1].NewParams.prm.Idx, Samples do
   SampleLine := ShownFrom + CursorY;
end;

procedure TOrnaments.OrnamentsPaint(Sender: TObject);
begin
 RedrawOrnaments;
end;

procedure TSamples.SamplesPaint(Sender: TObject);
begin
 RedrawSamples;
end;

procedure TTestLine.TestLinePaint(Sender: TObject);
begin
 RedrawTestLine;
end;

procedure TTracks.TracksPaint(Sender: TObject);
begin
 RedrawTracks;
end;

procedure TChildForm.ResetChanAlloc;
var
 MuteW, MutesW, i, Lft: integer;
 MuteV: boolean;
 Capt: string;
begin
 with Tracks do
  begin
   ResetSelection;
   Invalidate;
   CalcCaretPos;

   MutesW := SBMuteAT.Height; //square if possible

   MuteW := 13 * CelW - MutesW * 4;
   MuteV := MuteW >= MutesW; //hide mute all if too tight

   i := 13 * CelW;
   if MuteV then
     Dec(i, MuteW);

   if MutesW * 4 > i then //no space for square buttons
     MutesW := i div 4;

   //left offset of first char in tracks
   Lft := Left + GetSystemMetrics(SM_CXBORDER) + BevelWidth;

   //speed of reallocation depends of number of controls in parrent window;
   //since controls moved from TMDIChild windows to one main window,
   //this method is too slow now :(
   //todo better
   for i := 0 to 2 do
     with ChannelControls[i] do
      begin
       Solo.Width := MutesW;
       Solo.Left := Lft + (MainForm.ChanAlloc[i] + 1) * 14 * CelW +
         (7 + DigN) * CelW - MutesW;
       MuteE.Width := MutesW;
       MuteE.Left := Solo.Left - MutesW;
       MuteN.Width := MutesW;
       MuteN.Left := MuteE.Left - MutesW;
       MuteT.Width := MutesW;
       MuteT.Left := MuteN.Left - MutesW;
      end;

   if MuteV then
     if MuteW > SBMuteA.Canvas.GetTextWidth(Mes_ChanFull + ' A') then
       Capt := Mes_ChanFull + ' '
     else if MuteW > SBMuteA.Canvas.GetTextWidth(Mes_ChanMid + ' A') then
       Capt := Mes_ChanMid + ' '
     else
       Capt := '';

   for i := 0 to 2 do
     with ChannelControls[i] do
      begin
       Mute.Visible := MuteV;
       if MuteV then
        begin
         Mute.Width := MuteW;
         Mute.Left := MuteT.Left - MuteW;
         Mute.Caption := Capt + char(Ord('A') + i);
        end;
      end;

   //repos other track header controls

   //dividers
   BvEnv.Left := Lft + ((DigN - 1) * 2 + 1) * CelW div 2;
   BvNoise.Left := Lft + ((DigN + 4) * 2 + 1) * CelW div 2;
   BvChanA.Left := Lft + ((DigN + 7) * 2 + 1) * CelW div 2;
   BvChanB.Left := Lft + ((DigN + 21) * 2 + 1) * CelW div 2;
   BvChanC.Left := Lft + ((DigN + 35) * 2 + 1) * CelW div 2;

   //buttons
   SBDecTrLines.Width := CelW * (DigN - 1);
   SBDecTrLines.Left := Lft;
   SBEnvAsNote.Width := CelW * 4;
   SBEnvAsNote.Left := Lft + DigN * CelW;
   SBDecNoise.Width := CelW * 2;
   SBDecNoise.Left := Lft + (DigN + 5) * CelW;
  end;
end;

constructor TTracks.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 Parent := TWinControl(AOwner);
 ControlStyle := [csClickEvents, csDoubleClicks, csFixedHeight,
   csCaptureMouse, csOpaque];
 TabStop := True;
 ParentColor := False;
 BorderStyle := bsSingle;
 HLStep := 4;
 DigN := 3 + Ord(VTOptions.DecTrLines);
 KeyPressed := 0;
 CelW := 1;
 CelH := 1; //need for SetFont first call will return True
 //  SetFont;
 CursorX := 0;
 ShownFrom := 0;
 //  SetNOfLines;
 NOfLines := VTOptions.TracksNOfLines;
 Clicked := False;
 ShownPattern := nil;
 OnPaint := @TracksPaint;
end;

procedure TChildForm.CreateTracks;
begin
 Tracks := TTracks.Create(PatternsSheet);
 with Tracks do
  begin
   ParWind := Self;
   SBDecTrLines.Down := VTOptions.DecTrLines;
   SBDecNoise.Down := VTOptions.DecNoise;
   SBEnvAsNote.Down := VTOptions.EnvAsNote;
   ShowHint := VTOptions.TracksHint;
   TabOrder := 0;
   OnKeyDown := @TracksKeyDown;
   OnKeyUp := @TracksKeyUp;
   OnMouseDown := @TracksMouseDown;
   OnMouseMove := @TracksMouseMove;
   OnMouseWheelUp := @TracksMouseWheelUp;
   OnMouseWheelDown := @TracksMouseWheelDown;
   OnDblClick := @TracksDblClick;
  end;
end;

constructor TTestLine.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 Parent := TWinControl(AOwner);
 ControlStyle := [csClickEvents, csDoubleClicks, csFixedHeight,
   csCaptureMouse, csOpaque];
 TabStop := True;
 ParentColor := False;
 BorderStyle := bsSingle;
 KeyPressed := 0;
 Clicked := False;
 //  SetFont;
 OnKeyDown := @TestLineKeyDown;
 OnKeyUp := @TestLineKeyUp;
 OnMouseDown := @TestLineMouseDown;
 OnMouseMove := @TestLineMouseMove;
 OnPaint := @TestLinePaint;
 FTestOct := 4;
 CursorX := 8;
 SelX := CursorX;
end;


procedure TTestLine.SetFont;
begin
 Font.Name := VTOptions.TestsFont.Name;
 Font.Size := VTOptions.TestsFont.Size;
 if VTOptions.TestsFont.Bold then
   Font.Style := [fsBold]
 else
   Font.Style := [];
 Canvas.GetTextSize('0', CelW, CelH);
 ClientWidth := CelW * 21;
 ClientHeight := CelH;
end;

procedure TChildForm.CreateTestLines;
begin
 PatternTestLine := TTestLine.Create(PatternsSheet);
 PatternTestLine.ParWind := Self;
 PatternTestLine.LineIndex := tlPatterns;
 PatternTestLine.OnDblClick := @TestLineDblClick;
 PatternTestLine.TabOrder := 15;

 SampleTestLine := TTestLine.Create(PnSamsTop);
 SampleTestLine.ParWind := Self;
 SampleTestLine.LineIndex := tlSamples;
 SampleTestLine.OnDblClick := @TestLineDblClick;

 OrnamentTestLine := TTestLine.Create(PnOrnsTop);
 OrnamentTestLine.ParWind := Self;
 OrnamentTestLine.LineIndex := tlOrnaments;
 OrnamentTestLine.OnDblClick := @TestLineDblClick;
end;

constructor TSamples.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 Parent := TWinControl(AOwner);
 ControlStyle := [csClickEvents, csDoubleClicks, csFixedHeight,
   csCaptureMouse, csOpaque];
 TabStop := True;
 ParentColor := False;
 BorderStyle := bsSingle;
 NOfLines := 16;
 // SetFont;
 OnPaint := @SamplesPaint;
 ClickedX := -1;
 ShownFrom := 0;
 CursorX := 0;
 CursorY := 0;
 SelX := CursorX;
 SelY := ShownFrom + CursorY;
 ShownSample := nil;
end;

procedure TSamples.SetFont;
begin
 Font.Name := VTOptions.SamplesFont.Name;
 Font.Size := VTOptions.SamplesFont.Size;
 if VTOptions.SamplesFont.Bold then
   Font.Style := [fsBold]
 else
   Font.Style := [];
 Canvas.GetTextSize('0', CelW, CelH);
 ClientWidth := CelW * 40;
end;

procedure TChildForm.CreateSamples;
begin
 Samples := TSamples.Create(SamplesSheet);
 Samples.ParWind := Self;
 //Samples.ClientHeight := Samples.CelH * Samples.NOfLines;
 Samples.ShowHint := VTOptions.SamHint;
 Samples.TabOrder := 0;
 Samples.OnKeyDown := @SamplesKeyDown;
 Samples.OnMouseDown := @SamplesMouseDown;
 Samples.OnMouseMove := @SamplesMouseMove;
 Samples.OnMouseWheelUp := @SamplesMouseWheelUp;
 Samples.OnMouseWheelDown := @SamplesMouseWheelDown;
 Samples.OnContextPopup := @SamplesContextPopup;
end;

constructor TOrnaments.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 Parent := TWinControl(AOwner);
 ControlStyle := [csClickEvents, csDoubleClicks, csFixedHeight,
   csFixedWidth, csCaptureMouse, csOpaque];
 TabStop := True;
 ParentColor := False;
 BorderStyle := bsSingle;
 OrnNRow := 16;
 OrnNCol := 5;
 //  SetFont;
 OnPaint := @OrnamentsPaint;
 NOfLines := OrnNCol * OrnNRow;
 Clicked := False;
 CursorX := 3;
 CursorY := 0;
 SelI := 0;
 ShownFrom := 0;
 ShownOrnament := nil;
end;

procedure TOrnaments.SetFont;
begin
 Font.Name := VTOptions.OrnamentsFont.Name;
 Font.Size := VTOptions.OrnamentsFont.Size;
 if VTOptions.OrnamentsFont.Bold then
   Font.Style := [fsBold]
 else
   Font.Style := [];
 Canvas.GetTextSize('0', CelW, CelH);
end;

procedure TChildForm.CreateOrnaments;
begin
 Ornaments := TOrnaments.Create(OrnamentsSheet);
 Ornaments.ParWind := Self;
 //Ornaments.ClientHeight := Ornaments.CelH * Ornaments.OrnNRow;
 Ornaments.ShowHint := VTOptions.OrnHint;
 Ornaments.TabOrder := 0;
 Ornaments.OnKeyDown := @OrnamentsKeyDown;
 Ornaments.OnMouseDown := @OrnamentsMouseDown;
 Ornaments.OnMouseMove := @OrnamentsMouseMove;
 Ornaments.OnMouseWheelUp := @OrnamentsMouseWheelUp;
 Ornaments.OnMouseWheelDown := @OrnamentsMouseWheelDown;
end;

procedure TTracks.SelectAll;
begin
 ShownFrom := 0;
 CursorY := N1OfLines;
 CursorX := 0;
 RecreateCaret;
 if ShownPattern = nil then
   SelY := DefPatLen - 1
 else
   SelY := ShownPattern^.Length - 1;
 SelX := 48;
 Invalidate;
 CalcCaretPos;
 TChildForm(ParWind).ShowStat;
end;

procedure TTracks.ToggleSelection;
var
 Y1, Y2, X1, X2, W: integer;
begin
 Y1 := SelY - ShownFrom + N1OfLines;
 if (SelX = CursorX) and (CursorY = Y1) then //selection is just carret, no need to draw
   Exit;
 Y2 := CursorY;
 if Y1 > Y2 then
  begin
   Y2 := Y1;
   Y1 := CursorY;
  end;
 //Correct bounds to visible (no need more since show dot border)
 //if Y1 < 0 then Y1 := 0;
 //if Y2 >= NOfLines then Y2 := NOfLines - 1;
 //if Y1 > Y2 then exit;
 X2 := CursorX;
 X1 := SelX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 if X2 in [8, 22, 36] then
   W := 3
 else if (X2 = 0) and (ParWind as TChildForm).SBEnvAsNote.Down then
   W := 4
 else
   W := 1;
 if Enabled and Focused then
   HideCaret(Handle);
 CanvasInvertRect(Canvas, Rect((X1 + DigN) * CelW, Y1 * CelH,
   (X2 + DigN + W) * CelW, (Y2 + 1) * CelH));
 if Enabled and Focused then
   ShowCaret(Handle);
end;

procedure TTracks.SetNOfLines(Keep: boolean = True);
begin
 if not Keep then
  begin
   NOfLines := ((ParWind as TChildForm).EditorPages.ClientHeight -
     Top - (BevelWidth - GetSystemMetrics(SM_CYBORDER)) * 2 - Left) div CelH;
   if NOfLines < 3 then
     NOfLines := 3
   else if NOfLines > MaxPatLen then
     NOfLines := MaxPatLen;
  end;
 N1OfLines := NOfLines div 2;

 //move cursor to hooked line and reset selection
 CursorY := N1OfLines;
 SelX := CursorX;
 SelY := ShownFrom - N1OfLines + CursorY;
 //todo надо ли пытаться сохранить положение курсора и корректировать выделение?

 ClientHeight := CelH * NOfLines;
 CalcCaretPos;
end;

function TTracks.SetFont: boolean;
var
 PrevW, PrevH: integer;
begin
 Font.Name := VTOptions.TracksFont.Name;
 Font.Size := VTOptions.TracksFont.Size;
 if VTOptions.TracksFont.Bold then
   Font.Style := [fsBold]
 else
   Font.Style := [];
 PrevW := CelW;
 PrevH := CelH;
 Canvas.GetTextSize('0', CelW, CelH);
 ClientWidth := CelW * (49 + DigN);
 Result := (PrevW <> CelW) or (PrevH <> CelH);
end;

procedure TTracks.ResetSelection;
begin
 SelX := CursorX;
 SelY := ShownFrom - N1OfLines + CursorY;
end;

procedure TTracks.AbortSelection;
begin
 ToggleSelection;
 ResetSelection;
end;

procedure TTracks.RedrawTracks;
var
 i, n, From, i1, k: integer;
 s: string;
 PLen, EnvN: integer;
 DecL, DecN: boolean;
begin
 if Enabled and Focused then
   HideCaret(Handle);
 From := (N1OfLines - ShownFrom);
 n := NOfLines - From;
 if ShownPattern = nil then
   PLen := DefPatLen
 else
   PLen := ShownPattern^.Length;
 if PLen < n then
   n := PLen;
 if From < 0 then
  begin
   i1 := -From;
   Inc(n, From);
   From := 0;
  end
 else
   i1 := 0;
 From := From * CelH;
 if From > 0 then
  begin
   Canvas.Brush.Color := VTOptions.TracksColorBgBeyond;
   Canvas.FillRect(0, 0, Width, From);
  end;
 Canvas.Brush.Color := VTOptions.TracksColorBg;
 Canvas.Font.Color := VTOptions.TracksColorTxt;
 k := CelH * N1OfLines;
 with ParWind as TChildForm do
  begin
   DecL := SBDecTrLines.Down;
   if SBEnvAsNote.Down then
     EnvN := UDTable.Position
   else
     EnvN := -1;
   DecN := SBDecNoise.Down;
  end;
 for i := i1 to i1 + n - 1 do
  begin
   s := GetPatternLineString(ShownPattern, i, @MainForm.ChanAlloc,
     True, DecL, EnvN, DecN);
   if From = k then
    begin
     Canvas.Brush.Color := VTOptions.TracksColorBgHlMain;
     Canvas.Font.Color := VTOptions.TracksColorTxtHlMain;
    end
   else if i mod HLStep = 0 then
     Canvas.Brush.Color := VTOptions.TracksColorBgHl;
   Canvas.TextOut(0, From, s);
   if From = k then
    begin
     Canvas.Brush.Color := VTOptions.TracksColorBg;
     Canvas.Font.Color := VTOptions.TracksColorTxt;
    end
   else if i mod HLStep = 0 then
     Canvas.Brush.Color := VTOptions.TracksColorBg;
   Inc(From, CelH);
  end;
 n := CelH * NOfLines;
 if From < n then
  begin
   Canvas.Brush.Color := VTOptions.TracksColorBgBeyond;
   Canvas.FillRect(0, From, Width, From + n);
  end;
 ToggleSelection;
 if Enabled and Focused then
   ShowCaret(Handle);
end;

procedure TTestLine.SelectAll;
begin
 CursorX := 0;
 RecreateCaret;
 SelX := 20;
 Invalidate;
 CalcCaretPos;
end;

procedure TTestLine.ToggleSelection;
var
 X1, X2, W: integer;
begin
 if SelX = CursorX then //selection is just carret, no need to draw
   Exit;
 X2 := CursorX;
 X1 := SelX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 if X2 = 8 then
   W := 3
 else
   W := 1;
 if Focused then
   HideCaret(Handle);
 CanvasInvertRect(Canvas, Rect(X1 * CelW, 0, (X2 + W) * CelW, CelH));
 if Focused then
   ShowCaret(Handle);
end;

procedure TTestLine.ResetSelection;
begin
 SelX := CursorX;
end;

procedure TTestLine.AbortSelection;
begin
 ToggleSelection;
 ResetSelection;
end;

procedure TTestLine.RedrawTestLine;
begin
 if Focused then
   HideCaret(Handle);
 Color := VTOptions.TestsColorBg;
 Font.Color := VTOptions.TestsColorTxt;
 Canvas.TextOut(0, 0, GetPatternLineString(
   TChildForm(ParWind).VTMP^.Patterns[-1], LineIndex));
 ToggleSelection;
 if Focused then
   ShowCaret(Handle);
end;

procedure TSamples.SelectAll;
begin
 ShownFrom := 0;
 CursorY := 0;
 CursorX := 0;
 RecreateCaret;
 if ShownSample = nil then
   SelY := 0
 else
   SelY := ShownSample^.Length - 1;
 SelX := 20;
 Invalidate;
 CalcCaretPos;
end;

procedure TSamples.ToggleSelection;
var
 Y1, Y2, X1, X2, W: integer;
begin
 Y1 := SelY - ShownFrom;
 if (SelX = CursorX) and (CursorY = Y1) then //selection is just carret, no need to draw
   Exit;
 Y2 := CursorY;
 if Y1 > Y2 then
  begin
   Y2 := Y1;
   Y1 := CursorY;
  end;
 //Correct bounds to visible (no need more since show dot border)
 //if Y1 < 0 then Y1 := 0;
 //if Y2 >= NOfLines then Y2 := NOfLines - 1;
 //if Y1 > Y2 then
 // Exit;
 X2 := CursorX;
 X1 := SelX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 if (X2 = 4) and TChildForm(ParWind).SBSamAsNotes.Down then
   W := 4
 else if X2 = 5 then
   W := 3
 else if X2 in [11, 14] then
   W := 2
 else
   W := 1;
 if Focused then
   HideCaret(Handle);
 CanvasInvertRect(Canvas, Rect((X1 + 3) * CelW, Y1 * CelH, (X2 + 3 + W) *
   CelW, (Y2 + 1) * CelH));
 if Focused then
   ShowCaret(Handle);
end;

procedure TSamples.SetNOfLines;
begin
 //calculating visible line in samples, then corresponding client height
 with ParWind as TChildForm do
   NOfLines := (EditorPages.ClientHeight - PnSamsTop.Top - PnSamsTop.Height -
     PnSamsTop.Left * 2) div CelH;
 if NOfLines < 1 then
   NOfLines := 1
 else if NOfLines > MaxSamLen then
   NOfLines := MaxSamLen;
 if ShownSample <> nil then
   //correct ShownFrom, calc new cursor and selection scoords
  begin
   Inc(CursorY, ShownFrom);
   if ShownFrom > ShownSample^.Length - NOfLines then
    begin
     ShownFrom := ShownSample^.Length - NOfLines;
     if ShownFrom < 0 then
       ShownFrom := 0;
    end;
   if CursorY < ShownFrom then
     ShownFrom := CursorY
   else if CursorY >= ShownFrom + NOfLines then
     ShownFrom := CursorY - NOfLines + 1;
   Dec(CursorY, ShownFrom);
   CalcCaretPos;
  end;
 ClientHeight := CelH * NOfLines;
end;

procedure TSamples.ResetSelection;
begin
 SelX := CursorX;
 SelY := ShownFrom + CursorY;
end;

procedure TSamples.AbortSelection;
begin
 ToggleSelection;
 ResetSelection;
end;

procedure TSamples.RedrawSamples;
var
 i, len, lp, dl: integer;

 procedure SetColors; inline;
 begin
   if i >= len then
    begin
     Canvas.Font.Color := VTOptions.SamplesColorTxtBeyond;
     if not VTOptions.SamOrnHLines or ((dl > 1) and ((i mod dl) <> 0)) then
       Canvas.Brush.Color := VTOptions.SamplesColorBgBeyond
     else
       Canvas.Brush.Color := VTOptions.SamplesColorBgBeyondHl;
    end
   else if i >= lp then
    begin
     Canvas.Font.Color := VTOptions.SamplesColorTxtLp;
     if not VTOptions.SamOrnHLines or ((dl > 1) and ((i mod dl) <> 0)) then
       Canvas.Brush.Color := VTOptions.SamplesColorBgLp
     else
       Canvas.Brush.Color := VTOptions.SamplesColorBgLpHl;
    end
   else
    begin
     Canvas.Font.Color := VTOptions.SamplesColorTxt;
     if not VTOptions.SamOrnHLines or ((dl > 1) and ((i mod dl) <> 0)) then
       Canvas.Brush.Color := VTOptions.SamplesColorBg
     else
       Canvas.Brush.Color := VTOptions.SamplesColorBgHl;
    end;
 end;

var
 k: integer;
 ShiftHelper: TShiftToNoteHelper;
 ShiftHelperPtr: PShiftToNoteHelper;
 s: string;
begin
 if Focused then
   HideCaret(Handle);
 if ShownSample = nil then
  begin
   len := 1;
   lp := 0;
  end
 else
  begin
   len := ShownSample^.Length;
   lp := ShownSample^.Loop;
  end;
 with TChildForm(ParWind) do
  begin
   dl := VTMP^.Initial_Delay;
   if SBSamAsNotes.Down then
    begin
     ShiftHelper.Shift := GetNoteFreq(VTMP^.Ton_Table, GetBaseNote(tlSamples));
     if ShownSample <> nil then
       for i := 0 to ShownFrom - 1 do
         if ShownSample^.Items[i].Ton_Accumulation then
           Inc(ShiftHelper.Shift, ShownSample^.Items[i].Add_to_Ton);
     ShiftHelper.VTMP := TChildForm(ParWind).VTMP;
     ShiftHelperPtr := @ShiftHelper;
    end
   else
     ShiftHelperPtr := nil;
  end;

 k := 0;
 for i := ShownFrom to ShownFrom + NOfLines - 1 do
  begin
   if i > MaxSamLen - 1 then
     Break;
   SetColors;
   s := IntToHex(i, 2) + '|';
   if ShownSample = nil then
    begin
     if ShiftHelperPtr = nil then
       s := s + 'tne +000_ +00(00)_ 0_                '
     else
       s := s + 'tne ' + GetNoteS(ShiftHelper.VTMP^.Ton_Table, ShiftHelper.Shift) +
         '_ +00(00)_ 0_                ';
    end
   else
     s := s + GetSampleString(ShownSample^.Items[i], True, True, ShiftHelperPtr);
   Canvas.TextOut(0, k, s);
   Inc(k, CelH);
  end;
 if k < Height then
  begin
   Canvas.Brush.Color := VTOptions.GlobalColorBgEmpty;
   Canvas.FillRect(0, k, Width, Height);
  end;
 ToggleSelection;
 if Focused then
   ShowCaret(Handle);
end;

procedure TOrnaments.SelectAll;
begin
 ShownFrom := 0;
 CursorY := 0;
 CursorX := 3;
 if ShownOrnament = nil then
   SelI := 0
 else
   SelI := ShownOrnament^.Length - 1;
 CalcCaretPos;
 Invalidate;
end;

procedure TOrnaments.ToggleSelection;
var
 I1, I2, c, f, t: integer;
begin
 I1 := (CursorX - 3) div 7 * OrnNRow + CursorY;
 I2 := SelI - ShownFrom;
 if I1 < 0 then
   I1 := 0
 else if I1 >= OrnNRow * OrnNCol then
   I1 := OrnNRow * OrnNCol - 1;
 if I2 < 0 then
   I2 := 0
 else if I2 >= OrnNRow * OrnNCol then
   I2 := OrnNRow * OrnNCol - 1;
 if I1 = I2 then //selection is just carret, no need to draw
   Exit;
 if I1 > I2 then
  begin
   c := I2;
   I2 := I1;
   I1 := c;
  end;

 if Focused then
   HideCaret(Handle);
 repeat
   c := I1 div OrnNRow;
   f := I1 mod OrnNRow;
   if I2 - I1 >= OrnNRow - f then
     t := OrnNRow
   else
     t := f + I2 - I1 + 1;
   CanvasInvertRect(Canvas, Rect((c * 7 + 3) * CelW, f * CelH,
     (c * 7 + 6) * CelW, t * CelH));
   Inc(I1, t - f);
 until I1 > I2;
 if Focused then
   ShowCaret(Handle);
end;

procedure TOrnaments.SetNOfLines;
var
 CursorI: integer;
begin
 CursorI := ShownFrom + CursorX div 7 * OrnNRow + CursorY;
 //calculating visible lines and rows in ornaments, then corresponding client height
 with ParWind as TChildForm do
  begin
   OrnNRow := (EditorPages.ClientHeight - PnOrnsTop.Top - PnOrnsTop.Height -
     PnOrnsTop.Left * 2) div CelH;
   if OrnNRow < 1 then
     OrnNRow := 1
   else if OrnNRow > MaxOrnLen then
     OrnNRow := MaxOrnLen;
   OrnNCol := (EditorPages.ClientWidth - Ornaments.Left * 3 - PnOrnsRight.Width) div
     (CelW * 7);
   if OrnNCol < 1 then
     OrnNCol := 1;
  end;
 NOfLines := OrnNCol * OrnNRow;
 if NOfLines > MaxOrnLen then
   NOfLines := MaxOrnLen;
 if ShownOrnament <> nil then
   //correct ShownFrom and calc new cursor coords
  begin
   if ShownFrom > ShownOrnament^.Length - NOfLines then
    begin
     ShownFrom := ShownOrnament^.Length - NOfLines;
     if ShownFrom < 0 then
       ShownFrom := 0;
    end;
   if CursorI < ShownFrom then
     ShownFrom := CursorI
   else if CursorI >= ShownFrom + NOfLines then
     ShownFrom := CursorI - NOfLines + 1;
   Dec(CursorI, ShownFrom);
   CursorX := CursorI div OrnNRow * 7 + 3;
   CursorY := CursorI mod OrnNRow;
   CalcCaretPos;
  end;
 ClientWidth := CelW * OrnNCol * 7;
 ClientHeight := CelH * OrnNRow;
end;

procedure TOrnaments.ResetSelection;
begin
 SelI := ShownFrom + CursorX div 7 * OrnNRow + CursorY;
end;

procedure TOrnaments.AbortSelection;
begin
 ToggleSelection;
 ResetSelection;
end;

procedure TOrnaments.RedrawOrnaments;
var
 i, len, lp, dl: integer;

 procedure SetColors; inline;
 begin
   if i >= len then
    begin
     Canvas.Font.Color := VTOptions.OrnamentsColorTxtBeyond;
     if not VTOptions.SamOrnHLines or ((dl > 1) and ((i mod dl) <> 0)) then
       Canvas.Brush.Color := VTOptions.OrnamentsColorBgBeyond
     else
       Canvas.Brush.Color := VTOptions.OrnamentsColorBgBeyondHl;
    end
   else if i >= lp then
    begin
     Canvas.Font.Color := VTOptions.OrnamentsColorTxtLp;
     if not VTOptions.SamOrnHLines or ((dl > 1) and ((i mod dl) <> 0)) then
       Canvas.Brush.Color := VTOptions.OrnamentsColorBgLp
     else
       Canvas.Brush.Color := VTOptions.OrnamentsColorBgLpHl;
    end
   else
    begin
     Canvas.Font.Color := VTOptions.OrnamentsColorTxt;
     if not VTOptions.SamOrnHLines or ((dl > 1) and ((i mod dl) <> 0)) then
       Canvas.Brush.Color := VTOptions.OrnamentsColorBg
     else
       Canvas.Brush.Color := VTOptions.OrnamentsColorBgHl;
    end;
 end;

var
 x, y, v, n: integer;
 s: string;
begin
 if Focused then
   HideCaret(Handle);
 if ShownOrnament = nil then
  begin
   len := 1;
   lp := 0;
  end
 else
  begin
   len := ShownOrnament^.Length;
   lp := ShownOrnament^.Loop;
  end;
 dl := TChildForm(ParWind).VTMP^.Initial_Delay;
 x := 0;
 y := 0;
 for i := ShownFrom to ShownFrom + NOfLines - 1 do
  begin
   if i > MaxOrnLen - 1 then
     Break;
   SetColors;
   s := IntToHex(i, 2) + '|';
   if ShownOrnament = nil then
     v := 0
   else
     v := ShownOrnament^.Items[i];
   if TChildForm(ParWind).SBOrnAsNotes.Down then
    begin
     n := TChildForm(ParWind).GetBaseNote(tlOrnaments) + v;
     if n < 0 then
       n := 0
     else if n > 95 then
       n := 95;
     s := s + NoteToStr(n) + ' ';
    end
   else if v >= 0 then
     s := s + '+' + Int2ToStr(v) + ' '
   else
     s := s + '-' + Int2ToStr(-v) + ' ';
   Canvas.TextOut(x, y, s);
   if (i - ShownFrom) mod OrnNRow = OrnNRow - 1 then
    begin
     y := 0;
     Inc(x, CelW * 7);
    end
   else
     Inc(y, CelH);
  end;
 if y < Height then
  begin
   Canvas.Brush.Color := VTOptions.GlobalColorBgEmpty;
   Canvas.FillRect(x, y, x + CelW * 7, Height);
   y := 0;
   Inc(x, CelW * 7);
  end;
 if x < Width then
  begin
   Canvas.Brush.Color := VTOptions.GlobalColorBgEmpty;
   Canvas.FillRect(x, y, Width, Height);
  end;
 ToggleSelection;
 if Focused then
   ShowCaret(Handle);
end;

const
 //Tracks editor tabulation positions
 ColTabs: array[0..11] of integer =
   (0, 5, 8, 12, 17, 22, 26, 31, 36, 40, 45, 49);

 //Sample editor tabulation positions, True for AsNote mode
 SColTabsMax = 5;
 SColTabs: array[boolean] of array[0..SColTabsMax] of integer =
   ((0, 5, 11, 14, 19, 20),
   (0, 4, 11, 14, 19, 20));

//Get right tab X coord
function TabRight(const Tabs: array of integer; X: integer): integer;
var
 i: integer;
begin
 for i := High(Tabs) - 1 downto 0 do
   if X >= Tabs[i] then
     Exit(Tabs[i + 1]);
 Result := Tabs[0];
end;

//Get left tab X coord
function TabLeft(const Tabs: array of integer; X: integer): integer;
var
 i: integer;
begin
 for i := 1 to High(Tabs) do
   if X <= Tabs[i] then
     Exit(Tabs[i - 1]);
 Result := Tabs[High(Tabs)];
end;

procedure TTracks.DoHint;
var
 s: string;
begin
 case CursorX of
   0..3:
    begin
     if TChildForm(ParWind).SBEnvAsNote.Down then
       s := Mes_HintPatEnvPAsNote1 + #13 + Mes_HintPatEnvPAsNote2
     else
       s := Mes_HintPatEnvPUsual;
     s += #13 + Mes_HintPatEnvPCommon;
    end;
   5..6: s := Mes_HintPatNsP;
   8, 22, 36:
    begin
     s := Mes_HintPatNt1 + #13 + Mes_HintPatNt2;
     s += NotKeyCustomInfo(NK_RELEASE, Mes_HintPatNt3, #13);
    end;
   12, 26, 40: s := Mes_HintPatSam1 + #13 + Mes_HintPatSam2;
   13, 27, 41: s := Mes_HintPatEnvT1 + #13 + Mes_HintPatEnvT2;
   14, 28, 42: s := Mes_HintPatOrn1 + #13 + Mes_HintPatOrn2;
   15, 29, 43: s := Mes_HintPatVol;
   17, 31, 45: s := Mes_HintPatSpecCmd1_1 + #13 + Mes_HintPatSpecCmd1_2 +
       #13 + Mes_HintPatSpecCmd1_3;
   18, 32, 46: s := Mes_HintPatSpecCmd2_1 + #13 + Mes_HintPatSpecCmd2_2;
   19, 33, 47: s := Mes_HintPatSpecCmd3_1 + #13 + Mes_HintPatSpecCmd3_2 +
       #13 + Mes_HintPatSpecCmd3_3 + #13 + Mes_HintPatSpecCmd3_4;
   20, 34, 48: s := Mes_HintPatSpecCmd4_1 + #13 + Mes_HintPatSpecCmd4_2 +
       #13 + Mes_HintPatSpecCmd4_3 + #13 + Mes_HintPatSpecCmd4_4 +
       #13 + Mes_HintPatSpecCmd4_5;
 else
   s := '';
  end;
 if not (CursorX in [19, 33, 47, 20, 34, 48]) then
  begin
   s += ShortcutActionCustomInfo(SCA_PatternAutoStep, Mes_HintPatAutStp, #13);
   s += ShortcutActionCustomInfo(SCA_PatternAutoEnv, Mes_HintPatAutEnv, #13);
   s += ShortcutActionCustomInfo(SCA_PatternAutoPrms, Mes_HintPatAutPrm, #13);
   s += #13 + Mes_HintPatAutStpVal;
  end;
 MainForm.MainStatusBar.SimpleText := s;
 Hint := s;
end;

procedure TTracks.CreateMyCaret;
begin
 if Enabled and Focused then
   DoHint;
 if CursorX in [8, 22, 36] then
   CaretSize := 3
 else if (ParWind as TChildForm).SBEnvAsNote.Down and (CursorX = 0) then
   CaretSize := 4
 else
   CaretSize := 1;
 if Enabled and Focused then
   CreateCaret(Handle, 0, CelW * CaretSize, CelH);
end;

procedure TTracks.RecreateCaret;
begin
 if Enabled and Focused then
   DoHint;
 if ((CursorX in [8, 22, 36]) and (CaretSize <> 3)) or
   ((ParWind as TChildForm).SBEnvAsNote.Down and (CursorX = 0) and (CaretSize <> 4)) or
   (CaretSize <> 1) then
  begin
   if Enabled and Focused then
     DestroyCaret(Handle);
   CreateMyCaret;
   if Enabled and Focused then
     ShowCaret(Handle);
  end;
end;

procedure TTracks.CalcCaretPos;
begin
 if Enabled and Focused then
   SetCaretPos(CelW * (DigN + CursorX), CelH * CursorY);
end;

procedure TTestLine.CreateMyCaret;
begin
 if CursorX = 8 then
  begin
   BigCaret := True;
   if Enabled and Focused then
     CreateCaret(Handle, 0, CelW * 3, CelH);
  end
 else
  begin
   BigCaret := False;
   if Enabled and Focused then
     CreateCaret(Handle, 0, CelW, CelH);
  end;
end;

procedure TTestLine.RecreateCaret;
begin
 if CursorX = 8 then
  begin
   if not BigCaret then
    begin
     if Enabled and Focused then
       DestroyCaret(Handle);
     CreateMyCaret;
     if Enabled and Focused then
       ShowCaret(Handle);
    end;
  end
 else if BigCaret then
  begin
   if Enabled and Focused then
     DestroyCaret(Handle);
   CreateMyCaret;
   if Enabled and Focused then
     ShowCaret(Handle);
  end;
end;

procedure TTestLine.CalcCaretPos;
begin
 if Enabled and Focused then
   SetCaretPos(CelW * CursorX, 0);
end;

procedure TSamples.DoHint;
const
 MB: array[boolean] of string = (Mes_HintSamEnd2, Mes_HintSamEnd3);
var
 s: string;
begin
 case CursorX of
   0: s := Mes_HintSamT;
   1: s := Mes_HintSamN;
   2: s := Mes_HintSamE;
   4: begin
     if TChildForm(ParWind).SBSamAsNotes.Down then
       s := Mes_HintSamTShiftAsNote1 + #13 + Mes_HintSamTShiftAsNote2
     else
       s := Mes_HintSamTShiftS;
    end;
   5: s := Mes_HintSamTShift;
   8: s := Mes_HintSamTShiftAcc;
   10: s := Mes_HintSamNShiftS;
   11: s := Mes_HintSamNShift1 + #13 + Mes_HintSamNShift2;
   14: s := Mes_HintSamNShiftAbs1 + #13 + Mes_HintSamNShiftAbs2 +
       #13 + Mes_HintSamNShiftAbs3;
   17: s := Mes_HintSamNShiftAcc;
   19: s := Mes_HintSamAmp1 + #13 + Mes_HintSamAmp2;
   20: s := Mes_HintSamVolAcc1 + #13 + Mes_HintSamVolAcc2 + #13 +
       Mes_HintSamVolAcc3 + #13 + Mes_HintSamVolAcc4;
 else
   s := '';
  end;
 if s <> '' then
   s += #13 + Mes_HintSamEnd1 + #13 + MB[VTOptions.LMBToDraw];
 MainForm.MainStatusBar.SimpleText := s;
 Hint := s;
end;

procedure TSamples.CreateMyCaret;
begin
 if Enabled and Focused then
   DoHint;
 CaretSize := 1;
 if TChildForm(ParWind).SBSamAsNotes.Down then
  begin
   if CursorX = 4 then //SamAsNote mode in 4..7 cols
     CaretSize := 4;
  end
 else if CursorX = 5 then
   CaretSize := 3;
 if CursorX in [11, 14] then
   CaretSize := 2;
 if Enabled and Focused then
   CreateCaret(Handle, 0, CelW * CaretSize, CelH);
end;

procedure TSamples.RecreateCaret;
begin
 if Enabled and Focused then
   DoHint;
 if ((CursorX = 5) and (CaretSize <> 3)) or ((CursorX in [11, 14]) and
   (CaretSize <> 2)) or (TChildForm(ParWind).SBSamAsNotes.Down and
   (CursorX = 4) and (CaretSize <> 4)) or
   (((not TChildForm(ParWind).SBSamAsNotes.Down and (CursorX = 4)) or
   (CursorX in [0..2, 4, 8, 10, 17, 19..20])) and (CaretSize <> 1)) then
  begin
   if Enabled and Focused then
     DestroyCaret(Handle);
   CreateMyCaret;
   if Enabled and Focused then
     ShowCaret(Handle);
  end;
end;

procedure TSamples.CalcCaretPos;
begin
 if Enabled and Focused then
   SetCaretPos(CelW * (3 + CursorX), CelH * CursorY);
end;

procedure TOrnaments.CalcCaretPos;
begin
 if Enabled and Focused then
  begin
   SetCaretPos(CelW * CursorX, CelH * CursorY);
   DoHint;
  end;
end;

procedure TOrnaments.DoHint;
begin
 Hint := Mes_HintOrn1 + #13 + Mes_HintOrn2 + #13 + Mes_HintOrn3 + #13 + Mes_HintOrn4;
 MainForm.MainStatusBar.SimpleText := Hint;
end;

procedure TChildForm.ChangeNote(Pat, Line, Chan, Note: integer);
var
 f: boolean;
begin
 f := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Note <> Note;
 if f then
   SongChanged := True;
 if VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Note >= 0 then
   //need to test portamento
   VTMP^.Saves.Chns[Chan].Nt := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Note
 else if Note >= 0 then
   VTMP^.Saves.Chns[Chan].Nt := Note;
 if not UndoWorking and f then
   AddUndo(CAChangeNote, VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Note,
     Note, Pat, Line, Chan);
 VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Note := Note;
end;

procedure TChildForm.UpdatePatternTestLine(Pat, Line, Chan, CursorX, n: integer);
begin
 with VTMP^.Patterns[-1]^.Items[tlPatterns] do
   case CursorX of
     0..3:
       Envelope := n;
     5..6:
       Noise := n;
     12, 26, 40:
       Channel[0].Sample := n;
     13, 27, 41:
       Channel[0].Envelope := n;
     14, 28, 42:
       Channel[0].Ornament := n;
     15, 29, 43:
       Channel[0].Volume := n;
     17, 31, 45:
      begin
       Channel[0].Additional_Command.Number := n;
       Channel[0].Additional_Command.Delay :=
         VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Delay;
       Channel[0].Additional_Command.Parameter :=
         VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Parameter;
      end;
     18, 32, 46:
      begin
       Channel[0].Additional_Command.Delay := n;
       Channel[0].Additional_Command.Number :=
         VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Number;
       Channel[0].Additional_Command.Parameter :=
         VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Parameter;
      end;
     19..20, 33..34, 47..48:
      begin
       Channel[0].Additional_Command.Parameter := n;
       Channel[0].Additional_Command.Number :=
         VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Number;
       Channel[0].Additional_Command.Delay :=
         VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Delay;
      end;
    end;
 PatternTestLine.Invalidate;
end;

procedure TChildForm.ChangeTracks(Pat, Line, Chan, CursorX, n: integer;
 Keyboard: boolean; CanUpdateTestLine: boolean = True);
var
 old, r: integer;
begin
 case CursorX of
   0..3:
    begin
     old := VTMP^.Patterns[Pat]^.Items[Line].Envelope;
     if Keyboard then
      begin
       r := 4 * (3 - CursorX);
       n := (old and ($FFFF xor (15 shl r))) or ((n and 15) shl r);
      end;
    end;
   5..6:
    begin
     old := VTMP^.Patterns[Pat]^.Items[Line].Noise;
     if Keyboard then
       if SBDecNoise.Down then
        begin
         if CursorX = 5 then //1st digit
          begin
           n := old mod 10 + n * 10;
           if n > 31 then //extra case in decimal mode, need check range
             n := 31;
          end
         else //2nd digit
           n := old div 10 * 10 + n;
        end
       else
        begin
         r := 4 * (6 - CursorX);
         n := (old and ($FF xor (15 shl r))) or ((n and 15) shl r);
        end;
    end;
   12, 26, 40:
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Sample;
   13, 27, 41:
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Envelope;
   14, 28, 42:
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Ornament;
   15, 29, 43:
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Volume;
   17, 31, 45:
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Number;
   18, 32, 46:
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Delay;
   19..20, 33..34, 47..48:
    begin
     old := VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Parameter;
     if Keyboard then
       if CursorX and 1 <> 0 then
         n := (old and 15) or (n shl 4)
       else
         n := (old and $F0) or n;
    end;
  end;

 if not UndoWorking and CanUpdateTestLine then
   UpdatePatternTestLine(Pat, Line, Chan, CursorX, n);

 if old = n then
   Exit;

 if not UndoWorking then
  begin
   case CursorX of
     0..3:
       AddUndo(CAChangeEnvelopePeriod, old, n, Pat, Line, Chan, CursorX);
     5..6:
       AddUndo(CAChangeNoise, old, n, Pat, Line, Chan, CursorX);
     12, 26, 40:
       AddUndo(CAChangeSample, old, n, Pat, Line, Chan);
     13, 27, 41:
       AddUndo(CAChangeEnvelopeType, old, n, Pat, Line, Chan);
     14, 28, 42:
       AddUndo(CAChangeOrnament, old, n, Pat, Line, Chan);
     15, 29, 43:
       AddUndo(CAChangeVolume, old, n, Pat, Line, Chan);
     17, 31, 45:
       AddUndo(CAChangeSpecialCommandNumber, old, n, Pat, Line, Chan);
     18, 32, 46:
       AddUndo(CAChangeSpecialCommandDelay, old, n, Pat, Line, Chan);
     19..20, 33..34, 47..48:
       AddUndo(CAChangeSpecialCommandParameter, old, n, Pat, Line, Chan, CursorX);
    end;
  end;

 SongChanged := True;

 case CursorX of
   0..3:
    begin
     if (VTMP^.Patterns[Pat]^.Items[Line].Channel[0].Envelope in [1..14]) or
       (VTMP^.Patterns[Pat]^.Items[Line].Channel[1].Envelope in [1..14]) or
       (VTMP^.Patterns[Pat]^.Items[Line].Channel[2].Envelope in [1..14]) then
       VTMP^.Saves.EnvP := n;
     VTMP^.Patterns[Pat]^.Items[Line].Envelope := n;
    end;
   5..6:
     VTMP^.Patterns[Pat]^.Items[Line].Noise := n;
   12, 26, 40:
    begin
     if (n <> 0) and (VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Note <> NT_NO) then
       VTMP^.Saves.Chns[Chan].Smp := n;
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Sample := n;
     ToglSams.CheckUsedSamples;
    end;
   13, 27, 41:
    begin
     if n in [1..14] then
       VTMP^.Saves.Chns[Chan].EnvT := n;
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Envelope := n;
    end;
   14, 28, 42:
    begin
     if (n <> 0) or (VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Envelope <> 0) then
       VTMP^.Saves.Chns[Chan].Orn := n;
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Ornament := n;
    end;
   15, 29, 43:
    begin
     if n > 0 then
       VTMP^.Saves.Chns[Chan].Vol := n;
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Volume := n;
    end;
   17, 31, 45:
    begin
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Number := n;
     if (old = 11) or (n = 11) then
       //tempo changed
       CalcTotLen;
    end;
   18, 32, 46:
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Delay := n;
   19..20, 33..34, 47..48:
    begin
     VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Parameter := n;
     if VTMP^.Patterns[Pat]^.Items[Line].Channel[Chan].Additional_Command.Number
       = 11 then
       //tempo changed
       CalcTotLen;
    end;
  end;

end;

function Velocity2Volume(V: integer): integer;
begin
 if V < 31 then
   Exit(1);
 if V > 80 then
   Exit(15);
 Result := (V - 31) * 14 div (80 - 31) + 1; //linear
end;

procedure TChildForm.TracksKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);

 procedure GoToNextWindow(Right: boolean);
 begin
   if not (ssShift in Shift) then
     Tracks.AbortSelection;
   if (TSWindow <> nil) and (TSWindow <> Self) and TSWindow.Tracks.Enabled then
     //goto corresp. side of TS-pair
    begin
     TSWindow.Tracks.AbortSelection;
     if Right then TSWindow.Tracks.CursorX := 48
     else
       TSWindow.Tracks.CursorX := 0;
     TSWindow.Tracks.ResetSelection;
     TSWindow.EditorPages.ActivePageIndex := 0;
     TSWindow.SetForeground;
     if TSWindow.Tracks.CanSetFocus then TSWindow.Tracks.SetFocus;
    end
   else
     //wrap cursor to other side of same window (special for Lee Bee)
    begin
     Tracks.ToggleSelection;
     if Right then Tracks.CursorX := 48
     else
       Tracks.CursorX := 0;
     Tracks.RecreateCaret;
     Tracks.CalcCaretPos;
     if ssShift in Shift then
       Tracks.ToggleSelection
     else
       Tracks.ResetSelection;
    end;
 end;

 procedure DoNoteKey;
 var
   Note, Volu, i, c, ChangesStart: integer;
   e: word;
 begin
   if Key and $8000 <> 0 then //MIDI key flag
    begin
     Volu := Velocity2Volume((Key and $7F00) shr 8);
     Note := Key and $7F;
     Key := Key and $807F; //clear velocity info
    end
   else
    begin
     if Key >= 256 then
       Exit;
     Note := NoteKeys[Key]; //need -3 correction (see TNoteKeyCodes comment)
     if Note = 0 then
       Exit;
     if Note >= Ord(NK_OCTAVE1) then
      begin
       if Shift = [] then
        begin
         PatternTestLine.TestOct := Note - Ord(NK_OCTAVE1) + 1;
         UDOctave.Position := PatternTestLine.TestOct;
         Key := 0;
        end;
       Exit;
      end;
     Dec(Note, 3);
     Volu := 0;
    end;
   if Note >= 0 then
    begin
     if Key < 256 then //usual keyboard works with octave number
      begin
       Inc(Note, (UDOctave.Position - 1) * 12);
       if Shift = [ssShift] then
         Inc(Note, 12)
       else if Shift = [ssShift, ssCtrl] then
         Dec(Note, 12)
       else if Shift <> [] then
         Exit;
      end;
     if Tracks.CursorX in [0..3] then //EnvAsNote can be in 0th octave
      begin
       Inc(Note, 12);
       i := 95 + 12;
      end
     else
       i := 95;
     if Key and $8000 <> 0 then //MIDI key flag
       Dec(Note, 24);
     if (Note < 0) or (Note > i) then
       Exit;
    end
   else if Shift <> [] then
     Exit;
   Tracks.KeyPressed := Key;
   Key := 0; //ignoring shifts to fine switching if user tries play as legato
   ValidatePattern2(PatNum);
   i := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
   if (i >= 0) and (i < Tracks.ShownPattern^.Length) then
    begin
     ChangesStart := ChangeCount; //store next undo index
     if Tracks.CursorX in [0..3] then
      begin
       if not Note2EnvP(VTMP^.Patterns[PatNum], i, Note, VTMP^.Ton_Table, c, e) then
         Exit;
       ChangeTracks(PatNum, i, -1, Tracks.CursorX, e, False);
       if (Note > 0) and (c >= 0) and AutoEnv then
        begin
         Note := Note - 12 - round(12 * log2(AutoEnv1 / AutoEnv0));
         if Note in [0..95] then
           ChangeNote(PatNum, i, c, Note);
        end;
      end
     else
      begin
       c := MainForm.ChanAlloc[(Tracks.CursorX - 8) div 14];
       ChangeNote(PatNum, i, c, Note);
       if (Volu <> 0) and MainForm.TBMidiV.Down then //use volume from midi
         if not (SBAutoPars.Down and SBAutoVol.Down) then
           //if is volume in autoparameters don't change
           ChangeTracks(PatNum, i, c, 15, Volu, False);
       DoAutoPrms(PatNum, i, c);
       DoAutoEnv(PatNum, i, c);
      end;
     GroupLastChanges(ChangesStart);
     if DoStep(i, True) then
       ShowStat;
     Tracks.ResetSelection;
     Tracks.Invalidate;
     RestartPlayingLine(i);
    end;
 end;

 procedure DoOtherKeys;
 var
   i, n, c, ChangesStart: integer;
 begin
   if Shift <> [] then
     Exit;
   ValidatePattern2(PatNum);
   i := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
   if (i < 0) or (i >= Tracks.ShownPattern^.Length) then
     Exit;
   ChangesStart := ChangeCount; //store next undo index
   if Tracks.CursorX = 5 then //noise 1st digit
    begin
     if SBDecNoise.Down then
       c := 3
     else
       c := 1;
    end
   else if Tracks.CursorX = 6 then //noise 2nd digit
    begin
     if SBDecNoise.Down then
      begin
       if VTMP^.Patterns[PatNum]^.Items[i].Noise div 10 < 3 then
         c := 9
       else
         c := 1;
      end
     else
       c := 15;
    end
   else if Tracks.CursorX in SamPoses then
     c := 31
   else
     c := 15;
   case Key of
     VK_0..VK_9:
       n := Key - VK_0;
     //special for Lee Bee
     VK_NUMPAD0..VK_NUMPAD9:
       n := Key - VK_NUMPAD0;
     VK_A..VK_V:
      begin
       if (Tracks.CursorX in [5, 6]) and SBDecNoise.Down then //decimal noise
         Exit;
       n := Key - VK_A + 10;
      end;
   else
     Exit;
    end;
   if (n < 0) or (n > c) then
     Exit;
   Tracks.KeyPressed := Key;
   Key := 0; //ignoring shifts to fine switching if user tries play as legato
   c := (Tracks.CursorX - 8) div 14;
   if c >= 0 then c := MainForm.ChanAlloc[c];
   ChangeTracks(PatNum, i, c, Tracks.CursorX, n, True);
   if Tracks.CursorX in [13, 27, 41] then
    begin
     DoAutoEnv(PatNum, i, c);
     GroupLastChanges(ChangesStart);
    end;
   if DoStep(i, True) then
     ShowStat;
   Tracks.ResetSelection;
   Tracks.Invalidate;
   RestartPlayingLine(i);
 end;

 procedure DoCursorDown;
 var
   To1, PLen: integer;
 begin
   if Tracks.ShownPattern = nil then
     PLen := DefPatLen
   else
     PLen := Tracks.ShownPattern^.Length;
   To1 := PLen - Tracks.ShownFrom + Tracks.N1OfLines;
   if To1 > Tracks.NOfLines then
     To1 := Tracks.NOfLines;
   if (Tracks.CursorY < To1 - 1) and (Tracks.CursorY <> Tracks.N1OfLines) then
    begin
     if ssShift in Shift then
       Tracks.ToggleSelection;
     Inc(Tracks.CursorY);
     Tracks.CalcCaretPos;
     if ssShift in Shift then
       Tracks.ToggleSelection
     else
       Tracks.ResetSelection;
    end
   else if Tracks.ShownFrom < PLen - Tracks.CursorY - 1 + Tracks.N1OfLines then
    begin
     Inc(Tracks.ShownFrom);
     if not (ssShift in Shift) then
       Tracks.ResetSelection;
     Tracks.Invalidate;
    end
   else if Shift = [] then
    begin
     Tracks.ShownFrom := 0;
     Tracks.CursorY := Tracks.N1OfLines;
     Tracks.ResetSelection;
     Tracks.Invalidate;
     Tracks.CalcCaretPos;
    end;
   ShowStat;
   Key := 0;
 end;

 procedure DoCursorUp;
 var
   From, PLen: integer;
 begin
   From := (Tracks.N1OfLines - Tracks.ShownFrom);
   if From < 0 then
     From := 0;
   if (Tracks.CursorY > From) and (Tracks.CursorY <> Tracks.N1OfLines) then
    begin
     Tracks.ToggleSelection;
     Dec(Tracks.CursorY);
     Tracks.CalcCaretPos;
     if ssShift in Shift then
       Tracks.ToggleSelection
     else
       Tracks.ResetSelection;
    end
   else if Tracks.ShownFrom > Tracks.N1OfLines - Tracks.CursorY then
    begin
     Dec(Tracks.ShownFrom);
     if not (ssShift in Shift) then Tracks.ResetSelection;
     Tracks.Invalidate;
    end
   else if Shift = [] then
    begin
     if Tracks.ShownPattern = nil then
       PLen := DefPatLen
     else
       PLen := Tracks.ShownPattern^.Length;
     Tracks.ShownFrom := PLen - 1;
     Tracks.CursorY := Tracks.N1OfLines;
     Tracks.ResetSelection;
     Tracks.Invalidate;
     Tracks.CalcCaretPos;
    end;
   ShowStat;
   Key := 0;
 end;

 procedure DoCursorLeft(Ctrl: boolean);
 var
   min: integer;
 begin
   min := 0;
   if Ctrl then min := 4;
   if Tracks.CursorX > min then
    begin
     Tracks.ToggleSelection;
     if Ctrl then
       Tracks.CursorX := TabLeft(ColTabs, Tracks.CursorX)
     else
      begin
       if Tracks.CursorX in [12, 26, 40] then
         Dec(Tracks.CursorX, 4)
       else if SBEnvAsNote.Down and (Tracks.CursorX = 5) then
         Tracks.CursorX := 0
       else if ColSpace(Tracks.CursorX - 1) then
         Dec(Tracks.CursorX, 2)
       else
         Dec(Tracks.CursorX);
      end;
     Tracks.RecreateCaret;
     Tracks.CalcCaretPos;
     if ssShift in Shift then
       Tracks.ToggleSelection
     else
       Tracks.ResetSelection;
    end
   else
     GoToNextWindow(True);
   Key := 0;
 end;

 procedure DoCursorRight(Ctrl: boolean);
 var
   max: integer;
 begin
   if Ctrl then
     max := 44
   else
     max := 48;
   if Tracks.CursorX < max then
    begin
     Tracks.ToggleSelection;
     if Ctrl then
       Tracks.CursorX := TabRight(ColTabs, Tracks.CursorX)
     else
      begin
       if SBEnvAsNote.Down and (Tracks.CursorX = 0) then
         Tracks.CursorX := 5
       else
        begin
         Inc(Tracks.CursorX);
         if ColSpace(Tracks.CursorX) then
           Inc(Tracks.CursorX)
         else if Tracks.CursorX in [9, 23, 37] then
           Inc(Tracks.CursorX, 3);
        end;
      end;
     Tracks.RecreateCaret;
     Tracks.CalcCaretPos;
     if ssShift in Shift then
       Tracks.ToggleSelection
     else
       Tracks.ResetSelection;
    end
   else
     GoToNextWindow(False);
   Key := 0;
 end;

 procedure DoCursorHome(Ctrl: boolean);
 begin
   Tracks.ToggleSelection;
   Tracks.CursorX := 0;
   Tracks.RecreateCaret;
   if Ctrl then
    begin
     Tracks.ShownFrom := 0;
     Tracks.CursorY := Tracks.N1OfLines;
     if not (ssShift in Shift) then Tracks.ResetSelection;
     ShowStat;
     Tracks.Invalidate;
    end;
   Tracks.CalcCaretPos;
   if not Ctrl and (ssShift in Shift) then Tracks.ToggleSelection;
   if not (ssShift in Shift) then Tracks.ResetSelection;
   Key := 0;
 end;

 procedure DoCursorEnd(Ctrl: boolean);
 var
   PLen: integer;
 begin
   Tracks.ToggleSelection;
   Tracks.CursorX := 48;
   Tracks.RecreateCaret;
   if Ctrl then
    begin
     if Tracks.ShownPattern = nil then
       PLen := DefPatLen
     else
       PLen := Tracks.ShownPattern^.Length;
     Tracks.ShownFrom := PLen - 1;
     Tracks.CursorY := Tracks.N1OfLines;
     if not (ssShift in Shift) then Tracks.ResetSelection;
     ShowStat;
     Tracks.Invalidate;
    end;
   Tracks.CalcCaretPos;
   if not Ctrl and (ssShift in Shift) then Tracks.ToggleSelection;
   if not (ssShift in Shift) then Tracks.ResetSelection;
   Key := 0;
 end;

 procedure DoCursorPageUp(Ctrl: boolean);
 var
   PLen: integer;
 begin
   if Ctrl then
    begin
     Tracks.ShownFrom := 0;
     Tracks.CursorY := Tracks.N1OfLines;
     if not (ssShift in Shift) then Tracks.ResetSelection;
     Tracks.Invalidate;
     Tracks.CalcCaretPos;
    end
   else
    begin
     //cursor points to the first pattern line?
     if Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY = 0 then
      begin
       if not (ssShift in Shift) then
        begin
         if Tracks.ShownPattern = nil then
           PLen := DefPatLen
         else
           PLen := Tracks.ShownPattern^.Length;
         Tracks.ShownFrom := PLen - 1;
         Tracks.CursorY := Tracks.N1OfLines;
         Tracks.ResetSelection;
         Tracks.Invalidate;
         Tracks.CalcCaretPos;
        end;
      end
     //cursor in the middle or in the first line?
     else if (Tracks.CursorY = Tracks.N1OfLines) or (Tracks.CursorY = 0) then
      begin
       Dec(Tracks.ShownFrom, Tracks.NOfLines);
       if Tracks.ShownFrom < 0 then
         Tracks.ShownFrom := 0;
       if Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY < 0 then
         Tracks.CursorY := Tracks.N1OfLines - Tracks.ShownFrom;
       if not (ssShift in Shift) then Tracks.ResetSelection;
       Tracks.Invalidate;
       Tracks.CalcCaretPos;
      end
     //cursor in other location
     else
      begin
       Tracks.ToggleSelection;
       Tracks.CursorY := Tracks.N1OfLines - Tracks.ShownFrom;
       if Tracks.CursorY < 0 then Tracks.CursorY := 0;
       Tracks.CalcCaretPos;
       if ssShift in Shift then
         Tracks.ToggleSelection
       else
         Tracks.ResetSelection;
      end;
    end;
   ShowStat;
   Key := 0;
 end;

 procedure DoCursorPageDown(Ctrl: boolean);
 var
   PLen: integer;
 begin
   if Tracks.ShownPattern = nil then
     PLen := DefPatLen
   else
     PLen := Tracks.ShownPattern^.Length;
   if Ctrl then
    begin
     Tracks.ShownFrom := PLen - 1;
     Tracks.CursorY := Tracks.N1OfLines;
     if not (ssShift in Shift) then Tracks.ResetSelection;
     Tracks.Invalidate;
     Tracks.CalcCaretPos;
    end
   else
    begin
     //cursor points to the last pattern line?
     if Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY = PLen - 1 then
      begin
       if not (ssShift in Shift) then
        begin
         Tracks.ShownFrom := 0;
         Tracks.CursorY := Tracks.N1OfLines;
         Tracks.ResetSelection;
         Tracks.Invalidate;
         Tracks.CalcCaretPos;
        end;
      end
     //cursor in the middle or in the last line?
     else if (Tracks.CursorY = Tracks.N1OfLines) or
       (Tracks.CursorY = Tracks.NOfLines - 1) then
      begin
       Inc(Tracks.ShownFrom, Tracks.NOfLines);
       if Tracks.ShownFrom >= PLen then
         Tracks.ShownFrom := PLen - 1;
       if Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY >= PLen then
         Tracks.CursorY := PLen - Tracks.ShownFrom + Tracks.N1OfLines - 1;
       if not (ssShift in Shift) then Tracks.ResetSelection;
       Tracks.Invalidate;
       Tracks.CalcCaretPos;
      end
     //cursor in other location
     else
      begin
       Tracks.ToggleSelection;
       Tracks.CursorY := PLen - Tracks.ShownFrom + Tracks.N1OfLines - 1;
       if Tracks.CursorY >= Tracks.NOfLines then
         Tracks.CursorY := Tracks.NOfLines - 1;
       Tracks.CalcCaretPos;
       if ssShift in Shift then
         Tracks.ToggleSelection
       else
         Tracks.ResetSelection;
      end;
    end;
   ShowStat;
   Key := 0;
 end;

 procedure DoCursorStepUp;
 var
   Step, PLen, Line: integer;
 begin
   Step := Abs(UDAutoStep.Position);
   if Step = 0 then
     Exit;
   if Tracks.ShownPattern = nil then
     PLen := DefPatLen
   else
     PLen := Tracks.ShownPattern^.Length;
   if Step < PLen then //if too big step, do nothing
    begin
     //line of cursor
     Line := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;

     //cursor points to the first pattern lines before 2nd step line?
     if Line < Step then
      begin
       if not (ssShift in Shift) then //if top of selection, don't move
        begin
         //hook at center and step forward to PLen
         Tracks.ShownFrom := Line - Step + PLen;
         Tracks.CursorY := Tracks.N1OfLines;
         Tracks.ResetSelection;
         Tracks.Invalidate;
         Tracks.CalcCaretPos;
        end;
      end
     //cursor in the middle or in the first lines?
     else if (Tracks.CursorY = Tracks.N1OfLines) or (Tracks.CursorY < Step) then
      begin
       Dec(Tracks.ShownFrom, Step);
       if not (ssShift in Shift) then Tracks.ResetSelection;
       Tracks.Invalidate;
       Tracks.CalcCaretPos;
      end
     //cursor in other location
     else
      begin
       Tracks.ToggleSelection;
       Dec(Tracks.CursorY, Step);
       Tracks.CalcCaretPos;
       if ssShift in Shift then
         Tracks.ToggleSelection
       else
         Tracks.ResetSelection;
      end;
     ShowStat;
    end;
   Key := 0;
 end;

 procedure DoCursorStepDown;
 var
   Step, PLen, Line: integer;
 begin
   Step := Abs(UDAutoStep.Position);
   if Step = 0 then
     Exit;
   if Tracks.ShownPattern = nil then
     PLen := DefPatLen
   else
     PLen := Tracks.ShownPattern^.Length;
   if Step < PLen then //if too big step, do nothing
    begin
     //line of cursor
     Line := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;

     //cursor points to the end pattern lines (no step to)?
     if Line >= PLen - Step then
      begin
       if not (ssShift in Shift) then //if bottom of selection, don't move
        begin
         //hook at center and step backward by PLen
         Tracks.ShownFrom := Line + Step - PLen;
         Tracks.CursorY := Tracks.N1OfLines;
         Tracks.ResetSelection;
         Tracks.Invalidate;
         Tracks.CalcCaretPos;
        end;
      end
     //cursor in the middle or in the last lines?
     else if (Tracks.CursorY = Tracks.N1OfLines) or
       (Tracks.CursorY >= Tracks.NOfLines - Step) then
      begin
       Inc(Tracks.ShownFrom, Step);
       if not (ssShift in Shift) then Tracks.ResetSelection;
       Tracks.Invalidate;
       Tracks.CalcCaretPos;
      end
     //cursor in other location
     else
      begin
       Tracks.ToggleSelection;
       Inc(Tracks.CursorY, Step);
       Tracks.CalcCaretPos;
       if ssShift in Shift then
         Tracks.ToggleSelection
       else
         Tracks.ResetSelection;
      end;
     ShowStat;
    end;
   Key := 0;
 end;

type
 TA3 = array[0..2] of boolean;

 procedure GetColsToEdit(out E, N: boolean; out T: TA3; AllPat: boolean);
 begin
   if AllPat then
    begin
     E := True;
     N := True;
     T[0] := True;
     T[1] := True;
     T[2] := True;
    end
   else
    begin
     E := False;
     N := False;
     T[0] := False;
     T[1] := False;
     T[2] := False;
     if Tracks.CursorX < 4 then
       E := True
     else if Tracks.CursorX < 8 then
       N := True
     else
       T[MainForm.ChanAlloc[(Tracks.CursorX - 8) div 14]] := True;
    end;
 end;

 procedure DoInsertLine(AllPat: boolean);
 var
   i, j, c: integer;
   E, N: boolean;
   T: TA3;
 begin
   if Tracks.ShownPattern <> nil then
    begin
     i := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
     if (i >= 0) and (i < Tracks.ShownPattern^.Length) then
      begin
       SongChanged := True;
       AddUndo(CAPatternInsertLine,{%H-}PtrInt(Tracks.ShownPattern), 0, auAutoIdxs);
       GetColsToEdit(E, N, T, AllPat);
       if E then
        begin
         for j := MaxPatLen - 1 downto i do
           Tracks.ShownPattern^.Items[j].Envelope :=
             Tracks.ShownPattern^.Items[j - 1].Envelope;
         Tracks.ShownPattern^.Items[i].Envelope := 0;
        end;
       if N then
        begin
         for j := MaxPatLen - 1 downto i do
           Tracks.ShownPattern^.Items[j].Noise :=
             Tracks.ShownPattern^.Items[j - 1].Noise;
         Tracks.ShownPattern^.Items[i].Noise := 0;
        end;
       for c := 0 to 2 do if T[c] then
          begin
           for j := MaxPatLen - 1 downto i do
             Tracks.ShownPattern^.Items[j].Channel[c] :=
               Tracks.ShownPattern^.Items[j - 1].Channel[c];
           Tracks.ShownPattern^.Items[i].Channel[c] := EmptyChannelLine;
          end;
       CalcTotLen;
       if DoStep(i, True) then ShowStat;
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.PatternLine :=
         Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
       Tracks.Invalidate;
      end;
    end;
   Key := 0;
 end;

 procedure DoRemoveLine(AllPat: boolean);
 var
   i, j, c: integer;
   E, N: boolean;
   T: TA3;
 begin
   if Tracks.ShownPattern <> nil then
    begin
     i := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
     if (i >= 0) and (i < Tracks.ShownPattern^.Length) then
      begin
       SongChanged := True;
       AddUndo(CAPatternDeleteLine,{%H-}PtrInt(Tracks.ShownPattern), 0, auAutoIdxs);
       GetColsToEdit(E, N, T, AllPat);
       if E then
        begin
         for j := i + 1 to MaxPatLen - 1 do
           Tracks.ShownPattern^.Items[j - 1].Envelope :=
             Tracks.ShownPattern^.Items[j].Envelope;
         Tracks.ShownPattern^.Items[MaxPatLen - 1].Envelope := 0;
        end;
       if N then
        begin
         for j := i + 1 to MaxPatLen - 1 do
           Tracks.ShownPattern^.Items[j - 1].Noise :=
             Tracks.ShownPattern^.Items[j].Noise;
         Tracks.ShownPattern^.Items[MaxPatLen - 1].Noise := 0;
        end;
       for c := 0 to 2 do if T[c] then
          begin
           for j := i + 1 to MaxPatLen - 1 do
             Tracks.ShownPattern^.Items[j - 1].Channel[c] :=
               Tracks.ShownPattern^.Items[j].Channel[c];
           Tracks.ShownPattern^.Items[MaxPatLen - 1].Channel[c] := EmptyChannelLine;
          end;
       ToglSams.CheckUsedSamples;
       CalcTotLen;
       if DoStep(i, True) then ShowStat;
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.PatternLine :=
         Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
       Tracks.Invalidate;
      end;
    end;
   Key := 0;
 end;

 procedure DoClearLine(AllPat: boolean);
 var
   i, c: integer;
   E, N: boolean;
   T: TA3;
 begin
   if Tracks.ShownPattern <> nil then
    begin
     i := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
     if (i >= 0) and (i < Tracks.ShownPattern^.Length) then
      begin
       SongChanged := True;
       AddUndo(CAPatternClearLine,{%H-}PtrInt(Tracks.ShownPattern), 0, auAutoIdxs);
       GetColsToEdit(E, N, T, AllPat);
       if E then
         Tracks.ShownPattern^.Items[i].Envelope := 0;
       if N then
         Tracks.ShownPattern^.Items[i].Noise := 0;
       for c := 0 to 2 do if T[c] then
           Tracks.ShownPattern^.Items[i].Channel[c] := EmptyChannelLine;
       ToglSams.CheckUsedSamples;
       CalcTotLen;
       if DoStep(i, True) then ShowStat;
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.PatternLine :=
         Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
       Tracks.Invalidate;
      end;
    end;
   Key := 0;
 end;

var
 i: integer;
 Act: TShortcutActions;
begin
 if IsPlaying and (PlaybackWindow[0] = Self) and (PlayMode <> PMPlayLine) then
   Exit;

 if Tracks.KeyPressed <> Key then //skip keyboard's auto repeat
   if (Tracks.CursorX in NotePoses) or (SBEnvAsNote.Down and (Tracks.CursorX = 0)) or
     ((Key and $8000 <> 0) and not (Tracks.CursorX in [5, 6])) then //midi note
     DoNoteKey
   else
     DoOtherKeys;

 if Key = 0 then
   Exit;

 if GetShortcutAction(SCS_PatternEditor, Key, Shift, Act) then
   case Act of
     SCA_PatternTrackDown:
       DoCursorDown;
     SCA_PatternTrackUp:
       DoCursorUp;
     SCA_PatternLineLeft:
       DoCursorLeft(False);
     SCA_PatternLineColumnLeft:
       DoCursorLeft(True);
     SCA_PatternLineRight:
       DoCursorRight(False);
     SCA_PatternLineColumnRight:
       DoCursorRight(True);
     SCA_PatternLineBegin:
       DoCursorHome(False);
     SCA_PatternFirstLineBegin:
       DoCursorHome(True);
     SCA_PatternLineEnd:
       DoCursorEnd(False);
     SCA_PatternLastLineEnd:
       DoCursorEnd(True);
     SCA_PatternTrackPageUp:
       DoCursorPageUp(False);
     SCA_PatternTrackBegin:
       DoCursorPageUp(True);
     SCA_PatternTrackPageDown:
       DoCursorPageDown(False);
     SCA_PatternTrackEnd:
       DoCursorPageDown(True);
     SCA_PatternTrackStepUp:
       DoCursorStepUp;
     SCA_PatternTrackStepDown:
       DoCursorStepDown;
     SCA_PatternTrackInsertLine:
       DoInsertLine(False);
     SCA_PatternInsertLine:
       DoInsertLine(True);
     SCA_PatternPaste:
      begin
       if MainForm.EditPaste1.Enabled then
         MainForm.EditPaste1.Execute;
       Key := 0;
      end;
     SCA_PatternCopy:
      begin
       if MainForm.EditCopy1.Enabled then
         MainForm.EditCopy1.Execute;
       Key := 0;
      end;
     SCA_PatternCut:
      begin
       if MainForm.EditCut1.Enabled then
         MainForm.EditCut1.Execute;
       Key := 0;
      end;
     SCA_PatternTrackDeleteLine:
       DoRemoveLine(False);
     SCA_PatternDeleteLine, SCA_PatternDeleteLine2:
       DoRemoveLine(True);
     SCA_PatternStepBack:
      begin
       i := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
       if (i >= 0) and (i < Tracks.ShownPattern^.Length) then
         if DoStep(i, False) then
          begin
           ShowStat;
           Tracks.Invalidate;
          end;
       Key := 0;
      end;
     SCA_PatternSelectionClear:
      begin
       Tracks.ClearSelection;
       Key := 0;
      end;
     SCA_PatternTrackClearLine:
       DoClearLine(False);
     SCA_PatternClearLine:
       DoClearLine(True);
     SCA_PatternJumpToPosList:
      begin
       if SGPositions.CanSetFocus then
         SGPositions.SetFocus;
       Key := 0;
      end;
     SCA_PatternAutoEnv:
      begin
       ToggleAutoEnv;
       Key := 0;
      end;
     SCA_PatternAutoStep:
      begin
       ToggleAutoStep;
       Key := 0;
      end;
     SCA_PatternAutoPrms:
      begin
       SBAutoPars.Down := not SBAutoPars.Down;
       Key := 0;
      end;
     SCA_PatternSetAutoStep0..SCA_PatternSetAutoStep9:
      begin
       UDAutoStep.Position := Ord(Act) - Ord(SCA_PatternSetAutoStep0);
       if not SBAutoStep.Down then
         SBAutoStepClick(Sender);
      end;
     SCA_PatternPlayTillUp:
       if Tracks.KeyPressed <> Key then //skip keyboard's auto repeat
        begin
         Tracks.KeyPressed := Key;
         ValidatePattern2(PatNum);
         RestartPlayingPatternLine(True);
         Tracks.CursorY := Tracks.N1OfLines;
         Tracks.CalcCaretPos;
         Key := 0;
        end;
     //SCA_PatternSelectAll exists in popup menu
     SCA_PatternSelectAll2:
      begin
       Tracks.SelectAll;
       Key := 0;
      end;
    end;

 //block leave control by arrow keys
 MainForm.CheckKeysAndActionsConflicts(Key, Shift, [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]);
end;

function TChildForm.KeyToNote(var Key: word; Shift: TShiftState;
 out Note, Volu: integer; TL: TTestLine; OctaveToNote: boolean): boolean;
begin
 if Key and $8000 <> 0 then //MIDI key flag
  begin
   Volu := Velocity2Volume((Key and $7F00) shr 8);
   Note := Key and $7F;
   Key := Key and $807F; //clear velocity info
  end
 else
  begin
   Result := False;
   if Key >= 256 then
     Exit;
   Note := NoteKeys[Key]; //need -3 correction (see TNoteKeyCodes comment)
   if Note = 0 then
     Exit;
   Dec(Note, 3);
   with TL, VTMP^.Patterns[-1]^.Items[LineIndex] do
     if Note >= Ord(NK_OCTAVE1) - 3 then
      begin
       if Shift <> [] then
         Exit;
       TestOct := Note - Ord(NK_OCTAVE1) + 4;
       if not OctaveToNote then
         Note := -3 //fake for "Sample/Ornament as note" mode
       else
         Note := Channel[0].Note; //already modified after TestOct :=

       //modify associated octave chooser
       case LineIndex of
         tlPatterns:
           UDOctave.Position := TestOct;
         tlOrnaments:
           UDOrnOctave.Position := TestOct;
         tlSamples:
           UDSamOctave.Position := TestOct;
        end;
      end
     else if Note >= 0 then
       Inc(Note, (TestOct - 1) * 12);
   if (Note >= 96) or ((Note < 0) and (Shift <> [])) then
     Exit;
   if Note >= 0 then
     if Shift = [ssShift] then
      begin
       if Note < 96 - 12 then
         Inc(Note, 12);
      end
     else if Shift = [ssShift, ssCtrl] then
      begin
       if Note >= 12 then
         Dec(Note, 12);
      end
     else if Shift <> [] then
       Exit;
   Volu := 0;
  end;
 Result := True;
end;

function TChildForm.GetBaseNote(tlIdx: integer): integer;
begin
 Result := VTMP^.Patterns[-1]^.Items[tlIdx].Channel[0].Note;
 if Result < 0 then //R-- or ---
   Result := 36; //C-4
end;

procedure TChildForm.RecalcSample(NewNote: integer);
var
 i, f: integer;
begin
 if not SBSamRecalc.Down then
   Exit;

 if NewNote < 0 then //R-- or ---
   NewNote := 36; //C-4
 i := GetBaseNote(tlSamples);
 if i = NewNote then
   Exit;

 SongChanged := True;
 ValidateSample2(SamNum);
 AddUndo(CARecalcSample,{%H-}PtrInt(VTMP^.Samples[SamNum]), 0, auAutoIdxs);

 //note freqs difference
 f := GetNoteFreq(VTMP^.Ton_Table, i) - GetNoteFreq(VTMP^.Ton_Table, NewNote);

 for i := 0 to MaxSamLen{VTMP^.Samples[SamNum]^.Length} - 1 do
   VTMP^.Samples[SamNum]^.Items[i].Add_to_Ton :=
     Tne(VTMP^.Samples[SamNum]^.Items[i].Add_to_Ton + f);
 Samples.Invalidate;
end;

procedure TTestLine.TestLineKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);

 procedure DoNoteKey;
 var
   Note, Volu, i, c: integer;
   e: word;
 begin
   if not TChildForm(ParWind).KeyToNote(Key, Shift, Note, Volu, Self, True) then
     Exit;

   with TChildForm(ParWind), VTMP^, Patterns[-1]^.Items[LineIndex] do
    begin
     if Note >= 0 then
      begin
       if CursorX in [0..3] then //EnvAsNote can be in 0th octave
        begin
         Inc(Note, 12);
         i := 95 + 12;
        end
       else
         i := 95;
       if Key and $8000 <> 0 then //MIDI key flag
         Dec(Note, 24);
       if (Note < 0) or (Note > i) then
         Exit;
      end;
     KeyPressed := Key;
     if CursorX in [0..3] then
      begin
       if not Note2EnvP(Patterns[-1], LineIndex, Note, Ton_Table, c, e) then
         Exit;
       if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
         if Channel[0].Envelope in [1..14] then
           Saves.EnvP := Envelope;
       Envelope := e;
       if (Note > 0) and (c = 0) and AutoEnv then
        begin
         Note := Note - 12 - round(12 * log2(AutoEnv1 / AutoEnv0));
         if Note in [0..95] then
          begin
           if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
             if Channel[0].Note >= 0 then
               //need for testing portamento
               VTMP^.Saves.Chns[MidChan].Nt := Channel[0].Note
             else
               VTMP^.Saves.Chns[MidChan].Nt := Note;
           if LineIndex = tlSamples then
             RecalcSample(Note);
           Channel[0].Note := Note;
          end;
        end;
      end
     else
      begin
       if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
         if Channel[0].Note >= 0 then
           //need for testing portamento
           VTMP^.Saves.Chns[MidChan].Nt := Channel[0].Note
         else if Note >= 0 then
           VTMP^.Saves.Chns[MidChan].Nt := Note;
       if LineIndex = tlSamples then
         RecalcSample(Note);
       Channel[0].Note := Note;
       if (Volu <> 0) and MainForm.TBMidiV.Down then //use volume from midi
         Channel[0].Volume := Volu;
       DoAutoEnv(-1, LineIndex, 0);
       TChildForm(ParWind).BaseNoteChanged(LineIndex);
      end;
     ResetSelection;
     Self.Invalidate;
     RestartPlayingLine(-LineIndex - 1);
    end;
   Key := 0;
 end;

 procedure DoOtherKeys;
 var
   i, n: integer;
 begin
   if Shift <> [] then
     Exit;
   if CursorX = 5 then
     i := 1
   else if CursorX = 12 then
     i := 31
   else
     i := 15;
   case Key of
     VK_0..VK_9:
       n := Key - VK_0;
     //special for Lee Bee
     VK_NUMPAD0..VK_NUMPAD9:
       n := Key - VK_NUMPAD0;
     VK_A..VK_V:
       n := Key - VK_A + 10;
   else
     Exit;
    end;
   if (n < 0) or (n > i) then
     Exit;
   KeyPressed := Key;
   with TChildForm(ParWind), VTMP^.Patterns[-1]^.Items[LineIndex] do
     case CursorX of
       0..3:
        begin
         case CursorX of
           0: Envelope := Envelope and $FFF or (n shl 12);
           1: Envelope := Envelope and $F0FF or (n shl 8);
           2: Envelope := Envelope and $FF0F or (n shl 4);
           3: Envelope := Envelope and $FFF0 or n;
          end;
         if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
           if Channel[0].Envelope in [1..14] then
             VTMP^.Saves.EnvP := Envelope;
        end;
       5: Noise := Noise and 15 or (n shl 4);
       6: Noise := Noise and $F0 or n;
       12:
        begin
         Channel[0].Sample := n;
         if (n > 0) and (LineIndex = tlSamples) then
           TChildForm(ParWind).ChangeSample(n);
         if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
           if (n <> 0) and (Channel[0].Note <> NT_NO) then
             VTMP^.Saves.Chns[MidChan].Smp := n;
        end;
       13:
        begin
         Channel[0].Envelope := n;
         TChildForm(ParWind).DoAutoEnv(-1, LineIndex, 0);
         if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
           if n in [1..14] then
             VTMP^.Saves.Chns[MidChan].EnvT := n;
        end;
       14:
        begin
         Channel[0].Ornament := n;
         if (n > 0) and (LineIndex = tlOrnaments) then
           TChildForm(ParWind).ChangeOrnament(n);
         if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
           if (n <> 0) or (Channel[0].Envelope <> 0) then
             VTMP^.Saves.Chns[MidChan].Orn := n;
        end;
       15:
        begin
         Channel[0].Volume := n;
         if (IsPlayingWindow < 0) or (PlayMode = PMPlayLine) then
           if n > 0 then
             VTMP^.Saves.Chns[MidChan].Vol := n;
        end;
       17: Channel[0].Additional_Command.Number := n;
       18: Channel[0].Additional_Command.Delay := n;
       19: Channel[0].Additional_Command.Parameter :=
           Channel[0].Additional_Command.Parameter and 15 or (n shl 4);
       20: Channel[0].Additional_Command.Parameter :=
           Channel[0].Additional_Command.Parameter and $F0 or n
      end;
   ResetSelection;
   Invalidate;
   TChildForm(ParWind).RestartPlayingLine(-LineIndex - 1);
   Key := 0;
 end;

 procedure DoCursorRight(Ctrl: boolean);
 var
   max: integer;
 begin
   max := 20;
   if Ctrl then
     max := 16;
   ToggleSelection;
   if CursorX < max then
    begin
     if Ctrl then
       CursorX := TabRight(ColTabs, CursorX)
     else if ColSpace(CursorX + 1) then
       Inc(CursorX, 2)
     else if CursorX = 8 then
       Inc(CursorX, 4)
     else
       Inc(CursorX);
    end
   else
     //special for Lee Bee
     CursorX := 0;
   RecreateCaret;
   CalcCaretPos;
   if ssShift in Shift then
     ToggleSelection
   else
     ResetSelection;
   Key := 0;
 end;

 procedure DoCursorLeft(Ctrl: boolean);
 var
   min: integer;
 begin
   min := 0;
   if Ctrl then
     min := 4;
   ToggleSelection;
   if CursorX > min then
    begin
     if Ctrl then
       CursorX := TabLeft(ColTabs, CursorX)
     else if CursorX = 12 then
       Dec(CursorX, 4)
     else if ColSpace(CursorX - 1) then
       Dec(CursorX, 2)
     else
       Dec(CursorX);
    end
   else
     //special for Lee Bee
     CursorX := 20;
   RecreateCaret;
   CalcCaretPos;
   if ssShift in Shift then
     ToggleSelection
   else
     ResetSelection;
   Key := 0;
 end;

 procedure DoDelete(Cut: boolean);
 begin
   if Cut then
    begin
     if MainForm.EditCut1.Enabled then
       MainForm.EditCut1.Execute;
     Key := 0;
    end
   else
    begin
     ClearSelection;
     Key := 0;
    end;
 end;

 procedure DoCursorHome;
 begin
   ToggleSelection;
   CursorX := 0;
   RecreateCaret;
   CalcCaretPos;
   if ssShift in Shift then
     ToggleSelection
   else
     ResetSelection;
   Key := 0;
 end;

 procedure DoCursorEnd;
 begin
   ToggleSelection;
   CursorX := 20;
   RecreateCaret;
   CalcCaretPos;
   if ssShift in Shift then
     ToggleSelection
   else
     ResetSelection;
   Key := 0;
 end;

var
 Act: TShortcutActions;
begin
 if KeyPressed <> Key then //skip keyboard's auto repeat
   if (CursorX = 8) or (Key and $8000 <> 0) then //Midi note
     DoNoteKey
   else
     DoOtherKeys;

 if Key = 0 then
   Exit;

 if GetShortcutAction(SCS_TestLineEditor, Key, Shift, Act) then
   case Act of
     SCA_TestLineRight:
       DoCursorRight(False);
     SCA_TestLineColumnRight:
       DoCursorRight(True);
     SCA_TestLineLeft:
       DoCursorLeft(False);
     SCA_TestLineColumnLeft:
       DoCursorLeft(True);
     SCA_TestLineBegin:
       DoCursorHome;
     SCA_TestLineEnd:
       DoCursorEnd;
     SCA_TestLineSelectionClear:
       DoDelete(False);
     SCA_TestLineSelectionCut:
       DoDelete(True);
     SCA_TestLineJumpToEditor:
      begin
       case LineIndex of
         tlSamples:
          begin
           if TChildForm(ParWind).Samples.CanSetFocus then
             TChildForm(ParWind).Samples.SetFocus;
          end;
         tlOrnaments:
          begin
           if TChildForm(ParWind).Ornaments.CanSetFocus then
             TChildForm(ParWind).Ornaments.SetFocus;
          end;
         tlPatterns:
          begin
           if TChildForm(ParWind).Tracks.CanSetFocus then
             TChildForm(ParWind).Tracks.SetFocus;
          end;
        end;
       Key := 0;
      end;
     SCA_TestLineSelectAll, SCA_TestLineSelectAll2:
      begin
       SelectAll;
       Key := 0;
      end;
    end;

 //block leave control by arrow keys
 MainForm.CheckKeysAndActionsConflicts(Key, Shift, [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]);
end;

procedure TChildForm.SamplesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
type
 TSamToggles = (TgMixTone, TgMixNoise, TgMaskEnv, TgSgnTone, TgSgnNoise,
   TgAccTone, TgAccNoise, TgAccVol, TgSgnToneP, TgSgnToneM,
   TgSgnNoiseP, TgSgnNoiseM, TgAccVolP, TgAccVolM,
   TgAccTone_, TgAccNoise_, TgAccVol_, TgAccToneA, TgAccNoiseA);
 TSamNumbers = (NmTone, NmNoise, NmNoiseAbs, NmVol);

 procedure GetSamParams(var l, i: integer);
 begin
   with Samples do
    begin
     if ShownSample = nil then
       l := 1
     else
       l := ShownSample^.Length;
     i := ShownFrom + CursorY;
    end;
 end;

 procedure DoToggle(n: TSamToggles);
 var
   i, l: integer;
 begin
   with Samples do
    begin
     GetSamParams(l, i);
     if i >= l then exit;
     SongChanged := True;
     ValidateSample2(SamNum);
     AddUndo(CAChangeSampleValue,{%H-}PtrInt(@ShownSample^.Items[i]), 0, auAutoIdxs);
     with ShownSample^.Items[i] do
       case n of
         TgMixTone:
           Mixer_Ton := not Mixer_Ton;
         TgMixNoise:
           Mixer_Noise := not Mixer_Noise;
         TgMaskEnv:
           Envelope_Enabled := not Envelope_Enabled;
         TgSgnTone:
           Add_to_Ton := -Add_to_Ton;
         TgSgnToneP:
           Add_to_Ton := abs(Add_to_Ton);
         TgSgnToneM:
           Add_to_Ton := -abs(Add_to_Ton);
         TgSgnNoise:
           Add_to_Envelope_or_Noise := Nse(-Add_to_Envelope_or_Noise);
         TgSgnNoiseP:
           Add_to_Envelope_or_Noise := Nse(abs(Add_to_Envelope_or_Noise));
         TgSgnNoiseM:
           Add_to_Envelope_or_Noise := Nse(-abs(Add_to_Envelope_or_Noise));
         TgAccTone:
           Ton_Accumulation := not Ton_Accumulation;
         TgAccNoise:
           Envelope_or_Noise_Accumulation := not Envelope_or_Noise_Accumulation;
         TgAccVol:
           if not Amplitude_Sliding then
            begin
             Amplitude_Sliding := True;
             Amplitude_Slide_Up := False;
            end
           else if not Amplitude_Slide_Up then
             Amplitude_Slide_Up := True
           else
             Amplitude_Sliding := False;
         TgAccVolP:
          begin
           Amplitude_Sliding := True;
           Amplitude_Slide_Up := True;
          end;
         TgAccVolM:
          begin
           Amplitude_Sliding := True;
           Amplitude_Slide_Up := False;
          end;
         TgAccVol_:
           Amplitude_Sliding := False;
         TgAccTone_:
           Ton_Accumulation := False;
         TgAccNoise_:
           Envelope_or_Noise_Accumulation := False;
         TgAccToneA:
           Ton_Accumulation := True;
         TgAccNoiseA:
           Envelope_or_Noise_Accumulation := True
        end;
     ResetSelection;
     Invalidate;
    end;
   Key := 0;
 end;

 procedure DoToggleSpace;
 begin
   case Samples.CursorX of
     0..2:
       DoToggle(TSamToggles(Samples.CursorX));
     4..7:
       DoToggle(TgSgnTone);
     8:
       DoToggle(TgAccTone);
     10..15:
       DoToggle(TgSgnNoise);
     17:
       DoToggle(TgAccNoise);
     19, 20:
       DoToggle(TgAccVol)
    end;
   Key := 0;
 end;

 procedure DoTogglePlus;
 begin
   case Samples.CursorX of
     4..7:
       DoToggle(TgSgnToneP);
     10..15:
       DoToggle(TgSgnNoiseP);
     19, 20:
       DoToggle(TgAccVolP)
    end;
 end;

 procedure DoToggleMinus;
 begin
   case Samples.CursorX of
     4..7:
       DoToggle(TgSgnToneM);
     10..15:
       DoToggle(TgSgnNoiseM);
     19, 20:
       DoToggle(TgAccVolM)
    end;
   Key := 0;
 end;

 procedure DoToggleAccA;
 begin
   case Samples.CursorX of
     4..8:
       DoToggle(TgAccToneA);
     10..17:
       DoToggle(TgAccNoiseA)
    end;
   Key := 0;
 end;

 procedure DoToggle_;
 begin
   case Samples.CursorX of
     4..8:
       DoToggle(TgAccTone_);
     10..17:
       DoToggle(TgAccNoise_);
     19, 20:
       DoToggle(TgAccVol_)
    end;
   Key := 0;
 end;

 procedure DoNumber(n: TSamNumbers; Direct: boolean = False);
 var
   i, l: integer;
 begin
   with Samples do
    begin
     GetSamParams(l, i);
     if i >= l then exit;
     SongChanged := True;
     ValidateSample2(SamNum);
     AddUndo(CAChangeSampleValue,{%H-}PtrInt(@ShownSample^.Items[i]), 0, auAutoIdxs);
     with ShownSample^.Items[i] do
       case n of
         NmTone:
           if Direct then
             Add_to_Ton := InputSNumber
           else if Add_to_Ton < 0 then
             Add_to_Ton := -InputSNumber
           else
             Add_to_Ton := InputSNumber;
         NmNoise:
           if Add_to_Envelope_or_Noise < 0 then
             Add_to_Envelope_or_Noise := Nse(-InputSNumber)
           else
             Add_to_Envelope_or_Noise := Nse(InputSNumber);
         NmNoiseAbs:
           Add_to_Envelope_or_Noise := Nse(InputSNumber);
         NmVol:
           Amplitude := InputSNumber
        end;
     ResetSelection;
     Invalidate;
    end;
 end;

 procedure DoDigit(n: integer);
 var
   nm: integer;
 begin
   nm := Samples.InputSNumber * 16 + n;
   case Samples.CursorX of
     4..8:
      begin
       if nm > $FFF then
         nm := n;
       Samples.InputSNumber := nm;
       DoNumber(NmTone);
      end;
     10, 11:
      begin
       if nm > $10 then
         nm := n;
       Samples.InputSNumber := nm;
       DoNumber(NmNoise);
      end;
     14, 17:
      begin
       if nm > $1F then
         nm := n;
       Samples.InputSNumber := nm;
       DoNumber(NmNoiseAbs);
      end;
     19, 20:
      begin
       if nm > $F then
         nm := n;
       Samples.InputSNumber := nm;
       DoNumber(NmVol);
      end;
    end;
   Key := 0;
 end;

 procedure DoCursorRight(Ctrl: boolean);
 begin
   Samples.ToggleSelection;
   if Samples.CursorX < 20 then
    begin
     if Ctrl then
       Samples.CursorX := TabRight(SColTabs[SBSamAsNotes.Down], Samples.CursorX)
     else
      begin
       Inc(Samples.CursorX);
       if Samples.CursorX in [3, 9, 13, 16, 18] then
         Inc(Samples.CursorX)
       else if ((Samples.CursorX = 5) and SBSamAsNotes.Down) or
         (Samples.CursorX = 6) then
         Samples.CursorX := 8
       else if Samples.CursorX = 12 then
         Samples.CursorX := 14
       else if Samples.CursorX = 15 then
         Samples.CursorX := 17;
      end;
    end
   else
     //special for Lee Bee
     Samples.CursorX := 0;
   Samples.RecreateCaret;
   Samples.CalcCaretPos;
   if ssShift in Shift then
     Samples.ToggleSelection
   else
     Samples.ResetSelection;
   Key := 0;
 end;

 procedure DoCursorLeft(Ctrl: boolean);
 begin
   Samples.ToggleSelection;
   if Samples.CursorX > 0 then
    begin
     if Ctrl then
       Samples.CursorX := TabLeft(SColTabs[SBSamAsNotes.Down], Samples.CursorX)
     else
      begin
       if Samples.CursorX in [4, 10, 19] then
         Dec(Samples.CursorX, 2)
       else if Samples.CursorX in [8, 14, 17] then
        begin
         Dec(Samples.CursorX, 3);
         if (Samples.CursorX = 5) and SBSamAsNotes.Down then
           Samples.CursorX := 4;
        end
       else
         Dec(Samples.CursorX);
      end;
    end
   else
     //special for Lee Bee
     Samples.CursorX := 20;
   Samples.RecreateCaret;
   Samples.CalcCaretPos;
   if ssShift in Shift then
     Samples.ToggleSelection
   else
     Samples.ResetSelection;
   Key := 0;
 end;

 procedure DoCursorDown;
 var
   i, l: integer;
 begin
   GetSamParams(l, i);
   if (Samples.CursorY < Samples.NOfLines - 1) and (i < l - 1) then
     //just move cursor down
    begin
     Samples.ToggleSelection;
     Inc(Samples.CursorY);
     Samples.CalcCaretPos;
     if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end
   else if (Samples.ShownFrom <> 0) or (Samples.ShownFrom < l - Samples.NOfLines) then
    begin
     if Samples.ShownFrom < l - Samples.NOfLines then
       //scroll sheet up to make sense of moving cursor down
       Inc(Samples.ShownFrom)
     else
       //redraw from start and move cursor to top
      begin
       Samples.ShownFrom := 0;
       Samples.CursorY := 0;
       Samples.CalcCaretPos;
      end;
     if not (ssShift in Shift) then Samples.ResetSelection;
     Samples.Invalidate;
    end
   else
     //move cursot to top
    begin
     Samples.ToggleSelection;
     Samples.CursorY := 0;
     Samples.CalcCaretPos;
     if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end;
   Key := 0;
 end;

 procedure DoCursorUp;
 var
   i, l: integer;
 begin
   GetSamParams(l, i);
   if (Samples.CursorY > 0) then
     //just move cursor up
    begin
     Samples.ToggleSelection;
     Dec(Samples.CursorY);
     Samples.CalcCaretPos;
     if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end
   else if (Samples.ShownFrom > 0) or (l > Samples.NOfLines) then
    begin
     if Samples.ShownFrom > 0 then
       //scrool sheet down to make sense of moving cursor up
       Dec(Samples.ShownFrom)
     else
       //redraw sheet to show last item and move cursor to it
      begin
       Samples.ShownFrom := l - Samples.NOfLines;
       Samples.CursorY := Samples.NOfLines - 1;
       Samples.CalcCaretPos;
      end;
     if not (ssShift in Shift) then Samples.ResetSelection;
     Samples.Invalidate;
    end
   else
     //move cursor to last item
    begin
     Samples.ToggleSelection;
     Samples.CursorY := l - 1;
     Samples.CalcCaretPos;
     if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end;

   Key := 0;
 end;

 procedure DoCursorHome(Ctrl: boolean);
 begin
   Samples.ToggleSelection;
   Samples.CursorX := 0;
   if Ctrl then
     Samples.CursorY := 0;
   Samples.RecreateCaret;
   Samples.CalcCaretPos;
   if Ctrl and (Samples.ShownFrom > 0) then
    begin
     Samples.ShownFrom := 0;
     if not (ssShift in Shift) then Samples.ResetSelection;
     Samples.Invalidate;
    end
   else if ssShift in Shift then
     Samples.ToggleSelection
   else
     Samples.ResetSelection;
   Key := 0;
 end;

 procedure DoCursorEnd(Ctrl: boolean);
 var
   i, l, maxy: integer;
 begin
   GetSamParams(l, i);
   maxy := Samples.NOfLines;
   if maxy > l then maxy := l;
   Dec(maxy);
   Samples.ToggleSelection;
   if Samples.CursorX <> 20 then
    begin
     Samples.CursorX := 20;
     Samples.RecreateCaret;
    end;
   if Ctrl and (Samples.CursorY < maxy) then
     Samples.CursorY := maxy;
   Samples.CalcCaretPos;
   if Ctrl and (Samples.ShownFrom < {MaxSamLen} l - Samples.NOfLines) then
    begin
     Samples.ShownFrom := {MaxSamLen} l - Samples.NOfLines;
     if not (ssShift in Shift) then Samples.ResetSelection;
     Samples.Invalidate;
    end
   else if ssShift in Shift then
     Samples.ToggleSelection
   else
     Samples.ResetSelection;
   Key := 0;
 end;

 procedure DoCursorPageUp(Ctrl: boolean);
 begin
   if Ctrl then
    begin
     if Samples.ShownFrom = 0 then
       Samples.ToggleSelection;
     Samples.CursorY := 0;
     Samples.CalcCaretPos;
     if Samples.ShownFrom > 0 then
      begin
       Samples.ShownFrom := 0;
       if not (ssShift in Shift) then Samples.ResetSelection;
       Samples.Invalidate;
      end
     else if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end
   else if Samples.CursorY > 0 then
    begin
     Samples.ToggleSelection;
     Samples.CursorY := 0;
     Samples.CalcCaretPos;
     if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end
   else if Samples.ShownFrom > 0 then
    begin
     Dec(Samples.ShownFrom, Samples.NOfLines);
     if Samples.ShownFrom < 0 then
       Samples.ShownFrom := 0;
     if not (ssShift in Shift) then Samples.ResetSelection;
     Samples.Invalidate;
    end
   else if not (ssShift in Shift) then
     Samples.AbortSelection;
   Key := 0;
 end;

 procedure DoCursorPageDown(Ctrl: boolean);
 var
   i, l, maxy: integer;
 begin
   GetSamParams(l, i);
   maxy := Samples.NOfLines;
   if maxy > l then maxy := l;
   Dec(maxy);
   if Ctrl then
    begin
     if Samples.ShownFrom >= {MaxSamLen} l - Samples.NOfLines then
       Samples.ToggleSelection;
     if Samples.CursorY < {Samples.NOfLines - 1} maxy then
      begin
       Samples.CursorY := {Samples.NOfLines - 1} maxy;
       Samples.CalcCaretPos;
      end;
     if Samples.ShownFrom < {MaxSamLen} l - Samples.NOfLines then
      begin
       Samples.ShownFrom := {MaxSamLen} l - Samples.NOfLines;
       if not (ssShift in Shift) then Samples.ResetSelection;
       Samples.Invalidate;
      end
     else if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end
   else if (Samples.CursorY < {Samples.NOfLines - 1} maxy) then
    begin
     Samples.ToggleSelection;
     Samples.CursorY := {Samples.NOfLines - 1} maxy;
     Samples.CalcCaretPos;
     if ssShift in Shift then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
    end
   else if Samples.ShownFrom < {MaxSamLen} l - Samples.NOfLines then
    begin
     Inc(Samples.ShownFrom, Samples.NOfLines);
     if Samples.ShownFrom > {MaxSamLen} l - Samples.NOfLines then
       Samples.ShownFrom := {MaxSamLen} l - Samples.NOfLines;
     if not (ssShift in Shift) then Samples.ResetSelection;
     Samples.Invalidate;
    end
   else if not (ssShift in Shift) then
     Samples.AbortSelection;
   Key := 0;
 end;

 procedure DoDelete(Cut: boolean);
 begin
   if Cut then
    begin
     if MainForm.EditCut1.Enabled then
       MainForm.EditCut1.Execute;
     Key := 0;
    end
   else
    begin
     Samples.ClearSelection;
     Key := 0;
    end;
 end;

 procedure DoInsertLine;
 var
   i, L, j: integer;
 begin
   ValidateSample2(SamNum);
   GetSamParams(L, i);
   if (i >= 0) and (i < Samples.ShownSample^.Length) then
    begin
     SongChanged := True;
     AddUndo(CASampleInsertLine,{%H-}PtrInt(Samples.ShownSample), 0, auAutoIdxs);
     for j := MaxSamLen - 1 downto i do
       Samples.ShownSample^.Items[j] := Samples.ShownSample^.Items[j - 1];
     Samples.ShownSample^.Items[i] := EmptySampleTick;
     if (Samples.ShownSample^.Loop < MaxSamLen - 1) and
       (Samples.ShownSample^.Loop >= i) then
      begin
       Inc(Samples.ShownSample^.Loop);
       UDSamLoop.Position := Samples.ShownSample^.Loop;
      end;
     if L < MaxSamLen then
      begin
       UDSamLoop.Max := Samples.ShownSample^.Length;
       Inc(Samples.ShownSample^.Length);
       UDSamLen.Position := Samples.ShownSample^.Length;
      end;
     Samples.ResetSelection;
     Samples.Invalidate;
    end;
   Key := 0;
 end;

 procedure DoRemoveLine;
 var
   i, L, j: integer;
 begin
   ValidateSample2(SamNum);
   GetSamParams(L, i);
   if L = 1 then
     Exit;
   if (i >= 0) and (i < Samples.ShownSample^.Length) then
    begin
     SongChanged := True;
     AddUndo(CASampleDeleteLine,{%H-}PtrInt(Samples.ShownSample), 0, auAutoIdxs);
     for j := i + 1 to MaxSamLen - 1 do
       Samples.ShownSample^.Items[j - 1] := Samples.ShownSample^.Items[j];
     Samples.ShownSample^.Items[MaxSamLen - 1] := EmptySampleTick;
     if (Samples.ShownSample^.Loop > 0) and
       ((Samples.ShownSample^.Loop > i) or (Samples.ShownSample^.Loop = L - 1)) then
      begin
       Dec(Samples.ShownSample^.Loop);
       UDSamLoop.Position := Samples.ShownSample^.Loop;
      end;
     Dec(Samples.ShownSample^.Length);
     UDSamLoop.Max := Samples.ShownSample^.Length - 1;
     UDSamLen.Position := Samples.ShownSample^.Length;
     if i = Samples.ShownSample^.Length then //last line deleted, correct cursor
      begin
       if Samples.CursorY > 0 then
        begin
         Dec(Samples.CursorY);
         Samples.CalcCaretPos;
        end
       else
         //make prev line visible
         Dec(Samples.ShownFrom);
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.SampleLine :=
         Samples.ShownFrom + Samples.CursorY;
      end;
     Samples.ResetSelection;
     Samples.Invalidate;
    end;
   Key := 0;
 end;

var
 Act: TShortcutActions;
 Note, Dummy: integer;
begin
 if (Shift <> []) or not (Key in [Ord('0')..Ord('9'), VK_NUMPAD0..VK_NUMPAD9,
   Ord('A')..Ord('F')]) then
   Samples.InputSNumber := 0;

 if (Shift = []) and (not SBSamAsNotes.Down or (Samples.CursorX <> 4)) then
   case Key of
     VK_0..VK_9:
       DoDigit(Key - Ord('0'));
     //special for Lee Bee
     VK_NUMPAD0..VK_NUMPAD9:
       DoDigit(Key - VK_NUMPAD0);
     VK_A..VK_F:
       DoDigit(Key - VK_A + 10);
    end;

 if Key = 0 then
   Exit;

 if SBSamAsNotes.Down and ((Key and $8000 <> 0) or
   //MIDI NoteOn accepted with any CursorX
   (Samples.CursorX = 4)) and KeyToNote(Key, Shift, Note, Dummy,
   SampleTestLine, False) then
  begin
   if Note >= 0 then
    begin
     if Key and $8000 <> 0 then //MIDI key flag
       Dec(Note, 24);
     Samples.InputSNumber := (GetNoteFreq(VTMP^.Ton_Table, Note) -
       GetNoteFreq(VTMP^.Ton_Table, GetBaseNote(tlSamples))) mod $FFF;
     DoNumber(NmTone, True);
    end;
   Samples.InputSNumber := 0;
   Key := 0;
  end;

 if Key = 0 then
   Exit;

 if GetShortcutAction(SCS_SampleEditor, Key, Shift, Act) then
   case Act of
     SCA_SampleLineRight:
       DoCursorRight(False);
     SCA_SampleLineColumnRight:
       DoCursorRight(True);
     SCA_SampleLineLeft:
       DoCursorLeft(False);
     SCA_SampleLineColumnLeft:
       DoCursorLeft(True);
     SCA_SampleTrackDown:
       DoCursorDown;
     SCA_SampleTrackUp:
       DoCursorUp;
     SCA_SampleLineBegin:
       DoCursorHome(False);
     SCA_SampleFirstLineBegin:
       DoCursorHome(True);
     SCA_SampleLineEnd:
       DoCursorEnd(False);
     SCA_SampleLastLineEnd:
       DoCursorEnd(True);
     SCA_SampleTrackPageUp:
       DoCursorPageUp(False);
     SCA_SampleTrackBegin:
       DoCursorPageUp(True);
     SCA_SampleTrackPageDown:
       DoCursorPageDown(False);
     SCA_SampleTrackEnd:
       DoCursorPageDown(True);
     SCA_SampleSelectionClear:
       DoDelete(False);
     SCA_SampleSelectionCut:
       DoDelete(True);
     SCA_SampleToggleT:
       DoToggle(TgMixTone);
     SCA_SampleToggleN:
       DoToggle(TgMixNoise);
     SCA_SampleToggleE:
       DoToggle(TgMaskEnv);
     SCA_SampleToggle:
       DoToggleSpace;
     SCA_SamplePlus, SCA_SamplePlus2, SCA_SamplePlus3:
       DoTogglePlus;
     SCA_SampleMinus, SCA_SampleMinus2:
       DoToggleMinus;
     SCA_SampleAcc:
       DoToggleAccA;
     SCA_SampleClearSignOrAcc:
       DoToggle_;
     SCA_SampleInsertLine, SCA_SampleInsertLine2:
       DoInsertLine;
     SCA_SampleDeleteLine, SCA_SampleDeleteLine2:
       DoRemoveLine;
     SCA_SampleSelectAll, SCA_SampleSelectAll2:
      begin
       Samples.SelectAll;
       Key := 0;
      end;
     SCA_SampleJumpToTest:
      begin
       if SampleTestLine.CanSetFocus then
         SampleTestLine.SetFocus;
       Key := 0;
      end;
    end;

 //block leave control by arrow keys
 MainForm.CheckKeysAndActionsConflicts(Key, Shift, [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]);
end;

procedure TChildForm.OrnamentsKeyDown(Sender: TObject; var Key: word;
 Shift: TShiftState);
type
 TOrnToggles = (TgSgn, TgSgnP, TgSgnM);

 procedure GetOrnParams(out l, i, c: integer);
 begin
   with Ornaments do
    begin
     if ShownOrnament = nil then
       l := 1
     else
       l := ShownOrnament^.Length;
     c := CursorY + (CursorX div 7) * OrnNRow;
     i := ShownFrom + c;
    end;
 end;

 procedure DoToggles(n: TOrnToggles);
 var
   c, i, l, o: integer;
 begin
   with Ornaments do
    begin
     GetOrnParams(l, i, c);
     if i >= l then exit;
     SongChanged := True;
     ValidateOrnament(OrnNum);
     o := ShownOrnament^.Items[i];
     case n of
       TgSgn:
         ShownOrnament^.Items[i] := -ShownOrnament^.Items[i];
       TgSgnP:
         ShownOrnament^.Items[i] := Abs(ShownOrnament^.Items[i]);
       TgSgnM:
         ShownOrnament^.Items[i] := -Abs(ShownOrnament^.Items[i])
      end;
     AddUndo(CAChangeOrnamentValue, o, ShownOrnament^.Items[i], auAutoIdxs);
     ResetSelection;
     Invalidate;
    end;
   Key := 0;
 end;

 procedure DoToggleSpace;
 begin
   DoToggles(TgSgn);
 end;

 procedure DoTogglePlus;
 begin
   DoToggles(TgSgnP);
 end;

 procedure DoToggleMinus;
 begin
   DoToggles(TgSgnM);
 end;

 procedure DoNumber(Number: integer; Direct: boolean);
 var
   c, i, l, o: integer;
 begin
   with Ornaments do
    begin
     GetOrnParams(l, i, c);
     if i >= l then exit;
     SongChanged := True;
     ValidateOrnament(OrnNum);
     with ShownOrnament^ do
      begin
       o := Items[i];
       if Direct then
         Items[i] := Number
       else if Items[i] < 0 then
         Items[i] := -Number
       else
         Items[i] := Number;
       AddUndo(CAChangeOrnamentValue, o, Items[i], auAutoIdxs);
      end;
     ResetSelection;
     Invalidate;
    end;
 end;

 procedure DoDigit(n: integer);
 var
   nm: integer;
 begin
   nm := Ornaments.InputONumber * 10 + n;
   if nm > 96 then
     nm := n;
   Ornaments.InputONumber := nm;
   DoNumber(Ornaments.InputONumber, False);
   Key := 0;
 end;

 procedure DoCursorRight;
 var
   c, i, l: integer;
 begin
   GetOrnParams(l, i, c);
   if i >= l - 1 then //last item cel already selected
    begin
     if not (ssShift in Shift) then
       Ornaments.AbortSelection;
    end
   else if (Ornaments.CursorX >= (Ornaments.OrnNCol - 1) * 7) and
     (Ornaments.ShownFrom < l - Ornaments.NOfLines) then
     //rightest col and can scroll
    begin
     Inc(Ornaments.ShownFrom, Ornaments.OrnNRow);
     if Ornaments.ShownFrom > l - Ornaments.NOfLines then
       Ornaments.ShownFrom := l - Ornaments.NOfLines;
     if not (ssShift in Shift) then Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end
   else //just move carret
    begin
     Ornaments.ToggleSelection;
     Inc(i, Ornaments.OrnNRow);
     if i < l then
       Inc(Ornaments.CursorX, 7)
     else if i - l < Ornaments.CursorY then
      begin
       Inc(Ornaments.CursorX, 7);
       Dec(Ornaments.CursorY, i - l + 1);
      end
     else
       Inc(Ornaments.CursorY, l - i + Ornaments.OrnNRow - 1);
     Ornaments.CalcCaretPos;
     if ssShift in Shift then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
    end;
   Key := 0;
 end;

 procedure DoCursorLeft;
 begin
   if (Ornaments.CursorX <= 6) and (Ornaments.ShownFrom > 0) then
     //leftest col and can scroll
    begin
     Dec(Ornaments.ShownFrom, Ornaments.OrnNRow);
     if Ornaments.ShownFrom < 0 then Ornaments.ShownFrom := 0;
     if not (ssShift in Shift) then Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end
   else if (Ornaments.CursorX > 6) or (Ornaments.CursorY <> 0) then
     //just move carret
    begin
     Ornaments.ToggleSelection;
     if Ornaments.CursorX > 6 then
       Dec(Ornaments.CursorX, 7)
     else
       Ornaments.CursorY := 0;
     Ornaments.CalcCaretPos;
     if ssShift in Shift then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
    end
   else if not (ssShift in Shift) then //first item cel already selected
     Ornaments.AbortSelection;
   Key := 0;
 end;

 procedure DoCursorDown;
 var
   c, i, l: integer;
 begin
   GetOrnParams(l, i, c);
   if i >= l - 1 then //last item cel selected
    begin
     if Ornaments.ShownFrom = 0 then
       //just move cursor to 1st cel
      begin
       Ornaments.ToggleSelection;
       Ornaments.CursorY := 0;
       Ornaments.CursorX := 3;
       Ornaments.CalcCaretPos;
       if ssShift in Shift then
         Ornaments.ToggleSelection
       else
         Ornaments.ResetSelection;
      end
     else
       //redraw from start and move cursor to 1st cel
      begin
       Ornaments.ShownFrom := 0;
       Ornaments.CursorY := 0;
       Ornaments.CursorX := 3;
       Ornaments.CalcCaretPos;
       if not (ssShift in Shift) then Ornaments.ResetSelection;
       Ornaments.Invalidate;
      end;
    end
   else if (Ornaments.CursorY >= Ornaments.OrnNRow - 1) and
     (Ornaments.CursorX >= (Ornaments.OrnNCol - 1) * 7) then
     //lower right cel, need to scroll
    begin
     Inc(Ornaments.ShownFrom);
     if not (ssShift in Shift) then Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end
   else //just move carret to the next item cel
    begin
     Ornaments.ToggleSelection;
     if Ornaments.CursorY < Ornaments.OrnNRow - 1 then
       Inc(Ornaments.CursorY)
     else if Ornaments.CursorX < (Ornaments.OrnNCol - 1) * 7 then
      begin
       Ornaments.CursorY := 0;
       Inc(Ornaments.CursorX, 7);
      end;
     Ornaments.CalcCaretPos;
     if ssShift in Shift then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
    end;
   Key := 0;
 end;

 procedure DoCursorUp;
 var
   c, i, l: integer;
 begin
   GetOrnParams(l, i, c);
   if (Ornaments.CursorY = 0) and (Ornaments.CursorX < 7) then //upper left col selected
    begin
     if (Ornaments.ShownFrom > 0) or (l > Ornaments.NOfLines) then
      begin
       if Ornaments.ShownFrom > 0 then
         //scroll sheet down to make sense of moving cursor up
         Dec(Ornaments.ShownFrom)
       else
         //redraw to show last item and move cursor to it
        begin
         Ornaments.ShownFrom := l - Ornaments.NOfLines;
         Ornaments.CursorY := Ornaments.OrnNRow - 1;
         Ornaments.CursorX := Ornaments.OrnNCol * 7 - 4;
         Ornaments.CalcCaretPos;
        end;
       if not (ssShift in Shift) then Ornaments.ResetSelection;
       Ornaments.Invalidate;
      end
     else
       //just move cursor to last item
      begin
       Ornaments.ToggleSelection;
       Dec(l);
       Ornaments.CursorY := l mod Ornaments.OrnNRow;
       Ornaments.CursorX := l div Ornaments.OrnNRow * 7 + 3;
       Ornaments.CalcCaretPos;
       if ssShift in Shift then
         Ornaments.ToggleSelection
       else
         Ornaments.ResetSelection;
      end;
    end
   else
     //just move carret to the prev item cel
    begin
     Ornaments.ToggleSelection;
     if Ornaments.CursorY > 0 then
       Dec(Ornaments.CursorY)
     else
      begin
       Ornaments.CursorY := Ornaments.OrnNRow - 1;
       Dec(Ornaments.CursorX, 7);
      end;
     Ornaments.CalcCaretPos;
     if ssShift in Shift then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
    end;
   Key := 0;
 end;

 procedure DoCursorHome(Ctrl: boolean);
 begin
   if (Ornaments.ShownFrom <> 0) and //check for need redraw starting from other item
     (Ctrl or //redraw from start
     (Ornaments.CursorX < 7) //redraw page left
     ) then
    begin
     if Ctrl then //move carret to upper left since redraw from start
      begin
       Ornaments.CursorY := 0;
       Ornaments.CursorX := 3;
       Ornaments.ShownFrom := 0;
      end
     else //do page left
      begin
       Dec(Ornaments.ShownFrom, Ornaments.NOfLines);
       if Ornaments.ShownFrom < 0 then
         Ornaments.ShownFrom := 0;
      end;
     Ornaments.CalcCaretPos;
     if not (ssShift in Shift) then Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end
   else
    begin
     //just move carret to leftest col
     if (Ornaments.CursorX > 6) or //col > 0
       (Ornaments.CursorY <> 0) then //not 1st cel
      begin
       Ornaments.ToggleSelection;
       if Ctrl or (Ornaments.CursorX < 7) then //goto 1st row
         Ornaments.CursorY := 0;
       Ornaments.CursorX := 3; //and 1st col
       Ornaments.CalcCaretPos;
       if ssShift in Shift then
         Ornaments.ToggleSelection
       else
         Ornaments.ResetSelection;
      end
     else if not (ssShift in Shift) then //first item cel already selected
       Ornaments.AbortSelection;
    end;
   Key := 0;
 end;

 procedure DoCursorEnd(Ctrl: boolean);
 var
   c, i, l: integer;
 begin
   GetOrnParams(l, i, c);
   if (i >= l - 1) //last item cel already selected
{     or (not Ctrl and
      ((Ornaments.CursorX >= (OrnNCol-1)*7) or //carret in rigthest col already
       (c > (l - Ornaments.ShownFrom) div OrnNRow * OrnNRow) //last avail col already
      )
     ) } then
    begin
     if not (ssShift in Shift) then
       Ornaments.AbortSelection;
    end
   else if (l - Ornaments.ShownFrom > Ornaments.NOfLines) and //can page right
     (Ctrl or //redraw to show last cel
     (Ornaments.CursorX >= (Ornaments.OrnNCol - 1) * 7) //carret in rigthest col
     ) then
    begin
     if Ctrl then
      begin
       Ornaments.CursorY := Ornaments.OrnNRow - 1;
       Ornaments.CursorX := Ornaments.OrnNCol * 7 - 4;
       Ornaments.ShownFrom := l - Ornaments.NOfLines;
      end
     else
      begin
       Inc(Ornaments.ShownFrom, Ornaments.NOfLines);
       if Ornaments.ShownFrom > l - Ornaments.NOfLines then
         Ornaments.ShownFrom := l - Ornaments.NOfLines;
      end;
     Ornaments.CalcCaretPos;
     if not (ssShift in Shift) then Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end
   else //just move carret
    begin
     Ornaments.ToggleSelection;
     Ornaments.CursorX := Ornaments.CursorX div 7; //col index
     if Ornaments.CursorX < Ornaments.OrnNCol - 1 then //just move cursor to the rightest
      begin
       Ornaments.CursorX := (l - Ornaments.ShownFrom - 1) div Ornaments.OrnNRow;
       if Ornaments.CursorX >= Ornaments.OrnNCol then
         Ornaments.CursorX := Ornaments.OrnNCol - 1;
      end
     else
       Ornaments.CursorY := Ornaments.OrnNRow - 1; //maximize Y

     //check CursorY
     if Ctrl or //move to last cel
       (Ornaments.CursorX * Ornaments.OrnNRow + Ornaments.CursorY +
       Ornaments.ShownFrom >= l) then //jump farther than last item
       Ornaments.CursorY := l - Ornaments.ShownFrom - Ornaments.CursorX *
         Ornaments.OrnNRow - 1;

     Ornaments.CursorX := Ornaments.CursorX * 7 + 3; //back to X coord

     Ornaments.CalcCaretPos;
     if ssShift in Shift then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
    end;
   Key := 0;
 end;

 procedure DoCursorPageUp;
 begin
   if Ornaments.CursorY = 0 then //at top, same action as Left
     DoCursorLeft
   else
    begin
     Ornaments.ToggleSelection;
     Ornaments.CursorY := 0;
     Ornaments.CalcCaretPos;
     if ssShift in Shift then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
     Key := 0;
    end;
 end;

 procedure DoCursorPageDown;
 var
   c, i, l: integer;
 begin
   if Ornaments.CursorY >= Ornaments.OrnNRow - 1 then //at bottom, same action as Right
     DoCursorRight
   else
    begin
     GetOrnParams(l, i, c);
     if (i >= l - 1) then //last item, no move
      begin
       if not (ssShift in Shift) then
         Ornaments.AbortSelection;
      end
     else //just move carret
      begin
       Ornaments.ToggleSelection;
       Dec(l, Ornaments.ShownFrom + 1); //index of last cel
       if Ornaments.CursorX div 7 >= l div Ornaments.OrnNRow then
         //carret in last col, move to orn end
         Ornaments.CursorY := l mod Ornaments.OrnNRow
       else //move to bottom
         Ornaments.CursorY := Ornaments.OrnNRow - 1;
       Ornaments.CalcCaretPos;
       if ssShift in Shift then
         Ornaments.ToggleSelection
       else
         Ornaments.ResetSelection;
      end;
     Key := 0;
    end;
 end;

 procedure DoDelete(Cut: boolean);
 begin
   if Cut then
    begin
     if MainForm.EditCut1.Enabled then
       MainForm.EditCut1.Execute;
     Key := 0;
    end
   else
    begin
     Ornaments.ClearSelection;
     Key := 0;
    end;
 end;

 procedure DoInsertLine;
 var
   i, L, c, j: integer;
 begin
   ValidateOrnament(OrnNum);
   GetOrnParams(L, i, c);
   if (i >= 0) and (i < Ornaments.ShownOrnament^.Length) then
    begin
     SongChanged := True;
     AddUndo(CAOrnamentInsertLine,{%H-}PtrInt(Ornaments.ShownOrnament), 0, auAutoIdxs);
     for j := MaxOrnLen - 1 downto i do
       Ornaments.ShownOrnament^.Items[j] := Ornaments.ShownOrnament^.Items[j - 1];
     Ornaments.ShownOrnament^.Items[i] := 0;
     if (Ornaments.ShownOrnament^.Loop < MaxOrnLen - 1) and
       (Ornaments.ShownOrnament^.Loop >= i) then
      begin
       Inc(Ornaments.ShownOrnament^.Loop);
       UDOrnLoop.Position := Ornaments.ShownOrnament^.Loop;
      end;
     if L < MaxOrnLen then
      begin
       UDOrnLoop.Max := Ornaments.ShownOrnament^.Length;
       Inc(Ornaments.ShownOrnament^.Length);
       UDOrnLen.Position := Ornaments.ShownOrnament^.Length;
      end;
     Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end;
   Key := 0;
 end;

 procedure DoRemoveLine;
 var
   i, L, c, j: integer;
 begin
   ValidateOrnament(OrnNum);
   GetOrnParams(L, i, c);
   if L = 1 then
     Exit;
   if (i >= 0) and (i < Ornaments.ShownOrnament^.Length) then
    begin
     SongChanged := True;
     AddUndo(CAOrnamentDeleteLine,{%H-}PtrInt(Ornaments.ShownOrnament), 0, auAutoIdxs);
     for j := i + 1 to MaxOrnLen - 1 do
       Ornaments.ShownOrnament^.Items[j - 1] := Ornaments.ShownOrnament^.Items[j];
     Ornaments.ShownOrnament^.Items[MaxOrnLen - 1] := 0;
     if (Ornaments.ShownOrnament^.Loop > 0) and
       ((Ornaments.ShownOrnament^.Loop > i) or
       (Ornaments.ShownOrnament^.Loop = L - 1)) then
      begin
       Dec(Ornaments.ShownOrnament^.Loop);
       UDOrnLoop.Position := Ornaments.ShownOrnament^.Loop;
      end;
     Dec(Ornaments.ShownOrnament^.Length);
     UDOrnLoop.Max := Ornaments.ShownOrnament^.Length - 1;
     UDOrnLen.Position := Ornaments.ShownOrnament^.Length;
     if i = Ornaments.ShownOrnament^.Length then //last line deleted, correct cursor
      begin
       if c > 0 then
        begin
         if Ornaments.CursorY > 0 then
           Dec(Ornaments.CursorY)
         else
          begin
           Ornaments.CursorY := Ornaments.OrnNRow - 1;
           Dec(Ornaments.CursorX, 7);
          end;
         Ornaments.CalcCaretPos;
        end
       else
         //make prev line visible
         Dec(Ornaments.ShownFrom);
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.OrnamentLine :=
         Ornaments.ShownFrom + Ornaments.CursorY + (Ornaments.CursorX div 7) *
         Ornaments.OrnNRow;
      end;
     Ornaments.ResetSelection;
     Ornaments.Invalidate;
    end;
   Key := 0;
 end;

var
 Act: TShortcutActions;
 Note, Dummy: integer;
begin
 if (Shift <> []) or not (Key in [Ord('0')..Ord('9'), VK_NUMPAD0..VK_NUMPAD9]) or
   SBOrnAsNotes.Down then
   Ornaments.InputONumber := 0;

 if (Shift = []) and not SBOrnAsNotes.Down then
   case Key of
     VK_0..VK_9:
       DoDigit(Key - VK_0);
     //special for Lee Bee
     VK_NUMPAD0..VK_NUMPAD9:
       DoDigit(Key - VK_NUMPAD0);
    end
 else if KeyToNote(Key, Shift, Note, Dummy, OrnamentTestLine, False) then
  begin
   if Note >= 0 then
    begin
     if Key and $8000 <> 0 then //MIDI key flag
       Dec(Note, 24);
     Dec(Note, GetBaseNote(tlOrnaments));
     if Note < -96 then
       Note := -96
     else if Note > 96 then
       Note := 96;
     DoNumber(Note, True);
    end;
   Key := 0;
  end;

 if Key = 0 then
   Exit;

 if GetShortcutAction(SCS_OrnamentEditor, Key, Shift, Act) then
   case Act of
     SCA_OrnamentColumnRight:
       DoCursorRight;
     SCA_OrnamentColumnLeft:
       DoCursorLeft;
     SCA_OrnamentDown:
       DoCursorDown;
     SCA_OrnamentUp:
       DoCursorUp;
     SCA_OrnamentColumnShownFirst:
       DoCursorHome(False);
     SCA_OrnamentBegin, SCA_OrnamentBegin2:
       DoCursorHome(True);
     SCA_OrnamentColumnShownLast:
       DoCursorEnd(False);
     SCA_OrnamentEnd, SCA_OrnamentEnd2:
       DoCursorEnd(True);
     SCA_OrnamentPageUp:
       DoCursorPageUp;
     SCA_OrnamentPageDown:
       DoCursorPageDown;
     SCA_OrnamentSelectionClear:
       DoDelete(False);
     SCA_OrnamentSelectionCut:
       DoDelete(True);
     SCA_OrnamentToggle:
       DoToggleSpace;
     SCA_OrnamentPlus, SCA_OrnamentPlus2, SCA_OrnamentPlus3:
       DoTogglePlus;
     SCA_OrnamentMinus, SCA_OrnamentMinus2:
       DoToggleMinus;
     SCA_OrnamentInsertLine, SCA_OrnamentInsertLine2:
       DoInsertLine;
     SCA_OrnamentDeleteLine, SCA_OrnamentDeleteLine2:
       DoRemoveLine;
     SCA_OrnamentSelectAll, SCA_OrnamentSelectAll2:
      begin
       Ornaments.SelectAll;
       Key := 0;
      end;
     SCA_OrnamentJumpToTest:
      begin
       if OrnamentTestLine.CanSetFocus then
         OrnamentTestLine.SetFocus;
       Key := 0;
      end;
    end;

 //block leave control by arrow keys
 MainForm.CheckKeysAndActionsConflicts(Key, Shift, [VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT]);
end;

procedure TChildForm.TracksMoveCursorMouse(X, Y: integer; Sel, Mv, ButRight: boolean);
var
 x1, y1, i, PLen: integer;
 SX1, SX2, SY1, SY2: integer;
begin
 if Mv and not Tracks.Clicked then
   Exit;

 SX2 := Tracks.CursorX;
 SX1 := Tracks.SelX;
 if SX1 > SX2 then
  begin
   SX1 := SX2;
   SX2 := Tracks.SelX;
  end;
 SY1 := Tracks.SelY;
 SY2 := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
 if SY1 > SY2 then
  begin
   SY1 := SY2;
   SY2 := Tracks.SelY;
  end;

 x1 := X div Tracks.CelW - Tracks.DigN;
 y1 := Y div Tracks.CelH;
 if Y < 0 then
   Dec(y1);

 i := Tracks.N1OfLines - Tracks.ShownFrom;
 if Tracks.ShownPattern = nil then
   PLen := DefPatLen
 else
   PLen := Tracks.ShownPattern^.Length;
 if Mv then
  begin
   if y1 < i then y1 := i
   else if y1 >= i + PLen then y1 := i + PLen - 1;
   if x1 < 0 then x1 := 0
   else if x1 > 48 then x1 := 48;
  end
 else
   Tracks.Clicked := (y1 >= i) and (y1 < i + PLen) and (x1 >= 0) and
     not ColSpace(x1);
 if (y1 >= i) and (y1 < i + PLen) and (x1 >= 0) and not ColSpace(x1) then
  begin
   if x1 in [9..10] then
     x1 := 8
   else if x1 in [23..24] then
     x1 := 22
   else if x1 in [37..38] then
     x1 := 36
   else if SBEnvAsNote.Down and (x1 in [1..3]) then
     x1 := 0;

   if not Mv and ButRight and (x1 >= SX1) and (x1 <= SX2) and
     (y1 >= SY1 + i) and (y1 <= SY2 + i) then
    begin
     Tracks.Clicked := False;
     Exit;
    end;

   if (Tracks.CursorX <> x1) or (Tracks.CursorY <> y1) then
    begin
     Tracks.ToggleSelection;
     Tracks.CursorX := x1;
     Tracks.CursorY := y1;
     if Tracks.CursorY >= Tracks.NOfLines then
      begin
       Inc(Tracks.ShownFrom, Tracks.CursorY - Tracks.NOfLines + 1);
       Tracks.CursorY := Tracks.NOfLines - 1;
       Tracks.Invalidate;
      end
     else if Tracks.CursorY < 0 then
      begin
       Inc(Tracks.ShownFrom, Tracks.CursorY);
       Tracks.CursorY := 0;
       Tracks.Invalidate;
      end
     else if Sel then
       Tracks.ToggleSelection
     else
       Tracks.ResetSelection;
    end
   else if not Sel then
     Tracks.AbortSelection;
  end;
 Tracks.RecreateCaret;
 Tracks.CalcCaretPos;
 ShowStat;
end;

procedure TChildForm.TracksMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 if not Tracks.Focused then
   if Tracks.CanSetFocus then
     Tracks.SetFocus;
 TracksMoveCursorMouse(X, Y, GetKeyState(VK_SHIFT) and 128 <> 0,
   False, Shift = [ssRight]);
end;

procedure TTestLine.TestLineMoveCursorMouse(X, Y: integer; Sel, Mv, ButRight: boolean);
var
 x1: integer;
 SX1, SX2: integer;
begin
 if Mv and not Clicked then
   Exit;

 SX2 := CursorX;
 SX1 := SelX;
 if SX1 > SX2 then
  begin
   SX1 := SX2;
   SX2 := SelX;
  end;

 x1 := X div CelW;

 if Mv then
  begin
   if x1 < 0 then
     x1 := 0
   else if x1 > 20 then
     x1 := 20;
  end
 else
   Clicked := (x1 >= 0) and not ColSpace(x1);

 if (x1 >= 0) and not ColSpace(x1) then
  begin
   if x1 in [9..10] then
     x1 := 8;

   if not Mv and ButRight and (x1 >= SX1) and (x1 <= SX2) then
    begin
     Clicked := False;
     Exit;
    end;

   if CursorX <> x1 then
    begin
     ToggleSelection;
     CursorX := x1;
     if Sel then
       ToggleSelection
     else
       ResetSelection;
    end
   else if not Sel then
     AbortSelection;
  end;
 RecreateCaret;
 CalcCaretPos;
end;

procedure TTestLine.TestLineMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 if not Focused then
   if CanSetFocus then
     SetFocus;
 TestLineMoveCursorMouse(X, Y, GetKeyState(VK_SHIFT) and 128 <> 0,
   False, Shift = [ssRight]);
end;

procedure TChildForm.SamplesVolMouse(x, y: integer);
var
 i: integer;
begin
 Dec(x, 21);
 if (x < 0) or (x > 15) then
   Exit;
 with Samples do
  begin
   ValidateSample2(SamNum);
   i := ShownFrom + y;
   if (i < 0) or (i >= ShownSample^.Length) then
     Exit;
   if ShownSample^.Items[i].Amplitude <> x then
    begin
     SongChanged := True;
     AddUndo(CAChangeSampleValue,{%H-}PtrInt(@ShownSample^.Items[i]), 0, SamNum, i, 19);
     if ChangeCount - 2 >= ClickedChangesStart then
       //group with a previous "onmove" changing
       ChangeList[ChangeCount - 2].Grouped := True;
     ShownSample^.Items[i].Amplitude := x;
     ResetSelection;
     Invalidate;
    end;
  end;
end;

procedure TChildForm.SamplesMoveCursorMouse(X, Y: integer; Sel, Mv: boolean;
 Shift: TShiftState);

 function DrawAccepted: boolean; inline;
 begin
   //draw volume if left/right button clicked due options
   if VTOptions.LMBToDraw then
     Result := Shift = [ssLeft]
   else
     Result := Shift = [ssRight];
 end;

var
 x1, y1, i, l: integer;
 b: boolean;
 ST: PSampleTick;
 SX1, SX2, SY1, SY2: integer;
begin
 if Mv then //moved to X,Y
  begin
   if Samples.ClickedX < 0 then //not clicked before, ignoring
     Exit;
   if Samples.ClickedX > 20 then //volume graphic area
    begin
     if DrawAccepted then
       SamplesVolMouse(X div Samples.CelW - 3, Y div Samples.CelH);
     Exit;
    end;
  end;

 //calculate selected area coords
 SX2 := Samples.CursorX;
 SX1 := Samples.SelX;
 if SX1 > SX2 then
  begin
   SX1 := SX2;
   SX2 := Samples.SelX;
  end;
 SY1 := Samples.SelY;
 SY2 := Samples.ShownFrom + Samples.CursorY;
 if SY1 > SY2 then
  begin
   SY1 := SY2;
   SY2 := Samples.SelY;
  end;

 Samples.InputSNumber := 0; //reset number inputing

 //calculate cel coords
 x1 := X div Samples.CelW - 3;
 y1 := Y div Samples.CelH;
 if Y < 0 then Dec(y1); //prevent small negative Y be rounded to zero

 //calculate sample size
 if Samples.ShownSample = nil then
   l := 1
 else
   l := Samples.ShownSample^.Length;

 i := -Samples.ShownFrom; //coord of zero line

 //if moved then check coords to be inside of sample body
 if Mv then
  begin
   if y1 < i then
     y1 := i
   else if y1 >= i + l then
     y1 := i + l - 1;
   if x1 < 0 then
     x1 := 0
   else if x1 > 20 then
     x1 := 20;
  end
 //if just clicked then be sure that it is editable cel to start selection from or
 //volume visualisation are to edit by mouse right move
 else if (x1 >= 0) and not (x1 in [3, 9, 13, 16, 18]) and (y1 >= 0) and
   (y1 < Samples.NOfLines) and (y1 - i < l) then
  begin
   Samples.ClickedX := x1;
   Samples.ClickedChangesStart := ChangeCount;
   //store next undo index to group changes during moving
  end
 else
   Samples.ClickedX := -1;

 //check if coords of editable cel or area
 if (y1 >= i) and (y1 < i + l) and (x1 >= 0) and not (x1 in [3, 9, 13, 16, 18]) then
  begin
   //calculate start coord of wide cels
   if x1 in [6..7] then
     x1 := 5
   else if x1 = 12 then
     x1 := 11
   else if x1 = 15 then
     x1 := 14;

   if (x1 = 5) and SBSamAsNotes.Down then
     Dec(x1);

   //if right click on selection, don't reset for popup menu
   if not Mv and (Shift = [ssRight]) and (x1 >= SX1) and (x1 <= SX2) and
     (y1 >= SY1 - Samples.ShownFrom) and (y1 <= SY2 - Samples.ShownFrom) then
    begin
     Samples.ClickedX := -1;
     Exit;
    end;

   if x1 <= 20 then //clicks on area with cels
     if (Samples.CursorX <> x1) or (Samples.CursorY <> y1) then //pointed new cel
      begin
       Samples.ToggleSelection; //hide selection
       Samples.CursorX := x1;
       Samples.CursorY := y1;
       if Samples.CursorY >= Samples.NOfLines then
         //new cel after visible lines, redraw to show it at last line
        begin
         Inc(Samples.ShownFrom, Samples.CursorY - Samples.NOfLines + 1);
         Samples.CursorY := Samples.NOfLines - 1;
         Samples.Invalidate;
        end
       //new cel before visible lines, redraw to show it at first line
       else if Samples.CursorY < 0 then
        begin
         Inc(Samples.ShownFrom, Samples.CursorY);
         Samples.CursorY := 0;
         Samples.Invalidate;
        end
       //since not redrawn, need show or reset selection
       else if Sel then
         Samples.ToggleSelection
       else
         Samples.ResetSelection;
      end
     //pointed same cel, so check if need too keep selection
     else if not Sel then
       Samples.AbortSelection;

   //check if some buttons clicked for specific actions
   if DrawAccepted then
     SamplesVolMouse(x1, y1) //change volume by clicking on volume graphic area
   else if Shift = [ssMiddle] then //toggle value of non numeric cel
    begin
     with Samples do
      begin
       ValidateSample2(SamNum);
       i := ShownFrom + y1; //calculating line number
       New(ST);
       ST^ := ShownSample^.Items[i]; //keep previous state for undo
       b := True;
       with ShownSample^.Items[i] do
         case x1 of
           0: Mixer_Ton := not Mixer_Ton;
           1: Mixer_Noise := not Mixer_Noise;
           2: Envelope_Enabled := not Envelope_Enabled;
           4: Add_to_Ton := -Add_to_Ton;
           8: Ton_Accumulation := not Ton_Accumulation;
           10: Add_to_Envelope_or_Noise := Nse(-Add_to_Envelope_or_Noise);
           17: Envelope_or_Noise_Accumulation := not Envelope_or_Noise_Accumulation;
           20: if not Amplitude_Sliding then
              begin
               Amplitude_Sliding := True;
               Amplitude_Slide_Up := False;
              end
             else if not Amplitude_Slide_Up then
               Amplitude_Slide_Up := True
             else
               Amplitude_Sliding := False;
         else
           //clicked on numeric cels, not changed
          begin
           b := False;
           Dispose(ST);
          end;
          end;
       if b then
        begin
         SongChanged := True;
         AddUndo(CAChangeSampleValue,{%H-}PtrInt(ST),{%H-}PtrInt(@ShownSample^.Items[i]),
           SamNum, i, x1);
         Invalidate;
        end;
      end;
    end;
  end;
 //need to correct caret width, if selected cell CursorX coord changed
 Samples.RecreateCaret;
 Samples.CalcCaretPos;
end;

procedure TChildForm.SamplesMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 if not Samples.Focused then
   if Samples.CanSetFocus then
     Samples.SetFocus;
 SamplesMoveCursorMouse(X, Y, GetKeyState(VK_SHIFT) and 128 <> 0, False, Shift);
end;

procedure TChildForm.TracksMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
begin
 if ((ssLeft in Shift) or (ssRight in Shift)) and Tracks.Enabled and Tracks.Focused then
   TracksMoveCursorMouse(X, Y, True, True, Shift = [ssRight]);
end;

procedure TTestLine.TestLineMouseMove(Sender: TObject; Shift: TShiftState;
 X, Y: integer);
begin
 if ((ssLeft in Shift) or (ssRight in Shift)) and Focused then
   TestLineMoveCursorMouse(X, Y, True, True, Shift = [ssRight]);
end;

procedure TChildForm.SamplesMouseMove(Sender: TObject; Shift: TShiftState;
 X, Y: integer);
begin
 if ((ssLeft in Shift) or (ssRight in Shift)) and Samples.Focused then
   SamplesMoveCursorMouse(X, Y, True, True, Shift);
end;

procedure TChildForm.OrnamentsMouseMove(Sender: TObject; Shift: TShiftState;
 X, Y: integer);
begin
 if ((ssLeft in Shift) or (ssRight in Shift)) and Ornaments.Focused then
   OrnamentsMoveCursorMouse(X, Y, True, True, Shift);
end;

procedure TChildForm.OrnamentsMoveCursorMouse(X, Y: integer; Sel, Mv: boolean;
 Shift: TShiftState);
var
 x1, y1, i, sf, l, c, SI1, SI2: integer;
begin
 if Mv and not Ornaments.Clicked then //not clicked before, ignoring moving
   Exit;

 //calculate selected lines idxs
 SI2 := (Ornaments.CursorX div 7) * Ornaments.OrnNRow + Ornaments.CursorY;
 SI1 := Ornaments.SelI;
 if SI1 > SI2 then
  begin
   SI1 := SI2;
   SI2 := Ornaments.SelI;
  end;

 Ornaments.InputONumber := 0;//reset number inputing

 //calculate cel coords
 x1 := X div Ornaments.CelW;
 if X < 0 then Dec(x1); //prevent small negative X be rounded to zero
 y1 := Y div Ornaments.CelH;
 if Y < 0 then Dec(y1); //prevent small negative Y be rounded to zero

 //calculate ornament size
 if Ornaments.ShownOrnament = nil then
   l := 1
 else
   l := Ornaments.ShownOrnament^.Length;

 sf := Ornaments.ShownFrom; //wanted ShownFrom

 //calculate cel index
 if Mv then
  begin
   //if moved upper of bound sub -y1 lines
   if y1 < 0 then
     c := sf + y1 //todo scroll speed
   //if moved lower of bound add y1-OrnNRow lines
   else if y1 >= Ornaments.OrnNRow then
     c := sf + Ornaments.NOfLines + y1 - Ornaments.OrnNRow
   //if moved lefter of bound sub column size
   else if x1 < 0 then
     c := sf - Ornaments.OrnNRow
   //if moved righter of bound add column size
   else if x1 >= Ornaments.OrnNCol * 7 then
     c := sf + Ornaments.NOfLines + Ornaments.OrnNRow - 1
   //if moved over editable cel
   else if byte(x1 mod 7) in [3..5] then
     c := sf + x1 div 7 * Ornaments.OrnNRow + y1
   else
     Exit;
   //check range for item index
   if c < 0 then
     c := 0
   else if c >= l then
     c := l - 1;
   //calc sf, x1 and y1 from cel index
   if sf > c then //need redraw to upper left
    begin
     sf := c;
     y1 := 0;
     x1 := 3;
    end
   else if sf + Ornaments.NOfLines <= c then //need redraw to view cel at lower right
    begin
     sf := c - Ornaments.NOfLines + 1;
     y1 := Ornaments.OrnNRow - 1;
     x1 := Ornaments.OrnNCol * 7 - 4;
    end
   else
    begin
     Dec(c, sf);
     y1 := c mod Ornaments.OrnNRow;
     x1 := c div Ornaments.OrnNRow * 7 + 3;
    end;
  end
 //if just clicked then be sure that is is editable cel to start selection from
 else
  begin
   i := x1 div 7;
   c := i * Ornaments.OrnNRow + y1;
   Ornaments.Clicked := (x1 >= 3) and (byte(x1 mod 7) in [3..5]) and
     (i < Ornaments.OrnNCol) and (y1 >= 0) and (y1 < Ornaments.OrnNRow) and
     (c < -sf + l);
   //set cursor X at start of cel
   x1 := i * 7 + 3;
  end;

 //check if clicked or moved over editable cel
 if Ornaments.Clicked then
   with Ornaments do
    begin
     //if right click on selection, don't reset for popup menu
     if not Mv and (Shift = [ssRight]) and (c >= SI1) and (c <= SI2) then
      begin
       Clicked := False;
       Exit;
      end;

     if (CursorX <> x1) or (CursorY <> y1) or (ShownFrom <> sf) then
       //pointed new cel or need redraw
      begin
       if ShownFrom = sf then //no need to redraw
         ToggleSelection; //hide selection
       CursorX := x1;
       CursorY := y1;
       if ShownFrom <> sf then
        begin
         ShownFrom := sf;
         Invalidate;
        end
       //since not redrawn, need show or reset selection
       else if Sel then
         ToggleSelection
       else
         ResetSelection;
      end
     //pointed same cel, so check if need too keep selection
     else if not Sel then
       AbortSelection;

     if (Shift = [ssMiddle]) and (ShownOrnament <> nil) then
       //toggle sign if middle button click
      begin
       i := sf + c;
       if (i < ShownOrnament^.Length) and (ShownOrnament^.Items[i] <> 0) then
        begin
         SongChanged := True;
         AddUndo(CAChangeOrnamentValue, ShownOrnament^.Items[i],
           -ShownOrnament^.Items[i], auAutoIdxs);
         ShownOrnament^.Items[i] := -ShownOrnament^.Items[i];
         ResetSelection;
         Invalidate;
        end;
      end;
    end;
 Ornaments.CalcCaretPos;
end;

procedure TChildForm.OrnamentsMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 if not Ornaments.Focused then
   if Ornaments.CanSetFocus then
     Ornaments.SetFocus;
 OrnamentsMoveCursorMouse(X, Y, GetKeyState(VK_SHIFT) and 128 <> 0, False, Shift);
end;

procedure TChildForm.SamplesContextPopup(Sender: TObject; MousePos: TPoint;
 var Handled: boolean);
begin
 //if RMB draw amplitude, don't pop-up in draw area
 Handled := not VTOptions.LMBToDraw and (Samples.ClickedX > 20);
end;

procedure TChildForm.DisposeUndo(All: boolean);
var
 i: integer;
begin
 if All then
   i := 0
 else
   i := ChangeCount - 1;
 for i := i to ChangeTop - 1 do
   case ChangeList[i].Action of
     CALoadPattern, CAInsertPatternFromClipboard, CAPatternInsertLine,
     CAPatternDeleteLine,
     CAPatternClearLine, CAPatternClearSelection, CATransposePattern,
     CATracksManagerCopy,
     CAExpandShrinkPattern, CASwapPattern:
       Dispose(ChangeList[i].Ptr.Pattern);
     CADeletePosition, CAInsertPosition, CAReorderPatterns:
      begin
       Dispose(ChangeList[i].Ptr.PositionList);
       if ChangeList[i].Action = CAReorderPatterns then
         Dispose(ChangeList[i].ComParams.PatternsIndex);
      end;
     CALoadOrnament, CAOrGen, CARenderOrnament, CAOrnamentInsertLine,
     CAOrnamentDeleteLine,
     CAOrnamentClearSelection, CAInsertOrnamentFromClipboard:
       Dispose(ChangeList[i].Ptr.Ornament);
     CALoadSample, CAUnrollSample, CARenderSample, CARecalcSample,
     CASampleInsertLine, CASampleDeleteLine, CASampleClearSelection,
     CAInsertSampleFromClipboard:
       Dispose(ChangeList[i].Ptr.Sample);
     CAChangeSampleValue:
       Dispose(ChangeList[i].Ptr.SampleLineValues);
    end;
 if All then
   ChangeCount := 0;
 ChangeTop := ChangeCount;
end;

procedure TChildForm.GroupLastChanges(From: integer);
//group last actions for one step undo
var
 i: integer;
begin
 for i := From to ChangeCount - 2 do //group all excluding last
   ChangeList[i].Grouped := True;
end;

procedure TChildForm.FormDestroy(Sender: TObject);
var
 ToFocus: TChildForm;
begin
 if MainForm.ActiveChild = Self then
  begin
   MainForm.Caption := 'Vortex Tracker II';

   //try to activate other window
   ToFocus := MainForm.Next(-1, False, False, True);
  end
 else
   ToFocus := nil;

 if IsPlayingWindow >= 0 then
  begin
   digsoundthread_stop;
   MainForm.RestoreControls;
  end;
 MainForm.DeleteWindowListItem(Self);
 MainForm.Childs.Delete(MainForm.Childs.IndexOf(Self));

 DisposeUndo(True);
 ChangeList := nil;
 FreeVTMP(VTMP);
 WinMenuItem.Free;

 if TSWindow <> nil then
  begin
   TSWindow.TSWindow := nil; //was Self (which destroying now)
   //don't close 2nd window if just joined existing modules (i.e. with different filenames)
   if TSWindow.WinFileName = WinFileName then
     TSWindow.Close;
  end;

 //perform some actions later need after disappearing child
 Application.QueueAsyncCall(@MainForm.ChildClosed, PtrInt(ToFocus));
end;

procedure TChildForm.SetFileName(aFileName: string);
var
 i: integer;
begin
 WinFileName := aFileName;
 Caption := IntToStr(WinNumber) + ': ' + ExtractFileName(aFileName) +
   ' (' + ExtractFilePath(aFileName) + ')';
 if Active then
   MainForm.Caption := Caption + ' - Vortex Tracker II';
 WinMenuItem.Caption := Caption;
 for i := 1 to TSSel.ListBox1.Items.Count - 1 do
   if TSSel.ListBox1.Items.Objects[i] = Self then
    begin
     TSSel.ListBox1.Items.Strings[i] := Caption;
     break;
    end;
 for i := 0 to MainForm.Childs.Count - 1 do
   if TChildForm(MainForm.Childs.Items[i]).TSWindow = Self then
     TChildForm(MainForm.Childs.Items[i]).SBTS.Caption :=
       PrepareTSString(TChildForm(MainForm.Childs.Items[i]).SBTS, Caption);
end;

function TChildForm.LoadTrackerModule(aFileName: string; var VTMP2: PModule): boolean;
const
 ers: array[1..6] of string =
   (Mes_LoadErrModNotFound,
   Mes_LoadErrSyntax,
   Mes_LoadErrRange,
   Mes_LoadErrUnEnd,
   Mes_LoadErrBadSam,
   Mes_LoadErrBadPat);
var
 ZXP: TSpeccyModule;
 i, Tm, TSSize2: integer;
 Andsix: byte;
 ZXAddr: word;
 AuthN, SongN: string;

 function Convert(FType: Available_Types; VTMP: PModule; var VTMP2: PModule): boolean;
 begin
   Result := True; //todo result
   case FType of
     Unknown:
      begin
       i := LoadModuleFromText(aFileName, VTMP, VTMP2);
       if i <> 0 then
        begin
         Application.MessageBox(PChar(ers[i] + ' (' + Mes_LoadErrLine +
           ': ' + IntToStr(TxtLine) + ')'), @Mes_LoadErrCapt[1], MB_ICONEXCLAMATION);
         Exit(False);
        end;
      end;
     PT2File:
       PT22VTM(@ZXP, VTMP);
     PT1File:
       PT12VTM(@ZXP, VTMP);
     STCFile:
       STC2VTM(@ZXP, i, VTMP);
     ST1File:
       ST12VTM(@ZXP, i, SongN, AuthN, VTMP);
     ST3File:
       ST32VTM(@ZXP, i, VTMP);
     STPFile:
       STP2VTM(@ZXP, VTMP);
     STFFile:
       STF2VTM(@ZXP, i, VTMP);
     SQTFile:
       SQT2VTM(@ZXP, VTMP);
     ASCFile:
       ASC2VTM(@ZXP, VTMP);
     ASC0File:
       ASC02VTM(@ZXP, i, VTMP);
     PSCFile:
       PSC2VTM(@ZXP, VTMP);
     FLSFile:
       FLS2VTM(@ZXP, VTMP);
     GTRFile:
       GTR2VTM(@ZXP, VTMP);
     FTCFile:
       FTC2VTM(@ZXP, VTMP);
     FXMFile:
       FXM2VTM(@ZXP, ZXAddr, Tm, Andsix, SongN, AuthN, VTMP);
     PSMFile:
       PSM2VTM(@ZXP, VTMP);
     PT3File:
      begin
       PT32VTM(@ZXP, i, VTMP, VTMP2);
       SavedAsText := False;
      end;
    end;
 end;

var
 FileType, FType2: Available_Types;
 s: string;
 f: file;
 dummy: PModule;
begin
 Result := True;
 UndoWorking := True;
 SavedAsText := True;
  try
   if VTMP2 = nil then
    begin
     FileType := LoadAndDetect(@ZXP, aFileName, i, FType2, TSSize2,
       ZXAddr, Tm, Andsix, AuthN, SongN);
     Result := Convert(FileType, VTMP, VTMP2);
     if not Result then exit;
     if (VTMP2 = nil) and (FType2 <> Unknown) and (TSSize2 <> 0) then
      begin
       FillChar(ZXP, 65536, 0);
       AssignFile(f, aFileName);
       Reset(f, 1);
       Seek(f, i);
       BlockRead(f, ZXP, TSSize2, i);
       CloseFile(f);
       if i = TSSize2 then
        begin
         PrepareZXModule(@ZXP, FType2, TSSize2);
         if FType2 <> Unknown then
          begin
           NewVTMP(VTMP2);
           dummy := nil;
           Convert(FType2, VTMP2, dummy); //todo if Convert?
           if dummy <> nil then FreeVTMP(dummy);
          end;
        end;
      end;
    end
   else
    begin
     FreeVTMP(VTMP);
     VTMP := VTMP2;
     if LowerCase(ExtractFileExt(aFileName)) = '.pt3' then SavedAsText := False;
    end;
   SetFileName(aFileName);
   GBFeatures.ItemIndex := VTMP^.FeaturesLevel;
   GBHeader.ItemIndex := Ord(not VTMP^.VortexModule_Header);
   MainForm.AddFileName(aFileName);
   SBPositionsUpdateMax;
   if VTMP^.Positions.Length > 0 then
     ChangePattern(VTMP^.Positions.Value[0])
   else
     ChangePattern(0);
   UDSpeed.Position := VTMP^.Initial_Delay;
   FillToneTableControls;
   UpdateToneTableHints;
   EdTitle.Text := WinCPToUTF8(VTMP^.Title);
   EdAuthor.Text := WinCPToUTF8(VTMP^.Author);
   PosDelay := VTMP^.Initial_Delay;
   for i := 0 to VTMP^.Positions.Length - 1 do
    begin
     s := IntToStr(VTMP^.Positions.Value[i]);
     if i = VTMP^.Positions.Loop then
       s := 'L' + s;
     SGPositions.Cells[i, 0] := s;
    end;
   Samples.ShownSample := VTMP^.Samples[1];
   if VTMP^.Samples[1] <> nil then
    begin
     UDSamLen.Position := VTMP^.Samples[1]^.Length;
     UDSamLoop.Max := VTMP^.Samples[1]^.Length - 1;
     UDSamLoop.Position := VTMP^.Samples[1]^.Loop;
    end;
   Ornaments.ShownOrnament := VTMP^.Ornaments[1];
   if VTMP^.Ornaments[1] <> nil then
    begin
     UDOrnLen.Position := VTMP^.Ornaments[1]^.Length;
     UDOrnLoop.Max := VTMP^.Ornaments[1]^.Length - 1;
     UDOrnLoop.Position := VTMP^.Ornaments[1]^.Loop;
    end;
   ToglSams.CheckUsedSamples;
   CalcTotLen;
   for i := 1 to 31 do
     if VTMP^.Samples[i] <> nil then
      begin
       VTMP^.Samples[i]^.Enabled := True;
       for Tm := VTMP^.Samples[i]^.Length to MaxSamLen - 1 do
         FillChar(VTMP^.Samples[i]^.Items[Tm], SizeOf(TSampleTick), 0);
      end;
   for i := 1 to 15 do
     if VTMP^.Ornaments[i] <> nil then
       for Tm := VTMP^.Ornaments[i]^.Length to MaxOrnLen - 1 do
         VTMP^.Ornaments[i]^.Items[Tm] := 0;
   Tracks.Invalidate;
  finally
   UndoWorking := False;
   SongChanged := False;
  end;
end;

procedure TChildForm.TracksMouseWheelDown(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
var
 PLen: integer;
begin
 Handled := True;
 if Tracks.ShownPattern = nil then
   PLen := DefPatLen
 else
   PLen := Tracks.ShownPattern^.Length;
 if Tracks.ShownFrom < PLen - 1 then
  begin
   Inc(Tracks.ShownFrom);
   if (Tracks.CursorY > 0) and (Tracks.CursorY <> Tracks.N1OfLines) then
    begin
     Dec(Tracks.CursorY);
     Tracks.CalcCaretPos;
    end;
   if GetKeyState(VK_SHIFT) and 128 = 0 then
     Tracks.ResetSelection;
   Tracks.Invalidate;
  end
 else
  begin
   Tracks.ShownFrom := 0;
   Tracks.CursorY := Tracks.N1OfLines;
   Tracks.ResetSelection;
   Tracks.Invalidate;
   Tracks.CalcCaretPos;
  end;
 ShowStat;
end;

procedure TChildForm.TracksMouseWheelUp(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
var
 PLen: integer;
begin
 Handled := True;
 if Tracks.ShownFrom > 0 then
  begin
   Dec(Tracks.ShownFrom);
   if (Tracks.CursorY < Tracks.NOfLines - 1) and
     (Tracks.CursorY <> Tracks.N1OfLines) then
    begin
     Inc(Tracks.CursorY);
     Tracks.CalcCaretPos;
    end;
   if GetKeyState(VK_SHIFT) and 128 = 0 then
     Tracks.ResetSelection;
   Tracks.Invalidate;
  end
 else
  begin
   if Tracks.ShownPattern = nil then
     PLen := DefPatLen
   else
     PLen := Tracks.ShownPattern^.Length;
   Tracks.ShownFrom := PLen - 1;
   Tracks.CursorY := Tracks.N1OfLines;
   Tracks.ResetSelection;
   Tracks.Invalidate;
   Tracks.CalcCaretPos;
  end;
 ShowStat;
end;

procedure TChildForm.ShowSelectedInstrument(Pat: PPattern; Line, CursorX: integer);
var
 Chan: integer;
begin
 if (Pat = nil) or (Line < 0) or (Line >= Pat^.Length) then
   Exit;
 Chan := (CursorX - 8) div 14;
 if (CursorX in SamPoses) and (Pat^.Items[Line].Channel[Chan].Sample > 0) then
  begin
   ChangeSample(Pat^.Items[Line].Channel[Chan].Sample);
   EditorPages.ActivePageIndex := piSamples;
  end
 else if (CursorX in OrnPoses) and (Pat^.Items[Line].Channel[Chan].Ornament > 0) then
  begin
   ChangeOrnament(Pat^.Items[Line].Channel[Chan].Ornament);
   EditorPages.ActivePageIndex := piOrnaments;
  end;
end;

procedure TChildForm.TracksDblClick(Sender: TObject);
begin
 ShowSelectedInstrument(Tracks.ShownPattern, Tracks.ShownFrom -
   Tracks.N1OfLines + Tracks.CursorY, Tracks.CursorX);
end;

procedure TChildForm.TestLineDblClick(Sender: TObject);
begin
 with Sender as TTestLine do
   ShowSelectedInstrument(VTMP^.Patterns[-1], LineIndex, CursorX);
end;

procedure TChildForm.SamplesMouseWheelDown(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
var
 l: integer;
 Redraw, Carret: boolean;
begin
 if ssMiddle in Shift then //middle buttons clicks to toggle sample values, don't move
   Exit;

 Samples.InputSNumber := 0;
 Handled := True;

 Redraw := False;
 Carret := False;

 if Samples.ShownSample = nil then
   l := 1
 else
   l := Samples.ShownSample^.Length;

 if Samples.ShownFrom < l - Samples.NOfLines then
   //scroll sheet up to make sense that cursor jumping down
  begin
   Inc(Samples.ShownFrom);
   Redraw := True;
  end
 else if (Samples.ShownFrom + Samples.CursorY < l - 1) and //not last item
   (Samples.CursorY < Samples.NOfLines - 1) then //not last line
   //jump cursor down
  begin
   Samples.ToggleSelection;
   Inc(Samples.CursorY);
   Carret := True;
  end
 else if Samples.ShownFrom <> 0 then
   //redraw from start and move cursor to top
  begin
   Samples.ShownFrom := 0;
   Samples.CursorY := 0;
   Redraw := True;
   Carret := True;
  end
 else
   //just move cursor to top
  begin
   Samples.ToggleSelection;
   Samples.CursorY := 0;
   Carret := True;
  end;

 if Carret then
  begin
   Samples.CalcCaretPos;
   if not Redraw then
     if GetKeyState(VK_SHIFT) and 128 <> 0 then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
  end;
 if Redraw then
  begin
   if GetKeyState(VK_SHIFT) and 128 = 0 then
     Samples.ResetSelection;
   Samples.Invalidate;
  end;
end;

procedure TChildForm.SamplesMouseWheelUp(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
var
 l: integer;
 Redraw, Carret: boolean;
begin
 if ssMiddle in Shift then //middle buttons clicks to toggle sample values, don't move
   Exit;

 Samples.InputSNumber := 0;
 Handled := True;

 Redraw := False;
 Carret := False;

 if Samples.ShownSample = nil then
   l := 1
 else
   l := Samples.ShownSample^.Length;

 if Samples.ShownFrom > 0 then
   //scroll sheet down to make sense that cursor jumping up
  begin
   Dec(Samples.ShownFrom);
   Redraw := True;
  end
 else if Samples.CursorY > 0 then
   //jump cursor up
  begin
   Samples.ToggleSelection;
   Dec(Samples.CursorY);
   Carret := True;
  end
 else if l > Samples.NOfLines then
   //redraw to fit end and move cursor to bottom
  begin
   Samples.ShownFrom := l - Samples.NOfLines;
   Samples.CursorY := Samples.NOfLines - 1;
   Redraw := True;
   Carret := True;
  end
 else
   //just move cursor to end
  begin
   Samples.ToggleSelection;
   Samples.CursorY := l - 1;
   Carret := True;
  end;

 if Carret then
  begin
   Samples.CalcCaretPos;
   if not Redraw then
     if GetKeyState(VK_SHIFT) and 128 <> 0 then
       Samples.ToggleSelection
     else
       Samples.ResetSelection;
  end;
 if Redraw then
  begin
   if GetKeyState(VK_SHIFT) and 128 = 0 then
     Samples.ResetSelection;
   Samples.Invalidate;
  end;
end;

procedure TChildForm.OrnamentsMouseWheelDown(Sender: TObject;
 Shift: TShiftState; MousePos: TPoint; var Handled: boolean);
var
 l, c: integer;
 Redraw, Carret: boolean;
begin
 Ornaments.InputONumber := 0;
 Handled := True;

 Redraw := False;
 Carret := False;

 if Ornaments.ShownOrnament = nil then
   l := 1
 else
   l := Ornaments.ShownOrnament^.Length;
 c := Ornaments.CursorX div 7 * Ornaments.OrnNRow + Ornaments.CursorY;

 if Ornaments.ShownFrom < l - Ornaments.NOfLines then
   //scroll sheet up to make sense that cursor jumping down
  begin
   Inc(Ornaments.ShownFrom);
   Redraw := True;
  end
 else if (Ornaments.ShownFrom + c < l - 1) and //not last item
   (c < Ornaments.NOfLines - 1) then //not last cel
   //jump cursor to next cel
  begin
   Ornaments.ToggleSelection;
   if Ornaments.CursorY < Ornaments.OrnNRow - 1 then //just down
     Inc(Ornaments.CursorY)
   else //to top of righter col
    begin
     Ornaments.CursorY := 0;
     Inc(Ornaments.CursorX, 7);
    end;
   Carret := True;
  end
 else if Ornaments.ShownFrom <> 0 then
   //redraw from start and move cursor to top
  begin
   Ornaments.ShownFrom := 0;
   Ornaments.CursorX := 3;
   Ornaments.CursorY := 0;
   Redraw := True;
   Carret := True;
  end
 else
   //just move cursor to top
  begin
   Ornaments.ToggleSelection;
   Ornaments.CursorX := 3;
   Ornaments.CursorY := 0;
   Carret := True;
  end;

 if Carret then
  begin
   Ornaments.CalcCaretPos;
   if not Redraw then
     if GetKeyState(VK_SHIFT) and 128 <> 0 then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
  end;
 if Redraw then
  begin
   if GetKeyState(VK_SHIFT) and 128 = 0 then
     Ornaments.ResetSelection;
   Ornaments.Invalidate;
  end;
end;

procedure TChildForm.OrnamentsMouseWheelUp(Sender: TObject; Shift: TShiftState;
 MousePos: TPoint; var Handled: boolean);
var
 l: integer;
 Redraw, Carret: boolean;
begin
 Ornaments.InputONumber := 0;
 Handled := True;

 Redraw := False;
 Carret := False;

 if Ornaments.ShownOrnament = nil then
   l := 1
 else
   l := Ornaments.ShownOrnament^.Length;

 if Ornaments.ShownFrom > 0 then
   //scroll sheet down to make sense that cursor jumping up
  begin
   Dec(Ornaments.ShownFrom);
   Redraw := True;
  end
 else if Ornaments.CursorY > 0 then
   //jump cursor up
  begin
   Ornaments.ToggleSelection;
   Dec(Ornaments.CursorY);
   Carret := True;
  end
 else if Ornaments.CursorX > 6 then
   //jump cursor to bottom of left
  begin
   Ornaments.ToggleSelection;
   Dec(Ornaments.CursorX, 7);
   Ornaments.CursorY := Ornaments.OrnNRow - 1;
   Carret := True;
  end
 else if l > Ornaments.NOfLines then
   //redraw to fit end and move cursor to last cel
  begin
   Ornaments.ShownFrom := l - Ornaments.NOfLines;
   Ornaments.CursorX := Ornaments.OrnNCol * 7 - 4;
   Ornaments.CursorY := Ornaments.OrnNRow - 1;
   Redraw := True;
   Carret := True;
  end
 else
   //just move cursor to end
  begin
   Ornaments.ToggleSelection;
   Dec(l);
   Ornaments.CursorY := l mod Ornaments.OrnNRow;
   Ornaments.CursorX := l div Ornaments.OrnNRow * 7 + 3;
   Carret := True;
  end;

 if Carret then
  begin
   Ornaments.CalcCaretPos;
   if not Redraw then
     if GetKeyState(VK_SHIFT) and 128 <> 0 then
       Ornaments.ToggleSelection
     else
       Ornaments.ResetSelection;
  end;
 if Redraw then
  begin
   if GetKeyState(VK_SHIFT) and 128 = 0 then
     Ornaments.ResetSelection;
   Ornaments.Invalidate;
  end;
end;

procedure TChildForm.UDAutoStepClick(Sender: TObject; Button: TUDBtnType);
begin
 if not SBAutoStep.Down then
   SBAutoStep.Click;
end;

procedure TChildForm.ValidatePattern2(pat: integer);
begin
 ValidatePattern(pat, VTMP);
 if pat = PatNum then
   Tracks.ShownPattern := VTMP^.Patterns[PatNum];
end;

procedure TChildForm.TracksKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 if Tracks.KeyPressed = Key then
   //if user tries play legato, stop playing only if same key is up
  begin
   if IsPlaying and (PlayMode in [PMPlayLine, PMPlayPattern]) and
     (PlaybackWindow[0] = Self) then
    begin
     MainForm.VisTimer.Enabled := False;
     CatchAndResetPlaying;
     PlayMode := PMPlayLine;
    end;
   Tracks.KeyPressed := 0;
  end;
end;

procedure TTestLine.TestLineKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
 if KeyPressed = Key then
   //if user tries play legato, stop playing only if same key is up
  begin
   if (PlayMode = PMPlayLine) and IsPlaying and (PlaybackWindow[0] = ParWind) then
     CatchAndResetPlaying;
   KeyPressed := 0;
  end;
end;

procedure TChildForm.RestartPlayingPos(Pos: integer);
begin
 if IsPlayingWindow < 0 then
   Exit;
 if PlayMode <> PMPlayModule then
   Exit;
 digsoundloop_catch;
  try
   RerollToPos(Pos);
   ResetPlaying;
  finally
   digsoundloop_release;
  end;
end;

procedure TChildForm.RestartPlayingLine(Line: integer);
var
 i, ifrom, ito, aLine, aPat: integer;
begin
 if IsPlaying then
  begin
   if PlayMode <> PMPlayLine then
     Exit;
   digsoundloop_catch;
  end;
  try
   if IsPlaying then
     if PlaybackWindow[0] <> Self then //no need to recreate player if same window
       MainForm.FreePlayers
     else
       MainForm.FreePlayers(0); //free players, but keep first
   PlayMode := PMPlayLine;
   if not IsPlaying or (PlaybackWindow[0] <> Self) then
     //Disable controls in Options only
    begin
     OptionsDlg.PlayStarts;
     PlaybackWindow[0] := Self;
     SetLength(PlaybackBufferMaker.Players, 1);
     VTMP^.NewPlayer(PlaybackBufferMaker.Players[0]);
    end;
   if Line >= 0 then //all 3 channels (usual pattern)
    begin
     ifrom := 0;
     ito := 2;
     aLine := Line;
     aPat := PatNum;
    end
   else //middle channel (test line)
    begin
     ifrom := MidChan;
     ito := MidChan;
     aLine := -(Line + 1);
     aPat := -1; //fake pattern
    end;
   PlaybackBufferMaker.InitForAllTypes;
   with PlaybackBufferMaker.Players[0]^ do
    begin
     with VTMP^.Saves do
      begin
       for i := ifrom to ito do
         with Chans[i], Chns[i] do
          begin
           Note := Nt;
           Sample := Smp;
           Ornament := Orn;
           Volume := Vol;
          end;
       for i := ito downto ifrom do //only the highest chan controls EnvT
         with Chans[i], Chns[i] do
           if EnvT > 0 then
            begin
             EnvP_Base := EnvP;
             EnvelopeEnabled := EnvT;
             SoundChip.SetEnvelopeRegister(EnvT);
             Break;
            end;
      end;
     for i := ifrom to ito do
       with VTMP^.Patterns[aPat]^.Items[aLine].Channel[i] do
         if (Note = NT_NO) and (Envelope in [1..14]) then
           Chans[i].SoundEnabled := True;
     Module_SetPattern(aPat);
     Pattern_SetLine(aLine);
    end;

   //need to call PatternInterpreter here, do it via Pattern_PlayLine
   PlaybackBufferMaker.Players[0]^.Pattern_PlayLine;

   //Update Saves for next RestartPlayingLine
   with PlaybackBufferMaker.Players[0]^, VTMP^.Saves do
    begin
     for i := ifrom to ito do
       with Chans[i], Chns[i] do
        begin
         Nt := Note;
         Smp := Sample;
         Orn := Ornament;
         Vol := Volume;
        end;
     for i := ito downto ifrom do //only the highest chan controls EnvT
       with Chans[i], Chns[i] do
         if EnvelopeEnabled > 0 then
          begin
           EnvP := EnvP_Base;
           EnvT := EnvelopeEnabled;
           Break;
          end;
    end;

   ResetPlaying;

   //we was forced to call Pattern_PlayLine, so must inform MakeBufferTracker that
   //registers already obtained and no need to call Get_Registers for this tick
   PlaybackBufferMaker.LineReady := True;

  finally
   if IsPlaying then
     digsoundloop_release(True);
  end;
 if not IsPlaying then
   digsoundthread_start2(False); //silent (without error message showing)
end;

procedure TChildForm.RestartPlayingPatternLine(Enter: boolean);
begin
 if IsPlaying then
  begin
   if PlayMode <> PMPlayLine then
     Exit;
   //We are during editing, no need to reinit digisound
   digsoundloop_catch;
  end;
  try
   if IsPlaying then
     if PlaybackWindow[0] <> Self then //no need to recreate player if same window
       MainForm.FreePlayers
     else
       MainForm.FreePlayers(0); //free players, but keep first
   PlayMode := PMPlayPattern;
   //todo если pattern совпадает с выделенной позицией, сделать reroll (можно с учётом TSWindow как в VT 2.6)
   if not IsPlaying or (PlaybackWindow[0] <> Self) then
     if Enter then
       //Disable controls in Options only
      begin
       OptionsDlg.PlayStarts;
       PlaybackWindow[0] := Self;
       SetLength(PlaybackBufferMaker.Players, 1);
       VTMP^.NewPlayer(PlaybackBufferMaker.Players[0]);
      end
     else
       //Same actions for all controls
       MainForm.DisableControls;
   Tracks.AbortSelection;
   with PlaybackBufferMaker.Players[0]^ do
    begin
     Module_SetDelay;
     CurrentPosition := -1;
     Module_SetPattern(PatNum);
    end;
   PlaybackBufferMaker.InitForAllTypes;
   RerollToPatternLine;
   ResetPlaying;
  finally
   if IsPlaying then
     digsoundloop_release(True);
  end;
 if not IsPlaying then
   if not digsoundthread_start2(True) then
    begin
     MainForm.RestoreControls;
     Tracks.ResetSelection;
     Exit;
    end;
 MainForm.VisTimer.Enabled := True;
end;

//InitForAllTypes must be called somewhere before
procedure TChildForm.RerollToInt(Int_: integer);
var
 i: integer;
begin
 i := IsPlaybackWindow;
 if i >= 0 then
   with PlaybackBufferMaker, Players[i]^ do
    begin
     Module_SetDelay;
     Module_SetPosition;
     if Int_ > 0 then
      begin
       repeat
         if Module_PlayLine = 3 then
           if not LoopAllowed and (not MainForm.LoopAllAllowed or
             (MainForm.Childs.Count <> 1)) then
            begin
             Real_End := True;
             SoundChip.SetAmplA(0);
             SoundChip.SetAmplB(0);
             SoundChip.SetAmplC(0);
            end;
       until (IntCnt >= Int_) or Real_End;
       LineReady := True;
      end;
    end;
end;

procedure TChildForm.RerollToPos(Pos: integer);
var
 i: integer;
begin
 i := IsPlaybackWindow;
 if i >= 0 then
   with PlaybackBufferMaker, Players[i]^ do
    begin
     Module_SetDelay;
     Module_SetPosition;
     InitForAllTypes;
     if Pos > 0 then
      begin
       repeat
         i := Module_PlayLine;
       until (i = 2) and (CurrentPosition = Pos);
       LineReady := True;
      end;
     if Length(Players) > 1 then
       TSWindow.RerollToInt(IntCnt);
    end;
end;

procedure TChildForm.RerollToLine;
var
 i: integer;
begin
 i := IsPlaybackWindow;
 if i >= 0 then
   with PlaybackBufferMaker, Players[i]^ do
    begin
     Module_SetDelay;
     Module_SetPosition;
     InitForAllTypes;
     if PositionNumber > 0 then
      begin
       repeat
         i := Module_PlayLine;
       until (i = 2) and (CurrentPosition = PositionNumber);
       LineReady := True;
      end;
     if Tracks.ShownFrom > 0 then
      begin
       repeat
         i := Module_PlayLine;
       until (i = 1) and (CurrentLine = Tracks.ShownFrom + 1);
       LineReady := True;
      end;
     if Length(Players) > 1 then
       TSWindow.RerollToInt(IntCnt);
    end;
end;

procedure TChildForm.RerollToPatternLine;
var
 i, j: integer;
begin
 i := IsPlaybackWindow;
 if i >= 0 then
   with PlaybackBufferMaker, Players[i]^ do
    begin
     LineReady := False;
     j := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
     if (j > 0) and (j < Tracks.ShownPattern^.Length) then
      begin
       repeat
         i := Pattern_PlayLine;
       until (i = 1) and (CurrentLine = j + 1);
       LineReady := True;
      end;
    end;
end;

procedure TChildForm.GoToTime(Time: integer);
var
 Pos, Line: integer;
begin
 GetTimeParams(VTMP, Time, Pos, Line);
 if Pos >= 0 then
   MainForm.RedrawPlWindow(Self, Pos, VTMP^.Positions.Value[Pos], Line)
 else if VTMP^.Positions.Length < SGPositions.ColCount then
   //select cell after last filled position
   SGPositions.Col := VTMP^.Positions.Length;
end;

procedure TChildForm.SinchronizeModules;
begin
 if IsSinchronizing then
   Exit;
 if (TSWindow <> nil) and (TSWindow <> Self) and
   ((IsPlayingWindow < 0) or (PlayMode <> PMPlayModule)) then
  begin
   TSWindow.IsSinchronizing := True;
    try
     TSWindow.GoToTime(PosBegin + LineInts);
    finally
     TSWindow.IsSinchronizing := False;
    end;
  end;
end;

procedure TChildForm.SelectPattern(aPat: integer);
begin
 //no need to select if selected already
 if PatNum <> aPat then
   ChangePattern(aPat);
end;

procedure TChildForm.SelectPosition(aPos: integer);
var
 IsPl: boolean;
begin
 if aPos < VTMP^.Positions.Length then
   //valid position
  begin
   PositionNumber := aPos;
   CalculatePos0;
   IsPl := IsPlayingWindow >= 0;
   if IsPl and (PlayMode = PMPlayModule) then
     //each user click during playing module restarts it from selected position
     RestartPlayingPos(aPos)
   else if not IsPl or (PlayMode <> PMPlayPattern) then
     //try select new pattern only if not playing any pattern
     SelectPattern(VTMP^.Positions.Value[aPos]);
  end
 else
   //selected cell somewhere in empty area
  begin
   //just update duration info by total length values
   PosBegin := TotInts;
   LineInts := 0;
   LbTime.Caption := IntsToTime(PosBegin);
   LbTicks.Caption := '(' + IntToStr(PosBegin);
   SinchronizeModules;
  end;
 InputPNumber := 0;
end;

procedure TChildForm.ShowPosition(aPos: integer);
var
 EvHndStore: TOnSelectCellEvent;
begin
 //todo подумать над случаями, когда надо убирать выделение в этой функции, может это лучше вынести наружу
 if VTMP^.Positions.Length = 0 then
  begin
   PosRemoveSelection;
   SGPositions.Col := 0;
   Exit;
  end;
 if SGPositions.Col <> aPos then
  begin
   if aPos >= SGPositions.LeftCol + PosVisibleCols{SGPositions.VisibleColCount} then
     SGPositions.LeftCol := aPos + 1 - PosVisibleCols{SGPositions.VisibleColCount}
   else if aPos < SGPositions.LeftCol then
     SGPositions.LeftCol := aPos;

   Inc(PosReselection); //prevent handling OnSelection
   //prevent raising OnSelectCell
   EvHndStore := SGPositions.OnSelectCell;
   SGPositions.OnSelectCell := nil;
   PosRemoveSelection;
   SGPositions.Col := aPos;
   SGPositions.OnSelectCell := EvHndStore;
   Dec(PosReselection);

   InputPNumber := 0;

   if aPos < VTMP^.Positions.Length then
     //todo два раза делается если ShowPosition и SelectPosition использовать друг за другом
    begin
     PositionNumber := aPos;
     CalculatePos0;
    end;
  end
 else //no need to show, just hide selection
   PosRemoveSelection;
end;

procedure TChildForm.SGPositionsSelectCell(Sender: TObject; ACol, ARow: integer;
 var CanSelect: boolean);
begin
 CanSelect := ACol <= 255;

 if not CanSelect then
   Exit;

 if VTMP^.Positions.Length <> 0 then
   //at least last used pos must be visible
   CanSelect := ACol + 1 < VTMP^.Positions.Length + PosVisibleCols
 else
   //or 1st unused pos
   CanSelect := ACol < PosVisibleCols;

 if CanSelect and (SGPositions.Tag < 2) then //not clicked or clicked but not moved
   SelectPosition(ACol);
end;

procedure TChildForm.RedrawPositions(From: integer = 0);
var
 i: integer;
 s: string;
begin
 for i := From to VTMP^.Positions.Length - 1 do
  begin
   s := IntToStr(VTMP^.Positions.Value[i]);
   if i = VTMP^.Positions.Loop then
     s := 'L' + s;
   SGPositions.Cells[i, 0] := s;
  end;
 for i := VTMP^.Positions.Length to 255 do
   SGPositions.Cells[i, 0] := '...';
end;

procedure TChildForm.PositionsChanged(Since: integer = 0);
begin
 RedrawPositions(Since);
 SBPositionsUpdateMax;
 CalcTotLen;
end;

procedure TChildForm.SBPositionsUpdateMax;
begin
 if VTMP^.Positions.Length < 256 then
   SBPositions.Max := VTMP^.Positions.Length //Length + 1 empty cell
 else
   SBPositions.Max := 255; //no empty cells
end;

procedure TChildForm.InsertPositions(Mode: integer);
var
 i, j, num, start, dest, pat, len: integer;
 Used: TPatFlags;
begin
 if (SGPositions.Selection.Right < VTMP^.Positions.Length) and
   (VTMP^.Positions.Length < 256) then
  begin
   SongChanged := True;
   AddUndo(CAInsertPosition,{%H-}PtrInt(@VTMP^.Positions), 0, auAutoIdxs);

   Used := GetUsedPatterns(VTMP^.Positions);

   start := SGPositions.Selection.Left;
   dest := SGPositions.Selection.Right;

   //fill with values of last pattern of selection
   pat := VTMP^.Positions.Value[dest];
   len := GetPatternLength(VTMP^.Patterns[pat]);

   Inc(dest);

   with ChangeList[ChangeCount - 1] do
     NewParams.prm.Idx.CurrentPosition := dest;

   num := dest - start;
   if VTMP^.Positions.Length + num > 256 then //max length of poslist
     num := 256 - VTMP^.Positions.Length;

   Inc(VTMP^.Positions.Length, num);
   if dest <= VTMP^.Positions.Loop then
     Inc(VTMP^.Positions.Loop, num);

   for i := VTMP^.Positions.Length - 1 downto dest + num do //move last positions
     VTMP^.Positions.Value[i] := VTMP^.Positions.Value[i - num];

   for i := dest to dest + num - 1 do
    begin
     case Mode of
       0: GetFreeEmptyPattern2(Used, pat, len);
       1: pat := VTMP^.Positions.Value[start];
       2: begin
         pat := GetFreeEmptyPattern(Used, VTMP);
         if pat >= 0 then
          begin
           ValidatePattern2(pat);
           len := VTMP^.Positions.Value[start]; //source pattern
           ValidatePattern2(len);
           for j := 0 to MaxPatLen - 1 do
             VTMP^.Patterns[pat]^.Items[j] := VTMP^.Patterns[len]^.Items[j];
           VTMP^.Patterns[pat]^.Length := VTMP^.Patterns[len]^.Length;
          end
         else
           //no free pattern to clone, so just duplicate
           pat := VTMP^.Positions.Value[start];
        end;
      end;
     VTMP^.Positions.Value[i] := pat;
     Inc(start);
    end;

   PositionsChanged(dest); //draw positions from first added
   ShowPosition(dest); //move selection to 1st added position
   SelectPosition(dest); //call onclick handler
  end;
 InputPNumber := 0;
end;

procedure TChildForm.DeletePositions;
var
 i, First, start, last, num: integer;
begin
 if SGPositions.Selection.Right < VTMP^.Positions.Length then
  begin
   SongChanged := True;
   AddUndo(CADeletePosition,{%H-}PtrInt(@VTMP^.Positions), 0, auAutoIdxs);

   start := SGPositions.Selection.Left;
   First := start; //first changed cell
   last := SGPositions.Selection.Right;

   num := last - start + 1;

   Dec(VTMP^.Positions.Length, num);
   if VTMP^.Positions.Length > 0 then
    begin
     if last < VTMP^.Positions.Loop then
       Dec(VTMP^.Positions.Loop, num)
     else if start <= VTMP^.Positions.Loop then
       VTMP^.Positions.Loop := start;
     if VTMP^.Positions.Loop >= VTMP^.Positions.Length then
      begin
       VTMP^.Positions.Loop := VTMP^.Positions.Length - 1;
       First := VTMP^.Positions.Loop;
      end;
    end
   else
     VTMP^.Positions.Loop := 0; //will be zero when adding positions further

   for i := start to VTMP^.Positions.Length - 1 do
     VTMP^.Positions.Value[i] := VTMP^.Positions.Value[i + num];

   PositionsChanged(First); //draw positions from 1st changed
   ShowPosition(start); //move selection to 1st deleted position
   SelectPosition(start); //call onclick handler
  end;
 InputPNumber := 0;
end;

procedure TChildForm.ChangePositionValue(pos, Value: integer);
var
 s: string;
begin
 SongChanged := True;
 PositionNumber := pos;
 AddUndo(CAChangePositionValue, VTMP^.Positions.Value[pos], Value, pos);
 if pos = VTMP^.Positions.Length then
  begin
   Inc(VTMP^.Positions.Length);
   SBPositionsUpdateMax;
  end;
 if not UndoWorking then
   ChangeList[ChangeCount - 1].NewParams.prm.Two.PositionListLen :=
     VTMP^.Positions.Length;
 VTMP^.Positions.Value[pos] := Value;
 s := IntToStr(Value);
 if pos = VTMP^.Positions.Loop then s := 'L' + s;
 SGPositions.Cells[pos, 0] := s;
 ToglSams.CheckUsedSamples;
 CalcTotLen;
 ValidatePattern2(Value);
 if SGPositions.Col <> pos then ShowPosition(pos);
 ChangePattern(Value);
end;

procedure TChildForm.ChangePatternsOrder(Idx: PPatIndex; Reverse: boolean = False);
var
 PatsP: array[0..MaxPatNum] of PPattern;
 i: integer;
begin
 //quick copy pattern pointers array (need only 0..MaxPatNum items)
 Move(VTMP^.Patterns[0], PatsP, SizeOf(PatsP));

 //reorder pattern pointers
 if Reverse then
   for i := 0 to MaxPatNum do
     VTMP^.Patterns[i] := PatsP[Idx^[i]]
 else
   for i := 0 to MaxPatNum do
     VTMP^.Patterns[Idx^[i]] := PatsP[i];
end;

procedure TChildForm.GetFreeEmptyPattern2(var Used: TPatFlags;
 var DefPat: integer; DefLen: integer);
var
 i: integer;
begin
 i := GetFreeEmptyPattern(Used, VTMP);
 if i >= 0 then
  begin
   if VTMP^.Patterns[i] = nil then
     ValidatePattern2(i)
   else
     //we want to change length, so be sure that all extra lines are empty
     EmptyPattern(VTMP^.Patterns[i]);
   DefPat := i;
   VTMP^.Patterns[i]^.Length := DefLen;
  end;
end;

procedure TChildForm.FillPositions;
var
 pat, len: integer;
 Used: TPatFlags;
 i, plen: integer;
begin
 plen := VTMP^.Positions.Length;

 if plen > SGPositions.Col then
   //selected not empty cell
   Exit;

 Used := GetUsedPatterns(VTMP^.Positions);

 if plen > 0 then
   pat := VTMP^.Positions.Value[plen - 1]
 else
   pat := 0;

 len := GetPatternLength(VTMP^.Patterns[pat]);

 if SGPositions.Col = plen then
   //one pattern adding
  begin
   GetFreeEmptyPattern2(Used, pat, len);
   ChangePositionValue(plen, pat);
  end
 else
  begin
   SongChanged := True;
   AddUndo(CAInsertPosition,{%H-}PtrInt(@VTMP^.Positions), 0, auAutoIdxs);

   for i := plen to SGPositions.Col do
    begin
     GetFreeEmptyPattern2(Used, pat, len);
     VTMP^.Positions.Value[i] := pat;
    end;

   VTMP^.Positions.Length := SGPositions.Col + 1;

   PositionsChanged(plen); //draw new positions
   SelectPosition(SGPositions.Col);
   //reselect last position to update time stats and show its pattern
  end;
 InputPNumber := 0;
end;

procedure TChildForm.SGPositionsKeyPress(Sender: TObject; var Key: char);
begin
 case Key of
   '0'..'9':
     if not (IsPlaying and (PlayMode = PMPlayModule) and
       ((PlaybackWindow[0] = Self) or
       ((Length(PlaybackBufferMaker.Players) > 1) and (PlaybackWindow[1] = Self))))
       and (SGPositions.Col <= VTMP^.Positions.Length) then
      begin
       InputPNumber := InputPNumber * 10 + Ord(Key) - Ord('0');
       if InputPNumber > MaxPatNum then
         InputPNumber := Ord(Key) - Ord('0');
       ChangePositionValue(SGPositions.Col, InputPNumber);
       Exit;
      end;
  end;
 InputPNumber := 0;
end;

procedure TChildForm.PosRemoveSelection;
var
 aSel: TGridRect;
begin
 //seems only one way to remove selection in tstringgrid:
 aSel.Left := -1;
 aSel.Right := -1;
 aSel.Top := -1;
 aSel.Bottom := -1;
 SGPositions.Selection := aSel;
end;

procedure TChildForm.SGPositionsMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
var
 x1, y1: integer;
begin
 SGPositions.Tag := 1; //button pushed flag
 if (Button = mbRight) then
  begin
   if ((IsPlayingWindow < 0) or (PlayMode <> PMPlayModule)) then
    begin
     SGPositions.MouseToCell(X, Y, x1, y1);
     if (SGPositions.Selection.Left = SGPositions.Selection.Right) or
       (x1 < SGPositions.Selection.Left) or (x1 > SGPositions.Selection.Right) then
       //no selection or clicked outside of selection
      begin
       PosRemoveSelection;
       SGPositions.Col := x1;
       SelectPosition(x1);
      end;
    end;
   if SGPositions.CanSetFocus then
     SGPositions.SetFocus;
  end;
end;

procedure TChildForm.SetTitle(const ttl: string);
var
 s: string;
begin
 s := UTF8ToWinCP(PChar(ttl));
 if VTMP^.Title <> s then
  begin
   SongChanged := True;
   AddUndo(CAChangeTitle,{%H-}PtrInt(PChar(VTMP^.Title)),{%H-}PtrInt(PChar(s)));
   VTMP^.Title := s;
   EdTitle.Text := ttl;
  end;
end;

procedure TChildForm.EdTitleChange(Sender: TObject);
begin
 if EdTitle.Modified then
   SetTitle(EdTitle.Text);
end;

procedure TChildForm.SetAuthor(const aut: string);
var
 s: string;
begin
 s := UTF8ToWinCP(PChar(aut));
 if VTMP^.Author <> s then
  begin
   SongChanged := True;
   AddUndo(CAChangeAuthor,{%H-}PtrInt(PChar(VTMP^.Author)),{%H-}PtrInt(PChar(s)));
   VTMP^.Author := s;
   EdAuthor.Text := aut;
  end;
end;

procedure TChildForm.EdAuthorChange(Sender: TObject);
begin
 if EdAuthor.Modified then
   SetAuthor(EdAuthor.Text);
end;

procedure TChildForm.ChangePattern(aPat: integer; FromLine: integer = 0);
var
 l: integer;
begin
 PatNum := aPat;
 UDPat.Position := aPat;
 Tracks.ShownPattern := VTMP^.Patterns[PatNum];
 if VTMP^.Patterns[PatNum] = nil then
   l := DefPatLen
 else
   l := VTMP^.Patterns[PatNum]^.Length;
 UDPatLen.Position := l;
 UDAutoHL.Max := l;
 if SBAutoHL.Down then
   CalcHLStep;
 Tracks.ShownFrom := FromLine;
 Tracks.CursorY := Tracks.N1OfLines;
 Tracks.ResetSelection;
 Tracks.Invalidate;
 Tracks.CalcCaretPos;
 if Active then
   SetToolsPattern;
end;

procedure TChildForm.UDPatChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := NewValue in [0..MaxPatNum]; //pattern number to change
 if AllowChange then
   //set new pattern and redraw tracks
   ChangePattern(NewValue);
end;

procedure TChildForm.Edit2ExitOrDone(Sender: TObject);
begin
 //copy pattern number from associated UpDown
 EdPat.Text := IntToStr(UDPat.Position);
end;

procedure TChildForm.EdPatChange(Sender: TObject);
begin
 //set pattern number on user input and if new value only
 if EdPat.Modified and (PatNum <> UDPat.Position) then
  begin
   ChangePattern(UDPat.Position);
   EdPat.Text := IntToStr(UDPat.Position);
  end;
end;

procedure TChildForm.Edit6ExitOrDone(Sender: TObject);
begin
 EdSpeed.Text := IntToStr(UDSpeed.Position);
end;

procedure TChildForm.EdSpeedChange(Sender: TObject);
begin
 if EdSpeed.Modified and (VTMP^.Initial_Delay <> UDSpeed.Position) then
  begin
   SetInitDelay(UDSpeed.Position);
   EdSpeed.Text := IntToStr(UDSpeed.Position);
  end;
end;

procedure TChildForm.UDSpeedChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := NewValue in [1..255];
 if AllowChange then
   SetInitDelay(NewValue);
end;

procedure TChildForm.UpdateEnvelopes(PrevNTNum: integer);
var
 aPat, aLn, aNt, c: integer;
 aEnvP: word;
begin
 //if not AcceptCannotUndo('Envelopes recalculation') then
 //Exit;
 for aPat := -1 to MaxPatNum do //including test lines
   with VTMP^ do
     if Patterns[aPat] <> nil then
       for aLn := 0 to Patterns[aPat]^.Length - 1 do
         with Patterns[aPat]^.Items[aLn] do
          begin
           aNt := EnvP2Note(Patterns[aPat], aLn, PrevNTNum);
           if aNt >= 0 then
            begin
             if Note2EnvP(Patterns[aPat], aLn, aNt, Ton_Table, c, aEnvP) and
               (Envelope <> aEnvP) then
              begin
               if aPat < 0 then //test lines
                begin
                 Envelope := aEnvP;
                 case aLn of
                   tlPatterns:
                     PatternTestLine.Invalidate;
                   tlSamples:
                     SampleTestLine.Invalidate;
                   tlOrnaments:
                     OrnamentTestLine.Invalidate;
                  end;
                end
               else
                 ChangeTracks(aPat, aLn, -1, 0, aEnvP, False);
              end;
            end;
          end;
 if SongChanged then
   Tracks.Invalidate;
end;

procedure TChildForm.SetTable(nt: integer);
var
 prev, ChangesStart: integer;
begin
 prev := VTMP^.Ton_Table;
 if (prev <> nt) and SetToneTable(nt, VTMP) then
  begin
   SongChanged := True;
   ChangesStart := ChangeCount; //store next undo index
   AddUndo(CAChangeToneTable, prev, VTMP^.Ton_Table);
   FillToneTableControls;
   UpdateToneTableHints;
   if VTOptions.RecalcEnv and not UndoWorking then
     UpdateEnvelopes(prev);
   GroupLastChanges(ChangesStart);
  end;
end;

procedure TChildForm.FillToneTableControls;
var
 c, r, i: integer;
 s: string;
begin
 UDTable.Position := VTMP^.Ton_Table;
 MTable.Visible := SBTableAsList.Down;
 SGTable.Visible := not SBTableAsList.Down;
 if MTable.Visible then
  begin
   MTable.Clear;
   s := '';
   for i := 0 to 95 do
    begin
     if SBTableAsDec.Down then
       s += IntToStr(GetNoteFreq(VTMP^.Ton_Table, i)) + ','
     else
       s += IntToHex(GetNoteFreq(VTMP^.Ton_Table, i), 0) + ',';
    end;
   SetLength(s, Length(s) - 1);
   MTable.Append(s);
  end
 else
  begin
   c := 1;
   r := 1;
   i := 0;
   for r := 1 to 8 do
     for c := 1 to 12 do
      begin
       if SBTableAsDec.Down then
         SGTable.Cells[c, r] := IntToStr(GetNoteFreq(VTMP^.Ton_Table, i))
       else
         SGTable.Cells[c, r] := IntToHex(GetNoteFreq(VTMP^.Ton_Table, i), 0);
       Inc(i);
      end;
  end;
end;

procedure TChildForm.UpdateToneTableHints;
var
 s: string;
begin
 s := Mes_ToneTblFor + ' ';
 case VTMP^.Ton_Table of
   0: s := s + Mes_ToneTbl0;
   1: s := s + Mes_ToneTbl1;
   2: s := s + Mes_ToneTbl2;
   3: s := s + Mes_ToneTbl3;
  end;
 UDTable.Hint := s;
 EdTable.Hint := s;
end;

procedure TChildForm.UDTableChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := NewValue in [0..3];
 if AllowChange then
   SetTable(NewValue);
end;

procedure TChildForm.Edit7ExitOrDone(Sender: TObject);
begin
 EdTable.Text := IntToStr(UDTable.Position);
end;

procedure TChildForm.EdTableChange(Sender: TObject);
begin
 if EdTable.Modified and (VTMP^.Ton_Table <> UDTable.Position) then
  begin
   SetTable(UDTable.Position);
   EdTable.Text := IntToStr(UDTable.Position);
  end;
end;

procedure TChildForm.Edit8ExitOrDone(Sender: TObject);
begin
 EdPatLen.Text := IntToStr(UDPatLen.Position);
 ChangePatternLength(UDPatLen.Position);
end;

procedure TChildForm.UDPatLenChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := (NewValue > 0) and (NewValue <= MaxPatLen);
 if AllowChange then
   ChangePatternLength(NewValue);
end;

procedure TChildForm.CheckTracksAfterSizeChanged(NL: integer);
begin
 UDAutoHL.Max := NL;
 if SBAutoHL.Down then
   CalcHLStep;
 if Tracks.ShownFrom >= NL then Tracks.ShownFrom := NL - 1;
 if Tracks.CursorY > NL - Tracks.ShownFrom - 1 + Tracks.N1OfLines then
  begin
   Tracks.CursorY := NL - Tracks.ShownFrom - 1 + Tracks.N1OfLines;
   Tracks.CalcCaretPos;
  end;
 if not UndoWorking then
   ChangeList[ChangeCount - 1].NewParams.prm.Idx.PatternLine :=
     Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
 Tracks.ResetSelection;
 Tracks.Invalidate;
 ToglSams.CheckUsedSamples;
 CalcTotLen;
 CalculatePos0;
 ShowStat;
end;

procedure TChildForm.ChangePatternLength(NL: integer);
begin
 ValidatePattern2(PatNum);
 if NL <> VTMP^.Patterns[PatNum]^.Length then
  begin
   SongChanged := True;
   AddUndo(CAChangePatternSize, VTMP^.Patterns[PatNum]^.Length, NL, auAutoIdxs);
   VTMP^.Patterns[PatNum]^.Length := NL;
   CheckTracksAfterSizeChanged(NL);
  end;
end;

procedure TChildForm.EdOctaveExitOrDone(Sender: TObject);
begin
 EdOctave.Text := IntToStr(UDOctave.Position);
end;

procedure TChildForm.ToggleMute(C: integer);
begin
 with VTMP^.Mutes[C] do
   if Ton and Noise and Envelope then
    begin
     Ton := False;
     Noise := False;
     Envelope := False;
     ChannelControls[C].MuteT.Down := True;
     ChannelControls[C].MuteN.Down := True;
     ChannelControls[C].MuteE.Down := True;
    end
   else
    begin
     Ton := True;
     Noise := True;
     Envelope := True;
     ChannelControls[C].MuteT.Down := False;
     ChannelControls[C].MuteN.Down := False;
     ChannelControls[C].MuteE.Down := False;
    end;
 if IsPlayingWindow >= 0 then
   MainForm.StopAndRestart;
end;

procedure TChildForm.ApplyMuteT(C: integer);
begin
 VTMP^.Mutes[C].Ton := not ChannelControls[C].MuteT.Down;
 if IsPlayingWindow >= 0 then
   MainForm.StopAndRestart;
end;

procedure TChildForm.ApplyMuteN(C: integer);
begin
 VTMP^.Mutes[C].Noise := not ChannelControls[C].MuteN.Down;
 if IsPlayingWindow >= 0 then
   MainForm.StopAndRestart;
end;

procedure TChildForm.ApplyMuteE(C: integer);
begin
 VTMP^.Mutes[C].Envelope := not ChannelControls[C].MuteE.Down;
 if IsPlayingWindow >= 0 then
   MainForm.StopAndRestart;
end;

procedure TChildForm.ApplyMutes;
var
 i: integer;
begin
 for i := 0 to 2 do
   with VTMP^.Mutes[i], ChannelControls[i] do
    begin
     Ton := not MuteT.Down;
     Noise := not MuteN.Down;
     Envelope := not MuteE.Down;
    end;
 if (TSWindow <> nil) and (TSWindow <> Self) then
   with TSWindow do
     for i := 0 to 2 do
       with VTMP^.Mutes[i], ChannelControls[i] do
        begin
         Ton := not MuteT.Down;
         Noise := not MuteN.Down;
         Envelope := not MuteE.Down;
        end;
 if IsPlayingWindow >= 0 then
   MainForm.StopAndRestart;
end;

procedure TChildForm.ApplySolo(C: integer);
var
 i: integer;
 MuteNotSolo, OtherSolo: boolean;
begin
 OtherSolo := False;
 for i := 0 to 2 do
   if i <> C then
     if ChannelControls[i].Solo.Down then
      begin
       OtherSolo := True;
       break;
      end;
 if (not OtherSolo) and (TSWindow <> nil) and (TSWindow <> Self) then
   for i := 0 to 2 do
     if TSWindow.ChannelControls[i].Solo.Down then
      begin
       OtherSolo := True;
       break;
      end;

 with ChannelControls[C] do
  begin
   MuteNotSolo := Solo.Down or OtherSolo;
   for i := 0 to 2 do
     with ChannelControls[i] do
       if i <> C then
         if not Solo.Down then
          begin
           MuteT.Down := MuteNotSolo;
           MuteN.Down := MuteNotSolo;
           MuteE.Down := MuteNotSolo;
          end;
   if (TSWindow <> nil) and (TSWindow <> Self) then
     for i := 0 to 2 do
       with TSWindow.ChannelControls[i] do
         if not Solo.Down then
          begin
           MuteT.Down := MuteNotSolo;
           MuteN.Down := MuteNotSolo;
           MuteE.Down := MuteNotSolo;
          end;
   MuteNotSolo := not Solo.Down and OtherSolo;
   MuteT.Down := MuteNotSolo;
   MuteN.Down := MuteNotSolo;
   MuteE.Down := MuteNotSolo;
  end;
 ApplyMutes;
end;

procedure TChildForm.SBMuteClick(Sender: TObject);
begin
 ToggleMute((Sender as TSpeedButton).Tag);
end;

procedure TChildForm.SBMuteTClick(Sender: TObject);
begin
 ApplyMuteT((Sender as TSpeedButton).Tag);
end;

procedure TChildForm.SBMuteNClick(Sender: TObject);
begin
 ApplyMuteN((Sender as TSpeedButton).Tag);
end;

procedure TChildForm.SBSoloClick(Sender: TObject);
begin
 ApplySolo((Sender as TSpeedButton).Tag);
end;

procedure TChildForm.SBMuteEClick(Sender: TObject);
begin
 ApplyMuteE((Sender as TSpeedButton).Tag);
end;

procedure TChildForm.GBFeaturesClick(Sender: TObject);
begin
 if VTMP^.FeaturesLevel <> GBFeatures.ItemIndex then
  begin
   SongChanged := True;
   AddUndo(CAChangeFeatures, VTMP^.FeaturesLevel, GBFeatures.ItemIndex);
   VTMP^.FeaturesLevel := GBFeatures.ItemIndex;
  end;
end;

procedure TChildForm.GBHeaderClick(Sender: TObject);
begin
 if VTMP^.VortexModule_Header = boolean(GBHeader.ItemIndex) then
  begin
   SongChanged := True;
   AddUndo(CAChangeHeader, integer(not VTMP^.VortexModule_Header), GBHeader.ItemIndex);
   VTMP^.VortexModule_Header := not boolean(GBHeader.ItemIndex);
  end;
end;

procedure TChildForm.EdSampleChange(Sender: TObject);
begin
 if EdSample.Modified and (SamNum <> UDSample.Position) then
  begin
   ChangeSample(UDSample.Position);
   EdSample.Text := IntToStr(UDSample.Position);
  end;
end;

procedure TChildForm.EdSampleExitOrDone(Sender: TObject);
begin
 EdSample.Text := IntToStr(UDSample.Position);
end;

procedure TChildForm.UDSampleChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := NewValue in [1..31];
 if AllowChange then
   if SamNum <> NewValue then
     ChangeSample(NewValue);
end;

procedure TChildForm.Edit9ExitOrDone(Sender: TObject);
begin
 ChangeSampleLength(UDSamLen.Position);
 EdSamLen.Text := IntToStr(UDSamLen.Position);
end;

procedure TChildForm.UDSamLenChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := NewValue in [1..MaxSamLen];
 if AllowChange then
   ChangeSampleLength(NewValue);
end;

procedure TChildForm.ChangeSample(n: integer);
var
 l: integer;
begin
 SamNum := n;
 UDSample.Position := n;
 with SampleTestLine do
  begin
   VTMP^.Patterns[-1]^.Items[tlSamples].Channel[0].Sample := n;
   Invalidate;
  end;
 Samples.ShownSample := VTMP^.Samples[SamNum];
 if VTMP^.Samples[SamNum] = nil then
   l := 1
 else
   l := VTMP^.Samples[SamNum]^.Length;
 UDSamLen.Position := l;
 UDSamLoop.Max := l - 1;
 if VTMP^.Samples[SamNum] = nil then
   l := 0
 else
   l := VTMP^.Samples[SamNum]^.Loop;
 UDSamLoop.Position := l;
 if not UndoWorking then
  begin
   Samples.ShownFrom := 0;
   Samples.CursorX := 0;
   Samples.CursorY := 0;
  end;
 Samples.RecreateCaret; //undo can change CursorX
 Samples.CalcCaretPos;
 Samples.ResetSelection;
 Samples.Invalidate;
end;

procedure TChildForm.ChangeSampleLength(NL: integer);
begin
 if (VTMP^.Samples[SamNum] = nil) and (NL = 1) then exit;
 ValidateSample2(SamNum);
 if NL <> VTMP^.Samples[SamNum]^.Length then
  begin
   SongChanged := True;
   AddUndo(CAChangeSampleSize, VTMP^.Samples[SamNum]^.Length, NL, auAutoIdxs);
   VTMP^.Samples[SamNum]^.Length := NL;
   if not UndoWorking then
     ChangeList[ChangeCount - 1].OldParams.prm.Two.PrevLoop :=
       VTMP^.Samples[SamNum]^.Loop;
   if VTMP^.Samples[SamNum]^.Loop >= VTMP^.Samples[SamNum]^.Length then
     VTMP^.Samples[SamNum]^.Loop := VTMP^.Samples[SamNum]^.Length - 1;
   if not UndoWorking then
     ChangeList[ChangeCount - 1].NewParams.prm.Two.PrevLoop :=
       VTMP^.Samples[SamNum]^.Loop;
   UDSamLoop.Max := NL - 1;
   UDSamLoop.Position := VTMP^.Samples[SamNum]^.Loop;
   with Samples do
    begin
     if ShownFrom + CursorY >= NL then
      begin
       CursorY := NL - ShownFrom - 1;
       if CursorY < 0 then
        begin
         Inc(ShownFrom, CursorY);
         CursorY := 0;
        end;
       CalcCaretPos;
      end;
     if not UndoWorking then
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.SampleLine :=
         Samples.ShownFrom + Samples.CursorY;
     ResetSelection;
     Invalidate;
    end;
  end;
end;

procedure TChildForm.ChangeSampleLoop(NL: integer);
begin
 if (VTMP^.Samples[SamNum] = nil) then
   Exit;
 if (NL <> VTMP^.Samples[SamNum]^.Loop) and (NL < VTMP^.Samples[SamNum]^.Length) then
  begin
   SongChanged := True;
   AddUndo(CAChangeSampleLoop, VTMP^.Samples[SamNum]^.Loop, NL, auAutoIdxs);
   VTMP^.Samples[SamNum]^.Loop := NL;
   UDSamLoop.Position := NL;
   Samples.Invalidate;
  end;
end;

procedure TChildForm.ChangeOrnament(n: integer);
var
 l: integer;
begin
 //no check for OrnNum <> n because of ornament can be changed itself
 //(f.e. by loading from file or changing loop/size)
 OrnNum := n;
 UDOrn.Position := n;
 with OrnamentTestLine do
  begin
   VTMP^.Patterns[-1]^.Items[tlOrnaments].Channel[0].Ornament := n;
   Invalidate;
  end;
 Ornaments.ShownOrnament := VTMP^.Ornaments[OrnNum];
 if VTMP^.Ornaments[OrnNum] = nil then
   l := 1
 else
   l := VTMP^.Ornaments[OrnNum]^.Length;
 UDOrnLen.Position := l;
 UDOrnLoop.Max := l - 1;
 if VTMP^.Ornaments[OrnNum] = nil then
   l := 0
 else
   l := VTMP^.Ornaments[OrnNum]^.Loop;
 UDOrnLoop.Position := l;
 if not UndoWorking then
  begin
   Ornaments.CursorX := 3;
   Ornaments.CursorY := 0;
   Ornaments.ShownFrom := 0;
  end;
 Ornaments.CalcCaretPos;
 Ornaments.ResetSelection;
 Ornaments.Invalidate;
end;

procedure TChildForm.ChangeOrnamentLength(NL: integer);
var
 c: integer;
begin
 if (VTMP^.Ornaments[OrnNum] = nil) and (NL = 1) then
   Exit;
 ValidateOrnament(OrnNum);
 if NL <> VTMP^.Ornaments[OrnNum]^.Length then
  begin
   SongChanged := True;
   AddUndo(CAChangeOrnamentSize, VTMP^.Ornaments[OrnNum]^.Length, NL, auAutoIdxs);
   VTMP^.Ornaments[OrnNum]^.Length := NL;
   if not UndoWorking then
     ChangeList[ChangeCount - 1].OldParams.prm.Two.PrevLoop :=
       VTMP^.Ornaments[OrnNum]^.Loop;
   if VTMP^.Ornaments[OrnNum]^.Loop >= VTMP^.Ornaments[OrnNum]^.Length then
     VTMP^.Ornaments[OrnNum]^.Loop := VTMP^.Ornaments[OrnNum]^.Length - 1;
   if not UndoWorking then
     ChangeList[ChangeCount - 1].NewParams.prm.Two.PrevLoop :=
       VTMP^.Ornaments[OrnNum]^.Loop;
   UDOrnLoop.Max := NL - 1;
   UDOrnLoop.Position := VTMP^.Ornaments[OrnNum]^.Loop;
   with Ornaments do
    begin
     if ShownFrom + CursorX div 7 * OrnNRow + CursorY >= NL then
      begin
       c := NL - ShownFrom - 1;
       if c < 0 then
        begin
         Inc(ShownFrom, c);
         CursorX := 3;
         CursorY := 0;
        end
       else
        begin
         CursorX := c div OrnNRow * 7 + 3;
         CursorY := c mod OrnNRow;
        end;
       CalcCaretPos;
      end;
     if not UndoWorking then
       ChangeList[ChangeCount - 1].NewParams.prm.Idx.OrnamentLine :=
         ShownFrom + CursorY + (CursorX div 7) * OrnNRow;
     ResetSelection;
     Invalidate;
    end;
  end;
end;

procedure TChildForm.ChangeOrnamentLoop(NL: integer);
begin
 if (VTMP^.Ornaments[OrnNum] = nil) then exit;
 if (NL <> VTMP^.Ornaments[OrnNum]^.Loop) and (NL < VTMP^.Ornaments[OrnNum]^.Length) then
  begin
   SongChanged := True;
   AddUndo(CAChangeOrnamentLoop, VTMP^.Ornaments[OrnNum]^.Loop, NL, auAutoIdxs);
   VTMP^.Ornaments[OrnNum]^.Loop := NL;
   Ornaments.Invalidate;
  end;
end;

procedure TChildForm.ValidateSample2(sam: integer);
begin
 ValidateSample(sam, VTMP);
 if sam = SamNum then
   Samples.ShownSample := VTMP^.Samples[SamNum];
end;

procedure TChildForm.ValidateOrnament(orn: integer);
var
 i: integer;
begin
 if VTMP^.Ornaments[orn] = nil then
  begin
   New(VTMP^.Ornaments[orn]);
   VTMP^.Ornaments[orn]^.Loop := 0;
   VTMP^.Ornaments[orn]^.Length := 1;
   for i := 0 to MaxOrnLen - 1 do
     VTMP^.Ornaments[orn]^.Items[i] := 0;
   if orn = OrnNum then
     Ornaments.ShownOrnament := VTMP^.Ornaments[OrnNum];
  end;
end;

procedure TChildForm.Edit10ExitOrDone(Sender: TObject);
begin
 ChangeSampleLoop(UDSamLoop.Position);
 EdSamLoop.Text := IntToStr(UDSamLoop.Position);
end;

procedure TChildForm.UDSamLoopChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
var
 l: integer;
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 if VTMP^.Samples[SamNum] = nil then
   l := 1
 else
   l := VTMP^.Samples[SamNum]^.Length;
 AllowChange := (NewValue >= 0) and (NewValue < l);
 if AllowChange then
   ChangeSampleLoop(NewValue);
end;

procedure TChildForm.PlayStarts;
begin
 EdPat.Enabled := False;
 UDPat.Enabled := False;
 Tracks.Enabled := False;
 Tracks.Hint := '';
 SBTS.Enabled := False;
end;

procedure TChildForm.CalculatePos0;
begin
 PosBegin := GetPositionTime(VTMP, PositionNumber, PosDelay);
 LineInts := 0;
 LbTime.Caption := IntsToTime(PosBegin);
 LbTicks.Caption := '(' + IntToStr(PosBegin);
 SinchronizeModules;
end;

procedure TChildForm.CalculatePos(Line: integer);
var
 i: integer;
begin
 if (PositionNumber >= VTMP^.Positions.Length) or
   (VTMP^.Positions.Value[PositionNumber] <> PatNum) then exit;
 LineInts := GetPositionTimeEx(VTMP, PositionNumber, PosDelay, Line);
 i := PosBegin + LineInts;
 LbTime.Caption := IntsToTime(i);
 LbTicks.Caption := '(' + IntToStr(i);
 SinchronizeModules;
end;

procedure TChildForm.ShowStat;
begin
 if (VTMP^.Positions.Length > 0) and (SGPositions.Col < VTMP^.Positions.Length) and
   (VTMP^.Positions.Value[PositionNumber] = PatNum) then
   CalculatePos(Tracks.ShownFrom + Tracks.CursorY - Tracks.N1OfLines);
end;

procedure TChildForm.ShowAllTots;
begin
 LbTotTime.Caption := IntsToTime(TotInts);
 LbTotTicks.Caption := IntToStr(TotInts) + ')';
end;

procedure TChildForm.CalcTotLen;
begin
 TotInts := GetModuleTime(VTMP);
 ShowAllTots;
end;

procedure TChildForm.ReCalcTimes;
begin
 LbTotTime.Caption := IntsToTime(TotInts);
 LbTime.Caption := IntsToTime(PosBegin + LineInts);
end;

procedure TChildForm.SetInitDelay(nd: integer);
begin
 if VTMP^.Initial_Delay <> nd then
  begin
   SongChanged := True;
   AddUndo(CAChangeSpeed, VTMP^.Initial_Delay, nd);
   VTMP^.Initial_Delay := nd;
   UDSpeed.Position := nd;
   CalcTotLen;
   CalculatePos0;
   if IsPlaying then
     RestartPlayingPos(PositionNumber);
  end;
end;

procedure TChildForm.UDOrnChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 AllowChange := NewValue in [1..15];
 if AllowChange then
   if OrnNum <> NewValue then
     ChangeOrnament(NewValue);
end;

procedure TChildForm.EdOrnChange(Sender: TObject);
begin
 if EdOrn.Modified and (OrnNum <> UDOrn.Position) then
  begin
   ChangeOrnament(UDOrn.Position);
   EdOrn.Text := IntToStr(UDOrn.Position);
  end;
end;

procedure TChildForm.EdOrnExitOrDone(Sender: TObject);
begin
 EdOrn.Text := IntToStr(UDOrn.Position);
end;

procedure TChildForm.UDOrnLoopChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
var
 l: integer;
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 //EditDone not raised in this case

 if VTMP^.Ornaments[OrnNum] = nil then
   l := 1
 else
   l := VTMP^.Ornaments[OrnNum]^.Length;
 AllowChange := (NewValue >= 0) and (NewValue < l);
 if AllowChange then
   ChangeOrnamentLoop(NewValue);
end;

procedure TChildForm.EdOrnLoopExitOrDone(Sender: TObject);
begin
 //EditingDone called if user press Enter key (
 //and not called if set programmically
 //but can be called in some misterious cases,
 //so be sure that real changing is made

 //Exit called if loose focus only,
 //EditDone not raised in this case

 ChangeOrnamentLoop(UDOrnLoop.Position);
 EdOrnLoop.Text := IntToStr(UDOrnLoop.Position);
end;

procedure TChildForm.UDOrnLenChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically

 AllowChange := NewValue in [1..MaxOrnLen];
 if AllowChange then ChangeOrnamentLength(NewValue);
end;

procedure TChildForm.EdOrnLenExitOrDone(Sender: TObject);
begin
 ChangeOrnamentLength(UDOrnLen.Position);
 EdOrnLen.Text := IntToStr(UDOrnLen.Position);
end;

procedure TChildForm.ToggleAutoEnv;
begin
 AutoEnv := not AutoEnv;
 SBAutoEnv.Down := AutoEnv;
end;

procedure TChildForm.ToggleStdAutoEnv;
begin
 if not AutoEnv then ToggleAutoEnv;
 if StdAutoEnvIndex = StdAutoEnvMax then
   StdAutoEnvIndex := 0
 else
   Inc(StdAutoEnvIndex);
 AutoEnv0 := StdAutoEnv[StdAutoEnvIndex, 0];
 AutoEnv1 := StdAutoEnv[StdAutoEnvIndex, 1];
 SBAutoEnvDigit1.Caption := IntToStr(AutoEnv0);
 SBAutoEnvDigit2.Caption := IntToStr(AutoEnv1);
end;

procedure TChildForm.SBAutoEnvClick(Sender: TObject);
begin
 ToggleAutoEnv;
end;

procedure TChildForm.SBAutoEnvDigit1Click(Sender: TObject);
begin
 if not AutoEnv then ToggleAutoEnv;
 StdAutoEnvIndex := -1;
 if AutoEnv0 = 9 then
   AutoEnv0 := 1
 else
   Inc(AutoEnv0);
 SBAutoEnvDigit1.Caption := IntToStr(AutoEnv0);
end;

procedure TChildForm.SBAutoEnvDigit2Click(Sender: TObject);
begin
 if not AutoEnv then ToggleAutoEnv;
 StdAutoEnvIndex := -1;
 if AutoEnv1 = 9 then
   AutoEnv1 := 1
 else
   Inc(AutoEnv1);
 SBAutoEnvDigit2.Caption := IntToStr(AutoEnv1);
end;

procedure TChildForm.DoAutoEnv(i, j, k: integer);
var
 n, old: integer;
begin
 if AutoEnv then
  begin
   n := VTMP^.Patterns[i]^.Items[j].Channel[k].Note;
   if n < 0 then exit;
   case VTMP^.Patterns[i]^.Items[j].Channel[k].Envelope of
     8, 12:
       n := trunc(GetNoteFreq(VTMP^.Ton_Table, n) * AutoEnv0 / AutoEnv1 / 16 + 0.5);
     10, 14:
       n := trunc(GetNoteFreq(VTMP^.Ton_Table, n) * AutoEnv0 / AutoEnv1 / 32 + 0.5);
   else
     exit;
    end;
   old := VTMP^.Patterns[i]^.Items[j].Envelope;
   if n = old then
     Exit;
   if i >= 0 then //real pattern (not test line)
    begin
     AddUndo(CAChangeEnvelopePeriod, old, n, i, j);
     SongChanged := True;
    end;
   VTMP^.Patterns[i]^.Items[j].Envelope := n;
  end;
end;

procedure TChildForm.DoAutoPrms(i, j, k: integer);
begin
 if SBAutoPars.Down then
  begin
   if VTMP^.Patterns[i]^.Items[j].Channel[k].Note < 0 then
     Exit;

   if SBAutoSmp.Down then
     ChangeTracks(i, j, k, k * 14 + 12,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Sample, False, False);
   if SBAutoEnvT.Down then
     ChangeTracks(i, j, k, k * 14 + 13,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Envelope, False, False);
   if SBAutoOrn.Down then
     ChangeTracks(i, j, k, k * 14 + 14,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Ornament, False, False);
   if SBAutoVol.Down then
     ChangeTracks(i, j, k, k * 14 + 15,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Volume, False, False);
   if SBAutoCmd.Down then
    begin
     ChangeTracks(i, j, k, k * 14 + 17,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Additional_Command.Number,
       False, False);
     ChangeTracks(i, j, k, k * 14 + 18,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Additional_Command.Delay,
       False, False);
     ChangeTracks(i, j, k, k * 14 + 20,
       VTMP^.Patterns[-1]^.Items[tlPatterns].Channel[0].Additional_Command.Parameter,
       False, False);
    end;
  end;
end;

procedure TChildForm.SGPositionsKeyDown(Sender: TObject; var Key: word;
 Shift: TShiftState);
var
 Act: TShortcutActions;
 aPos: integer;
 aSel: TGridRect;
begin
 if SGPositions.Tag = 2 then
   SGPositions.Tag := 1; //reset "moved with pushed button" to just "pushed button" flag

 if GetShortcutAction(SCS_PositionListEditor, Key, Shift, Act) then
   case Act of
     SCA_PosListJumpToEditor:
      begin
       if Tracks.CanSetFocus then
         Tracks.SetFocus;
       Key := 0;
      end;
     SCA_PosListEnd:
      begin
       aPos := VTMP^.Positions.Length;
       if (Shift = [ssShift]) and (SGPositions.Col < aPos) then
         //select from Col to end
        begin
         Dec(aPos); //last cell
         //last cell already selected?
         if SGPositions.Col <> aPos then
           //set new selection
          begin
           aSel := SGPositions.Selection;
           if SGPositions.Col = aSel.Left then
             //remove selection before Right
             aSel.Left := aSel.Right;
           aSel.Right := aPos;
           ShowPosition(aPos);
           //сбрасывает выделение, подумать
           SGPositions.Selection := aSel; //SGPositions.Col = aPos after that already
          end;
        end
       else
        begin
         if (IsPlayingWindow >= 0) and (PlayMode = PMPlayModule) then
           //to restart playing last position
           Dec(aPos)
         else if aPos > 255 then
           aPos := 255;
         PosRemoveSelection;
         //внутри ShowPosition тоже есть, подумать
         ShowPosition(aPos);
        end;
       SelectPosition(aPos);
       Key := 0;
      end;
     SCA_PosListSelectAll2:
      begin
       PosSelectAll;
       Key := 0;
      end;
    end;

 MainForm.CheckSGKeysAndActionsConflicts(Key, Shift, True);

 //prevent reselect same cell on one row grid and deny any cursor control except left/right/home
 MainForm.CheckKeysAndActionsConflicts(Key, Shift,
   [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT, VK_END]);
end;

procedure TChildForm.Edit14ExitOrDone(Sender: TObject);
begin
 EdAutoStep.Text := IntToStr(UDAutoStep.Position);
end;

procedure TChildForm.HeaderMouseDown(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 if Button = mbLeft then
  begin
   if Sender is TPanel then
     Moving := ctMove
   else if Cursor = crSizeN then
     Moving := ctSizeN
   else if Cursor = crSizeS then
     Moving := ctSizeS
   else
     Moving := ctNone;
   dX := X;
   dY := Y;
  end;
end;

procedure TChildForm.ChildFormPaint(Sender: TObject);
begin
 Canvas.Pen.Color := clWindowFrame;
 Canvas.Pen.Width := ChildFrameWidth;
 Canvas.Frame(0, 0, Width, Height);
 if Maximized then
   Exit;
 if Active then
   Canvas.Brush.Color := clActiveCaption
 else
   Canvas.Brush.Color := clInactiveCaption;
 Canvas.FillRect(ChildFrameWidth, ChildFrameWidth,
   Width - ChildFrameWidth, ChildFrameWidth + SizeBorderWidth);
 Canvas.FillRect(ChildFrameWidth, Height - ChildFrameWidth - SizeBorderWidth,
   Width - ChildFrameWidth, Height - ChildFrameWidth);
end;

procedure TChildForm.EdOctaveChange(Sender: TObject);
begin
 //set octave number on user input and if new value only
 if EdOctave.Modified and (PatternTestLine.TestOct <> UDOctave.Position) then
  begin
   PatternTestLine.TestOct := UDOctave.Position;
   EdOctave.Text := IntToStr(UDOctave.Position);
  end;
end;

procedure TChildForm.EdOrnOctaveChange(Sender: TObject);
begin
 //set octave number on user input and if new value only
 if EdOrnOctave.Modified and (OrnamentTestLine.TestOct <> UDOrnOctave.Position) then
  begin
   OrnamentTestLine.TestOct := UDOrnOctave.Position;
   EdOrnOctave.Text := IntToStr(UDOrnOctave.Position);
  end;
end;

procedure TChildForm.EdOrnOctaveExitOrDone(Sender: TObject);
begin
 EdOrnOctave.Text := IntToStr(UDOrnOctave.Position);
end;

procedure TChildForm.EdSamOctaveChange(Sender: TObject);
begin
 //set octave number on user input and if new value only
 if EdSamOctave.Modified and (SampleTestLine.TestOct <> UDSamOctave.Position) then
  begin
   SampleTestLine.TestOct := UDSamOctave.Position;
   EdSamOctave.Text := IntToStr(UDSamOctave.Position);
  end;
end;

procedure TChildForm.EdSamOctaveExitOrDone(Sender: TObject);
begin
 EdSamOctave.Text := IntToStr(UDSamOctave.Position);
end;

procedure TChildForm.FrameMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
var
 Delta: integer;
begin
 case Moving of
   ctSizeN, ctSizeS:
    begin
     Delta := Y - dY;
     if Delta = 0 then
       Exit;
     if Moving = ctSizeN then
      begin
       //don't leave visible workarea
       if Top + Delta < 0 then
         Delta := -Top
       else if Top + Delta + SizeBorderWidth + ChildFrameWidth >=
         Parent.ClientRect.Bottom then
         Delta := Parent.ClientRect.Bottom - Top - SizeBorderWidth - ChildFrameWidth;
       if SetHeight(Height - Delta) then
         Top := Top + Delta;
      end
     else
      begin
       //don't leave visible workarea
       if Top + Height + Delta - SizeBorderWidth - ChildFrameWidth < 0 then
         Delta := SizeBorderWidth + ChildFrameWidth - Top - Height
       else if Top + Height + Delta >= Parent.ClientRect.Bottom then
         Delta := Parent.ClientRect.Bottom - Top - Height;
       if SetHeight(Height + Delta) then
         dY := Y;
      end;
    end;
   ctNone:
    begin
     Cursor := crDefault;
     if not Maximized then
       if (Y >= Height - SizeBorderWidth - ChildFrameWidth) and (Y < Height) then
         Cursor := crSizeS
       else if (Y >= 0) and (Y < SizeBorderWidth + ChildFrameWidth) then
         Cursor := crSizeN;
    end;
  end;
end;

procedure TChildForm.HeaderDblClick(Sender: TObject);
begin
 Moving := ctNone;
 MainForm.MaximizeChild(Self);
end;

procedure TChildForm.InvalidateSizeFrame;
var
 FrameRect: TRect;
begin
 if Maximized then
   Exit;
 //force to repaint top and bottom frame as soon as possible
 FrameRect := Rect(ChildFrameWidth, ChildFrameWidth, Width -
   ChildFrameWidth, ChildFrameWidth + SizeBorderWidth);
 InvalidateRect(Handle, @FrameRect, False);
 FrameRect := Rect(ChildFrameWidth, Height - ChildFrameWidth -
   SizeBorderWidth, Width - ChildFrameWidth, Height - ChildFrameWidth);
 InvalidateRect(Handle, @FrameRect, False);
end;

procedure TChildForm.FrameEnter(Sender: TObject);
begin
 MainForm.ActiveChild := Self;
 TabOrder := 0; //mask LCL error (see PageControl1Change comment)

 if not Maximized then
   MainForm.RestoreChilds;

 Header.Color := clActiveCaption;
 Header.Font.Color := clCaptionText;
 InvalidateSizeFrame;

 FormActivate(Sender);
 Moving := ctNone; //reset flag (can be set in MouseHook)
end;

procedure TChildForm.FrameExit(Sender: TObject);
begin
 Moving := ctNone;
 Header.Color := clInactiveCaption;
 Header.Font.Color := clGrayText;
 InvalidateSizeFrame;
end;

procedure TChildForm.HeaderMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
var
 ParPt: TPoint; //cursor coords in parent container
begin
 if Moving = ctMove then
  begin
   ParPt := Header.ClientToParent(Point(X, Y), Parent);
   if (ParPt.X < Parent.ClientRect.Left) or (ParPt.X >= Parent.ClientRect.Right) or
     (ParPt.Y < Parent.ClientRect.Top) or (ParPt.Y >= Parent.ClientRect.Bottom) then
     //don't move if cursor outside of frame
     Exit;
   MoveWnd(X - dX, Y - dY);
  end;
end;

procedure TChildForm.HeaderMouseUp(Sender: TObject; Button: TMouseButton;
 Shift: TShiftState; X, Y: integer);
begin
 Moving := ctNone;
end;

procedure TChildForm.EditorPagesResize(Sender: TObject);
begin
 DoResize;
end;

procedure TChildForm.SBCloseClick(Sender: TObject);
begin
 Close;
end;

procedure TChildForm.EdAutoStepChange(Sender: TObject);
begin
 if EdAutoStep.Modified then
   if not SBAutoStep.Down then
     SBAutoStep.Click;
end;

procedure TChildForm.EdAutoHLChange(Sender: TObject);
var
 NewStep: integer;
begin
 if EdAutoHL.Modified then
  begin
   SBAutoHL.Down := False;
   NewStep := UDAutoHL.Position;
   if NewStep = 0 then
     if Tracks.ShownPattern = nil then
       NewStep := DefPatLen
     else
       NewStep := Tracks.ShownPattern^.Length;
   if Tracks.HLStep <> NewStep then
    begin
     ChangeHLStep(UDAutoHL.Position);
     EdAutoHL.Text := IntToStr(UDAutoHL.Position);
    end;
  end;
end;

procedure TChildForm.Edit17ExitOrDone(Sender: TObject);
begin
 EdAutoHL.Text := IntToStr(UDAutoHL.Position);
end;

function TChildForm.DoStep(i: integer; StepForward: boolean): boolean;
var
 t: integer;
begin
 Result := False;
 if not AutoStep then exit;
 t := UDAutoStep.Position;
 if t <> 0 then
  begin
   if StepForward then Inc(t, i)
   else
     t := i - t;
   if (t >= 0) and (t < Tracks.ShownPattern^.Length) then
    begin
     Result := True;
     Tracks.ShownFrom := t;
     if Tracks.CursorY <> Tracks.N1OfLines then
      begin
       Tracks.CursorY := Tracks.N1OfLines;
       Tracks.CalcCaretPos;
      end;
     Tracks.ResetSelection;
    end;
  end;
end;

procedure TChildForm.SBSaveOrnClick(Sender: TObject);
begin
 SaveTextDlg.Title := Mes_SaveOrn;
 SaveTextDlg.InitialDir := OrnamentsFolder;
 if SaveTextDlg.Execute then
  begin
   OrnamentsFolder := ExtractFilePath(SaveTextDlg.FileName);
   AssignFile(TxtFile, SaveTextDlg.FileName);
   Rewrite(TxtFile);
    try
     Writeln(TxtFile, '[Ornament]');
     SaveOrnament(VTMP, UDOrn.Position);
    finally
     CloseFile(TxtFile);
    end;
  end;
end;

procedure TChildForm.SBLoadOrnClick(Sender: TObject);
begin
 LoadTextDlg.Title := Mes_LoadOrn;
 LoadTextDlg.Filter := Mes_TextFiles + '|*.txt;*.vto|' + Mes_AllFiles + '|*.*';
 //*.vto to load Ivan Pirog's data files
 LoadTextDlg.InitialDir := OrnamentsFolder;
 if LoadTextDlg.Execute then
  begin
   OrnamentsFolder := ExtractFilePath(LoadTextDlg.FileName);
   LoadOrnament(LoadTextDlg.FileName);
  end;
end;

procedure TChildForm.LoadOrnament(FN: string);
var
 f: TextFile;
 s: string;
 Orn: POrnament;
begin
 AssignFile(f, FN);
 Reset(f);
  try
   repeat
     if EOF(f) then
      begin
       ShowMessage(Mes_OrnNotFound);
       Exit;
      end;
     Readln(f, s);
     s := UpperCase(Trim(s));
   until s = '[ORNAMENT]';
   Readln(f, s);
  finally
   CloseFile(f);
  end;
 New(Orn);
 if not RecognizeOrnamentString(s, Orn) then
  begin
   ShowMessage(Mes_BadFileStruct);
   Dispose(Orn);
  end
 else
  begin
   SongChanged := True;
   ValidateOrnament(OrnNum);
   AddUndo(CALoadOrnament,{%H-}PtrInt(VTMP^.Ornaments[OrnNum]),
     {%H-}PtrInt(Orn), auAutoIdxs);
   ChangeOrnament(OrnNum);
   with ChangeList[ChangeCount - 1].NewParams.prm.Idx, Ornaments do
     OrnamentLine := ShownFrom + CursorY + CursorX div 7 * OrnNRow;
  end;
end;

procedure TChildForm.SBOrGenClick(Sender: TObject);
const
 FN = 'VTIITempOrnament.txt';
var
 tmpp, dir: string;
begin
 tmpp := IncludeTrailingPathDelimiter(GetTempDir) + FN;
 if FileExists(tmpp) then
   if not DeleteFile(tmpp) then
    begin
     ShowMessage(Mes_OrGenError);
     Exit;
    end;
 dir := IncludeTrailingPathDelimiter(ExtractFilePath(GetProcessFileName));
 ExecuteProcess(dir + 'orgen.exe', ['"' + FN + '"'], []);
 if FileExists(tmpp) then
  begin
   LoadOrnament(tmpp);
   ChangeList[ChangeCount - 1].Action := CAOrGen;
   DeleteFile(tmpp);
  end;
end;

procedure TChildForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
 res: integer;
begin
 CanClose := not (SongChanged or ((TSWindow <> nil) and TSWindow.SongChanged));
 if CanClose then
   Exit;
 res := MessageDlg(Mes_Edition + ' ' + Caption + ' ' + Mes_IsChangedSave,
   mtConfirmation, [mbYes, mbNo, mbCancel], 0);
 CanClose := res in [mrYes, mrNo];
 if res = mrYes then SaveModule;
 if CanClose then
  begin
   SongChanged := False;
   //todo если несколько модулей закрывать, и в середине передумать, то этот флажок неверен, подумать!
   if (TSWindow <> nil) and TSWindow.SongChanged then
     if TSWindow.WinFileName = WinFileName then
       TSWindow.SongChanged := False;
  end;
end;

procedure TChildForm.PasteToPositionsList(Merge: boolean = False);
var
 ps, ns: PChar;
 sz, len, start, finish, i: integer;
 s: string;
 vals: array[0..255] of integer;
begin
 ps := PChar(Clipboard.AsText);
 ns := ps;
 sz := GetStrSz(ps);
 len := 0;
 repeat
   if sz = 0 then
     Break;
   ps := ns;
   SetLength(s, GetSubStrSz(#9, ns, sz));
   if Length(s) = 0 then
     Break;
   Move(ps^, s[1], Length(s));
   if s[1] = 'L' then
     s[1] := ' ';
   s := Trim(s);
   if (s = '') or not TryStrToInt(s, vals[len]) or not (vals[len] in [0..MaxPatNum]) then
     Break;
   Inc(len);
   if len >= 256 then
     Break;
 until False;

 if len = 0 then
   Exit;

 //check len, calc start/finish and new cells number (in len variable)
 if not Merge then
  begin
   if VTMP^.Positions.Length + len > 256 then
    begin
     ShowMessage(Mes_PosLstNoRoomToPaste);
     Exit;
    end;
   if SGPositions.Col >= VTMP^.Positions.Length then
     //paste to the end of list
     start := VTMP^.Positions.Length
   else
     //paste after selection
     start := SGPositions.Selection.Right + 1;
   finish := start + len - 1;
  end
 else if SGPositions.Col >= VTMP^.Positions.Length then
  begin
   //paste to the end of list no more then max length
   if VTMP^.Positions.Length + len > 256 then
     len := 256 - VTMP^.Positions.Length;
   start := VTMP^.Positions.Length;
   finish := start + len - 1;
  end
 else
  begin
   start := SGPositions.Selection.Left;
   finish := start + len - 1;
   i := SGPositions.Selection.Right;
   if start = i then
     //if no range selection, then paste from start to end
     i := VTMP^.Positions.Length - 1;
   if finish > i then
     //selection too tight
    begin
     if i < VTMP^.Positions.Length - 1 then
       //paste into selection
      begin
       len := 0;
       finish := i;
      end
     else
      begin
       //allow exceeding if selection at end
       len := start + len - VTMP^.Positions.Length;
       if VTMP^.Positions.Length + len > 256 then
         len := 256 - VTMP^.Positions.Length;
       finish := VTMP^.Positions.Length + len - 1;
      end;
    end
   else
     len := 0;
  end;

 SongChanged := True;
 AddUndo(CAInsertPosition,{%H-}PtrInt(@VTMP^.Positions), 0, auAutoIdxs);

 with ChangeList[ChangeCount - 1] do
   NewParams.prm.Idx.CurrentPosition := start;

 if not Merge and (VTMP^.Positions.Length <> 0) and (start <= VTMP^.Positions.Loop) then
   Inc(VTMP^.Positions.Loop, len);

 Inc(VTMP^.Positions.Length, len);

 if not Merge and (SGPositions.Col < VTMP^.Positions.Length) then
   //move apart to get gap
   for i := VTMP^.Positions.Length - 1 downto start + len do //move last positions
     VTMP^.Positions.Value[i] := VTMP^.Positions.Value[i - len];

 len := 0;
 for i := start to finish do
  begin
   VTMP^.Positions.Value[i] := vals[len];
   ValidatePattern2(vals[len]);
   Inc(len);
  end;

 PositionsChanged(start); //draw positions from first added
 ShowPosition(start); //move selection to 1st added position
 SelectPosition(start); //call onclick handler

 InputPNumber := 0;
end;

procedure TChildForm.ToggleAutoStep;
begin
 AutoStep := not AutoStep;
 SBAutoStep.Down := AutoStep;
end;

procedure TChildForm.SBSaveSamClick(Sender: TObject);
begin
 SaveTextDlg.Title := Mes_SaveSam;
 SaveTextDlg.InitialDir := SamplesFolder;
 if SaveTextDlg.Execute then
  begin
   SamplesFolder := ExtractFilePath(SaveTextDlg.FileName);
   AssignFile(TxtFile, SaveTextDlg.FileName);
   Rewrite(TxtFile);
    try
     Writeln(TxtFile, '[Sample]');
     SaveSample(VTMP, UDSample.Position);
    finally
     CloseFile(TxtFile);
    end;
  end;
end;

procedure TChildForm.SBLoadSamClick(Sender: TObject);
begin
 LoadTextDlg.Title := Mes_LoadSam;
 LoadTextDlg.Filter := Mes_TextFiles + '|*.txt;*.vts|' + Mes_AllFiles + '|*.*';
 //*.vts to load Ivan Pirog's data files
 LoadTextDlg.InitialDir := SamplesFolder;
 if LoadTextDlg.Execute then
  begin
   SamplesFolder := ExtractFilePath(LoadTextDlg.FileName);
   LoadSample(LoadTextDlg.FileName);
  end;
end;

procedure TChildForm.LoadSample(FN: string);
var
 s: string;
 Sam: PSample;
begin
 AssignFile(TxtFile, FN);
 Reset(TxtFile);
  try
   repeat
     if EOF(TxtFile) then
      begin
       ShowMessage(Mes_SamNotFound);
       Exit;
      end;
     Readln(TxtFile, s);
     s := Trim(s);
   until UpperCase(s) = '[SAMPLE]';
   New(Sam);
   s := LoadSampleDataTxt(Sam);
   if s <> '' then
    begin
     Dispose(Sam);
     ShowMessage(s);
     Exit;
    end
  finally
   CloseFile(TxtFile)
  end;
 SongChanged := True;
 ValidateSample2(SamNum);
 AddUndo(CALoadSample,{%H-}PtrInt(VTMP^.Samples[SamNum]),{%H-}PtrInt(Sam), auAutoIdxs);
 ChangeSample(SamNum);
 with ChangeList[ChangeCount - 1].NewParams.prm.Idx, Samples do
   SampleLine := ShownFrom + CursorY;
end;

procedure TChildForm.SBLoadPatClick(Sender: TObject);
begin
 LoadTextDlg.Title := Mes_LoadPat;
 LoadTextDlg.Filter := Mes_TextFiles + '|*.txt;*.vtp|' + Mes_AllFiles + '|*.*';
 //*.vtp to load Ivan Pirog's data files
 LoadTextDlg.InitialDir := PatternsFolder;
 if LoadTextDlg.Execute then
  begin
   PatternsFolder := ExtractFilePath(LoadTextDlg.FileName);
   LoadPattern(LoadTextDlg.FileName);
  end;
end;

procedure TChildForm.LoadPattern(FN: string);
var
 s: string;
 i: integer;
 Pat: PPattern;
begin
 AssignFile(TxtFile, FN);
 Reset(TxtFile);
  try
   repeat
     if EOF(TxtFile) then
      begin
       ShowMessage(Mes_PatNotFound);
       Exit;
      end;
     Readln(TxtFile, s);
     s := Trim(s);
   until UpperCase(s) = '[PATTERN]';
   New(Pat);
   i := LoadPatternDataTxt(Pat);
   if i <> 0 then
    begin
     Dispose(Pat);
     ShowMessage(Mes_BadFileStruct);
     Exit;
    end;
   ValidatePattern(PatNum, VTMP);
   AddUndo(CALoadPattern,{%H-}PtrInt(VTMP^.Patterns[PatNum]),{%H-}PtrInt(Pat),
     auAutoIdxs);
  finally
   CloseFile(TxtFile);
  end;
 SongChanged := True;
 ChangePattern(PatNum);
 ChangeList[ChangeCount - 1].NewParams.prm.Idx.PatternLine :=
   Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
end;

procedure TChildForm.SBSavePatClick(Sender: TObject);
var
 p: integer;
begin
 p := UDPat.Position;
 SaveTextDlg.Title := Mes_SavePat;
 SaveTextDlg.InitialDir := PatternsFolder;
 if SaveTextDlg.Execute then
  begin
   PatternsFolder := ExtractFilePath(SaveTextDlg.FileName);
   AssignFile(TxtFile, SaveTextDlg.FileName);
   Rewrite(TxtFile);
    try
     Writeln(TxtFile, '[Pattern]');
     SavePattern(VTMP, p);
    finally
     CloseFile(TxtFile);
    end;
  end;
end;

const
 ClipHdrPat = 'Vortex Tracker II v1.0 Pattern';
 ClipPatLnSz = 49; //track line length

 ClipHdrSam = 'Vortex Tracker II v1.0 Sample';
 ClipSamLnSz = 21; //sample line

 ClipHdrOrn = 'Vortex Tracker II v1.0 Ornament';

 ClipHdrDump = 'Vortex Tracker II v1.0 Registers Dump';
 ClipDumpLnSz = 28; //registers dump line length

procedure TTracks.CopyToClipboard;
var
 cs, s: string;
 X1, X2, Y1, Y2, i, l: integer;
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
 cs := ClipHdrPat + #13#10;
 for i := Y1 to Y2 do
  begin
   s := GetPatternLineString(ShownPattern, i, @MainForm.ChanAlloc) + #13#10;
   for l := 1 to X1 do s[l] := #32;
   if X2 in NotePoses then
     l := 3 + 1
   else if (X2 = 0) and (ParWind as TChildForm).SBEnvAsNote.Down then
     l := 4 + 1
   else
     l := 1 + 1;
   for l := X2 + l to ClipPatLnSz do s[l] := #32;
   cs := cs + s;
  end;

 //get registers dump for rendering in sample
 with TChildForm(ParWind) do
  begin
   ValidatePattern2(PatNum); //VTM2VTX need valid pattern
   cs += #13#10 + ClipHdrDump + #13#10 + Pat2VTX(VTMP, PatNum, Y1, Y2);
  end;

 Clipboard.AsText := cs;
end;

procedure TTracks.CutToClipboard;
begin
 CopyToClipboard;
 ClearSelection;
end;

//return in Sz size of 1st line in ClipText (if ClipText = nil initialize it with Clipboard text)
//return True if Hdr matches
function CheckClipHdr(const Hdr: string; var ClipText, NextStr: PChar): boolean;
var
 Sz: integer;
begin
 if ClipText = nil then
   ClipText := PChar(Clipboard.AsText);
 NextStr := ClipText;
 Sz := GetStrSz(NextStr);
 Result := (Sz = Length(Hdr)) and (CompareMemRange(@Hdr[1], ClipText, Sz) = 0);
end;

procedure TTracks.PasteFromClipboard(Merge: boolean);
var
 ps, ns: PChar;
 X1, X2, Y1, Y2, sz, l, i, j: integer;
 nums: array[0..MaxPatLen - 1] of TPatternLineAsNums;
begin
 ps := nil;
 if not CheckClipHdr(ClipHdrPat, ps, ns) then
   Exit;
 l := 0;
 while l < MaxPatLen do
  begin
   //next string pointer
   ps := ns;
   sz := GetStrSz(ns);
   if sz <> ClipPatLnSz then
     Break;
   nums[l] := GetPatternLineAsNums(ps);
   Inc(l);
  end;
 if l = 0 then
   Exit;

 if not GetPatternNumsBounds(nums[0], i, j) then
   Exit;

 with ParWind as TChildForm do
   ValidatePattern2(PatNum);

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
 if (X1 = X2) and (Y1 = Y2) then
  begin
   X2 := 48;
   Y2 := ShownPattern^.Length - 1;
  end;

 CursorY := Y1 - ShownFrom + N1OfLines;
 if CursorY < 0 then
  begin
   CursorY := 0;
   ShownFrom := Y1 + N1OfLines;
  end;
 CursorX := X1;

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   AddUndo(CAInsertPatternFromClipboard,{%H-}PtrInt(ShownPattern), 0, auAutoIdxs);
  end;

 if l > Y2 - Y1 + 1 then
   l := Y2 - Y1 + 1;

 for l := 0 to l - 1 do
   UpdatePatternLineValues(ShownPattern, Y1 + l, X1, X2,
     (ParWind as TChildForm).VTMP^.Ton_Table, nums[l],
     (ParWind as TChildForm).SBEnvAsNote.Down, i, j, Merge);

 CalcCaretPos;
 ResetSelection;
 RecreateCaret;
 with TChildForm(ParWind) do
  begin
   DoStep(Y1, True);
   ChangeList[ChangeCount - 1].NewParams.prm.Idx.PatternLine :=
     Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
   ToglSams.CheckUsedSamples;
   CalcTotLen;
   ShowStat;
  end;
 Invalidate;
end;

procedure TTracks.ClearSelection;
var
 X1, X2, Y1, Y2, c, m: integer;
 one: boolean;
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

 one := (Y1 = Y2) and (X1 = X2);

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   ValidatePattern2(PatNum);
   if not one then
     AddUndo(CAPatternClearSelection,{%H-}PtrInt(VTMP^.Patterns[PatNum]), 0, auAutoIdxs);

   for Y1 := Y1 to Y2 do
    begin
     m := X1;
     with ShownPattern^.Items[Y1] do
       repeat
         c := (m - 8) div 14;
         if c >= 0 then c := MainForm.ChanAlloc[c];
         if m in NotePoses then
          begin
           if one then
             ChangeNote(PatNum, Y1, c, -1)
           else
             Channel[c].Note := NT_NO;
          end
         else if (m = 0) and SBEnvAsNote.Down then
          begin
           if one then
             ChangeTracks(PatNum, Y1, c, m, 0, False)
           else
             Envelope := 0;
          end
         else if one then
           ChangeTracks(PatNum, Y1, c, m, 0, True)
         else
           case m of
             0: Envelope := Envelope and $FFF;
             1: Envelope := Envelope and $F0FF;
             2: Envelope := Envelope and $FF0F;
             3: Envelope := Envelope and $FFF0;
             5: Noise := Noise and 15;
             6: Noise := Noise and $F0;
             12, 26, 40: Channel[c].Sample := 0;
             13, 27, 41: Channel[c].Envelope := 0;
             14, 28, 42: Channel[c].Ornament := 0;
             15, 29, 43: Channel[c].Volume := 0;
             17, 31, 45: Channel[c].Additional_Command.Number := 0;
             18, 32, 46: Channel[c].Additional_Command.Delay := 0;
             19, 33, 47: Channel[c].Additional_Command.Parameter :=
                 Channel[c].Additional_Command.Parameter and 15;
             20, 34, 48: Channel[c].Additional_Command.Parameter :=
                 Channel[c].Additional_Command.Parameter and $F0;
            end;
         if m >= 48 then
           break;
         Inc(m);
         if ColSpace(m) then
           Inc(m)
         else if m in [9, 23, 37] then
           Inc(m, 3);
       until m > X2;
    end;
  end;

 //one already checks used sample, so see selection intersection with sam poses
 if not one and (X2 >= 12) and ((X1 <= 12) or (X2 >= 26)) and
   ((X1 <= 26) or (X2 >= 40)) and (X1 <= 40) then
   ToglSams.CheckUsedSamples;
 Invalidate;
 TChildForm(ParWind).CalcTotLen;
 TChildForm(ParWind).ShowStat;
end;

procedure TSamples.CopyToClipboard;
var
 cs, s: string;
 X1, X2, Y1, Y2, i, l: integer;
begin
 with TChildForm(ParWind) do
   ValidateSample2(SamNum);
 X2 := CursorX;
 X1 := SelX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 Y1 := SelY;
 Y2 := ShownFrom + CursorY;
 if Y1 > Y2 then
  begin
   Y1 := Y2;
   Y2 := SelY;
  end;
 cs := ClipHdrSam + #13#10;
 for i := Y1 to Y2 do
  begin
   s := GetSampleString(ShownSample^.Items[i], False, True) + #13#10;
   for l := 1 to X1 do s[l] := #32;
   if X2 = 5 then
     l := 3 + 1
   else if X2 in [11, 14] then
     l := 2 + 1
   else
     l := 1 + 1;
   for l := X2 + l to ClipSamLnSz - 2 do s[l] := #32;
   cs := cs + s;
  end;
 Clipboard.AsText := cs;
end;

procedure TSamples.CutToClipboard;
begin
 CopyToClipboard;
 ClearSelection;
end;

procedure TSamples.PasteSampleToSample(var ns: PChar);
var
 ps: PChar;
 X1, X2, Y1, Y2, sz, l, i, j, k, m: integer;
 TonMinus, NsMinus: boolean;
 nums: array[0..MaxSamLen - 1, 0..11] of integer;
const
 aMinNum = 0;
 aMaxNum = $FFF;
 aMinus = $1000;
 aPlus = $1001;
 aOff = $2000;
 aOn = $2001;
 aAccNo = $3000;
 aAccYes = $3001;
 aAmpNo = $4000;
 aAmpDown = aMinus;
 aAmpUp = aPlus;

 function CheckFlag(CharPos, NumIdx: integer; CharNeu, CharRsd, CharDwn: char;
   Neu, Rsd, Dwn: integer): boolean;
 begin
   if ps[CharPos] <> #32 then
    begin
     if ps[CharPos] = CharNeu then
       nums[l, NumIdx] := Neu
     else if ps[CharPos] = CharRsd then
       nums[l, NumIdx] := Rsd
     else if ps[CharPos] = CharDwn then
       nums[l, NumIdx] := Dwn
     else
       Exit(False);
    end;
   Result := True;
 end;

 function CheckMask(CharPos, NumIdx: integer; CharOff, CharOn: char): boolean;
 begin
   Result := CheckFlag(CharPos, NumIdx, CharOff, CharOn, #32, aOff, aOn, -1);
 end;

 function CheckSign(CharPos, NumIdx: integer): boolean;
 begin
   Result := CheckFlag(CharPos, NumIdx, '-', '+', #32, aMinus, aPlus, -1);
 end;

 function CheckAcc(CharPos, NumIdx: integer): boolean;
 begin
   Result := CheckFlag(CharPos, NumIdx, '_', '^', #32, aAccNo, aAccYes, -1);
 end;

 function CheckVol(CharPos, NumIdx: integer): boolean;
 begin
   Result := CheckFlag(CharPos, NumIdx, '_', '+', '-', aAmpNo, aAmpUp, aAmpDown);
 end;

 function CheckHex(CharPos, NumIdx, Len: integer): boolean;
 var
   aNum, i: integer;
 begin
   aNum := 0;
   for i := CharPos to CharPos + Len - 1 do
    begin
     case ps[i] of
       #32:
         Exit(True);
       '0'..'9':
         aNum := aNum * 16 + Ord(ps[i]) - Ord('0');
       'A'..'F':
         aNum := aNum * 16 + Ord(ps[i]) - Ord('A') + 10;
     else
       Exit(False);
      end;
    end;
   nums[l, NumIdx] := aNum;
   Result := True;
 end;

 procedure GetFlag(var aRes: boolean; Neu, Rsd: integer);
 begin
   if nums[l, k] = Neu then
     aRes := False
   else if nums[l, k] = Rsd then
     aRes := True;
 end;

 procedure GetMask(var aRes: boolean);
 begin
   GetFlag(aRes, aOff, aOn);
 end;

 procedure GetSign(var aRes: boolean);
 begin
   GetFlag(aRes, aMinus, aPlus);
 end;

 procedure GetAcc(var aRes: boolean);
 begin
   GetFlag(aRes, aAccNo, aAccYes);
 end;

begin
 FillChar(nums, SizeOf(nums), 255);
 l := 0;
 while l < MaxSamLen do
  begin
   ps := ns;
   sz := GetStrSz(ns);
   if sz <> ClipSamLnSz then
     Break;
   if not CheckMask(0, 0, 't', 'T') then
     Exit;
   if not CheckMask(1, 1, 'n', 'N') then
     Exit;
   if not CheckMask(2, 2, 'e', 'E') then
     Exit;
   if not CheckSign(4, 3) then
     Exit;
   if not CheckHex(5, 4, 3) then
     Exit;
   if not CheckAcc(8, 5) then
     Exit;
   if not CheckSign(10, 6) then
     Exit;
   if not CheckHex(11, 7, 2) then
     Exit;
   if not CheckHex(14, 8, 2) then
     Exit;
   if not CheckAcc(17, 9) then
     Exit;
   if not CheckHex(19, 10, 1) then
     Exit;
   if not CheckVol(20, 11) then
     Exit;
   Inc(l);
  end;
 if l = 0 then
   Exit;

 i := 0;
 while (i <= 11) and (nums[0, i] < 0) do
   Inc(i);
 if i = 12 then
   Exit;
 j := 11;
 while (j >= 0) and (nums[0, j] < 0) do
   Dec(j);

 X2 := CursorX;
 X1 := SelX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 Y1 := SelY;
 Y2 := ShownFrom + CursorY;
 if Y1 > Y2 then
  begin
   Y1 := Y2;
   Y2 := SelY;
  end;
 if (X1 = X2) and (Y1 = Y2) then //selection is just curret
  begin
   X2 := 23;
   Y2 := MaxSamLen - 1; //allow paste to gray area
  end;

 CursorY := Y1 - ShownFrom;
 if CursorY < 0 then
  begin
   CursorY := 0;
   ShownFrom := Y1;
  end;
 CursorX := X1;

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   ValidateSample2(SamNum);
   AddUndo(CAInsertSampleFromClipboard,{%H-}PtrInt(ShownSample), 0, auAutoIdxs);
  end;

 if l > Y2 - Y1 + 1 then
   l := Y2 - Y1 + 1;
 for l := 0 to l - 1 do
   with ShownSample^.Items[Y1 + l] do
    begin
     TonMinus := Add_to_Ton < 0;
     NsMinus := Add_to_Envelope_or_Noise < 0;
     m := X1;
     for k := i to j do if nums[l, k] >= 0 then
        begin
         case m of
           0: GetMask(Mixer_Ton);
           1: GetMask(Mixer_Noise);
           2: GetMask(Envelope_Enabled);
           4: if (nums[l, k] = aMinus) or (nums[l, k] = aPlus) then
              begin
               if ((nums[l, k] = aPlus) and (Add_to_Ton < 0)) or
                 ((nums[l, k] = aMinus) and (Add_to_Ton > 0)) then
                 Add_to_Ton := -Add_to_Ton;
               TonMinus := nums[l, k] = aMinus;
              end;
           5: if (nums[l, k] >= aMinNum) and (nums[l, k] <= aMaxNum) then
              begin
               Add_to_Ton := nums[l, k];
               if TonMinus then
                 Add_to_Ton := -Add_to_Ton;
              end;
           8: GetAcc(Ton_Accumulation);
           10: if (nums[l, k] = aMinus) or (nums[l, k] = aPlus) then
              begin
               if ((nums[l, k] = aPlus) and (Add_to_Envelope_or_Noise < 0)) or
                 ((nums[l, k] = aMinus) and (Add_to_Envelope_or_Noise > 0)) then
                 Add_to_Envelope_or_Noise := -Add_to_Envelope_or_Noise;
               NsMinus := nums[l, k] = aMinus;
              end;
           11: if (nums[l, k] >= aMinNum) and (nums[l, k] <= aMaxNum) then
              begin
               Add_to_Envelope_or_Noise := nums[l, k] and 31;
               if (Add_to_Envelope_or_Noise = 16) and not NsMinus then
                 Add_to_Envelope_or_Noise := 0;
               if Add_to_Envelope_or_Noise > 16 then
                 Add_to_Envelope_or_Noise := Add_to_Envelope_or_Noise and 15;
               if NsMinus then
                 Add_to_Envelope_or_Noise := -Add_to_Envelope_or_Noise;
              end;
           14: if (nums[l, k] >= aMinNum) and (nums[l, k] <= aMaxNum) then
               Add_to_Envelope_or_Noise := Nse(nums[l, k] and 31);
           17: GetAcc(Envelope_or_Noise_Accumulation);
           19: if (nums[l, k] >= aMinNum) and (nums[l, k] <= aMaxNum) then
               Amplitude := nums[l, k] and 15;
           20: if nums[l, k] = aAmpNo then
               Amplitude_Sliding := False
             else if nums[l, k] = aAmpUp then
              begin
               Amplitude_Sliding := True;
               Amplitude_Slide_Up := True;
              end
             else if nums[l, k] = aAmpDown then
              begin
               Amplitude_Sliding := True;
               Amplitude_Slide_Up := False;
              end;
          end;
         if m >= 20 then
           break;
         case m of
           2, 8, 17:
             Inc(m, 2);
           5, 11, 14:
             Inc(m, 3);
         else
           Inc(m);
          end;
         if m > X2 then
           break;
        end;
    end;
 CalcCaretPos;
 ResetSelection;
 Invalidate;
end;

procedure TSamples.PasteRegDumpToSample(var ns: PChar; Chan: integer);
var
 ps: PChar;
 sz, l, j, k: integer;
 Sam: PSample;
 Done: boolean;
begin
 //check register dump header existence
 ps := ns;
 if not CheckClipHdr(ClipHdrDump, ps, ns) then
   Exit;

 with TChildForm(ParWind) do
   k := GetNoteFreq(VTMP^.Ton_Table, GetBaseNote(tlSamples));

 New(Sam);
 l := 0; //lines counter
 Done := False;
  try
   repeat
     //next string pointer
     ps := ns;
     sz := GetStrSz(ns);
     if sz <> ClipDumpLnSz then
       Break;

     Sam^.Items[l] := EmptySampleTick;

     if not SGetDumpW(@ps[Chan * 4], j) then //tone for Chan
       Exit;

     Sam^.Items[l].Add_to_Ton := Tne((j - k) and $FFF);

     if not SGetDumpB(@ps[7 * 2], j) then //mixer
       Exit;

     if (j and (1 shl Chan)) = 0 then
       Sam^.Items[l].Mixer_Ton := True;
     if (j and (1 shl (Chan + 3))) = 0 then
       Sam^.Items[l].Mixer_Noise := True;

     if not SGetDumpB(@ps[(8 + Chan) * 2], j) then //volume
       Exit;

     Sam^.Items[l].Envelope_Enabled := (j and 16) <> 0;
     Sam^.Items[l].Amplitude := j and 15;

     if Sam^.Items[l].Mixer_Noise then
      begin
       if not SGetDumpB(@ps[6 * 2], j) then //noise
         Exit;
       Sam^.Items[l].Add_to_Envelope_or_Noise := Nse(j);
      end;

     Inc(l);
   until l >= MaxSamLen;
   Done := l <> 0;
   if not Done then
     Exit;
  finally
   if not Done then
     Dispose(Sam);
  end;

 with Sam^ do
  begin
   Length := l;
   Loop := 0;
   Enabled := True;
   for l := l to MaxSamLen - 1 do
     Items[l] := EmptySampleTick;
  end;

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   ValidateSample2(SamNum);
   AddUndo(CARenderSample,{%H-}PtrInt(VTMP^.Samples[SamNum]),{%H-}PtrInt(Sam),
     auAutoIdxs);
   ChangeSample(SamNum);
   with ChangeList[ChangeCount - 1].NewParams.prm.Idx, Samples do
     SampleLine := ShownFrom + CursorY;
  end;
end;

function GetChanToPastePattern(var ns: PChar; out Chan: integer): boolean;
var
 ps: PChar;
 sz, l: integer;
begin
 Chan := 0; //leftest column
 l := 0; //lines counter
 repeat
   //next string pointer
   ps := ns;
   sz := GetStrSz(ns);
   if sz <> ClipPatLnSz then
     Break;
   if l = 0 then
    begin
     //analize only first line
     while (sz > 0) and (ps^ = #32) do
      begin
       Inc(Chan);
       Dec(sz);
       Inc(ps);
      end;
     if sz = 0 then //empty
       Exit(False);
    end;
   Inc(l);
 until False;
 if l = 0 then
   Exit(False);

 //detect leftest channel
 if Chan < 8 then
   Chan := 0
 else
   Chan := (Chan - 8) div 14;

 Result := True;
end;

procedure TSamples.PastePatternToSample(var ns: PChar);
var
 Chan: integer;
begin
 if GetChanToPastePattern(ns, Chan) then
   PasteRegDumpToSample(ns, Chan);
end;

procedure TSamples.PasteOrnamentToSample(var ns: PChar);
begin
 GetStrSz(ns); //ignore ornament values
 GetStrSz(ns); //skip empty line
 PasteRegDumpToSample(ns, 0);
end;

procedure TSamples.PasteFromClipboard;
var
 ps, ns: PChar;
begin
 ps := nil;
 if CheckClipHdr(ClipHdrSam, ps, ns) then
   PasteSampleToSample(ns)
 else if CheckClipHdr(ClipHdrPat, ps, ns) then
   PastePatternToSample(ns)
 else if CheckClipHdr(ClipHdrOrn, ps, ns) then
   PasteOrnamentToSample(ns);
end;

procedure TSamples.ClearSelection;
var
 X1, X2, Y1, Y2, m: integer;
begin
 X2 := CursorX;
 X1 := SelX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 Y1 := SelY;
 Y2 := ShownFrom + CursorY;
 if Y1 > Y2 then
  begin
   Y1 := Y2;
   Y2 := SelY;
  end;

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   ValidateSample2(SamNum);
   if Y1 <> Y2 then
     AddUndo(CASampleClearSelection,{%H-}PtrInt(VTMP^.Samples[SamNum]), 0, auAutoIdxs)
   else
     AddUndo(CAChangeSampleValue,{%H-}PtrInt(@ShownSample^.Items[Y1]), 0, auAutoIdxs);

   for Y1 := Y1 to Y2 do
    begin
     m := X1;
     with ShownSample^.Items[Y1] do
       repeat
         case m of
           0: Mixer_Ton := False;
           1: Mixer_Noise := False;
           2: Envelope_Enabled := False;
           4: begin
             if SBSamAsNotes.Down then
               //clear both sign and ton shift digits (united as note)
               Add_to_Ton := 0
             else
               Add_to_Ton := Abs(Add_to_Ton);
            end;
           5: Add_to_Ton := 0;
           8: Ton_Accumulation := False;
           10: Add_to_Envelope_or_Noise := Abs(Add_to_Envelope_or_Noise);
           11, 14: Add_to_Envelope_or_Noise := 0;
           17: Envelope_or_Noise_Accumulation := False;
           19: Amplitude := 0;
           20: Amplitude_Sliding := False;
          end;
         if m >= 20 then
           break;
         if m in [2, 8, 17] then
           Inc(m, 2)
         else if m in [5, 11, 14] then
           Inc(m, 3)
         else
           Inc(m);
       until m > X2;
    end;
  end;
 Invalidate;
end;

procedure TOrnaments.CopyToClipboard;
var
 cs: string;
 I1, I2, i: integer;
begin
 I1 := SelI;
 I2 := ShownFrom + CursorX div 7 * OrnNRow + CursorY;
 if I1 > I2 then
  begin
   I1 := I2;
   I2 := SelI;
  end;
 cs := ClipHdrOrn + #13#10;
 for i := I1 to I2 do
  begin
   if ShownOrnament = nil then
     cs := cs + '0'
   else
     cs := cs + IntToStr(ShownOrnament^.Items[i]);
   if i < I2 then cs := cs + ','
   else
     cs := cs + #13#10;
  end;

 //get registers dump for rendering in sample
 with TChildForm(ParWind) do
   cs += #13#10 + ClipHdrDump + #13#10 + Orn2VTX(VTMP, GetBaseNote(tlOrnaments),
     OrnNum, I1, I2);

 Clipboard.AsText := cs;
end;

procedure TOrnaments.CutToClipboard;
begin
 CopyToClipboard;
 ClearSelection;
end;

procedure TOrnaments.PasteOrnamentToOrnament(var ns: PChar);
var
 ps: PChar;
 s: string;
 I1, I2, i, v, sz: integer;
begin
 I1 := SelI;
 I2 := ShownFrom + CursorX div 7 * OrnNRow + CursorY;
 if I1 > I2 then
  begin
   I1 := I2;
   I2 := SelI;
  end;
 if (I1 = I2) then //selection is just carret
   //paste to gray area even (user can increase orn length after)
   I2 := MaxOrnLen - 1;

 if I1 > I2 then //extra protection (really cursor can't be in gray area)
   Exit;

 if I1 < ShownFrom then
   ShownFrom := I1;
 CursorX := (I1 - ShownFrom) div OrnNRow * 7 + 3;
 CursorY := (I1 - ShownFrom) mod OrnNRow;

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   ValidateOrnament(OrnNum);
   AddUndo(CAInsertOrnamentFromClipboard,{%H-}PtrInt(ShownOrnament), 0, auAutoIdxs);
  end;

 ps := ns;
 sz := GetStrSz(ns);
 ns := ps;

 for i := I1 to I2 do
  begin
   if sz = 0 then
     Break;
   ps := ns;
   SetLength(s, GetSubStrSz(',', ns, sz));
   Move(ps^, s[1], Length(s));
   s := Trim(s);
   if (s = '') or not TryStrToInt(s, v) then
     Break;
   ShownOrnament^.Items[i] := v;
  end;

 CalcCaretPos;
 ResetSelection;
 Invalidate;
end;

procedure TOrnaments.PasteRegDumpToOrnament(var ns: PChar; Chan: integer);
var
 ps: PChar;
 sz, l, j, BaseNote, Note, t: integer;
 Orn: POrnament;
 Done: boolean;
begin
 //check register dump header existence
 ps := ns;
 if not CheckClipHdr(ClipHdrDump, ps, ns) then
   Exit;

 with TChildForm(ParWind) do
  begin
   BaseNote := GetBaseNote(tlOrnaments);
   t := VTMP^.Ton_Table;
  end;

 New(Orn);
 l := 0; //lines counter
 Done := False;
  try
   repeat
     //next string pointer
     ps := ns;
     sz := GetStrSz(ns);
     if sz <> ClipDumpLnSz then
       Break;

     if not SGetDumpW(@ps[Chan * 4], j) then //tone for Chan
       Exit;

     Note := GetNoteN(t, j, j) - BaseNote;
     if Note < -96 then
       Note := -96
     else if Note > 96 then
       Note := 96;
     Orn^.Items[l] := Note;

     Inc(l);
   until l >= MaxOrnLen;
   Done := l <> 0;
   if not Done then
     Exit;
  finally
   if not Done then
     Dispose(Orn);
  end;

 with Orn^ do
  begin
   Length := l;
   Loop := 0;
   for l := l to MaxOrnLen - 1 do
     Items[l] := 0;
  end;

 with TChildForm(ParWind) do
  begin
   SongChanged := True;
   ValidateOrnament(OrnNum);
   AddUndo(CARenderOrnament,{%H-}PtrInt(VTMP^.Ornaments[OrnNum]),
     {%H-}PtrInt(Orn), auAutoIdxs);
   ChangeOrnament(OrnNum);
   with ChangeList[ChangeCount - 1].NewParams.prm.Idx, Ornaments do
     OrnamentLine := ShownFrom + CursorY + CursorX div 7 * OrnNRow;
  end;
end;

procedure TOrnaments.PastePatternToOrnament(var ns: PChar);
var
 Chan: integer;
begin
 if GetChanToPastePattern(ns, Chan) then
   PasteRegDumpToOrnament(ns, Chan);
end;

procedure TOrnaments.PasteFromClipboard;
var
 ps, ns: PChar;
begin
 ps := nil;
 if CheckClipHdr(ClipHdrOrn, ps, ns) then
   PasteOrnamentToOrnament(ns)
 else if CheckClipHdr(ClipHdrPat, ps, ns) then
   PastePatternToOrnament(ns);
end;

procedure TOrnaments.ClearSelection;
var
 I1, I2: integer;
begin
 I1 := SelI;
 I2 := ShownFrom + CursorX div 7 * OrnNRow + CursorY;
 if I1 > I2 then
  begin
   I1 := I2;
   I2 := SelI;
  end;

 with TChildForm(ParWind) do
  begin
   ValidateOrnament(OrnNum);
   if I1 <> I2 then
    begin
     SongChanged := True;
     AddUndo(CAOrnamentClearSelection,{%H-}PtrInt(VTMP^.Ornaments[OrnNum]),
       0, auAutoIdxs);
    end
   else if ShownOrnament^.Items[I1] <> 0 then
    begin
     SongChanged := True;
     AddUndo(CAChangeOrnamentValue, ShownOrnament^.Items[I1], 0, auAutoIdxs);
    end;
   for I1 := I1 to I2 do
     ShownOrnament^.Items[I1] := 0;
  end;
 Invalidate;
end;

procedure TTestLine.CopyToClipboard;
var
 cs: string;
 X1, X2, l: integer;
begin
 X1 := SelX;
 X2 := CursorX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;
 cs := GetPatternLineString(TChildForm(ParWind).VTMP^.Patterns[-1], LineIndex);
 SetLength(cs, ClipPatLnSz);
 cs := cs + #13#10;
 for l := 1 to X1 do cs[l] := #32;
 if X2 = 8 then l := 3 + 1
 else
   l := 1 + 1;
 for l := X2 + l to ClipPatLnSz do cs[l] := #32;
 Clipboard.AsText := ClipHdrPat + #13#10 + cs;
end;

procedure TTestLine.CutToClipboard;
begin
 CopyToClipboard;
 ClearSelection;
end;

procedure TTestLine.PasteFromClipboard;
var
 ps, ns: PChar;
 sz, X1, X2: integer;
begin
 ps := nil;
 if not CheckClipHdr(ClipHdrPat, ps, ns) then
   Exit;
 ps := ns;
 sz := GetStrSz(ns);
 if sz <> ClipPatLnSz then
   Exit;

 X1 := SelX;
 X2 := CursorX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;

 if X1 = X2 then //from cursor to end
   X2 := 20;

 CursorX := X1;

 UpdatePatternLineValues(TChildForm(ParWind).VTMP^.Patterns[-1], LineIndex,
   X1, X2, TChildForm(ParWind).VTMP^.Ton_Table, GetPatternLineAsNums(ps), False);

 if (X1 <= 8) and (X2 >= 8) then //note can be changed
   TChildForm(ParWind).BaseNoteChanged(LineIndex);

 CalcCaretPos;
 ResetSelection;
 RecreateCaret;
 Invalidate;
end;

procedure TTestLine.ClearSelection;
var
 X1, X2, m: integer;
begin
 X1 := SelX;
 X2 := CursorX;
 if X1 > X2 then
  begin
   X1 := X2;
   X2 := SelX;
  end;

 with TChildForm(ParWind).VTMP^.Patterns[-1]^.Items[LineIndex] do
  begin
   m := X1;
   repeat
     case m of
       0: Envelope := Envelope and $FFF;
       1: Envelope := Envelope and $F0FF;
       2: Envelope := Envelope and $FF0F;
       3: Envelope := Envelope and $FFF0;
       5: Noise := Noise and 15;
       6: Noise := Noise and $F0;
       8: begin
         Channel[0].Note := NT_NO;
         TChildForm(ParWind).BaseNoteChanged(LineIndex);
        end;
       12: Channel[0].Sample := 0;
       13: Channel[0].Envelope := 0;
       14: Channel[0].Ornament := 0;
       15: Channel[0].Volume := 0;
       17: Channel[0].Additional_Command.Number := 0;
       18: Channel[0].Additional_Command.Delay := 0;
       19: Channel[0].Additional_Command.Parameter :=
           Channel[0].Additional_Command.Parameter and 15;
       20: Channel[0].Additional_Command.Parameter :=
           Channel[0].Additional_Command.Parameter and $F0;
      end;
     if m >= 20 then
       break;
     Inc(m);
     if ColSpace(m) then
       Inc(m)
     else if m = 9 then
       Inc(m, 3);
   until m > X2;
  end;
 Invalidate;
end;

procedure TTestLine.SetTestOct(Oct: integer);
begin
 if (FTestOct = Oct) or not (Oct in [1..8]) then
   Exit;
 FTestOct := Oct;
 if Focused then //transpose note to new octave
  begin
   with TChildForm(ParWind).VTMP^.Patterns[-1]^.Items[LineIndex] do
     if Channel[0].Note >= 0 then
      begin
       Oct := (Channel[0].Note mod 12) + (TestOct - 1) * 12;
       if LineIndex = tlSamples then
         TChildForm(ParWind).RecalcSample(Oct);
       Channel[0].Note := Oct;
      end;
   Invalidate;
  end;
end;

procedure TChildForm.UDAutoHLChangingEx(Sender: TObject; var AllowChange: boolean;
 NewValue: smallint; Direction: TUpDownDirection);
var
 L: integer;
begin
 //called only if user clicked arrows or pressed up/down keys
 //and not called if set programmically
 if Assigned(Tracks.ShownPattern) then
   L := Tracks.ShownPattern^.Length
 else
   L := DefPatLen;
 AllowChange := (NewValue >= 0) and (NewValue <= L);
 if AllowChange then
   ChangeHLStep(NewValue);
end;

procedure TChildForm.AutoHLCheckClick(Sender: TObject);
begin
 if SBAutoHL.Down then
   CalcHLStep;
end;

procedure TChildForm.CalcHLStep;
var
 PLen, NS: integer;
begin
 if Tracks.ShownPattern = nil then
   PLen := DefPatLen
 else
   PLen := Tracks.ShownPattern^.Length;
 if PLen mod 5 = 0 then
   NS := 5
 else if PLen mod 3 = 0 then
   NS := 3
 else
   NS := 4;
 if NS <> Tracks.HLStep then
   ChangeHLStep(NS);
end;

procedure TChildForm.ChangeHLStep(NewStep: integer);
begin
 UDAutoHL.Position := NewStep;
 if NewStep = 0 then
   if Tracks.ShownPattern = nil then
     NewStep := DefPatLen
   else
     NewStep := Tracks.ShownPattern^.Length;
 if Tracks.HLStep <> NewStep then
  begin
   Tracks.HLStep := NewStep;
   Tracks.Invalidate;
  end;
end;

procedure TChildForm.UDAutoHLClick(Sender: TObject; Button: TUDBtnType);
begin
 SBAutoHL.Down := False;
end;

procedure TChildForm.SetLoopPos(lp: integer);
begin
 SongChanged := True;
 AddUndo(CAChangePositionListLoop, VTMP^.Positions.Loop, lp);
 SGPositions.Cells[VTMP^.Positions.Loop, 0] :=
   IntToStr(VTMP^.Positions.Value[VTMP^.Positions.Loop]);
 VTMP^.Positions.Loop := lp;
 SGPositions.Cells[VTMP^.Positions.Loop, 0] :=
   'L' + IntToStr(VTMP^.Positions.Value[VTMP^.Positions.Loop]);
 if SGPositions.Col <> lp then ShowPosition(lp);
end;

procedure TChildForm.AddUndo(CA: TChangeAction; OldP, NewP: PtrInt;
 IdxN: integer = -1; IdxX: integer = -1; IdxY: integer = -1; IdxZ: integer = -1);

 procedure SaveParameters;
 begin
   with ChangeList[ChangeCount - 1] do
    begin
     OldParams.prm.One.Value := OldP;
     NewParams.prm.One.Value := NewP;
     OldParams.prm.Two.PrevLoop := -1;
     NewParams.prm.Two.PrevLoop := -1;
    end;
 end;

 procedure SavePattern;
 begin
   with ChangeList[ChangeCount - 1] do
    begin
     with ComParams do
      begin
       if IdxN = auAutoIdxs then //autofill all
        begin
         IdxN := PatNum;
         IdxX := Tracks.ShownFrom - Tracks.N1OfLines + Tracks.CursorY;
         IdxY := (Tracks.CursorX - 8) div 14;
         if IdxY >= 0 then IdxY := MainForm.ChanAlloc[IdxY];
         IdxZ := Tracks.CursorX;
        end;
       CurrentPattern := IdxN;
      end;
     with OldParams.prm.Idx do
      begin
       PatternLine := IdxX;
       PatternChan := IdxY;
       PatternX := IdxZ;
       if (PositionNumber < VTMP^.Positions.Length) and
         (VTMP^.Positions.Value[PositionNumber] = IdxN) then
         CurrentPosition := PositionNumber
       else
         CurrentPosition := -1;
      end;
     with NewParams.prm.Idx do
      begin
       PatternLine := IdxX;
       PatternChan := IdxY;
       PatternX := IdxZ;
       CurrentPosition := OldParams.prm.Idx.CurrentPosition;
      end;
    end;
 end;

 procedure SaveSample;
 begin
   with ChangeList[ChangeCount - 1] do
    begin
     if IdxN = auAutoIdxs then //autofill all
      begin
       IdxN := SamNum;
       IdxX := Samples.ShownFrom + Samples.CursorY;
       IdxY := Samples.CursorX;
      end;
     ComParams.CurrentSample := IdxN;
     with OldParams.prm.Idx do
      begin
       SampleLine := IdxX;
       SampleCursorX := IdxY;
      end;
     with NewParams.prm.Idx do
      begin
       SampleLine := IdxX;
       SampleCursorX := IdxY;
      end;
    end;
 end;

 procedure SaveOrnament;
 begin
   with ChangeList[ChangeCount - 1] do
    begin
     if IdxN = auAutoIdxs then //autofill all
      begin
       IdxN := OrnNum;
       with Ornaments do
         IdxX := ShownFrom + CursorY + (CursorX div 7) * OrnNRow;
      end;
     ComParams.CurrentOrnament := IdxN;
     OldParams.prm.Idx.OrnamentLine := IdxX;
     NewParams.prm.Idx.OrnamentLine := IdxX;
    end;
 end;

 procedure SavePosition;
 begin
   with ChangeList[ChangeCount - 1] do
    begin
     if IdxN = auAutoIdxs then //autofill all
       IdxN := SGPositions.Col;
     OldParams.prm.Idx.CurrentPosition := IdxN;
     NewParams.prm.Idx.CurrentPosition := IdxN;
    end;
 end;

var
 i: integer;
begin
 if UndoWorking then
   Exit;
 Inc(ChangeCount);
 DisposeUndo(False);
 i := Length(ChangeList);
 if ChangeCount > i then
   SetLength(ChangeList, i + 64);
 with ChangeList[ChangeCount - 1] do
  begin
   Grouped := False;
   Action := CA;
   case CA of
     CAChangeSpeed, CAChangeToneTable, CAChangePositionListLoop, CAChangeFeatures,
     CAChangeHeader:
       SaveParameters;
     CAChangeTitle, CAChangeAuthor:
      begin
       StrCopy(OldParams.str,{%H-}PChar(OldP));
       StrCopy(NewParams.str,{%H-}PChar(NewP));
      end;
     CAChangePatternSize, CAChangeNote, CAChangeEnvelopePeriod, CAChangeNoise,
     CAChangeSample, CAChangeEnvelopeType, CAChangeOrnament, CAChangeVolume,
     CAChangeSpecialCommandNumber, CAChangeSpecialCommandDelay,
     CAChangeSpecialCommandParameter:
      begin
       SaveParameters;
       SavePattern;
      end;
     CATracksManagerCopy:
      begin
       Ptr.Pattern := {%H-}PPattern(OldP);
       SavePattern;
      end;
     CATransposePattern, CAExpandShrinkPattern, CASwapPattern:
      begin
       New(Ptr.Pattern);
       Ptr.Pattern^ := {%H-}PPattern(OldP)^;
       SavePattern;
      end;
     CALoadPattern:
      begin
       SavePattern;
       Ptr.Pattern := {%H-}PPattern(OldP);
       VTMP^.Patterns[ComParams.CurrentPattern] := {%H-}PPattern(NewP);
      end;
     CAPatternInsertLine, CAPatternDeleteLine, CAPatternClearLine,
     CAInsertPatternFromClipboard, CAPatternClearSelection:
      begin
       New(Ptr.Pattern);
       Ptr.Pattern^ := {%H-}PPattern(OldP)^;
       SavePattern;
      end;
     CAChangePositionValue:
      begin
       SaveParameters;
       SavePosition;
       OldParams.prm.Two.PositionListLen := VTMP^.Positions.Length;
      end;
     CAInsertPosition, CADeletePosition, CAReorderPatterns:
      begin
       New(Ptr.PositionList);
       Ptr.PositionList^ := {%H-}PPositionList(OldP)^;
       SavePosition;
       if CA = CAReorderPatterns then
         ComParams.PatternsIndex := {%H-}PPatIndex(NewP);
      end;
     CALoadOrnament, CAOrGen, CARenderOrnament:
      begin
       SaveOrnament;
       Ptr.Ornament := {%H-}POrnament(OldP);
       VTMP^.Ornaments[ComParams.CurrentOrnament] := {%H-}POrnament(NewP);
      end;
     CAInsertOrnamentFromClipboard, CAOrnamentInsertLine, CAOrnamentDeleteLine,
     CAOrnamentClearSelection:
      begin
       New(Ptr.Ornament);
       Ptr.Ornament^ := {%H-}POrnament(OldP)^;
       SaveOrnament;
      end;
     CAChangeOrnamentLoop, CAChangeOrnamentSize, CAChangeOrnamentValue:
      begin
       SaveParameters;
       SaveOrnament;
      end;
     CAChangeSampleLoop, CAChangeSampleSize:
      begin
       SaveParameters;
       SaveSample;
      end;
     CAChangeSampleValue:
      begin
       if NewP = 0 then //marker if OldP already allocated
        begin
         New(Ptr.SampleLineValues);
         Ptr.SampleLineValues^ := {%H-}PSampleTick(OldP)^;
        end
       else
         Ptr.SampleLineValues := {%H-}PSampleTick(OldP);
       SaveSample;
      end;
     CALoadSample, CAUnrollSample, CARenderSample:
      begin
       SaveSample;
       Ptr.Sample := {%H-}PSample(OldP);
       VTMP^.Samples[ComParams.CurrentSample] := {%H-}PSample(NewP);
      end;
     CAInsertSampleFromClipboard, CARecalcSample,
     CASampleInsertLine, CASampleDeleteLine, CASampleClearSelection:
      begin
       New(Ptr.Sample);
       Ptr.Sample^ := {%H-}PSample(OldP)^;
       SaveSample;
      end;
    end;
  end;
end;

procedure TChildForm.DoUndo(Undo: boolean);
var
 index: integer;

 function FirstInGroup: boolean; inline;
 begin
   Result := (index = 0) or not ChangeList[index - 1].Grouped;
 end;

 procedure SetF(Page: integer; Ctrl: TWinControl);
 var
   f: boolean;
 begin
   if not FirstInGroup then
     Exit;
   f := EditorPages.ActivePageIndex = Page;
   EditorPages.ActivePageIndex := Page;
   case Page of
     piTracks: if not f or not (Tracks.Enabled and Tracks.Focused) then
         if Ctrl.CanSetFocus then Ctrl.SetFocus;
     piSamples: if not f or not (Samples.Enabled and Samples.Focused) then
         if Ctrl.CanSetFocus then Ctrl.SetFocus;
     piOrnaments: if not f or not (Ornaments.Enabled and Ornaments.Focused) then
         if Ctrl.CanSetFocus then Ctrl.SetFocus;
     piTables, piOptions: if Ctrl.CanSetFocus then Ctrl.SetFocus;
    end;
   if Ctrl.Focused and (Ctrl is TEdit) then
     (Ctrl as TEdit).SelectAll;
 end;

var
 Pars: PChangeParameters;
 PatX: integer;

 procedure RedrawTracks(Fcs: TWinControl = nil);
 begin
   if not FirstInGroup then
     Exit;
   with ChangeList[index] do
    begin
     if Pars^.prm.Idx.CurrentPosition >= 0 then
       ShowPosition(Pars^.prm.Idx.CurrentPosition);

     ChangePattern(ComParams.CurrentPattern);

     //hook edit line
     Tracks.CursorY := Tracks.N1OfLines;
     if Pars^.prm.Idx.PatternLine < 0 then
       Tracks.ShownFrom := 0
     else if Pars^.prm.Idx.PatternLine <
       VTMP^.Patterns[ComParams.CurrentPattern]^.Length then
       Tracks.ShownFrom := Pars^.prm.Idx.PatternLine
     else
       Tracks.ShownFrom := VTMP^.Patterns[ComParams.CurrentPattern]^.Length - 1;

     Tracks.CursorX := PatX;
     if Tracks.CursorX in [1..3] then //check if EnvAsNote mode changed
       if SBEnvAsNote.Down then
         Tracks.CursorX := 0;

     Tracks.ResetSelection;
     Tracks.RecreateCaret;
     Tracks.CalcCaretPos;

     if Fcs = nil then
       SetF(piTracks, Tracks)
     else
       SetF(piTracks, Fcs);

     ShowStat;
    end;
 end;

 procedure ShowOrn(Fcs: TWinControl);
 var
   Line: integer;
 begin
   if not FirstInGroup then
     Exit;
   with ChangeList[index], Ornaments do
    begin
     if Pars^.prm.Idx.OrnamentLine >= 0 then
       Line := Pars^.prm.Idx.OrnamentLine
     else
       Line := ShownFrom + CursorY + (CursorX div 7) * OrnNRow;
     if Line >= VTMP^.Ornaments[ComParams.CurrentOrnament]^.Length then
       Line := VTMP^.Ornaments[ComParams.CurrentOrnament]^.Length - 1;

     //show all ornament if it fits
     if VTMP^.Ornaments[ComParams.CurrentOrnament]^.Length <= NOfLines then
       ShownFrom := 0
     else if ShownFrom > VTMP^.Ornaments[ComParams.CurrentOrnament]^.Length -
     NOfLines then
       //avoid show unused area if ornament size enough
       ShownFrom := VTMP^.Ornaments[ComParams.CurrentOrnament]^.Length - NOfLines;

     //if cell before visible area, redraw to make it first
     if Line < ShownFrom then
      begin
       ShownFrom := Line;
       CursorY := 0;
       CursorX := 3;
      end
     //if cell after visible area, redraw to make it last
     else if Line >= ShownFrom + NOfLines then
      begin
       ShownFrom := Line - NOfLines;
       CursorY := OrnNRow - 1;
       CursorX := OrnNCol * 7 - 4;
      end
     //else calc coords inside of visible area
     else
      begin
       CursorY := (Line - ShownFrom) mod OrnNRow;
       CursorX := (Line - ShownFrom) div OrnNRow * 7 + 3;
      end;
     Ornaments.ResetSelection;
     SetF(piOrnaments, Fcs);
     ChangeOrnament(ComParams.CurrentOrnament);
    end;
 end;

 procedure ShowSmp(Fcs: TWinControl);
 var
   Line: integer;
 begin
   if not FirstInGroup then
     Exit;
   with ChangeList[index], Samples do
    begin
     if Pars^.prm.Idx.SampleCursorX >= 0 then
       CursorX := Pars^.prm.Idx.SampleCursorX;
     if Pars^.prm.Idx.SampleLine >= 0 then
       Line := Pars^.prm.Idx.SampleLine
     else
       Line := ShownFrom + CursorY;
     if Line >= VTMP^.Samples[ComParams.CurrentSample]^.Length then
       Line := VTMP^.Samples[ComParams.CurrentSample]^.Length - 1;

     //show all sample if it fits
     if VTMP^.Samples[ComParams.CurrentSample]^.Length <= NOfLines then
       ShownFrom := 0
     else if ShownFrom > VTMP^.Samples[ComParams.CurrentSample]^.Length - NOfLines then
       //avoid show unused area if sample size enough
       ShownFrom := VTMP^.Samples[ComParams.CurrentSample]^.Length - NOfLines;

     //if cell before visible area, redraw to make it first
     if Line < ShownFrom then
      begin
       ShownFrom := Pars^.prm.Idx.SampleLine;
       CursorY := 0;
      end
     //if cell after visible area, redraw to make it last
     else if Pars^.prm.Idx.SampleLine >= ShownFrom + NOfLines then
      begin
       ShownFrom := Pars^.prm.Idx.SampleLine - NOfLines;
       CursorY := NOfLines - 1;
      end
     //else calc coord inside of visible area
     else
       CursorY := Line - ShownFrom;
     Samples.ResetSelection;
     SetF(piSamples, Fcs);
     ChangeSample(ComParams.CurrentSample);
    end;
 end;

 procedure GetPatX;
 begin
   with ChangeList[index], Pars^.prm.Idx do
     if PatternX >= 0 then
      begin
       PatX := PatternX;
       if PatX >= 8 then
         //repos chans due chans can be swapped by user after current changing
         PatX := (PatX - 8) mod 14 + MainForm.ChanAlloc[PatternChan] * 14 + 8;
      end
     else
       //calc CursorX
       case Action of
         CAChangeEnvelopePeriod: PatX := 3;
         CAChangeNoise: PatX := 6;
       else
        begin
         if PatternChan >= 0 then
           PatX := MainForm.ChanAlloc[PatternChan] * 14 + 8
         else
           PatX := 8; //can't be, just prevent possible future bugs
         case Action of
           CAChangeSample: PatX += 4;
           CAChangeEnvelopeType: PatX += 5;
           CAChangeOrnament: PatX += 6;
           CAChangeVolume: PatX += 7;
           CAChangeSpecialCommandNumber: PatX += 9;
           CAChangeSpecialCommandDelay: PatX += 10;
           CAChangeSpecialCommandParameter: PatX += 12;
          end;
        end;
        end;
 end;

var
 j: integer;
 Pnt: pointer;
 PosLst: TPositionList;
 s: string;
 ST: TSampleTick;
begin
 UndoWorking := True;
  try
   repeat
     if Undo then
      begin
       if ChangeCount = 0 then
         Exit;
       Dec(ChangeCount);
       index := ChangeCount;
       Pars := @ChangeList[index].OldParams;
      end
     else
      begin
       if ChangeCount >= ChangeTop then
         Exit;
       index := ChangeCount;
       Inc(ChangeCount);
       Pars := @ChangeList[index].NewParams;
      end;
     SongChanged := True;
     PatX := 0;
     with ChangeList[index] do
      begin
       if Action in PlaybackBewaredChanges then
         if (IsPlayingWindow >= 0) and (PlayMode <> PMPlayLine) then
           MainForm.StopPlaying;
       case Action of
         CAChangeSpeed:
          begin
           SetInitDelay(Pars^.prm.One.Speed);
           SetF(piTracks, EdSpeed);
           CalcTotLen;
          end;
         CAChangeTitle:
          begin
           SetTitle(WinCPToUTF8(Pars^.str));
           SetF(piTracks, EdTitle);
          end;
         CAChangeAuthor:
          begin
           SetAuthor(WinCPToUTF8(Pars^.str));
           SetF(piTracks, EdAuthor);
          end;
         CAChangeToneTable:
          begin
           SetTable(Pars^.prm.One.Table);
           SetF(piTables, EdTable);
          end;
         CAChangeSampleLoop:
          begin
           VTMP^.Samples[ComParams.CurrentSample]^.Loop := Pars^.prm.One.Loop;
           ShowSmp(EdSamLoop);
          end;
         CAChangeOrnamentLoop:
          begin
           VTMP^.Ornaments[ComParams.CurrentOrnament]^.Loop := Pars^.prm.One.Loop;
           ShowOrn(EdOrnLoop);
          end;
         CAChangePatternSize:
          begin
           GetPatX;
           VTMP^.Patterns[ComParams.CurrentPattern]^.Length := Pars^.prm.One.Size;
           RedrawTracks(EdPatLen);
           ToglSams.CheckUsedSamples;
           CalcTotLen;
          end;
         CAChangeEnvelopePeriod, CAChangeNoise, CAChangeNote, CAChangeSample,
         CAChangeEnvelopeType, CAChangeOrnament, CAChangeVolume,
         CAChangeSpecialCommandNumber, CAChangeSpecialCommandDelay,
         CAChangeSpecialCommandParameter:
          begin
           GetPatX;
           with ComParams, Pars^.prm do
             if Action = CAChangeNote then
               ChangeNote(CurrentPattern, Idx.PatternLine, Idx.PatternChan, One.Note)
             else
               ChangeTracks(CurrentPattern, Idx.PatternLine, Idx.PatternChan,
                 PatX, One.Value, False);
           RedrawTracks;
          end;
         CALoadPattern, CAInsertPatternFromClipboard, CAPatternInsertLine,
         CAPatternDeleteLine,
         CAPatternClearLine, CAPatternClearSelection, CATransposePattern,
         CATracksManagerCopy,
         CAExpandShrinkPattern, CASwapPattern:
          begin
           GetPatX;
           Pnt := Ptr.Pattern;
           Ptr.Pattern := VTMP^.Patterns[ComParams.CurrentPattern];
           VTMP^.Patterns[ComParams.CurrentPattern] := Pnt;
           RedrawTracks(EdPatLen);
           ToglSams.CheckUsedSamples;
           CalcTotLen;
          end;
         CAChangePositionListLoop:
          begin
           SetLoopPos(Pars^.prm.One.Loop);
           if PatNum <> VTMP^.Positions.Value[Pars^.prm.One.Loop] then
             ChangePattern(VTMP^.Positions.Value[Pars^.prm.One.Loop]);
           SetF(piTracks, SGPositions);
          end;
         CAChangePositionValue:
          begin
           for j := Pars^.prm.Two.PositionListLen to VTMP^.Positions.Length - 1 do
             SGPositions.Cells[j, 0] := '...';
           VTMP^.Positions.Length := Pars^.prm.Two.PositionListLen;
           SBPositionsUpdateMax;
           if Pars^.prm.Idx.CurrentPosition < VTMP^.Positions.Length then
             ChangePositionValue(Pars^.prm.Idx.CurrentPosition, Pars^.prm.One.Value);
           SetF(piTracks, SGPositions);
           ToglSams.CheckUsedSamples;
           CalcTotLen;
          end;
         CADeletePosition, CAInsertPosition, CAReorderPatterns:
          begin
           if Action = CAReorderPatterns then
             ChangePatternsOrder(ComParams.PatternsIndex, Undo);
           PosLst := Ptr.PositionList^;
           Ptr.PositionList^ := VTMP^.Positions;
           VTMP^.Positions := PosLst;
           for j := 0 to 255 do
             if j < VTMP^.Positions.Length then
              begin
               s := IntToStr(VTMP^.Positions.Value[j]);
               if j = VTMP^.Positions.Loop then s := 'L' + s;
               SGPositions.Cells[j, 0] := s;
              end
             else
               SGPositions.Cells[j, 0] := '...';
           SBPositionsUpdateMax;
           ToglSams.CheckUsedSamples;
           CalcTotLen;
           InputPNumber := 0;
           ShowPosition(Pars^.prm.Idx.CurrentPosition);
           if Pars^.prm.Idx.CurrentPosition < VTMP^.Positions.Length then
             ChangePositionValue(Pars^.prm.Idx.CurrentPosition,
               VTMP^.Positions.Value[Pars^.prm.Idx.CurrentPosition])
           else if VTMP^.Positions.Length > 0 then
            begin
             ShowPosition(VTMP^.Positions.Length - 1); //не лишнее?
             SelectPosition(VTMP^.Positions.Length - 1);
            end;
           SetF(piTracks, SGPositions);
          end;
         CAChangeSampleSize:
          begin
           VTMP^.Samples[ComParams.CurrentSample]^.Length := Pars^.prm.One.Size;
           VTMP^.Samples[ComParams.CurrentSample]^.Loop := Pars^.prm.Two.PrevLoop;
           ShowSmp(EdSamLen);
          end;
         CAChangeOrnamentSize:
          begin
           VTMP^.Ornaments[ComParams.CurrentOrnament]^.Length := Pars^.prm.One.Size;
           VTMP^.Ornaments[ComParams.CurrentOrnament]^.Loop := Pars^.prm.Two.PrevLoop;
           ShowOrn(EdOrnLen);
          end;
         CAChangeFeatures:
          begin
           GBFeatures.ItemIndex := Pars^.prm.One.NewFeatures;
           SetF(piOptions, GBFeatures.Controls[GBFeatures.ItemIndex] as TRadioButton);
          end;
         CAChangeHeader:
          begin
           GBHeader.ItemIndex := Pars^.prm.One.NewHeader;
           SetF(piOptions, GBHeader.Controls[GBHeader.ItemIndex] as TRadioButton);
          end;
         CAChangeOrnamentValue:
          begin
           with ComParams, Pars^.prm do
             VTMP^.Ornaments[CurrentOrnament]^.Items[Idx.OrnamentLine] := One.Value;
           ShowOrn(Ornaments);
          end;
         CALoadOrnament, CAOrGen, CARenderOrnament, CAOrnamentInsertLine,
         CAOrnamentDeleteLine,
         CAOrnamentClearSelection, CAInsertOrnamentFromClipboard:
          begin
           Pnt := Ptr.Ornament;
           Ptr.Ornament := VTMP^.Ornaments[ComParams.CurrentOrnament];
           VTMP^.Ornaments[ComParams.CurrentOrnament] := Pnt;
           ShowOrn(Ornaments);
          end;
         CALoadSample, CAUnrollSample, CARenderSample, CARecalcSample,
         CASampleInsertLine, CASampleDeleteLine, CASampleClearSelection,
         CAInsertSampleFromClipboard:
          begin
           Pnt := Ptr.Sample;
           Ptr.Sample := VTMP^.Samples[ComParams.CurrentSample];
           VTMP^.Samples[ComParams.CurrentSample] := Pnt;
           ShowSmp(Samples);
          end;
         CAChangeSampleValue:
           with ComParams do
            begin
             ST := Ptr.SampleLineValues^;
             Ptr.SampleLineValues^ :=
               VTMP^.Samples[CurrentSample]^.Items[Pars^.prm.Idx.SampleLine];
             VTMP^.Samples[CurrentSample]^.Items[Pars^.prm.Idx.SampleLine] := ST;
             ShowSmp(Samples);
            end;
        end;
      end;
     if Undo then
      begin
       if (ChangeCount = 0) or not ChangeList[ChangeCount - 1].Grouped then
         Exit;
      end
     else if not ChangeList[index].Grouped then
       Exit;
   until False;
  finally
   UndoWorking := False;
  end;
end;

procedure CheckExtSaveAs;
begin
 with MainForm, SaveDialogVTM do
   FileName := ChangeFileExt(FileName, '.' + GetSaveAsFileExt);
end;

procedure TChildForm.SaveModuleAs;
begin
 with MainForm, SaveDialogVTM do
  begin
   FilterIndex := Ord(not SavedAsText) + 1;
   if GetFileName(SaveDialogVTM, Self, @CheckExtSaveAs) then
    begin
     SavePT3(Self, FileName, FilterIndex = 1);
     OpenDialogVTM.InitialDir := SaveDialogVTM.InitialDir;
    end;
  end;
end;

procedure TChildForm.SaveModule;
var
 FN: string;
begin
 //exit if single and not changed or TS-pair and both not changed
 if not SongChanged and ((TSWindow = nil) or not TSWindow.SongChanged) then
   Exit;

 //check if one of TS-pair already have file name
 FN := WinFileName;
 if (FN = '') and (TSWindow <> nil) then
   FN := TSWindow.WinFileName;

 //call save file dialog if no FN was set yet
 if FN = '' then
   SaveModuleAs
 else
  begin
   if SavedAsText then
     FN := ChangeFileExt(FN, '.txt')
   else
     FN := ChangeFileExt(FN, '.pt3');
   MainForm.SavePT3(Self, FN, SavedAsText);
  end;
end;

procedure TChildForm.BringToFrontBoth;
//bring to front and check if need to do same with TS-pair
begin
 //active window can be overlapped after DoCascade
 if (IsSoftRepos = 0) and (TSWindow <> nil) then
   //bring to front 2nd window of TS-Pair
   TSWindow.BringToFront;
 BringToFront;
end;

procedure TChildForm.ScrollWorkspace;
var
 DeltaX, DeltaY: integer;
begin
 if not MainForm.HScrollBar.Visible and not MainForm.VScrollBar.Visible then
   //All childs fit in workspace
   Exit;

 //scroll if >50% of width/height beyond workspace

 DeltaX := 0;
 DeltaY := 0;
 if MainForm.HScrollBar.Visible then
   if Left + Width div 2 >= MainForm.Workspace.ClientWidth then
     DeltaX := -Min(Left - MainForm.Workspace.ClientWidth + Width, Left)
   else if Left + Width div 2 < 0 then
     DeltaX := -Left;

 if MainForm.VScrollBar.Visible then
   if Top + Height div 2 >= MainForm.Workspace.ClientHeight then
     DeltaY := -Min(Top - MainForm.Workspace.ClientHeight + Height, Top)
   else if Top + Height div 2 < 0 then
     DeltaY := -Top;

 if (DeltaX <> 0) or (DeltaY <> 0) then
  begin
   MainForm.Workspace.ScrollBy(DeltaX, DeltaY);
   MainForm.CalcSBs;
  end;
end;

procedure TChildForm.FormActivate(Sender: TObject);
begin
 MainForm.Caption := Caption + ' - Vortex Tracker II';
 WinMenuItem.Checked := True;

 BringToFrontBoth;

 if Moving = ctNone then
   //not clicked by LMB, so scroll to make visible
   ScrollWorkspace;

 with ToglSams do
  begin
   CheckEnabledSamples;
   CheckUsedSamples;
  end;
 SetToolsPattern;
end;

function TChildForm.PrepareTSString(aTSBut: TSpeedButton; const s: string): string;
begin
 Result := s;
 CheckStringFitting(aTSBut.Canvas.Handle, Result, aTSBut.ClientWidth);
end;

procedure TChildForm.SBTSClick(Sender: TObject);
var
 i: integer;
begin
 for i := 0 to TSSel.ListBox1.Count - 1 do
   if TSSel.ListBox1.Items.Objects[i] = TSWindow then
    begin
     TSSel.ListBox1.ItemIndex := i;
     Break;
    end;
 if (TSSel.ShowModal = mrOk) and (TSSel.ListBox1.ItemIndex >= 0) and
   (TChildForm(TSSel.ListBox1.Items.Objects[TSSel.ListBox1.ItemIndex]) <> Self) then
  begin
   SBTS.Caption := PrepareTSString(SBTS, TSSel.ListBox1.Items[TSSel.ListBox1.ItemIndex]);
   if (TSWindow <> nil) and (TSWindow <> Self) then
    begin
     TSWindow.SBTS.Caption := PrepareTSString(TSWindow.SBTS, TSSel.ListBox1.Items[0]);
     TSWindow.TSWindow := nil;
    end;
   TSWindow := TChildForm(TSSel.ListBox1.Items.Objects[TSSel.ListBox1.ItemIndex]);
   if (TSWindow <> nil) and (TSWindow <> Self) then
    begin
     TSWindow.SBTS.Caption := PrepareTSString(TSWindow.SBTS, Caption);
     TSWindow.TSWindow := Self;
    end;
   HookTSWindow(False);
  end;
end;

procedure TChildForm.SetToolsPattern;
begin
 GlbTrans.Edit2.Text := IntToStr(PatNum);
 TrMng.Edit2.Text := IntToStr(PatNum);
 TrMng.Edit3.Text := IntToStr(PatNum);
end;

procedure TChildForm.EdPatLenKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
 i: integer;
 Act: TShortcutActions;
begin
 if GetShortcutAction(SCS_PatternLengthEditor, Key, Shift, Act) then
   case Act of
     SCA_PatLenStepInc:
      begin
       i := UDPatLen.Position + Tracks.HLStep;
       if i > MaxPatLen then i := MaxPatLen;
       ChangePatternLength(i);
       EdPatLen.Text := IntToStr(i);
       Key := 0;
      end;
     SCA_PatLenStepDec:
      begin
       i := UDPatLen.Position - Tracks.HLStep;
       if i <= 0 then i := 1;
       ChangePatternLength(i);
       EdPatLen.Text := IntToStr(i);
       Key := 0;
      end;
    end;
end;

function TChildForm.CanHookTSWindow: boolean;
begin
 Result := (TSWindow <> nil) and (Width + TSWindow.Width - ChildFrameWidth <=
   MainForm.ClientWidth);
end;

procedure TChildForm.HookTSWindow(Move: boolean = True);
begin
 if CanHookTSWindow then //hook TSWindow if work area is wide
  begin
   //considering earliest window at left side
   if (WinNumber < TSWindow.WinNumber) or Move then //repos 2nd (inactive) window
    begin
     Inc(TSWindow.IsSoftRepos);
     TSWindow.Top := Top;
     if WinNumber < TSWindow.WinNumber then
       TSWindow.Left := Left + Width - ChildFrameWidth
     else
       TSWindow.Left := Left - TSWindow.Width + ChildFrameWidth;
     Dec(TSWindow.IsSoftRepos);
    end
   else //repos active window (first hooking, i.e. not moving)
    begin
     Inc(IsSoftRepos);
     Top := TSWindow.Top;
     Left := TSWindow.Left + TSWindow.Width - ChildFrameWidth;
     Dec(IsSoftRepos);
    end;
   if not Move then
    begin
     Inc(TSWindow.IsSoftRepos);
     TSWindow.Height := Height;
     Dec(TSWindow.IsSoftRepos);
     TSWindow.BringToFront;
     BringToFront;
    end;
  end;
end;

procedure TChildForm.DoMove;
begin
 if IsSoftRepos <> 0 then
   Exit;
 HookTSWindow;
 MainForm.CalcSBs;
end;

procedure TChildForm.DoResize;
begin
 if IsSoftRepos <> 0 then
   Exit;
 SetNOfLines;
 if TSWindow <> nil then
  begin
   TSWindow.Height := Height;
   if CanHookTSWindow then
     TSWindow.Top := Top;
  end;
 MainForm.CalcSBs;
end;

procedure TChildForm.SetNOfLines;
begin
 Tracks.SetNOfLines(False);
 Samples.SetNOfLines;
 Ornaments.SetNOfLines;
end;

procedure TChildForm.CheckTSString;
var
 j: integer;
begin
 //retruncate long string with '...'
 if TSWindow = nil then
   SBTS.Caption := PrepareTSString(SBTS, TSSel.ListBox1.Items[0])
 else
   for j := 0 to MainForm.Childs.Count - 1 do
     if TChildForm(MainForm.Childs.Items[j]) = TSWindow then
      begin
       SBTS.Caption := PrepareTSString(SBTS, TSSel.ListBox1.Items[j + 1]);
       Break;
      end;
end;

procedure TChildForm.FullResize;
begin
 if Tracks.SetFont then
   Tracks.SetNOfLines;
 Samples.SetFont;
 Ornaments.SetFont;
 SampleTestLine.SetFont;
 OrnamentTestLine.SetFont;
 PatternTestLine.SetFont;
 CalcSize;
end;

procedure TChildForm.ResizeTracksWidth;
begin
 with Tracks do
   ClientWidth := CelW * (49 + DigN);
 CalcSize;
end;

function TChildForm.AcceptCannotUndo(const Op: string): boolean;
begin
 Result := VTOptions.NotWarnUndo or
   (MessageDlg(Op + ' ' + Mes_UndoCant, mtConfirmation, [mbYes, mbNo], 0) = mrYes);
 if Result then
   DisposeUndo(True);
end;

procedure TChildForm.UpdateHints;
var
 s: string;
begin
 EdPatLen.Hint := Mes_HintPatLen1;
 s := MainForm.CreateTwoKeysHintGeneral(SCA_PatLenStepInc, SCA_PatLenStepDec, '', False);
 if s <> '' then
   EdPatLen.Hint := EdPatLen.Hint + ', ' + s + ' - ' + Mes_HintPatLen2
 else
   EdPatLen.Hint := EdPatLen.Hint + ')';

 SBAutoStep.Hint := MainForm.AutoStep.Hint;
 SBAutoEnv.Hint := MainForm.AutoEnv.Hint;
 SBAutoPars.Hint := MainForm.AutoPrms.Hint;

 //need to apply translation
 UpdateToneTableHints;
 Ornaments.DoHint;
end;

function TChildForm.IsPlayingWindow: integer;
begin
 if IsPlaying then
   Result := IsPlaybackWindow
 else
   Result := -1;
end;

function TChildForm.IsPlaybackWindow: integer;
var
 i: integer;
begin
 for i := 0 to Length(PlaybackBufferMaker.Players) - 1 do
   if PlaybackWindow[i] = Self then
     Exit(i);
 Result := -1;
end;

procedure TChildForm.BaseNoteChanged(tlIdx: integer);
begin
 //base note in test line changed
 if (tlIdx = tlOrnaments) and SBOrnAsNotes.Down then
   //redraw ornament
   Ornaments.Invalidate
 else if (tlIdx = tlSamples) and SBSamAsNotes.Down then
   //redraw sample
   Samples.Invalidate;
end;

procedure TChildForm.WMWindowPosChanged(var Message: TLMWindowPosChanged);
begin
 inherited WMWindowPosChanged(Message);
 if not Assigned(Message.WindowPos) {or
  (WindowState = wsMinimized) or
  (WindowState = wsMaximized)} then
   Exit;
 if (Message.WindowPos^.flags and SWP_NOMOVE) = 0 then
   DoMove;
end;

constructor TChildForm.Create(TheOwner: TComponent);
begin
 inherited Create(TheOwner);
 FormCreate(TheOwner);
end;

destructor TChildForm.Destroy;
begin
 FormDestroy(Self);
 inherited Destroy;
end;

procedure TChildForm.Close;
var
 CanClose: boolean;
begin
 CanClose := True;
 FormCloseQuery(Self, CanClose);
 if CanClose then
  begin
   //hide buttons of maximized mode
   MainForm.MIRestore1.Visible := False;
   MainForm.MIClose1.Visible := False;
   //not using Free here because of Close can be called from message handlers,
   //which do not expect that object will disapear
   Application.ReleaseComponent(Self);
  end;
end;

procedure TChildForm.SetForeground;
var
 MaximezedMode: boolean;
begin
 BringToFront;
 if CanSetFocus then
  begin
   MaximezedMode := MaximizedChilds;
   SetFocus;
   if MaximezedMode then
     MainForm.MaximizeChild(Self);
  end;
end;

function TChildForm.Active: boolean;
begin
 Result := Focused or (MainForm.ActiveChild = Self);
end;

procedure TChildForm.MoveWnd(DeltaX, DeltaY: integer);
begin
 Left := Left + DeltaX;
 Top := Top + DeltaY;
end;

function TChildForm.SetHeight(Value: integer): boolean;
begin
 Result := (Value <> Height) and (Value >= Header.Height +
   (SizeBorderWidth + ChildFrameWidth) * 2) and
   ((Constraints.MinHeight = 0) or (Value >= Constraints.MinHeight)) and
   ((Constraints.MaxHeight = 0) or (Value <= Constraints.MaxHeight));
 if Result then
   Height := Value;
end;

procedure TChildForm.CheckCaptionFitting;
var
 s: string;
begin
 s := FCaption;
 CheckStringFitting(Header.Canvas.Handle, s, SBMax.Left - 4);
 Header.Caption := s;
end;

procedure TChildForm.SetCaption(const aCapt: string);
begin
 FCaption := aCapt;
 CheckCaptionFitting;
end;

procedure TChildForm.SetFocusAtActiveControl;
begin
 BringToFront;
 if MainForm.ActiveChild <> Self then
   if Assigned(ActiveControl) and ActiveControl.CanSetFocus then
     ActiveControl.SetFocus
   else if CanSetFocus then
     SetFocus;
end;

procedure TChildForm.PosSelectAll;
var
 aSel: TGridRect;
begin
 with SGPositions do
  begin
   aSel := Selection;
   aSel.Left := 0;
   aSel.Right := VTMP^.Positions.Length - 1;
   if aSel.Right < 0 then
     aSel.Right := 0;
   Selection := aSel;
  end;
end;

procedure TChildForm.Maximize(Remaximize: boolean = False);
begin
 if not Remaximize and Maximized then
   Exit;
 if not Maximized then
  begin
   HeightBeforeMax := Height;
   LeftBeforeMax := Left;
   TopBeforeMax := Top;
  end;
 Maximized := True;
 MainForm.MIRestore1.Visible := True;
 MainForm.MIClose1.Visible := True;
 Inc(IsSoftRepos);
 //height with no size frame
 EditorPages.Height := Height - EditorPages.Top - ChildFrameWidth;
 Header.Height := 0;
 Header.Top := ChildFrameWidth;
 Height := MainForm.Workspace.Height;
 Top := 0;
 if TSWindow = nil then
   Left := (MainForm.Workspace.Width - Width) div 2
 else
  begin
   if WinNumber < TSWindow.WinNumber then
     Left := MainForm.Workspace.Width div 2 - Width
   else
     Left := MainForm.Workspace.Width div 2 - ChildFrameWidth;
   if CanHookTSWindow then
     TSWindow.Maximize;
  end;
 if Left < 0 then
   Left := 0;
 SetNOfLines;
 Dec(IsSoftRepos);
end;

procedure TChildForm.Restore;
begin
 if not Maximized then
   Exit;
 Maximized := False;
 Inc(IsSoftRepos);
 //height with size frame
 EditorPages.Height := Height - EditorPages.Top - ChildFrameWidth - SizeBorderWidth;
 Header.Height := GetSystemMetrics(SM_CYCAPTION);
 Header.Top := ChildFrameWidth + SizeBorderWidth;
 Height := HeightBeforeMax;
 Left := LeftBeforeMax;
 Top := TopBeforeMax;
 if TSWindow <> nil then
   TSWindow.Restore;
 SetNOfLines;
 Dec(IsSoftRepos);
end;

//OnExit not fires in many cases
procedure TTracks.WMKillFocus(var Message: TLMKillFocus);
begin
 if (PlayMode in [PMPlayLine, PMPlayPattern]) and IsPlaying and
   (PlaybackWindow[0] = ParWind) then
  begin
   MainForm.VisTimer.Enabled := False;
   CatchAndResetPlaying;
  end;
 KeyPressed := 0;
 DestroyCaret(Handle);
 Clicked := False;
 inherited WMKillFocus(Message);
end;

//OnEnter works, but moved here too
procedure TTracks.WMSetFocus(var Message: TLMSetFocus);
begin
 inherited WMSetFocus(Message);
 CreateMyCaret;
 CalcCaretPos;
 ShowCaret(Handle);
 (ParWind as TChildForm).ShowStat;
end;

procedure TTestLine.WMKillFocus(var Message: TLMKillFocus);
begin
 DestroyCaret(Handle);
 if (PlayMode = PMPlayLine) and IsPlaying and (PlaybackWindow[0] = ParWind) then
   CatchAndResetPlaying;
 KeyPressed := 0;
 Clicked := False;
 inherited WMKillFocus(Message);
end;

procedure TTestLine.WMSetFocus(var Message: TLMSetFocus);
begin
 inherited WMSetFocus(Message);
 CreateMyCaret;
 CalcCaretPos;
 ShowCaret(Handle);
end;

procedure TSamples.WMKillFocus(var Message: TLMKillFocus);
begin
 DestroyCaret(Handle);
 ClickedX := -1;
 inherited WMKillFocus(Message);
end;

procedure TSamples.WMSetFocus(var Message: TLMSetFocus);
begin
 inherited WMSetFocus(Message);
 InputSNumber := 0;
 CreateMyCaret;
 CalcCaretPos;
 ShowCaret(Handle);
end;

procedure TOrnaments.WMKillFocus(var Message: TLMKillFocus);
begin
 DestroyCaret(Handle);
 Clicked := False;
 inherited WMKillFocus(Message);
end;

procedure TOrnaments.WMSetFocus(var Message: TLMSetFocus);
begin
 inherited WMSetFocus(Message);
 InputONumber := 0;
 CreateCaret(Handle, 0, CelW * 3, CelH);
 CalcCaretPos;
 ShowCaret(Handle);
end;

end.
