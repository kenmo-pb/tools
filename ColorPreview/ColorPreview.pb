; +--------------+
; | ColorPreview |
; +--------------+
; | 2017-07-18 . Rewrite (PureBasic 5.60)
; | 2017-07-19 . Cleanup, added text description
; | 2019-08-12 . Added support for RGBA values (alpha does not affect preview)

; DESCRIPTION
;   This tool for the PureBasic IDE will show a preview when you hover over a color.
;   Detects:
;     The RGB function, in decimal or hex, such as RGB( $FF, 128, $40)
;     Hex literal, such as $aaFF22
;     Common color constants, such as #Blue
;
; INSTRUCTIONS
;   Build executable (currently Windows-only)
;   Add the tool to the PB IDE with two triggers:
;     - New Sourcecode created
;     - Sourcecode loaded
;   You can edit the size, position, etc. in the INI file created (in same folder).
;   Each triggered exe should quit when you close its tab in the IDE.
;   You can add a hotkey to kill the exe by its Windows "VK" value.
;     Example: KillVK = 119 (for F8 key)


;-
;- Constants

#SW_Title   = "ColorPreview"
#SW_Version = "1.1"

CompilerIf (#PB_Compiler_OS <> #PB_OS_Windows)
  CompilerError "Please build on Windows!"
CompilerElseIf (#PB_Compiler_Debugger)
  CompilerError "Please build executable and launch from PB IDE!"
CompilerEndIf




;-
;- Globals

EnableExplicit

Global *IDE, *Scintilla

Global HoverTime.i
Global PreviewSize.i, BorderSize.i
Global PreviewX.i, PreviewY.i
Global KillKey.i = #VK_F8
Global Shown.i

Global PrefFile.s = GetPathPart(ProgramFilename()) + #SW_Title + ".ini"

Global NewMap KnownColor.i()
  KnownColor("#BLACK")   = #Black
  KnownColor("#WHITE")   = #White
  KnownColor("#GRAY")    = #Gray
  KnownColor("#RED")     = #Red
  KnownColor("#GREEN")   = #Green
  KnownColor("#BLUE")    = #Blue
  KnownColor("#CYAN")    = #Cyan
  KnownColor("#MAGENTA") = #Magenta
  KnownColor("#YELLOW")  = #Yellow


;-
;- Macros

Macro SSM(Message, Param = 0, lParam = 0)
  SendMessage_(*Scintilla, (Message), (Param), (lParam))
EndMacro




;-
;- Procedures

Procedure.s GetSciText(Start.i, Stop.i)
  If (Start >= 0) And (Stop > Start)
    Protected *Buffer = AllocateMemory(Stop - Start)
    If (*Buffer)
      Protected i.i
      For i = 0 To (Stop - Start - 1)
        PokeA(*Buffer + i, SSM(#SCI_GETCHARAT, Start + i))
      Next i
      Protected Result.s = PeekS(*Buffer, Stop - Start, #PB_UTF8 | #PB_ByteLength)
      FreeMemory(*Buffer)
      ProcedureReturn (Result)
    EndIf
  EndIf
EndProcedure

Procedure Show(Color.i)
  SetGadgetColor(0, #PB_Gadget_BackColor, Color)
  If (Not Shown)
    ResizeWindow(0,
        DesktopMouseX() + PreviewX, DesktopMouseY() + PreviewY,
        #PB_Ignore, #PB_Ignore)
    HideWindow(0, #False, #PB_Window_NoActivate)
    Shown = #True
  EndIf
EndProcedure

Procedure Hide()
  If (Shown)
    HideWindow(0, #True)
    Shown = #False
  EndIf
EndProcedure

Procedure.i FindRGBValue(Pos.i, *Color.INTEGER)
  If (Pos >= 0)
    Protected LN.i     = SSM(#SCI_LINEFROMPOSITION, Pos)
    Protected LStart.i = SSM(#SCI_GETLINEINDENTPOSITION, LN)
    Protected LStop.i  = SSM(#SCI_GETLINEENDPOSITION, LN)
    Protected LText.s  = GetSciText(LStart, LStop)
    If (LText)
      Protected PosInLine.i = Pos - LStart + 1
      
      Protected i.i = FindString(LText, "RGB", 1, #PB_String_NoCase)
      While (i)
        Protected ParenCount.i =  0
        Protected FirstParen.i = -1
        Protected LastParen.i  = -1
        Protected *C.CHARACTER = @LText + (i-1) * SizeOf(CHARACTER)
        
        While (#True)
          If (*C\c = '(')
            ParenCount + 1
            If (ParenCount = 1) And (FirstParen = -1)
              FirstParen = 1 + (*C - @LText) / SizeOf(CHARACTER)
            EndIf
          ElseIf (*C\c = ')')
            ParenCount - 1
            If (ParenCount < 0)
              Break
            ElseIf (ParenCount = 0)
              LastParen = 1 + (*C - @LText) / SizeOf(CHARACTER)
              Break
            EndIf
          ElseIf (*C\c = #NUL)
            Break 2
          EndIf
          *C + SizeOf(CHARACTER)
        Wend
        
        If (FirstParen <> -1) And (LastParen <> -1)
          If (PosInLine >= i) And (PosInLine <= LastParen)
            Protected Text.s = Mid(LText, FirstParen + 1, LastParen - FirstParen - 1)
            Text = RemoveString(Text, "(")
            Text = RemoveString(Text, ")")
            Text = RemoveString(Text, " ")
            Text = RemoveString(Text, #TAB$)
            If ((CountString(Text, ",") = 2) Or (CountString(Text, ",") = 3))
              *Color\i = RGB(Val(StringField(Text, 1, ",")),
                  Val(StringField(Text, 2, ",")),
                  Val(StringField(Text, 3, ",")))
              ProcedureReturn (#True)
            EndIf
          EndIf
        EndIf
        
        i = FindString(LText, "RGB", i+1, #PB_String_NoCase)
      Wend
    EndIf
  EndIf
  ProcedureReturn (#False)
EndProcedure

Procedure TrackCursor()
  If (Not IsWindowVisible_(*Scintilla)) Or (Not IsWindowVisible_(*IDE))
    Hide()
    ProcedureReturn
  EndIf
  
  Static Pos.i   = -1, oPos.i
  Static Start.i = -1, oStart.i
  Static Stop.i  = -1, oStop.i
  Static HoverStart.i
  
  ; Get relative mouse coordinates
  Protected R.RECT
  GetWindowRect_(*Scintilla, @R)
  Protected SciX.i = DesktopMouseX() - R\left
  Protected SciY.i = DesktopMouseY() - R\top
  
  oPos   = Pos
  oStart = Start
  oStop  = Stop
  
  ; Get word under cursor
  Pos = SSM(#SCI_POSITIONFROMPOINTCLOSE, SciX, SciY)
  If (Pos <> -1)
    Start = SSM(#SCI_WORDSTARTPOSITION, Pos, #False)
    Stop  = SSM(#SCI_WORDENDPOSITION,   Pos, #False)
  Else
    Start = -1
    Stop = -1
  EndIf
  
  If (Shown)
    ; If hover word has changed, hide window
    If ((Start <> oStart) Or (Stop <> oStop))
      Hide()
      HoverStart = ElapsedMilliseconds()
    EndIf
  Else
    
    ; If hover word has changed...
    If ((Start <> oStart) Or (Stop <> oStop))
      HoverStart = ElapsedMilliseconds()
    EndIf
    If (ElapsedMilliseconds() - HoverStart > HoverTime)
      Protected Valid.i = #False
      Protected Color.i
      Protected Text.s
      
      ; Show random color
      If (#False)
        Valid = #True
        Color = Random(#White)
      EndIf
      
      ; Detect RGB() value
      If (Not Valid)
        Valid = FindRGBValue(Pos, @Color)
      EndIf
      
      If (Not Valid)
        Text = GetSciText(Start, Stop)
        If (Text)
          
          ; Detect standard color constants
          If (FindMapElement(KnownColor(), UCase(Text)))
            Valid = #True
            Color = KnownColor()
            
          ; Detect color in hex format
          ElseIf ((Left(Text, 1) = "$") And (Len(Text) >= 4))
            Valid = #True
            Color = Val(Text) & $FFFFFF
            
          EndIf
        EndIf
      EndIf
      
      If (Valid)
        Show(Color)
      Else
        Shown = #True
      EndIf
    EndIf
  EndIf
EndProcedure







;-
;- Initialization

*IDE       = Val(GetEnvironmentVariable("PB_TOOL_MainWindow"))
*Scintilla = Val(GetEnvironmentVariable("PB_TOOL_Scintilla"))
If ((Not *IDE) Or (Not *Scintilla))
  MessageRequester(#SW_Title + " " + #SW_Version, #SW_Title + " must be run As a PureBasic IDE tool." + #LF$ + #LF$ + 
      "Add two copies of this tool with the triggers:" + #LF$ +
      "- New Sourcecode created" + #LF$ + 
      "- Sourcecode loaded", #PB_MessageRequester_Info)
  End
EndIf

; Read / load default settings
OpenPreferences(PrefFile)
  PreviewSize = ReadPreferenceInteger("PreviewSize", 50)
  BorderSize  = ReadPreferenceInteger("BorderSize",  1)
  HoverTime   = ReadPreferenceInteger("HoverTime",   500)
  PreviewX    = ReadPreferenceInteger("PreviewX",    1)
  PreviewY    = ReadPreferenceInteger("PreviewY",    10)
  KillKey     = ReadPreferenceInteger("KillVK",     #Null)
ClosePreferences()

; Write settings file (it may not exist yet)
If (CreatePreferences(PrefFile))
  PreferenceComment(#SW_Title)
  WritePreferenceInteger("PreviewSize", PreviewSize)
  WritePreferenceInteger("BorderSize",  BorderSize)
  WritePreferenceInteger("HoverTime",   HoverTime)
  WritePreferenceInteger("PreviewX",    PreviewX)
  WritePreferenceInteger("PreviewY",    PreviewY)
  WritePreferenceInteger("KillVK",      KillKey)
  ClosePreferences()
EndIf







;-
;- Window Setup

If (Not OpenWindow(0, 0, 0,
    PreviewSize + 2*BorderSize, PreviewSize + 2*BorderSize, 
    #SW_Title, #PB_Window_BorderLess | #PB_Window_Invisible, *IDE))
  End
EndIf
SetWindowColor(0, #Black)
ContainerGadget(0, BorderSize, BorderSize, PreviewSize, PreviewSize, #PB_Container_BorderLess)
  CloseGadgetList()






;-
;- Main Loop

Define Event.i, ExitFlag.i

If (KillKey)
  GetAsyncKeyState_(KillKey)
EndIf

Repeat
  Event = WaitWindowEvent(20)
  If (Event = #PB_Event_CloseWindow)
    ExitFlag = #True
  ElseIf (Not Event)
    
    ; Conditions for quitting
    If ((Not IsWindow_(*Scintilla)) Or (Not IsWindow_(*IDE)))
      ExitFlag = #True
    ElseIf (KillKey And GetAsyncKeyState_(KillKey))
      ExitFlag = #True
    EndIf
    
    ; Monitor mouse action
    If (Not ExitFlag)
      TrackCursor()
    EndIf
    
  EndIf
Until (ExitFlag)

;-
;- Finish

End

;-