# PureBasic IDE Tools

## [ChangeTheme](./ChangeTheme.pb)
Tool for automatically changing the IDE's color theme, much more quickly than importing it via the Preferences window.  
You can browse for a theme file, or pass it as a commandline parameter.  
The tool will close the IDE, update the colors, and re-launch the IDE.

## [ColorPreview](./ColorPreview.pb)
This tool will pop up a small preview of a color constant in your code when you hover the mouse over it.  
They can be in hex format (`$FF00FF`), RGB() format (`RGB(255, 0, 255)`), or standard named constants (`#Magenta`).  
Currently Windows-only.
