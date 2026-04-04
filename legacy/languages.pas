{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit Languages;

{$mode objfpc}{$H+}

interface

resourcestring
 Mes_WinVersion = 'Supported in Windows version only';
 Mes_CantCompileTooBig =
   'Cannot compile module due 65536 size limit for PT3-modules. You can save it in text yet.';
 Mes_SizeTooBig = 'Size of module with player exceeds 65536 RAM size.';
 Mes_CantExport = 'Cannot export';
 Mes_HobetaSizeTooBig = 'Size of hobeta file exceeds 255 sectors.';
 Mes_CantOpen = 'Can''t open';
 Mes_FIR = 'FIR';
 Mes_PTS = 'pts';
 Mes_Averager = 'Averager';
 Mes_NewMod = 'new module';

 Mes_PackNoNeed = 'No reason to pack empty pattern.';
 Mes_PackCant = 'Can''t pack it, sorry...';

 Mes_SplitCant = 'To split pattern move cursor to 2nd line or further.';
 Mes_SplitNoRoom = 'No free pattern to split this one.';

 Mes_FindCapt = 'Find module';
 Mes_FindIntro = 'Please type in some information';
 Mes_FindCont = 'Continue searching?';

 Mes_ConvInProgress = 'Conversion in progress, try later...';
 Mes_ConvTo = 'Converting to';
 Mes_ConvAborted = 'Converted partially (aborted by user)';

 Mes_IceErr = 'Error while packing';
 Mes_IceErrEmpty = 'empty archive.';
 Mes_IceErrUnpkbl = 'too many unpackable bytes found before source offset';
 Mes_IceErrBufSmall = 'destination buffer too small, error at source offset';

 Mes_File = 'File';
 Mes_ExistOvr = 'exists. Overwrite?';

 Mes_ExpPatNotice1 = 'To expand pattern size twice original size must be';
 Mes_ExpPatNotice2 = 'or smaller.';
 Mes_ShrPatNotice = 'To shrink pattern size twice original size must be 2 or bigger.';

 Mes_UndoThisOp = 'This operation';
 Mes_UndoCant = 'cannot be undo. Are you sure you want to continue?';

 Mes_SelectedPatLen = 'Selected patterns length';
 Mes_InputPatLen = 'Input length from 1 to 256:';

 Mes_PatternsInOrder = 'Nothing to do: patterns already in order';
 Mes_PosLstNoRoomToPaste = 'No room in position list to paste selected patterns';

 Mes_HintWhenEdit = 'when editing tracks';
 Mes_HintVolCtrl = 'Volume control';
 Mes_HintMouseWheel = 'Mouse Wheel';
 Mes_HintTglAutStp = 'Toggle autostep';
 Mes_HintTglAutEnv = 'Toggle autoenvelope';
 Mes_HintTglPrm = 'Toggle auto fill parameters while inputting note';
 Mes_HintPatLen1 = 'Pattern length (Up/Down to change by 1';
 Mes_HintPatLen2 = 'by highlight step)';

 Mes_HintPatEnvPAsNote1 = 'Note keys when envelope period as note.';
 Mes_HintPatEnvPAsNote2 = 'Hold Ctrl+Shift to reach 0th octave.';
 Mes_HintPatEnvPUsual = 'Envelope generator period (0-FFFF).';
 Mes_HintPatEnvPCommon = 'Set envelope type to 1-E.';
 Mes_HintPatNsP = 'Noise generator period base (0-1F).';
 Mes_HintPatNt1 = 'Note (from C-1 to B-8).';
 Mes_HintPatNt2 = 'Num1-8 (by default) for octave.';
 Mes_HintPatNt3 = 'R-- (release).';
 Mes_HintPatSam1 = 'Sample (1-9,A-V). Double click to edit.';
 Mes_HintPatSam2 = 'Use with Note or R--.';
 Mes_HintPatEnvT1 = 'Envelope type (1-E) or envelope off (F).';
 Mes_HintPatEnvT2 = '0th ornament can be set only with 1-F.';
 Mes_HintPatOrn1 = 'Ornament (0-F). Double click to edit.';
 Mes_HintPatOrn2 = '0th can be set only with envtype or off (1-F).';
 Mes_HintPatVol = 'Volume (1-F). Use R-- instead of 0.';
 Mes_HintPatSpecCmd1_1 = 'Spec. command (1/2 tone down/up,';
 Mes_HintPatSpecCmd1_2 = '3 porto, 4 sam offset, 5 orn offset,';
 Mes_HintPatSpecCmd1_3 = '6 vibrato, 9/A env down/up, B speed).';
 Mes_HintPatSpecCmd2_1 = 'Delay for spec. commands 1-3/9-A';
 Mes_HintPatSpecCmd2_2 = '(1-F for change period, 0 to stop).';
 Mes_HintPatSpecCmd3_1 = 'High digit of parameter (0-F)';
 Mes_HintPatSpecCmd3_2 = 'for spec. commands 1-5/9-B';
 Mes_HintPatSpecCmd3_3 = 'or 1st parameter for command 6';
 Mes_HintPatSpecCmd3_4 = '(1-F for sound on period, 0 to stop).';
 Mes_HintPatSpecCmd4_1 = 'Low digit of parameter (0-F)';
 Mes_HintPatSpecCmd4_2 = 'for spec. commands 1-5/9-B';
 Mes_HintPatSpecCmd4_3 = 'or 2nd parameter for command 6';
 Mes_HintPatSpecCmd4_4 = '(1-F for sound off period,';
 Mes_HintPatSpecCmd4_5 = '0 to stop after sound on period).';
 Mes_HintPatAutStp = 'autostep.';
 Mes_HintPatAutEnv = 'autoenv.';
 Mes_HintPatAutPrm = 'autoparams.';
 Mes_HintPatAutStpVal = 'Ctrl+0-9 (by default) for autostep value.';

 Mes_HintSamT = 'Tone generator mask (T to turn on).';
 Mes_HintSamN = 'Noise generator mask (N to turn on).';
 Mes_HintSamE = 'Envelope using (E for enabling).';
 Mes_HintSamTShiftAsNote1 = 'Note of final tone period for base in test line';
 Mes_HintSamTShiftAsNote2 = '(= exact, >< no more than a quarter tone).';
 Mes_HintSamTShiftS = 'Sign of shift for tone generator period.';
 Mes_HintSamTShift = 'Shift for tone generator period (-FFF...+FFF).';
 Mes_HintSamTShiftAcc = 'Tone slide mark (^ to use, _ to non).';
 Mes_HintSamNShiftS = 'Sign of shift for noise/envelope generator period.';
 Mes_HintSamNShift1 = 'Shift for noise/envelope period (-10...+F).';
 Mes_HintSamNShift2 = 'For noise if mask is N, for envelope otherwise.';
 Mes_HintSamNShiftAbs1 = 'Absolute 5-bit value of noise/envelope shift (0-1F).';
 Mes_HintSamNShiftAbs2 = 'Can be treated as final value';
 Mes_HintSamNShiftAbs3 = 'if used with 0 noise base in tracks.';
 Mes_HintSamNShiftAcc = 'Noise/envelope slide mark (^ to use, _ to non).';
 Mes_HintSamAmp1 = 'Absolute amplitude (1-F).';
 Mes_HintSamAmp2 = 'Actual one depends on sample volume.';
 Mes_HintSamVolAcc1 = 'Sample volume slide mark';
 Mes_HintSamVolAcc2 = '(+ to increase, - to decrease, _ to keep).';
 Mes_HintSamVolAcc3 = 'Initially 0 (amplitude kept),';
 Mes_HintSamVolAcc4 = 'range -F...+F (from muted to maximized).';
 Mes_HintSamEnd1 = 'MMB or (MIDI) keyboard to edit,';
 Mes_HintSamEnd2 = 'RMB for menu or to draw amplitude.';
 Mes_HintSamEnd3 = 'RMB for menu, LMB to draw amplitude.';

 Mes_HintOrn1 = 'Either note keys in Ornament as notes mode,';
 Mes_HintOrn2 = 'or range from -96 to +96 in semitones.';
 Mes_HintOrn3 = 'Use -96 to get C-1 for any base note';
 Mes_HintOrn4 = '(useful for note independent drums, etc.).';

 Mes_LoadErrModNotFound = 'Module not found';
 Mes_LoadErrSyntax = 'Syntax error';
 Mes_LoadErrRange = 'Parameter out of range';
 Mes_LoadErrUnEnd = 'Unexpected end of file';
 Mes_LoadErrBadSam = 'Bad sample structure';
 Mes_LoadErrBadPat = 'Bad pattern structure';
 Mes_LoadErrLine = 'line';
 Mes_LoadErrCapt = 'Text module loader error';

 Mes_BadFileStruct = 'Bad file structure';
 Mes_ErrEmptySam = 'Error: empty sample';
 Mes_PT36TryTS = 'This PT 3.6 module can contain Turbo Sound data. Try to import?';

 Mes_ToneTblFor = 'Tone Table for';
 Mes_ToneTbl0 = '1.625 MHz (not recommended)';
 Mes_ToneTbl1 = '1.7734 MHz -1 Tone (original ZX Spectrum 128K)';
 Mes_ToneTbl2 = '1.75 MHz (xUSSR clones of ZX Spectrum)';
 Mes_ToneTbl3 = '1.625 MHz -1 Semitone (not recommended)';

 Mes_SaveOrn = 'Save ornament in text file';
 Mes_LoadOrn = 'Load ornament from text file';
 Mes_OrnNotFound = 'Ornament data not found';
 Mes_OrGenError = 'Plug-in communication error: cannot delete file.';

 Mes_SaveSam = 'Save sample in text file';
 Mes_LoadSam = 'Load sample from text file';
 Mes_SamNotFound = 'Sample data not found';

 Mes_SavePat = 'Save pattern in text file';
 Mes_LoadPat = 'Load pattern from text file';
 Mes_PatNotFound = 'Pattern data not found';

 Mes_TextFiles = 'Text files';
 Mes_AllFiles = 'All files';

 Mes_Edition = 'Edition';
 Mes_IsChangedSave = 'is changed. Save it now?';

 Mes_HintTestPat = 'Test line and Auto Parameters'' values';
 Mes_HintTestSam = 'Test line for sample';
 Mes_HintTestOrn = 'Test line for ornament';

 Mes_MidiHint1 = 'MIDI Keyboard';
 Mes_MidiHint2 = 'Waiting for MIDI input device appearance, click to switch off';
 Mes_MidiHint3 = 'Manually switched off, click to switch on or to start waiting';
 Mes_MidiHint4 = 'opened, click to toggle next or to switch off';

 Mes_AutParFull = 'Auto Parameters';
 Mes_AutParMid = 'AutoParams';
 Mes_AutParSmall = 'AutoPrms';

 Mes_ChanFull = 'Channel';
 Mes_ChanMid = 'Chan';

 Mes_No2ndChip = '2nd soundchip is disabled';

 Mes_WantCont = 'Do you want to continue with';
 Mes_Removeing = 'removing';
 Mes_Conflict = 'conflict';
 Mes_Conflicts = 'conflicts';
 Mes_And = 'and';
 Mes_Or = 'or';
 Mes_Ignoring = 'ignoring';
 Mes_Warning = 'warning';
 Mes_Warnings = 'warnings';

 Mes_Shortcut = 'Shortcut';
 Mes_DueConflict = 'cannot be selected due conflict with value inputting/control keys';
 Mes_ConflictWith = 'Conflict with';
 Mes_ConflictWithNote = 'Conflict with note key';
 Mes_SameWith = 'Same with';
 Mes_SameWithNote = 'Same with note key';

 Mes_NoteKeys = 'Note keys';

 Mes_ms = 'ms';
 Mes_For = 'for';

 Mes_CantInitDigSnd = 'Can''t initialize digital sound playback';

 //Shortcuts sources descriptions
 Mes_SCS_GlobalActions = 'Global shortcuts';
 Mes_SCS_PositionListEditor = 'Position list editor';
 Mes_SCS_PatternLengthEditor = 'Pattern length editor';
 Mes_SCS_TestLineEditor = 'Test line editor';
 Mes_SCS_PatternEditor = 'Pattern tracks editor';
 Mes_SCS_SampleEditor = 'Sample editor';
 Mes_SCS_OrnamentEditor = 'Ornament editor';

 //Shortcuts descriptions
 Mes_SCA_FileNew = 'Menu File->New';
 Mes_SCA_FileOpen = 'Menu File->Open';
 Mes_SCA_FileClose = 'Menu File->Close';
 Mes_SCA_FileClose2 = 'Menu File->Close alternative';
 Mes_SCA_FileSave = 'Menu File->Save';
 Mes_SCA_FileSaveAs = 'Menu File->Save As...';
 Mes_SCA_FileExportSNDH = 'Menu File->Exports->SNDH';
 Mes_SCA_FileExportZX = 'Menu File->Exports->ZX';
 Mes_SCA_FileExportPSG = 'Menu File->Exports->PSG';
 Mes_SCA_FileExportWAV = 'Menu File->Exports->WAV';
 Mes_SCA_FileOptions = 'Menu File->Options';
 Mes_SCA_FileExit = 'Menu File->Exit';
 Mes_SCA_PlayStop = 'Menu Play->Stop';
 Mes_SCA_PlayPlay = 'Menu Play->Play';
 Mes_SCA_PlayFromStart = 'Menu Play->Play from start';
 Mes_SCA_PlayPattern = 'Menu Play->Play patterm';
 Mes_SCA_PlayPatternFromStart = 'Menu Play->Play pattern from start';
 Mes_SCA_PlayToggleLoop = 'Menu Play->Toggle looping';
 Mes_SCA_PlayToggleLoopAll = 'Menu Play->Toggle looping all';
 Mes_SCA_PlayToggleSamples = 'Menu Play->Toggle samples';
 Mes_SCA_EditUndo = 'Menu Edit->Undo';
 Mes_SCA_EditRedo = 'Menu Edit->Redo';
 Mes_SCA_EditCut = 'Menu Edit->Cut';
 Mes_SCA_EditCopy = 'Menu Edit->Copy';
 Mes_SCA_EditPaste = 'Menu Edit->Paste';
 Mes_SCA_EditTracksManager = 'Menu Edit->Tracks manager';
 Mes_SCA_EditGlobalTransposition = 'Menu Edit->Global transposition';
 Mes_SCA_WindowCascade = 'Menu Window->Cascade';
 Mes_SCA_WindowTileH = 'Menu Window->Tile Horizontally';
 Mes_SCA_WindowTileV = 'Menu Window->Tile Vertically';
 Mes_SCA_WindowMaximized = 'Menu Window->Maximized';
 // Mes_SCA_WindowMinAll = 'Menu Window->Minimize All';
 // Mes_SCA_WindowArrAll = 'Menu Window->Arrange All';
 Mes_SCA_WindowFind = 'Menu Window->Find Module';
 Mes_SCA_WindowNext = 'Menu Window->Next';
 Mes_SCA_WindowNext2 = 'Menu Window->Next alternative';
 Mes_SCA_WindowPrev = 'Menu Window->Previous';
 Mes_SCA_WindowPrev2 = 'Menu Window->Previous alternative';
 Mes_SCA_WindowCloseAll = 'Menu Window->Close All';
 Mes_SCA_HelpAbout = 'Menu Help->About';
 Mes_SCA_HelpGuide = 'Menu Help->Quick guide';
 Mes_SCA_HelpManual = 'Menu Help->Manual';
 Mes_SCA_ChipType = 'Toggle chip type';
 Mes_SCA_ChipChans = 'Toggle chip channels';
 Mes_SCA_VolumeUp = 'Volume +';
 Mes_SCA_VolumeDown = 'Volume -';
 Mes_SCA_EditorAutoStep = 'Toggle auto step';
 Mes_SCA_EditorAutoEnv = 'Toggle auto envelope';
 Mes_SCA_EditorAutoEnvStd = 'Toggle envelope standard combinations';
 Mes_SCA_EditorAutoPrms = 'Toggle auto parameters';
 Mes_SCA_MidiToggle = 'Switch/toggle MIDI keyboards';
 Mes_SCA_MidiVolume = 'Use MIDI NoteOn''s volume';
 Mes_SCA_Octave1 = 'Select octave 1';
 Mes_SCA_Octave2 = 'Select octave 2';
 Mes_SCA_Octave3 = 'Select octave 3';
 Mes_SCA_Octave4 = 'Select octave 4';
 Mes_SCA_Octave5 = 'Select octave 5';
 Mes_SCA_Octave6 = 'Select octave 6';
 Mes_SCA_Octave7 = 'Select octave 7';
 Mes_SCA_Octave8 = 'Select octave 8';
 Mes_SCA_PosListEnd = 'Cursor to the end of list';
 Mes_SCA_PosListSetLoop = 'Mark position for looping';
 Mes_SCA_PosListAdd = 'Add positions';
 Mes_SCA_PosListDup = 'Duplicate positions';
 Mes_SCA_PosListClone = 'Clone positions';
 Mes_SCA_PosListDelete = 'Delete selected positions';
 Mes_SCA_PosListPatLens = 'Change patterns length';
 Mes_SCA_PosListRenumPats = 'Renumber patterns';
 Mes_SCA_PosListMerge = 'Merge from clipboard';
 Mes_SCA_PosListSelectAll = 'Select all';
 Mes_SCA_PosListSelectAll2 = 'Select all alternative';
 Mes_SCA_PosListJumpToEditor = 'Jump to pattern editor';
 Mes_SCA_PatLenStepInc = 'Increase by highlight step value';
 Mes_SCA_PatLenStepDec = 'Decrease by highlight step value';
 Mes_SCA_TestLineLeft = 'Cursor left';
 Mes_SCA_TestLineRight = 'Cursor right';
 Mes_SCA_TestLineColumnLeft = 'Cursor column left';
 Mes_SCA_TestLineColumnRight = 'Cursor column right';
 Mes_SCA_TestLineBegin = 'Cursor begin';
 Mes_SCA_TestLineEnd = 'Cursor end';
 Mes_SCA_TestLineJumpToEditor = 'Jump to associated editor';
 Mes_SCA_TestLineSelectionClear = 'Clear selection';
 Mes_SCA_TestLineSelectionCut = 'Cut selection to clipboard';
 Mes_SCA_TestLineSelectAll = 'Select all';
 Mes_SCA_TestLineSelectAll2 = 'Select all alternative';
 Mes_SCA_PatternLineLeft = 'Cursor left';
 Mes_SCA_PatternLineRight = 'Cursor right';
 Mes_SCA_PatternLineColumnLeft = 'Cursor column left';
 Mes_SCA_PatternLineColumnRight = 'Cursor column right';
 Mes_SCA_PatternLineBegin = 'Cursor line begin';
 Mes_SCA_PatternLineEnd = 'Cursor line end';
 Mes_SCA_PatternTrackUp = 'Cursor up';
 Mes_SCA_PatternTrackDown = 'Cursor down';
 Mes_SCA_PatternTrackStepUp = 'Cursor step up';
 Mes_SCA_PatternTrackStepDown = 'Cursor step down';
 Mes_SCA_PatternTrackPageUp = 'Cursor page up';
 Mes_SCA_PatternTrackPageDown = 'Cursor page down';
 Mes_SCA_PatternTrackBegin = 'Cursor track begin';
 Mes_SCA_PatternTrackEnd = 'Cursor track end';
 Mes_SCA_PatternJumpQuarter1 = 'Quick jump to 1st quarter';
 Mes_SCA_PatternJumpQuarter2 = 'Quick jump to 2nd quarter';
 Mes_SCA_PatternJumpQuarter3 = 'Quick jump to 3rd quarter';
 Mes_SCA_PatternJumpQuarter4 = 'Quick jump to 4th quarter';
 Mes_SCA_PatternFirstLineBegin = 'Cursor first line begin';
 Mes_SCA_PatternLastLineEnd = 'Cursor last line end';
 Mes_SCA_PatternJumpToPosList = 'Jump to position list';
 Mes_SCA_PatternAutoStep = 'Toggle auto step';
 Mes_SCA_PatternAutoEnv = 'Toggle auto envelope';
 Mes_SCA_PatternAutoPrms = 'Toggle auto parameters';
 Mes_SCA_PatternCopy = 'Copy selection to clipboard';
 Mes_SCA_PatternCut = 'Cut selection to clipboard';
 Mes_SCA_PatternPaste = 'Paste from clipboard';
 Mes_SCA_PatternMerge = 'Merge from clipboard';
 Mes_SCA_PatternTransposeUp1 = 'Transpose semitone up';
 Mes_SCA_PatternTransposeDown1 = 'Transpose semitone down';
 Mes_SCA_PatternTransposeUp3 = 'Transpose 3 semitones up';
 Mes_SCA_PatternTransposeDown3 = 'Transpose 3 semitones down';
 Mes_SCA_PatternTransposeUp5 = 'Transpose 5 semitones up';
 Mes_SCA_PatternTransposeDown5 = 'Transpose 5 semitones down';
 Mes_SCA_PatternTransposeUp12 = 'Transpose octave up';
 Mes_SCA_PatternTransposeDown12 = 'Transpose octave down';
 Mes_SCA_PatternSwapLeft = 'Swap channels left';
 Mes_SCA_PatternSwapRight = 'Swap channels right';
 Mes_SCA_PatternSetAutoStep0 = 'Set autostep to 0';
 Mes_SCA_PatternSetAutoStep1 = 'Set autostep to 1';
 Mes_SCA_PatternSetAutoStep2 = 'Set autostep to 2';
 Mes_SCA_PatternSetAutoStep3 = 'Set autostep to 3';
 Mes_SCA_PatternSetAutoStep4 = 'Set autostep to 4';
 Mes_SCA_PatternSetAutoStep5 = 'Set autostep to 5';
 Mes_SCA_PatternSetAutoStep6 = 'Set autostep to 6';
 Mes_SCA_PatternSetAutoStep7 = 'Set autostep to 7';
 Mes_SCA_PatternSetAutoStep8 = 'Set autostep to 8';
 Mes_SCA_PatternSetAutoStep9 = 'Set autostep to 9';
 Mes_SCA_PatternExpand = 'Expand pattern';
 Mes_SCA_PatternShrink = 'Shrink pattern';
 Mes_SCA_PatternSplit = 'Split pattern';
 Mes_SCA_PatternPack = 'Pack pattern';
 Mes_SCA_PatternInsertLine = 'Insert pattern line';
 Mes_SCA_PatternTrackInsertLine = 'Insert track line';
 Mes_SCA_PatternDeleteLine = 'Delete pattern line';
 Mes_SCA_PatternDeleteLine2 = 'Delete pattern line alternative';
 Mes_SCA_PatternTrackDeleteLine = 'Delete track line';
 Mes_SCA_PatternClearLine = 'Clear pattern line';
 Mes_SCA_PatternTrackClearLine = 'Clear track line';
 Mes_SCA_PatternSelectionClear = 'Clear selection';
 Mes_SCA_PatternSelectAll = 'Select all';
 Mes_SCA_PatternSelectAll2 = 'Select all alternative';
 Mes_SCA_PatternStepBack = 'Autostep backward';
 Mes_SCA_PatternPlayTillUp = 'Play till the key up';
 Mes_SCA_SampleLineLeft = 'Cursor left';
 Mes_SCA_SampleLineRight = 'Cursor right';
 Mes_SCA_SampleLineColumnLeft = 'Cursor column left';
 Mes_SCA_SampleLineColumnRight = 'Cursor column right';
 Mes_SCA_SampleLineBegin = 'Cursor line begin';
 Mes_SCA_SampleLineEnd = 'Cursor line end';
 Mes_SCA_SampleTrackUp = 'Cursor up';
 Mes_SCA_SampleTrackDown = 'Cursor down';
 Mes_SCA_SampleTrackPageUp = 'Cursor page up';
 Mes_SCA_SampleTrackPageDown = 'Cursor page down';
 Mes_SCA_SampleTrackBegin = 'Cursor track begin';
 Mes_SCA_SampleTrackEnd = 'Cursor track end';
 Mes_SCA_SampleFirstLineBegin = 'Cursor first line begin';
 Mes_SCA_SampleLastLineEnd = 'Cursor last line end';
 Mes_SCA_SampleJumpToTest = 'Jump to test line';
 Mes_SCA_SampleInsertLine = 'Insert sample line';
 Mes_SCA_SampleInsertLine2 = 'Insert sample line alternative';
 Mes_SCA_SampleDeleteLine = 'Delete sample line';
 Mes_SCA_SampleDeleteLine2 = 'Delete sample line alternative';
 Mes_SCA_SampleSelectionClear = 'Clear selection';
 Mes_SCA_SampleSelectionCut = 'Cut selection to clipboard';
 Mes_SCA_SampleSelectAll = 'Select all';
 Mes_SCA_SampleSelectAll2 = 'Select all alternative';
 Mes_SCA_SampleToggle = 'Toggle sign/value';
 Mes_SCA_SampleToggleT = 'Toggle tone mask';
 Mes_SCA_SampleToggleN = 'Toggle noise mask';
 Mes_SCA_SampleToggleE = 'Toggle envelope mask';
 Mes_SCA_SamplePlus = 'Set plus sign';
 Mes_SCA_SamplePlus2 = 'Set plus sign alternative';
 Mes_SCA_SamplePlus3 = 'Set plus sign alternative';
 Mes_SCA_SampleMinus = 'Set minus sign';
 Mes_SCA_SampleMinus2 = 'Set minus sign alternative';
 Mes_SCA_SampleAcc = 'Set accumulation marker';
 Mes_SCA_SampleClearSignOrAcc = 'Reset accumulation/sign';
 Mes_SCA_OrnamentColumnLeft = 'Cursor left';
 Mes_SCA_OrnamentColumnRight = 'Cursor right';
 Mes_SCA_OrnamentColumnShownFirst = 'Cursor to first shown column';
 Mes_SCA_OrnamentColumnShownLast = 'Cursor to last shown column';
 Mes_SCA_OrnamentUp = 'Cursor up';
 Mes_SCA_OrnamentDown = 'Cursor down';
 Mes_SCA_OrnamentPageUp = 'Cursor page up';
 Mes_SCA_OrnamentPageDown = 'Cursor page down';
 Mes_SCA_OrnamentBegin = 'Cursor to first value';
 Mes_SCA_OrnamentBegin2 = 'Cursor to first value alternative';
 Mes_SCA_OrnamentEnd = 'Cursor to last value';
 Mes_SCA_OrnamentEnd2 = 'Cursor to last value alternative';
 Mes_SCA_OrnamentJumpToTest = 'Jump to test line';
 Mes_SCA_OrnamentInsertLine = 'Insert ornament line';
 Mes_SCA_OrnamentInsertLine2 = 'Insert ornament line alternative';
 Mes_SCA_OrnamentDeleteLine = 'Delete ornament line';
 Mes_SCA_OrnamentDeleteLine2 = 'Delete ornament line alternative';
 Mes_SCA_OrnamentSelectionClear = 'Clear selection';
 Mes_SCA_OrnamentSelectionCut = 'Cut selection to clipboard';
 Mes_SCA_OrnamentSelectAll = 'Select all';
 Mes_SCA_OrnamentSelectAll2 = 'Select all alternative';
 Mes_SCA_OrnamentToggle = 'Toggle sign';
 Mes_SCA_OrnamentPlus = 'Set plus sign';
 Mes_SCA_OrnamentPlus2 = 'Set plus sign alternative';
 Mes_SCA_OrnamentPlus3 = 'Set plus sign alternative';
 Mes_SCA_OrnamentMinus = 'Set minus sign';
 Mes_SCA_OrnamentMinus2 = 'Set minus sign alternative';

 //Note keys description
 Mes_NK_NO = 'Not defined';
 Mes_NK_RELEASE = 'Release';
 Mes_NK_EMPTY = 'Empty';
 Mes_NK_DO = 'Do';
 Mes_NK_DODiesis = 'Do Diesis';
 Mes_NK_RE = 'Re';
 Mes_NK_REDiesis = 'Re Diesis';
 Mes_NK_MI = 'Mi';
 Mes_NK_FA = 'Fa';
 Mes_NK_FADiesis = 'Fa Diesis';
 Mes_NK_SOL = 'Sol';
 Mes_NK_SOLDiesis = 'Sol Diesis';
 Mes_NK_LA = 'La';
 Mes_NK_LADiesis = 'La Diesis';
 Mes_NK_SI = 'Si';
 Mes_NK_DO2 = 'Do +1';
 Mes_NK_DODiesis2 = 'Do Diesis +1';
 Mes_NK_RE2 = 'Re +1';
 Mes_NK_REDiesis2 = 'Re Diesis +1';
 Mes_NK_MI2 = 'Mi +1';
 Mes_NK_FA2 = 'Fa +1';
 Mes_NK_FADiesis2 = 'Fa Diesis +1';
 Mes_NK_SOL2 = 'Sol +1';
 Mes_NK_SOLDiesis2 = 'Sol Diesis +1';
 Mes_NK_LA2 = 'La +1';
 Mes_NK_LADiesis2 = 'La Diesis +1';
 Mes_NK_SI2 = 'Si +1';
 Mes_NK_DO3 = 'Do +2';
 Mes_NK_DODiesis3 = 'Do Diesis +2';
 Mes_NK_RE3 = 'Re +2';
 Mes_NK_REDiesis3 = 'Re Diesis +2';
 Mes_NK_MI3 = 'Mi +2';
 Mes_NK_FA3 = 'Fa +2';
 Mes_NK_FADiesis3 = 'Fa Diesis +2';
 Mes_NK_SOL3 = 'Sol +2';
 Mes_NK_OCTAVE1 = 'Octave 1';
 Mes_NK_OCTAVE2 = 'Octave 2';
 Mes_NK_OCTAVE3 = 'Octave 3';
 Mes_NK_OCTAVE4 = 'Octave 4';
 Mes_NK_OCTAVE5 = 'Octave 5';
 Mes_NK_OCTAVE6 = 'Octave 6';
 Mes_NK_OCTAVE7 = 'Octave 7';
 Mes_NK_OCTAVE8 = 'Octave 8';

implementation

end.
