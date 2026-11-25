@echo off
REM ===========================================================================
REM  Vision64 Export Helper - launcher          developed by Young Wang
REM ---------------------------------------------------------------------------
REM  Starts the helper with a PORTABLE copy of AutoHotkey v2 - nothing has to
REM  be installed on this PC.
REM
REM  SETUP (once):
REM    1. Download the AutoHotkey v2 ZIP:  https://www.autohotkey.com/download/
REM       (the .zip / portable download, not the setup .exe)
REM    2. Extract it and copy  AutoHotkey64.exe  next to this .bat file
REM    3. Double-click this .bat
REM ===========================================================================
setlocal
set "HERE=%~dp0"
set "SCRIPT=%HERE%Vision64_BatchExport.ahk"

if not exist "%SCRIPT%" (
    echo Vision64_BatchExport.ahk was not found next to this launcher.
    echo Keep both files in the same folder.
    pause & exit /b 1
)

set "AHK="
for %%P in (
    "%HERE%AutoHotkey64.exe"
    "%HERE%AutoHotkey32.exe"
    "%HERE%AutoHotkey.exe"
    "%HERE%AutoHotkey\AutoHotkey64.exe"
    "%HERE%AutoHotkey\v2\AutoHotkey64.exe"
    "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
    "%ProgramFiles%\AutoHotkey\AutoHotkey64.exe"
    "%ProgramFiles(x86)%\AutoHotkey\v2\AutoHotkey64.exe"
    "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
) do if not defined AHK if exist %%P set "AHK=%%~P"

if not defined AHK (
    echo.
    echo   AutoHotkey v2 was not found.
    echo.
    echo   No installation needed - just do this once:
    echo     1. Go to  https://www.autohotkey.com/download/
    echo     2. Download the AutoHotkey v2 ZIP ^(not the setup .exe^)
    echo     3. Extract it and copy  AutoHotkey64.exe  into this folder:
    echo          %HERE%
    echo     4. Double-click this launcher again.
    echo.
    pause & exit /b 1
)

echo Starting Vision64 Export Helper ...
start "" "%AHK%" "%SCRIPT%"
exit /b 0
