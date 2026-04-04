{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit keys;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils, Languages, LCLType, LCLProc;

type
 //Key actions sources
 TShortcutSources = (
   SCS_GlobalActions, SCS_PositionListEditor, SCS_PatternLengthEditor,
   SCS_TestLineEditor, SCS_PatternEditor, SCS_SampleEditor, SCS_OrnamentEditor);

 //Key actions enumeration
 TShortcutActions = (

   {Main (global) actions}
   //File menu actions
   SCA_FileNew, SCA_FileOpen, SCA_FileClose, SCA_FileClose2,
   SCA_FileSave, SCA_FileSaveAs,
   SCA_FileExportSNDH, SCA_FileExportZX, SCA_FileExportPSG, SCA_FileExportWAV,
   SCA_FileOptions, SCA_FileExit,
   //Play menu actions
   SCA_PlayStop, SCA_PlayPlay, SCA_PlayFromStart,
   SCA_PlayPattern, SCA_PlayPatternFromStart,
   SCA_PlayToggleLoop, SCA_PlayToggleLoopAll,
   SCA_PlayToggleSamples,
   //Edit menu actions
   SCA_EditUndo, SCA_EditRedo, SCA_EditCut, SCA_EditCopy, SCA_EditPaste,
   SCA_EditTracksManager, SCA_EditGlobalTransposition,
   //Window menu actions
   SCA_WindowCascade, SCA_WindowTileH, SCA_WindowTileV, SCA_WindowMaximized,
   //SCA_WindowMinAll,SCA_WindowArrAll,
   SCA_WindowFind,
   SCA_WindowNext, SCA_WindowNext2, SCA_WindowPrev, SCA_WindowPrev2,
   SCA_WindowCloseAll,
   //Help menu actions
   SCA_HelpAbout, SCA_HelpGuide, SCA_HelpManual,
   //Chip actions
   SCA_ChipType, SCA_ChipChans, SCA_VolumeUp, SCA_VolumeDown,
   //Editor action
   SCA_EditorAutoStep, SCA_EditorAutoEnv, SCA_EditorAutoEnvStd, SCA_EditorAutoPrms,
   //MIDI keyboard
   SCA_MidiToggle, SCA_MidiVolume,
   //Octave choosing
   SCA_Octave1, SCA_Octave2, SCA_Octave3, SCA_Octave4,
   SCA_Octave5, SCA_Octave6, SCA_Octave7, SCA_Octave8,

   {Positions list actions}
   //Positions list cursor (except Left/Right/Home - standard for TStringGrid
   SCA_PosListEnd,
   //Menu commands
   SCA_PosListSetLoop,
   SCA_PosListAdd, SCA_PosListDup, SCA_PosListClone, SCA_PosListDelete,
   SCA_PosListPatLens, SCA_PosListRenumPats,
   //Merge/select
   SCA_PosListMerge, SCA_PosListSelectAll, SCA_PosListSelectAll2,
   //Jump to editor
   SCA_PosListJumpToEditor,

   {Pattern length editor actions}
   SCA_PatLenStepInc, SCA_PatLenStepDec,

   {Test line editor actions}
   //Test line cursor control
   SCA_TestLineLeft, SCA_TestLineRight,
   SCA_TestLineColumnLeft, SCA_TestLineColumnRight,
   SCA_TestLineBegin, SCA_TestLineEnd,
   //Jump to editor
   SCA_TestLineJumpToEditor,
   //Clear/select
   SCA_TestLineSelectionClear, SCA_TestLineSelectionCut, SCA_TestLineSelectAll,
   SCA_TestLineSelectAll2,

   {Pattern editor actions}
   //Pattern cursor control
   SCA_PatternLineLeft, SCA_PatternLineRight,
   SCA_PatternLineColumnLeft, SCA_PatternLineColumnRight,
   SCA_PatternLineBegin, SCA_PatternLineEnd,
   SCA_PatternTrackUp, SCA_PatternTrackDown,
   SCA_PatternTrackStepUp, SCA_PatternTrackStepDown,
   SCA_PatternTrackPageUp, SCA_PatternTrackPageDown,
   SCA_PatternTrackBegin, SCA_PatternTrackEnd,
   SCA_PatternJumpQuarter1, SCA_PatternJumpQuarter2, SCA_PatternJumpQuarter3,
   SCA_PatternJumpQuarter4,
   SCA_PatternFirstLineBegin, SCA_PatternLastLineEnd,
   //Jump to position list editor
   SCA_PatternJumpToPosList,
   //Global actions duplicates
   SCA_PatternAutoStep, SCA_PatternAutoEnv, SCA_PatternAutoPrms,
   //Special paste and other clipboard related
   SCA_PatternCopy, SCA_PatternCut, SCA_PatternPaste, SCA_PatternMerge,
   //Fast transpositions
   SCA_PatternTransposeUp1, SCA_PatternTransposeDown1,
   SCA_PatternTransposeUp3, SCA_PatternTransposeDown3,
   SCA_PatternTransposeUp5, SCA_PatternTransposeDown5,
   SCA_PatternTransposeUp12, SCA_PatternTransposeDown12,
   //Swap channels left/right
   SCA_PatternSwapLeft, SCA_PatternSwapRight,
   //Fast autostep choosers
   SCA_PatternSetAutoStep0, SCA_PatternSetAutoStep1, SCA_PatternSetAutoStep2,
   SCA_PatternSetAutoStep3, SCA_PatternSetAutoStep4, SCA_PatternSetAutoStep5,
   SCA_PatternSetAutoStep6, SCA_PatternSetAutoStep7, SCA_PatternSetAutoStep8,
   SCA_PatternSetAutoStep9,
   //Size tools
   SCA_PatternExpand, SCA_PatternShrink, SCA_PatternSplit, SCA_PatternPack,
   //Insert/delete/clear/select
   SCA_PatternInsertLine, SCA_PatternTrackInsertLine,
   SCA_PatternDeleteLine, SCA_PatternDeleteLine2, SCA_PatternTrackDeleteLine,
   SCA_PatternClearLine, SCA_PatternTrackClearLine,
   SCA_PatternSelectionClear, SCA_PatternSelectAll, SCA_PatternSelectAll2,
   //Autostep backward
   SCA_PatternStepBack,
   //Playback related
   SCA_PatternPlayTillUp,

   {Sample editor actions}
   //Sample cursor control
   SCA_SampleLineLeft, SCA_SampleLineRight,
   SCA_SampleLineColumnLeft, SCA_SampleLineColumnRight,
   SCA_SampleLineBegin, SCA_SampleLineEnd,
   SCA_SampleTrackUp, SCA_SampleTrackDown,
   SCA_SampleTrackPageUp, SCA_SampleTrackPageDown,
   SCA_SampleTrackBegin, SCA_SampleTrackEnd,
   SCA_SampleFirstLineBegin, SCA_SampleLastLineEnd,
   //Jump to test line
   SCA_SampleJumpToTest,
   //Insert/delete/clear/select
   SCA_SampleInsertLine, SCA_SampleInsertLine2,
   SCA_SampleDeleteLine, SCA_SampleDeleteLine2,
   SCA_SampleSelectionClear, SCA_SampleSelectionCut,
   SCA_SampleSelectAll, SCA_SampleSelectAll2,
   //Toggles
   SCA_SampleToggle, SCA_SampleToggleT, SCA_SampleToggleN, SCA_SampleToggleE,
   SCA_SamplePlus, SCA_SamplePlus2, SCA_SamplePlus3,
   SCA_SampleMinus, SCA_SampleMinus2,
   SCA_SampleAcc, SCA_SampleClearSignOrAcc,

   {Ornament editor actions}
   //Ornament cursor control
   SCA_OrnamentColumnLeft, SCA_OrnamentColumnRight,
   SCA_OrnamentColumnShownFirst, SCA_OrnamentColumnShownLast,
   SCA_OrnamentUp, SCA_OrnamentDown,
   SCA_OrnamentPageUp, SCA_OrnamentPageDown,
   SCA_OrnamentBegin, SCA_OrnamentBegin2, SCA_OrnamentEnd, SCA_OrnamentEnd2,
   //Jump to test line
   SCA_OrnamentJumpToTest,
   //Insert/delete/clear/select
   SCA_OrnamentInsertLine, SCA_OrnamentInsertLine2,
   SCA_OrnamentDeleteLine, SCA_OrnamentDeleteLine2,
   SCA_OrnamentSelectionClear, SCA_OrnamentSelectionCut,
   SCA_OrnamentSelectAll, SCA_OrnamentSelectAll2,
   //Toggles
   SCA_OrnamentToggle,
   SCA_OrnamentPlus, SCA_OrnamentPlus2, SCA_OrnamentPlus3,
   SCA_OrnamentMinus, SCA_OrnamentMinus2
   );

 TShortcutRecord = record
   Action: TShortcutActions;
   Shortcut: TShortCut;
 end;

 TShortcutActionsSet = set of TShortcutActions;
 TShortcuts = array[TShortcutActions] of TShortCut;
 TShortcutsSorted = array[TShortcutSources] of array of TShortcutRecord;

const
 //Text descritions of each group
 ShortcutSourcesDesc: array[TShortcutSources] of string = (
   Mes_SCS_GlobalActions, Mes_SCS_PositionListEditor, Mes_SCS_PatternLengthEditor,
   Mes_SCS_TestLineEditor, Mes_SCS_PatternEditor, Mes_SCS_SampleEditor,
   Mes_SCS_OrnamentEditor);

 //Text descritions of each action
 ShortcutActionsDesc: array[TShortcutActions] of string = (
   Mes_SCA_FileNew, Mes_SCA_FileOpen, Mes_SCA_FileClose, Mes_SCA_FileClose2,
   Mes_SCA_FileSave, Mes_SCA_FileSaveAs,
   Mes_SCA_FileExportSNDH, Mes_SCA_FileExportZX, Mes_SCA_FileExportPSG,
   Mes_SCA_FileExportWAV,
   Mes_SCA_FileOptions, Mes_SCA_FileExit,
   Mes_SCA_PlayStop, Mes_SCA_PlayPlay, Mes_SCA_PlayFromStart,
   Mes_SCA_PlayPattern, Mes_SCA_PlayPatternFromStart,
   Mes_SCA_PlayToggleLoop, Mes_SCA_PlayToggleLoopAll,
   Mes_SCA_PlayToggleSamples,
   Mes_SCA_EditUndo, Mes_SCA_EditRedo, Mes_SCA_EditCut, Mes_SCA_EditCopy, Mes_SCA_EditPaste,
   Mes_SCA_EditTracksManager, Mes_SCA_EditGlobalTransposition,
   Mes_SCA_WindowCascade, Mes_SCA_WindowTileH, Mes_SCA_WindowTileV, Mes_SCA_WindowMaximized,
   //Mes_SCA_WindowMinAll,Mes_SCA_WindowArrAll,
   Mes_SCA_WindowFind,
   Mes_SCA_WindowNext, Mes_SCA_WindowNext2, Mes_SCA_WindowPrev, Mes_SCA_WindowPrev2,
   Mes_SCA_WindowCloseAll,
   Mes_SCA_HelpAbout, Mes_SCA_HelpGuide, Mes_SCA_HelpManual,
   Mes_SCA_ChipType, Mes_SCA_ChipChans, Mes_SCA_VolumeUp, Mes_SCA_VolumeDown,
   Mes_SCA_EditorAutoStep, Mes_SCA_EditorAutoEnv, Mes_SCA_EditorAutoEnvStd,
   Mes_SCA_EditorAutoPrms,
   Mes_SCA_MidiToggle, Mes_SCA_MidiVolume,
   Mes_SCA_Octave1, Mes_SCA_Octave2, Mes_SCA_Octave3, Mes_SCA_Octave4,
   Mes_SCA_Octave5, Mes_SCA_Octave6, Mes_SCA_Octave7, Mes_SCA_Octave8,

   Mes_SCA_PosListEnd,
   Mes_SCA_PosListSetLoop,
   Mes_SCA_PosListAdd, Mes_SCA_PosListDup, Mes_SCA_PosListClone, Mes_SCA_PosListDelete,
   Mes_SCA_PosListPatLens, Mes_SCA_PosListRenumPats,
   Mes_SCA_PosListMerge, Mes_SCA_PosListSelectAll, Mes_SCA_PosListSelectAll2,
   Mes_SCA_PosListJumpToEditor,

   Mes_SCA_PatLenStepInc, Mes_SCA_PatLenStepDec,

   Mes_SCA_TestLineLeft, Mes_SCA_TestLineRight,
   Mes_SCA_TestLineColumnLeft, Mes_SCA_TestLineColumnRight,
   Mes_SCA_TestLineBegin, Mes_SCA_TestLineEnd,
   Mes_SCA_TestLineJumpToEditor,
   Mes_SCA_TestLineSelectionClear, Mes_SCA_TestLineSelectionCut,
   Mes_SCA_TestLineSelectAll, Mes_SCA_TestLineSelectAll2,

   Mes_SCA_PatternLineLeft, Mes_SCA_PatternLineRight,
   Mes_SCA_PatternLineColumnLeft, Mes_SCA_PatternLineColumnRight,
   Mes_SCA_PatternLineBegin, Mes_SCA_PatternLineEnd,
   Mes_SCA_PatternTrackUp, Mes_SCA_PatternTrackDown,
   Mes_SCA_PatternTrackStepUp, Mes_SCA_PatternTrackStepDown,
   Mes_SCA_PatternTrackPageUp, Mes_SCA_PatternTrackPageDown,
   Mes_SCA_PatternTrackBegin, Mes_SCA_PatternTrackEnd,
   Mes_SCA_PatternJumpQuarter1, Mes_SCA_PatternJumpQuarter2,
   Mes_SCA_PatternJumpQuarter3, Mes_SCA_PatternJumpQuarter4,
   Mes_SCA_PatternFirstLineBegin, Mes_SCA_PatternLastLineEnd,
   Mes_SCA_PatternJumpToPosList,
   Mes_SCA_PatternAutoStep, Mes_SCA_PatternAutoEnv, Mes_SCA_PatternAutoPrms,
   Mes_SCA_PatternCopy, Mes_SCA_PatternCut, Mes_SCA_PatternPaste, Mes_SCA_PatternMerge,
   Mes_SCA_PatternTransposeUp1, Mes_SCA_PatternTransposeDown1,
   Mes_SCA_PatternTransposeUp3, Mes_SCA_PatternTransposeDown3,
   Mes_SCA_PatternTransposeUp5, Mes_SCA_PatternTransposeDown5,
   Mes_SCA_PatternTransposeUp12, Mes_SCA_PatternTransposeDown12,
   Mes_SCA_PatternSwapLeft, Mes_SCA_PatternSwapRight,
   Mes_SCA_PatternSetAutoStep0, Mes_SCA_PatternSetAutoStep1, Mes_SCA_PatternSetAutoStep2,
   Mes_SCA_PatternSetAutoStep3, Mes_SCA_PatternSetAutoStep4, Mes_SCA_PatternSetAutoStep5,
   Mes_SCA_PatternSetAutoStep6, Mes_SCA_PatternSetAutoStep7, Mes_SCA_PatternSetAutoStep8,
   Mes_SCA_PatternSetAutoStep9,
   Mes_SCA_PatternExpand, Mes_SCA_PatternShrink, Mes_SCA_PatternSplit, Mes_SCA_PatternPack,
   Mes_SCA_PatternInsertLine, Mes_SCA_PatternTrackInsertLine,
   Mes_SCA_PatternDeleteLine, Mes_SCA_PatternDeleteLine2, Mes_SCA_PatternTrackDeleteLine,
   Mes_SCA_PatternClearLine, Mes_SCA_PatternTrackClearLine,
   Mes_SCA_PatternSelectionClear, Mes_SCA_PatternSelectAll, Mes_SCA_PatternSelectAll2,
   Mes_SCA_PatternStepBack,
   Mes_SCA_PatternPlayTillUp,

   Mes_SCA_SampleLineLeft, Mes_SCA_SampleLineRight,
   Mes_SCA_SampleLineColumnLeft, Mes_SCA_SampleLineColumnRight,
   Mes_SCA_SampleLineBegin, Mes_SCA_SampleLineEnd,
   Mes_SCA_SampleTrackUp, Mes_SCA_SampleTrackDown,
   Mes_SCA_SampleTrackPageUp, Mes_SCA_SampleTrackPageDown,
   Mes_SCA_SampleTrackBegin, Mes_SCA_SampleTrackEnd,
   Mes_SCA_SampleFirstLineBegin, Mes_SCA_SampleLastLineEnd,
   Mes_SCA_SampleJumpToTest,
   Mes_SCA_SampleInsertLine, Mes_SCA_SampleInsertLine2,
   Mes_SCA_SampleDeleteLine, Mes_SCA_SampleDeleteLine2,
   Mes_SCA_SampleSelectionClear, Mes_SCA_SampleSelectionCut,
   Mes_SCA_SampleSelectAll, Mes_SCA_SampleSelectAll2,
   Mes_SCA_SampleToggle, Mes_SCA_SampleToggleT, Mes_SCA_SampleToggleN, Mes_SCA_SampleToggleE,
   Mes_SCA_SamplePlus, Mes_SCA_SamplePlus2, Mes_SCA_SamplePlus3,
   Mes_SCA_SampleMinus, Mes_SCA_SampleMinus2,
   Mes_SCA_SampleAcc, Mes_SCA_SampleClearSignOrAcc,

   Mes_SCA_OrnamentColumnLeft, Mes_SCA_OrnamentColumnRight,
   Mes_SCA_OrnamentColumnShownFirst, Mes_SCA_OrnamentColumnShownLast,
   Mes_SCA_OrnamentUp, Mes_SCA_OrnamentDown,
   Mes_SCA_OrnamentPageUp, Mes_SCA_OrnamentPageDown,
   Mes_SCA_OrnamentBegin, Mes_SCA_OrnamentBegin2, Mes_SCA_OrnamentEnd, Mes_SCA_OrnamentEnd2,
   Mes_SCA_OrnamentJumpToTest,
   Mes_SCA_OrnamentInsertLine, Mes_SCA_OrnamentInsertLine2,
   Mes_SCA_OrnamentDeleteLine, Mes_SCA_OrnamentDeleteLine2,
   Mes_SCA_OrnamentSelectionClear, Mes_SCA_OrnamentSelectionCut,
   Mes_SCA_OrnamentSelectAll, Mes_SCA_OrnamentSelectAll2,
   Mes_SCA_OrnamentToggle,
   Mes_SCA_OrnamentPlus, Mes_SCA_OrnamentPlus2, Mes_SCA_OrnamentPlus3,
   Mes_SCA_OrnamentMinus, Mes_SCA_OrnamentMinus2
   );

 //Default shortcuts of each action
 DefaultShortcuts: TShortcuts = (
   VK_N or scCtrl, //SCA_FileNew
   VK_O or scCtrl, //SCA_FileOpen
   VK_W or scCtrl, //SCA_FileClose
   VK_F4 or scCtrl, //SCA_FileClose2
   VK_S or scCtrl, //SCA_FileSave
   0, //SCA_FileSaveAs,
   0, //SCA_FileExportSNDH
   0, //SCA_FileExportZX
   0, //SCA_FileExportPSG
   0, //SCA_FileExportWAV
   0, //SCA_FileOptions
   0, //SCA_FileExit
   VK_ESCAPE, //SCA_PlayStop
   VK_F5, //SCA_PlayPlay
   VK_F6, //SCA_PlayFromStart
   VK_F7, //SCA_PlayPattern
   VK_F8, //SCA_PlayPatternFromStart
   VK_L or scCtrl, //SCA_PlayToggleLoop
   VK_L or scCtrl or scAlt, //SCA_PlayToggleLoopAll
   VK_M or scCtrl, //SCA_PlayToggleSamples
   VK_BACK or scAlt, //SCA_EditUndo
   VK_RETURN or scAlt, //SCA_EditRedo
   VK_X or scCtrl, //SCA_EditCut
   VK_C or scCtrl, //SCA_EditCopy
   VK_V or scCtrl, //SCA_EditPaste
   VK_T or scCtrl, //SCA_EditTracksManager
   VK_T or scCtrl or scAlt, //SCA_EditGlobalTransposition
   0, //SCA_WindowCascade
   0, //SCA_WindowTileH
   0, //SCA_WindowTileV
   0, //SCA_WindowMaximized
   //  0, //SCA_WindowMinAll
   //  0, //SCA_WindowArrAll
   0, //SCA_WindowFind
   VK_F6 or scCtrl, //SCA_WindowNext
   VK_TAB or scCtrl, //SCA_WindowNext2
   VK_F6 or scCtrl or scShift, //SCA_WindowPrev
   VK_TAB or scCtrl or scShift, //SCA_WindowPrev2
   0, //SCA_WindowCloseAll
   0, //SCA_HelpAbout
   VK_F1, //SCA_HelpGuide
   0, //SCA_HelpManual

   VK_C or scCtrl or scAlt, //SCA_ChipType
   VK_A or scCtrl or scAlt, //SCA_ChipChans
   0, //SCA_VolumeUp
   0, //SCA_VolumeDown
   VK_R or scCtrl, //SCA_EditorAutoStep
   VK_E or scCtrl, //SCA_EditorAutoEnv
   VK_E or scCtrl or scAlt, //SCA_EditorAutoEnvStd
   VK_P or scCtrl, //SCA_EditorAutoPrms
   VK_M or scCtrl or scAlt, //SCA_MidiToggle
   0, //SCA_MidiVolume,

   VK_1 or scAlt, //SCA_Octave1
   VK_2 or scAlt, //SCA_Octave2
   VK_3 or scAlt, //SCA_Octave3
   VK_4 or scAlt, //SCA_Octave4
   VK_5 or scAlt, //SCA_Octave5
   VK_6 or scAlt, //SCA_Octave6
   VK_7 or scAlt, //SCA_Octave7
   VK_8 or scAlt, //SCA_Octave8

   VK_END, //SCA_PosListLastPos
   VK_L, //SCA_PosListSetLoop
   VK_INSERT, //SCA_PosListAdd
   0, //SCA_PosListDup
   0, //SCA_PosListClone
   VK_DELETE, //SCA_PosListDelete
   0, //Mes_SCA_PosListPatLens
   0, //Mes_SCA_PosListRenumPats
   VK_V or scCtrl or scAlt, //SCA_PosListMerge,
   VK_A or scCtrl, //SCA_PosListSelectAll
   VK_NUMPAD5 or scCtrl, //SCA_PosListSelectAll2
   VK_OEM_3 {'`'}, //SCA_PosListJumpToEditor

   VK_PRIOR, //SCA_PatLenStepInc
   VK_NEXT, //SCA_PatLenStepDec

   VK_LEFT, //SCA_TestLineLeft
   VK_RIGHT, //SCA_TestLineRight
   VK_LEFT or scCtrl, //SCA_TestLineColumnLeft
   VK_RIGHT or scCtrl, //SCA_TestLineColumnRight
   VK_HOME, //SCA_TestLineBegin
   VK_END, //SCA_TestLineEnd
   VK_OEM_3 {'`'}, //SCA_TestLineJumpToEditor
   VK_DELETE, //SCA_TestLineSelectionClear
   VK_DELETE or scShift, //SCA_TestLineSelectionCut
   VK_A or scCtrl, //SCA_TestLineSelectAll
   VK_NUMPAD5 or scCtrl, //SCA_TestLineSelectAll2,

   VK_LEFT, //SCA_PatternLineLeft
   VK_RIGHT, //SCA_PatternLineRight
   VK_LEFT or scCtrl, //SCA_PatternLineColumnLeft
   VK_RIGHT or scCtrl, //SCA_PatternLineColumnRight
   VK_HOME, //SCA_PatternLineBegin
   VK_END, //SCA_PatternLineEnd
   VK_UP, //SCA_PatternTrackUp
   VK_DOWN, //SCA_PatternTrackDown
   VK_UP or scAlt, //SCA_PatternTrackStepUp
   VK_DOWN or scAlt, //SCA_PatternTrackStepDown
   VK_PRIOR, //SCA_PatternTrackPageUp
   VK_NEXT, //SCA_PatternTrackPageDown
   VK_PRIOR or scCtrl, //SCA_PatternTrackBegin
   VK_NEXT or scCtrl, //SCA_PatternTrackEnd
   VK_F9, //SCA_PatternJumpQuarter1
   VK_F10, //SCA_PatternJumpQuarter2
   VK_F11, //SCA_PatternJumpQuarter3
   VK_F12, //SCA_PatternJumpQuarter4
   VK_HOME or scCtrl, //SCA_PatternFirstLineBegin
   VK_END or scCtrl, //SCA_PatternLastLineEnd
   VK_OEM_3 {'`'}, //SCA_PatternJumpToPosList
   VK_SPACE, //SCA_PatternAutoStep
   VK_NUMPAD0, //SCA_PatternAutoEnv
   0, //SCA_PatternAutoPrms
   VK_INSERT or scCtrl, //SCA_PatternCopy
   VK_DELETE or scShift, //SCA_PatternCut
   VK_INSERT or scShift, //SCA_PatternPaste
   VK_V or scCtrl or scAlt, //SCA_PatternMerge
   VK_ADD, //SCA_PatternTransposeUp1
   VK_SUBTRACT, //SCA_PatternTransposeDown1
   0, //SCA_PatternTransposeUp3
   0, //SCA_PatternTransposeDown3
   0, //SCA_PatternTransposeUp5
   0, //SCA_PatternTransposeDown5
   VK_ADD or scCtrl, //SCA_PatternTransposeUp12
   VK_SUBTRACT or scCtrl, //SCA_PatternTransposeDown12
   VK_LEFT + scAlt, //SCA_PatternSwapLeft
   VK_RIGHT + scAlt, //SCA_PatternSwapRight
   VK_0 or scCtrl, //SCA_PatternSetAutoStep0
   VK_1 or scCtrl, //SCA_PatternSetAutoStep1
   VK_2 or scCtrl, //SCA_PatternSetAutoStep2,
   VK_3 or scCtrl, //SCA_PatternSetAutoStep3
   VK_4 or scCtrl, //SCA_PatternSetAutoStep4
   VK_5 or scCtrl, //SCA_PatternSetAutoStep5
   VK_6 or scCtrl, //SCA_PatternSetAutoStep6
   VK_7 or scCtrl, //SCA_PatternSetAutoStep7
   VK_8 or scCtrl, //SCA_PatternSetAutoStep8
   VK_9 or scCtrl, //SCA_PatternSetAutoStep9
   VK_MULTIPLY, //SCA_PatternExpand
   VK_DIVIDE, //SCA_PatternShrink
   0, //SCA_PatternSplit
   0, //SCA_PatternPack
   VK_I or scCtrl, //SCA_PatternInsertLine
   VK_INSERT, //SCA_PatternTrackInsertLine
   VK_BACK or scCtrl, //SCA_PatternDeleteLine
   VK_Y or scCtrl, //SCA_PatternDeleteLine2
   VK_BACK, //SCA_PatternTrackDeleteLine
   VK_DELETE or scCtrl, //SCA_PatternClearLine
   0, //SCA_PatternTrackClearLine
   VK_DELETE, //SCA_PatternSelectionClear
   VK_A or scCtrl, //SCA_PatternSelectAll
   VK_NUMPAD5 or scCtrl, //SCA_PatternSelectAll2
   VK_BACK or scShift, //SCA_PatternStepBack
   VK_RETURN, //SCA_PatternPlayTillUp

   VK_LEFT, //SCA_SampleLineLeft
   VK_RIGHT, //SCA_SampleLineRight
   VK_LEFT or scCtrl, //SCA_SampleLineColumnLeft
   VK_RIGHT or scCtrl, //SCA_SampleLineColumnRight
   VK_HOME, //SCA_SampleLineBegin
   VK_END, //SCA_SampleLineEnd
   VK_UP, //SCA_SampleTrackUp
   VK_DOWN, //SCA_SampleTrackDown
   VK_PRIOR, //SCA_SampleTrackPageUp
   VK_NEXT, //SCA_SampleTrackPageDown
   VK_PRIOR or scCtrl, //SCA_SampleTrackBegin
   VK_NEXT or scCtrl, //SCA_SampleTrackEnd
   VK_HOME or scCtrl, //SCA_SampleFirstLineBegin
   VK_END or scCtrl, //SCA_SampleLastLineEnd
   VK_OEM_3 {'`'}, //SCA_SampleJumpToTest,
   VK_INSERT, //SCA_SampleInsertLine
   VK_I or scCtrl, //SCA_SampleInsertLine2
   VK_BACK, //SCA_SampleDeleteLine
   VK_Y or scCtrl, //SCA_SampleDeleteLine2
   VK_DELETE, //SCA_SampleSelectionClear
   VK_DELETE or scShift, //SCA_SampleSelectionCut
   VK_A or scCtrl, //SCA_SampleSelectAll
   VK_NUMPAD5 or scCtrl, //Mes_SCA_SampleSelectAll2
   VK_SPACE, //SCA_SampleToggle
   VK_T, //SCA_SampleToggleT
   VK_N, //SCA_SampleToggleN
   VK_M, //SCA_SampleToggleE
   VK_OEM_PLUS, //SCA_SamplePlus
   VK_OEM_PLUS or scShift, //SCA_SamplePlus2
   VK_ADD, //SCA_SamplePlus3
   VK_OEM_MINUS, //SCA_SampleMinus
   VK_SUBTRACT, //SCA_SampleMinus2,
   VK_6 or scShift, //SCA_SampleAcc
   VK_OEM_MINUS or scShift, //SCA_SampleClearSignOrAcc

   VK_LEFT, //SCA_OrnamentColumnLeft
   VK_RIGHT, //SCA_OrnamentColumnRight
   VK_HOME, //SCA_OrnamentColumnShownFirst
   VK_END, //SCA_OrnamentColumnShownLast
   VK_UP, //SCA_OrnamentUp
   VK_DOWN, //SCA_OrnamentDown
   VK_PRIOR, //SCA_OrnamentPageUp
   VK_NEXT, //SCA_OrnamentPageDown
   VK_HOME or scCtrl, //SCA_OrnamentBegin
   VK_PRIOR or scCtrl, //SCA_OrnamentBegin2
   VK_END or scCtrl, //SCA_OrnamentEnd
   VK_NEXT or scCtrl, //SCA_OrnamentEnd2
   VK_OEM_3 {'`'}, //SCA_OrnamentJumpToTest
   VK_INSERT, //SCA_OrnamentInsertLine
   VK_I or scCtrl, //SCA_OrnamentInsertLine2
   VK_BACK, //SCA_OrnamentDeleteLine
   VK_Y or scCtrl, //SCA_OrnamentDeleteLine2
   VK_DELETE, //SCA_OrnamentSelectionClear
   VK_DELETE or scShift, //SCA_OrnamentSelectionCut
   VK_A or scCtrl, //SCA_OrnamentSelectAll
   VK_NUMPAD5 or scCtrl, //SCA_OrnamentSelectAll2
   VK_SPACE, //SCA_OrnamentToggle
   VK_OEM_PLUS, //SCA_OrnamentPlus
   VK_OEM_PLUS or scShift, //SCA_OrnamentPlus2
   VK_ADD, //SCA_OrnamentPlus3,
   VK_OEM_MINUS, //SCA_OrnamentMinus
   VK_SUBTRACT //SCA_OrnamentMinus2
   );

 //Sets of actions by source
 ShortcutBySource: array[TShortcutSources] of TShortcutActionsSet = (
   [SCA_FileNew..SCA_Octave8],
   [SCA_PosListEnd..SCA_PosListJumpToEditor],
   [SCA_PatLenStepInc..SCA_PatLenStepDec],
   [SCA_TestLineLeft..SCA_TestLineSelectAll2],
   [SCA_PatternLineLeft..SCA_PatternPlayTillUp],
   [SCA_SampleLineLeft..SCA_SampleClearSignOrAcc],
   [SCA_OrnamentColumnLeft..SCA_OrnamentMinus2]
   );

 //Sets of cursor moving actions by source
 ShortcutCursorBySource: array[TShortcutSources] of TShortcutActionsSet = (
   [], [SCA_PosListEnd], [],
   [SCA_TestLineLeft..SCA_TestLineEnd],
   [SCA_PatternLineLeft..SCA_PatternLastLineEnd],
   [SCA_SampleLineLeft..SCA_SampleLastLineEnd],
   [SCA_OrnamentColumnLeft..SCA_OrnamentEnd2]
   );

var
 //Custom shortcuts storage
 CustomShortcuts: TShortcuts;
 CustomShortcutsSorted: TShortcutsSorted;

type
 //We want use TypeInfo and GetEnumName, so enumeration
 //mast start with 0 and no gaps allowed.
 //So, need correct by -3 to get real note index
 TNoteKeyCodes = (
   NK_NO,
   NK_RELEASE,
   NK_EMPTY,
   NK_DO, //0 after correction
   NK_DODiesis,
   NK_RE,
   NK_REDiesis,
   NK_MI,
   NK_FA,
   NK_FADiesis,
   NK_SOL,
   NK_SOLDiesis,
   NK_LA,
   NK_LADiesis,
   NK_SI,
   NK_DO2,
   NK_DODiesis2,
   NK_RE2,
   NK_REDiesis2,
   NK_MI2,
   NK_FA2,
   NK_FADiesis2,
   NK_SOL2,
   NK_SOLDiesis2,
   NK_LA2,
   NK_LADiesis2,
   NK_SI2,
   NK_DO3,
   NK_DODiesis3,
   NK_RE3,
   NK_REDiesis3,
   NK_MI3,
   NK_FA3,
   NK_FADiesis3,
   NK_SOL3,
   NK_OCTAVE1,
   NK_OCTAVE2,
   NK_OCTAVE3,
   NK_OCTAVE4,
   NK_OCTAVE5,
   NK_OCTAVE6,
   NK_OCTAVE7,
   NK_OCTAVE8
   );

const
 //Text descritions of each note key code
 NoteKeyCodesDesc: array[TNoteKeyCodes] of string = (
   Mes_NK_NO,
   Mes_NK_RELEASE,
   Mes_NK_EMPTY,
   Mes_NK_DO,
   Mes_NK_DODiesis,
   Mes_NK_RE,
   Mes_NK_REDiesis,
   Mes_NK_MI,
   Mes_NK_FA,
   Mes_NK_FADiesis,
   Mes_NK_SOL,
   Mes_NK_SOLDiesis,
   Mes_NK_LA,
   Mes_NK_LADiesis,
   Mes_NK_SI,
   Mes_NK_DO2,
   Mes_NK_DODiesis2,
   Mes_NK_RE2,
   Mes_NK_REDiesis2,
   Mes_NK_MI2,
   Mes_NK_FA2,
   Mes_NK_FADiesis2,
   Mes_NK_SOL2,
   Mes_NK_SOLDiesis2,
   Mes_NK_LA2,
   Mes_NK_LADiesis2,
   Mes_NK_SI2,
   Mes_NK_DO3,
   Mes_NK_DODiesis3,
   Mes_NK_RE3,
   Mes_NK_REDiesis3,
   Mes_NK_MI3,
   Mes_NK_FA3,
   Mes_NK_FADiesis3,
   Mes_NK_SOL3,
   Mes_NK_OCTAVE1,
   Mes_NK_OCTAVE2,
   Mes_NK_OCTAVE3,
   Mes_NK_OCTAVE4,
   Mes_NK_OCTAVE5,
   Mes_NK_OCTAVE6,
   Mes_NK_OCTAVE7,
   Mes_NK_OCTAVE8
   );


var
 //Note cell codes for each key code (NK_NO if unused)
 NoteKeys: array[0..255] of shortint;

procedure ShortcutsSort;
procedure ShortcutsSetDefault;
function GetShortcutAction(Src: TShortcutSources; Key: word;
 Shift: TShiftState; out Act: TShortcutActions): boolean;
procedure NoteKeysSetDefault;
function ShortcutActionTextInfo(Act: TShortcutActions): string;

//customized description for shortcut action
function ShortcutActionCustomInfo(Act: TShortcutActions;
 const Info: string = ''; const Pre: string = ''): string;

function NotKeyTextInfo(NK: byte): string;
function NoteKeyFindFirst(NKCode: TNoteKeyCodes): integer;

//customized description for first found note key code
function NotKeyCustomInfo(NKCode: TNoteKeyCodes;
 const Info: string = ''; const Pre: string = ''): string;

implementation

procedure ShortcutsSort;
var
 Src: TShortcutSources;
 Act: TShortcutActions;
 Lens: array[TShortcutSources] of integer;

 procedure QuickSort(L, R: integer);
 var
   I, J, P: integer;
   N: TShortcutRecord;
 begin
   repeat
     I := L;
     J := R;
     P := (L + R) shr 1;
     repeat
       while CustomShortcutsSorted[Src][I].Shortcut <
         CustomShortcutsSorted[Src][P].Shortcut do Inc(I);
       while CustomShortcutsSorted[Src][J].Shortcut >
         CustomShortcutsSorted[Src][P].Shortcut do Dec(J);
       if I <= J then
        begin
         N := CustomShortcutsSorted[Src][J];
         CustomShortcutsSorted[Src][J] := CustomShortcutsSorted[Src][I];
         CustomShortcutsSorted[Src][I] := N;
         if P = I then
           P := J
         else if P = J then
           P := I;
         Inc(I);
         Dec(J);
        end;
     until I > J;
     if L < J then QuickSort(L, J);
     L := I;
   until I >= R;
 end;

begin
 for Src := Low(TShortcutSources) to High(TShortcutSources) do
  begin
   SetLength(CustomShortcutsSorted[Src], Length(CustomShortcuts));
   Lens[Src] := 0;
  end;

 for Act := Low(TShortcutActions) to High(TShortcutActions) do
  begin
   for Src := Low(TShortcutSources) to High(TShortcutSources) do
     if (Act in ShortcutBySource[Src]) and (CustomShortcuts[Act] <> 0) then
      begin
       with CustomShortcutsSorted[Src][Lens[Src]] do
        begin
         Action := Act;
         Shortcut := CustomShortcuts[Act];
        end;
       Inc(Lens[Src]);
       Break;
      end;
  end;

 for Src := Low(TShortcutSources) to High(TShortcutSources) do
  begin
   SetLength(CustomShortcutsSorted[Src], Lens[Src]);
   if Lens[Src] > 1 then
     QuickSort(0, Lens[Src] - 1);
  end;
end;

procedure ShortcutsSetDefault;
begin
 CustomShortcuts := DefaultShortcuts;
end;

function GetShortcutAction(Src: TShortcutSources; Key: word;
 Shift: TShiftState; out Act: TShortcutActions): boolean;
var
 Sc: TShortCut;

 function BinSearch: integer;
 var
   left, right, mid: integer;
   midSc: TShortCut;
 begin
   left := 0;
   right := Length(CustomShortcutsSorted[Src]) - 1;
   while left <= right do
    begin
     mid := left + (right - left) shr 1;
     midSc := CustomShortcutsSorted[Src][mid].Shortcut;
     if midSc = Sc then
       Exit(mid)
     else if midSc < Sc then
       left := mid + 1
     else
       right := mid - 1;
    end;
   Exit(-1);
 end;

var
 Idx: integer;
begin
 Sc := KeyToShortCut(Key, Shift);
 Idx := BinSearch;
 if (Idx < 0) and (ssShift in Shift) then
  //remove ssShift and check for Cursor control keys
  begin
   Sc := KeyToShortCut(Key, Shift - [ssShift]);
   Idx := BinSearch;
   if (Idx > 0) and not (CustomShortcutsSorted[Src][Idx].Action in
     ShortcutCursorBySource[Src]) then
     Idx := -1;
  end;
 Result := Idx >= 0;
 if Result then
   Act := CustomShortcutsSorted[Src][Idx].Action;
end;

procedure NoteKeysSetDefault;
begin
 FillChar(NoteKeys, SizeOf(NoteKeys), 0);
 NoteKeys[VK_A] := shortint(NK_RELEASE);
 NoteKeys[VK_K] := shortint(NK_EMPTY);
 NoteKeys[VK_Z] := shortint(NK_DO);
 NoteKeys[VK_S] := shortint(NK_DODiesis);
 NoteKeys[VK_X] := shortint(NK_RE);
 NoteKeys[VK_D] := shortint(NK_REDiesis);
 NoteKeys[VK_C] := shortint(NK_MI);
 NoteKeys[VK_V] := shortint(NK_FA);
 NoteKeys[VK_G] := shortint(NK_FADiesis);
 NoteKeys[VK_B] := shortint(NK_SOL);
 NoteKeys[VK_H] := shortint(NK_SOLDiesis);
 NoteKeys[VK_N] := shortint(NK_LA);
 NoteKeys[VK_J] := shortint(NK_LADiesis);
 NoteKeys[VK_M] := shortint(NK_SI);
 NoteKeys[VK_OEM_COMMA] := shortint(NK_DO2);
 NoteKeys[VK_L] := shortint(NK_DODiesis2);
 NoteKeys[VK_OEM_PERIOD] := shortint(NK_RE2);
 NoteKeys[VK_OEM_1 {;}] := shortint(NK_REDiesis2);
 NoteKeys[VK_OEM_2 {/}] := shortint(NK_MI2);
 NoteKeys[VK_Q] := shortint(NK_DO2);
 NoteKeys[VK_2] := shortint(NK_DODiesis2);
 NoteKeys[VK_W] := shortint(NK_RE2);
 NoteKeys[VK_3] := shortint(NK_REDiesis2);
 NoteKeys[VK_E] := shortint(NK_MI2);
 NoteKeys[VK_R] := shortint(NK_FA2);
 NoteKeys[VK_5] := shortint(NK_FADiesis2);
 NoteKeys[VK_T] := shortint(NK_SOL2);
 NoteKeys[VK_6] := shortint(NK_SOLDiesis2);
 NoteKeys[VK_Y] := shortint(NK_LA2);
 NoteKeys[VK_7] := shortint(NK_LADiesis2);
 NoteKeys[VK_U] := shortint(NK_SI2);
 NoteKeys[VK_I] := shortint(NK_DO3);
 NoteKeys[VK_9] := shortint(NK_DODiesis3);
 NoteKeys[VK_O] := shortint(NK_RE3);
 NoteKeys[VK_0] := shortint(NK_REDiesis3);
 NoteKeys[VK_P] := shortint(NK_MI3);
 NoteKeys[VK_OEM_4 {[}] := shortint(NK_FA3);
 NoteKeys[VK_OEM_PLUS {=}] := shortint(NK_FADiesis3);
 NoteKeys[VK_OEM_6 {]}] := shortint(NK_SOL3);
 NoteKeys[VK_NUMPAD1] := shortint(NK_OCTAVE1);
 NoteKeys[VK_NUMPAD2] := shortint(NK_OCTAVE2);
 NoteKeys[VK_NUMPAD3] := shortint(NK_OCTAVE3);
 NoteKeys[VK_NUMPAD4] := shortint(NK_OCTAVE4);
 NoteKeys[VK_NUMPAD5] := shortint(NK_OCTAVE5);
 NoteKeys[VK_NUMPAD6] := shortint(NK_OCTAVE6);
 NoteKeys[VK_NUMPAD7] := shortint(NK_OCTAVE7);
 NoteKeys[VK_NUMPAD8] := shortint(NK_OCTAVE8);
end;

function ShortcutActionTextInfo(Act: TShortcutActions): string;
var
 scs: TShortcutSources;
begin
 Result := '';
 for scs := Low(TShortcutSources) to High(TShortcutSources) do
   if Act in ShortcutBySource[scs] then
    begin
     Result := ShortcutSourcesDesc[scs];
     break;
    end;
 Result := ShortcutActionsDesc[Act] + ' (' + Result + ')';
end;

function ShortcutActionCustomInfo(Act: TShortcutActions;
 const Info: string = ''; const Pre: string = ''): string;
var
 SC: TShortCut;
begin
 SC := CustomShortcuts[Act];
 if SC <> 0 then
  begin
   Result := {%H-}ShortCutToText{Raw}(SC);
   if Info <> '' then
     Result := Pre + Result + ' ' + Mes_For + ' ' + Info;
  end
 else
   Result := '';
end;

function NotKeyTextInfo(NK: byte): string;
begin
 Result := '"' + {%H-}ShortCutToText{Raw}(NK) + '" ' + Mes_For + ' "' +
   NoteKeyCodesDesc[TNoteKeyCodes(NoteKeys[NK])] + '"';
end;

function NoteKeyFindFirst(NKCode: TNoteKeyCodes): integer;
var
 i: integer;
begin
 for i := 0 to 255 do
   if NoteKeys[i] = shortint(NKCode) then
     Exit(i);
 Result := -1;
end;

function NotKeyCustomInfo(NKCode: TNoteKeyCodes;
 const Info: string = ''; const Pre: string = ''): string;
var
 NK: integer;
begin
 NK := NoteKeyFindFirst(NKCode);
 if NK >= 0 then
  begin
   Result := {%H-}ShortCutToText{Raw}(NK);
   if Info <> '' then
     Result := Pre + Result + ' ' + Mes_For + ' ' + Info;
  end
 else
   Result := '';
end;

initialization

 ShortcutsSetDefault;
 ShortcutsSort;
 NoteKeysSetDefault;

end.
