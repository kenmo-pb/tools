; +-------------+
; | ChangeTheme |
; +-------------+
; | Tool for automatically switching the color theme of the PureBasic IDE
; |
; | Usage:
; |   Build this executable and run it as a Tool from the PureBasic IDE.
; |   Set the trigger to "Menu Or Shortcut" but don't set "Wait until tool quits".
; |   
; |   ChangeTheme (no parameters specified)
; |     Browse for a theme file. If selected, apply to prefs and re-open IDE.
; |   ChangeTheme <theme file>
; |     Apply specific theme file to prefs and re-open IDE.
; |   ChangeTheme <theme file> --apply (or -a)
; |     Apply theme to active source code. Do not close IDE or modify prefs.
; |   ChangeTheme "" --apply (or -a)
; |     Browse and apply to active source code. Do not close IDE or modify prefs.
; |   
; |   The file format must match color settings as exported from the IDE.
; | 

;-
#SW_Title   = "ChangeTheme"
#SW_Release =  20190619


;- Compiler checks
CompilerIf (#PB_Compiler_Debugger)
  CompilerError #SW_Title + " must be run from the PureBasic IDE as a Tool."
CompilerEndIf
#SW_Windows = Bool(#PB_Compiler_OS = #PB_OS_Windows)


;- Locate IDE executable and Preferences file
IDEFile.s   = GetEnvironmentVariable("PB_TOOL_IDE")
PrefsFile.s = GetEnvironmentVariable("PB_TOOL_Preferences")
If ((IDEFile = "") Or (PrefsFile = ""))
  MessageRequester(#SW_Title + " v" + Str(#SW_Release),
      #SW_Title + " must be run from the PureBasic IDE as a Tool.",
      #PB_MessageRequester_Info)
  End
EndIf
PrefsModDate.i = GetFileDate(PrefsFile, #PB_Date_Modified)


;- Locate new color theme file
ThemeFile.s = ProgramParameter(0)
If (ThemeFile = "")
  ThemeFile = OpenFileRequester(#SW_Title, GetCurrentDirectory(),
      "PureBasic Themes|*.prefs;*.ini;*.theme;*.txt|All Files (*.*)|*", 0)
EndIf
If (ThemeFile = "")
  End
EndIf


;- Parse extra options
ApplyNow.i = #False
For i = 1 To (CountProgramParameters() - 1)
  Select (LCase(Trim(ProgramParameter(i), "-")))
    Case "a", "apply"
      ApplyNow = #True
  EndSelect
Next i


;- Read new color theme values
NewMap ThemeValue.s()
NewList ColorToDisable.s()
If (OpenPreferences(ThemeFile))
  PreferenceGroup("Colors")
  ExaminePreferenceKeys()
  While (NextPreferenceKey())
    If (FindString(PreferenceKeyName(), "_Used"))
      If (Val(PreferenceKeyValue()) = 0)
        AddElement(ColorToDisable())
        ColorToDisable() = StringField(PreferenceKeyName(), 1, "_Used")
      EndIf
    Else
      ThemeValue(PreferenceKeyName()) = PreferenceKeyValue()
    EndIf
  Wend
  ClosePreferences()
Else
  MessageRequester(#SW_Title, "Theme could not be loaded:" +
      #LF$ + #LF$ + ThemeFile, #PB_MessageRequester_Error)
EndIf


If (MapSize(ThemeValue()) > 0)
  
  ;- Convert RGB(r,g,b) strings into Decimal integer values
  ForEach ThemeValue()
    If (FindString(ThemeValue(), "RGB", 1, #PB_String_NoCase))
      TempStr.s = StringField(ThemeValue(), 2, "(")
      TempStr   = StringField(TempStr, 1, ")")
      TempStr   = RemoveString(TempStr, " ")
      
      RValue.i = Val(StringField(TempStr, 1, ","))
      GValue.i = Val(StringField(TempStr, 2, ","))
      BValue.i = Val(StringField(TempStr, 3, ","))
      
      ThemeValue() = Str(RGB(RValue, GValue, BValue))
    EndIf
  Next
  
  
  ;-
  If (ApplyNow) ;- Apply directly to Scintilla
    
    *Scintilla = Val(GetEnvironmentVariable("PB_TOOL_Scintilla"))
    If (*Scintilla)
      
      ; Pre-styling actions
      CompilerIf (#SW_Windows)
        *Window = Val(GetEnvironmentVariable("PB_TOOL_MainWindow"))
        SendMessage_(*Window, #WM_SETREDRAW, #False, #Null)
        KeywordBolding.i = Bool(SendMessage_(*Scintilla, #SCI_STYLEGETBOLD, 2, 0))
      CompilerEndIf
      
      ; Apply all found style colors
      Restore PB_IDE_ScintillaStyles
      Read.i i
      While (i >= 0)
        Read *Ptr : Fore.s = PeekS(*Ptr)
        Read *Ptr : Back.s = PeekS(*Ptr)
        CompilerIf (#SW_Windows)
          If (Fore And FindMapElement(ThemeValue(), Fore))
            SendMessage_(*Scintilla, #SCI_STYLESETFORE, i, Val(ThemeValue()))
          EndIf
          If (Back And FindMapElement(ThemeValue(), Back))
            SendMessage_(*Scintilla, #SCI_STYLESETBACK, i, Val(ThemeValue()))
          EndIf
          If (i = #STYLE_DEFAULT)
            SendMessage_(*Scintilla, #SCI_STYLECLEARALL, 0, 0)
          EndIf
        CompilerEndIf
        Read.i i
      Wend
      
      ; Final styling and post-styling actions
      CompilerIf (#SW_Windows)
        If (FindMapElement(ThemeValue(), "CurrentLineColor"))
          SendMessage_(*Scintilla, #SCI_SETCARETLINEBACK, Val(ThemeValue()), 0)
        EndIf
        If FindMapElement(ThemeValue(), "SelectionColor")
          SendMessage_(*Scintilla, #SCI_SETSELBACK, #True, Val(ThemeValue()))
        EndIf
        If FindMapElement(ThemeValue(), "SelectionFrontColor")
          SendMessage_(*Scintilla, #SCI_SETSELFORE, #True, Val(ThemeValue()))
        EndIf
        If FindMapElement(ThemeValue(), "SelectionRepeatColor")
          SendMessage_(*Scintilla, #SCI_INDICSETFORE, 2, Val(ThemeValue()))
        EndIf
        If FindMapElement(ThemeValue(), "CursorColor")
          SendMessage_(*Scintilla, #SCI_SETCARETFORE, Val(ThemeValue()), 0)
        EndIf
        If FindMapElement(ThemeValue(), "LineNumberBackColor")
          SendMessage_(*Scintilla, #SCI_SETFOLDMARGINCOLOUR, #True, Val(ThemeValue()))
          SendMessage_(*Scintilla, #SCI_SETFOLDMARGINHICOLOUR, #True, Val(ThemeValue()))
          For i = 25 To 31
            SendMessage_(*Scintilla, #SCI_MARKERSETFORE, i, Val(ThemeValue()))
          Next i
        EndIf
        SendMessage_(*Scintilla, #SCI_STYLESETBOLD,  2, KeywordBolding)
        SendMessage_(*Scintilla, #SCI_STYLESETBOLD, 14, KeywordBolding)
        SendMessage_(*Window, #WM_SETREDRAW, #True, #Null)
        RedrawWindow_(*Window, #Null, #Null,
            #RDW_ERASE | #RDW_FRAME | #RDW_INVALIDATE | #RDW_ALLCHILDREN)
      CompilerEndIf
      
    Else
      MessageRequester(#SW_Title, "No Scintilla handle found!",
          #PB_MessageRequester_Error)
    EndIf
    
  ;- or
  Else ; Close IDE, modify prefs file, re-open
    
    ;- Close IDE automatically or prompt user
    CompilerIf (#PB_Compiler_OS = #PB_OS_Windows)
    
      *Window = Val(GetEnvironmentVariable("PB_TOOL_MainWindow"))
      If (*Window)
        PostMessage_(*Window, #WM_CLOSE, #Null, #Null)
        StartTime = ElapsedMilliseconds()
        Repeat
          Delay(50)
        Until ((Not IsWindow_(*Window)) Or (ElapsedMilliseconds() - StartTime > 10*1000))
        If (IsWindow_(*Window))
          Prompt.i = #True
        EndIf
      EndIf
      
    CompilerElse
      Prompt = #True
    CompilerEndIf
    If (Prompt)
      MessageRequester(#SW_Title, "Please close the PureBasic IDE, then press OK.",
          #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
    EndIf
    
    ;- Wait for Prefs file to be updated (with timeout)
    StartTime.i = ElapsedMilliseconds()
    Repeat
      Delay(50)
    Until ((GetFileDate(PrefsFile, #PB_Date_Modified) > PrefsModDate) Or
        (ElapsedMilliseconds() - StartTime > 3*1000))
    
    
    ;- Back up existing Prefs file
    If (#True)
      CopyFile(PrefsFile, PrefsFile + ".backup")
    EndIf
    
    ;- Write new values to Prefs file
    If (OpenPreferences(PrefsFile))
      PreferenceGroup("Editor")
      NewList ColorToEnable.s()
      ExaminePreferenceKeys()
      While (NextPreferenceKey())
        If (FindMapElement(ThemeValue(), PreferenceKeyName()))
          WritePreferenceString(PreferenceKeyName(), ThemeValue())
          AddElement(ColorToEnable())
          ColorToEnable() = PreferenceKeyName()
        EndIf
      Wend
      ForEach (ColorToEnable())
        WritePreferenceInteger(ColorToEnable() + "_Disabled", #False)
      Next
      ForEach (ColorToDisable())
        WritePreferenceInteger(ColorToDisable() + "_Disabled", #True)
      Next
      
      ; Tools Panel colors stored in different group
      PreferenceGroup("ToolsPanel")
      If (FindMapElement(ThemeValue(), "ToolsPanel_FrontColor"))
        WritePreferenceString("FrontColor", ThemeValue())
      EndIf
      If (FindMapElement(ThemeValue(), "ToolsPanel_BackColor"))
        WritePreferenceString("BackColor", ThemeValue())
      EndIf
      
      ClosePreferences()
      Delay(50)
    EndIf
    
    ;- Launch IDE
    RunProgram(IDEFile)
    
  EndIf
  
EndIf
End


;- Map Scintilla Styles to Color Names
DataSection
  PB_IDE_ScintillaStyles:
  Data.i #STYLE_DEFAULT, @"", @"BackgroundColor"
  ;
  Data.i  1, @"NormalTextColor",    @"BackgroundColor"
  Data.i  2, @"BasicKeywordColor",  @"BackgroundColor"
  Data.i  3, @"CommentColor",       @"BackgroundColor"
  Data.i  4, @"ConstantColor",      @"BackgroundColor"
  Data.i  5, @"StringColor",        @"BackgroundColor"
  Data.i  6, @"PureKeywordColor",   @"BackgroundColor"
  Data.i  7, @"ASMKeywordColor",    @"BackgroundColor"
  Data.i  8, @"OperatorColor",      @"BackgroundColor"
  Data.i  9, @"StructureColor",     @"BackgroundColor"
  Data.i 10, @"NumberColor",        @"BackgroundColor"
  Data.i 11, @"PointerColor",       @"BackgroundColor"
  Data.i 12, @"SeparatorColor",     @"BackgroundColor"
  Data.i 13, @"LabelColor",         @"BackgroundColor"
  Data.i 14, @"CustomKeywordColor", @"BackgroundColor"
  Data.i 15, @"ModuleColor",        @"BackgroundColor"
  Data.i 16, @"BadBraceColor",      @"BackgroundColor"
  ;
  Data.i 33, @"LineNumberColor",    @"LineNumberBackColor"
  Data.i 34, @"GoodBraceColor",     @"CurrentLineColor"
  Data.i 35, @"BadBraceColor",      @"CurrentLineColor"
  Data.i 35, @"BadBraceColor",      @"CurrentLineColor"
  Data.i 37, @"IndentColor",        @"BackgroundColor"
  ;
  Data.i -1, #Null, #Null
EndDataSection

;-