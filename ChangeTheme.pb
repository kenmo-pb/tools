; +-------------+
; | ChangeTheme |
; +-------------+
; | Tool for automatically switching the color theme of the PureBasic IDE
; |
; | Usage:
; |   Build this executable and run it as a Tool from the PureBasic IDE.
; |   Set the trigger to "Menu Or Shortcut" but don't set "Wait until tool quits".
; |   
; |   Run with no parameters to BROWSE for a color theme file,
; |   or run with one parameter: a specific color theme file.
; |   The file format must match the color settings as exported from the IDE.
; |   
; |   If the theme can be loaded, this will try to close the IDE,
; |   write the new colors to your PB prefs file, and re-launch the IDE.
; | 

;-
#SW_Title   = "ChangeTheme"
#SW_Release =  20190503


;- Compiler checks
CompilerIf (#PB_Compiler_Debugger)
  CompilerError #SW_Title + " must be run from the PureBasic IDE as a Tool."
CompilerEndIf


;- Locate IDE executable and Preferences file
IDEFile.s   = GetEnvironmentVariable("PB_TOOL_IDE")
PrefsFile.s = GetEnvironmentVariable("PB_TOOL_Preferences")
If ((IDEFile = "") Or (PrefsFile = ""))
  MessageRequester(#SW_Title + " v" + Str(#SW_Release), #SW_Title + " must be run from the PureBasic IDE as a Tool.",
      #PB_MessageRequester_Info)
  End
EndIf
PrefsModDate.i = GetFileDate(PrefsFile, #PB_Date_Modified)


;- Locate new color theme file
ThemeFile.s = ProgramParameter(0)
If (ThemeFile = "")
  ThemeFile = OpenFileRequester(#SW_Title, GetHomeDirectory(), "PureBasic Themes|*.prefs;*.ini;*.theme|All Files (*.*)|*", 0)
EndIf
If (ThemeFile = "")
  End
EndIf


;- Read new color theme values
NewMap ThemeValue.s()
If (OpenPreferences(ThemeFile))
  PreferenceGroup("Colors")
  ExaminePreferenceKeys()
  While (NextPreferenceKey())
    ThemeValue(PreferenceKeyName()) = ReadPreferenceString(PreferenceKeyName(), "")
  Wend
  ClosePreferences()
Else
  MessageRequester(#SW_Title, "Theme could not be loaded:" +
      #LF$ + #LF$ + ThemeFile, #PB_MessageRequester_Error)
EndIf


If (MapSize(ThemeValue()) > 0)
  
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
    ExaminePreferenceKeys()
    While (NextPreferenceKey())
      If (FindMapElement(ThemeValue(), PreferenceKeyName()))
        WritePreferenceString(PreferenceKeyName(), ThemeValue())
      EndIf
    Wend
    
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
  
EndIf


;- Launch IDE
RunProgram(IDEFile)

;-