;=============================================================================
;  Vision64_BatchExport.ahk        (requires AutoHotkey v2  -  autohotkey.com)
;-----------------------------------------------------------------------------
;  Guided export helper for Bruker Vision64 (DektakXT, Data Analysis view).
;
;  For every trace file you pick it saves, into the folder you choose:
;      <original name>.csv    (right-click plot -> Export Data -> Save As)
;      <original name>.bmp    (Copy To Clipboard -> Save As Bitmap...)
;  and leaves the plot image on the clipboard.
;
;  Hotkeys:  F7 = batch export      F8 = export current trace
;            F10 / F11 / F12 = calibrate plot / copy arrow / Open button
;            F6 = restore the panel after minimizing      F9 = window info
;            Esc = stop a run (quits the helper when idle)
;
;  Every step is logged to Vision64_ExportLog.txt next to this script.
;-----------------------------------------------------------------------------
;  Developed by Young Wang
;  Version 1.1  -  November 2026
;=============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
SetTitleMatchMode 2

;=============================================================================
;  CONFIG  (the panel handles everything important - rarely needs editing)
;=============================================================================
AppAuthor       := "Young Wang"
AppVersion      := "1.1"
Vision64Win     := ""                    ; "" = auto-detect
CsvMenuKeys     := "{Up}{Enter}"         ; "Export Data" = last item of plot menu
BitmapItemKeys  := "{Down 2}{Enter}"     ; "Save As Bitmap..." = 2nd dropdown item
OpenMenuKeys    := "{Down}{Enter}"       ; "Dataset" = 1st item of the Open menu
ExportDlgTitles := ["Save As", "Export Data", "Save"]
BmpDlgTitles    := ["Save Bitmap as", "Save As Bitmap", "Save Bitmap", "Save"]
OpenDlgTitles   := ["Open Dataset", "Open"]
ShortDelay      := 150                   ; ms settle pause
MenuDelay       := 350                   ; ms for menus to render
NextDelay       := 1000                  ; ms for a dataset to load
DlgTimeout      := 10                    ; s to wait for dialogs
; All delays are tripled when "Slow mode" is ticked on the panel.

;=============================================================================
;  SAVED STATE
;=============================================================================
IniFile    := A_ScriptDir "\Vision64_BatchExport.ini"
LogFile    := A_ScriptDir "\Vision64_ExportLog.txt"
ListFile   := A_ScriptDir "\Vision64_TraceList.txt"
OutputDir  := IniRead(IniFile, "Settings", "OutputDir", "")
SourceDir  := IniRead(IniFile, "Settings", "SourceDir", "")
AvgSecs    := IniRead(IniFile, "Settings", "AvgSecs", "0") + 0
SlowMode   := (IniRead(IniFile, "Settings", "SlowMode", "0") = "1")
PlotX      := IniRead(IniFile, "Calib", "PlotX", "")
PlotY      := IniRead(IniFile, "Calib", "PlotY", "")
CopyBtnX   := IniRead(IniFile, "Calib", "CopyBtnX", "")
CopyBtnY   := IniRead(IniFile, "Calib", "CopyBtnY", "")
OpenBtnX   := IniRead(IniFile, "Calib", "OpenBtnX", "")
OpenBtnY   := IniRead(IniFile, "Calib", "OpenBtnY", "")
TraceNames := []
TracePaths := []
NameIndex  := 1
NameCounter := 0
Busy       := false
StopFlag   := false
EtaSuffix  := ""

;=============================================================================
;  CONTROL PANEL
;=============================================================================
MainGui := Gui("+AlwaysOnTop +MinimizeBox", "Vision64 Export Helper  v" AppVersion)
MainGui.SetFont("s10", "Segoe UI")
MainGui.SetFont("s10 Bold")
StepText := MainGui.Add("Text", "w480 r6", "")
MainGui.SetFont("s9 Norm")
MainGui.Add("Text", "xm y+8", "Export folder:")
FolderText := MainGui.Add("Text", "x+6 w300 cNavy", "(not chosen yet)")
BtnFolder  := MainGui.Add("Button", "x+8 w110", "Choose folder...")
MainGui.Add("Text", "xm y+6", "File names:")
NamesText  := MainGui.Add("Text", "x+16 w300 cNavy", "(none)")
BtnNames   := MainGui.Add("Button", "x+8 w110", "Pick trace files...")
CalibText  := MainGui.Add("Text", "xm y+8 w480", "")
BtnRecal   := MainGui.Add("Button", "xm y+6 w150", "Redo calibration")
BtnRestart := MainGui.Add("Button", "x+10 w150", "Restart name list")
ChkSlow    := MainGui.Add("Checkbox", "x+14 yp+6", "Slow mode")
BtnExport  := MainGui.Add("Button", "xm y+10 w185 h34", "Export current trace  (F8)")
BtnBatch   := MainGui.Add("Button", "x+12 w185 h34", "Batch export all...  (F7)")
BtnStop    := MainGui.Add("Button", "x+12 w86 h34 Disabled", "STOP  (Esc)")
BtnMin     := MainGui.Add("Button", "xm y+8 w200", "Minimize   (F6 brings it back)")
MainGui.SetFont("s9")
StatusText := MainGui.Add("Text", "xm y+10 w480 r4 cGreen", "")
MainGui.SetFont("s8")
MainGui.Add("Text", "xm y+8 w330 cGray",
    "Vision64 Export Helper  v" AppVersion "  -  developed by " AppAuthor)
BtnAbout   := MainGui.Add("Button", "x+8 yp-4 w80", "About")

BtnFolder.OnEvent("Click",  (*) => ChooseFolder())
BtnNames.OnEvent("Click",   (*) => PickTraceFiles())
BtnRecal.OnEvent("Click",   (*) => ResetCalibration())
BtnRestart.OnEvent("Click", (*) => RestartNames())
BtnExport.OnEvent("Click",  (*) => DoExportCurrent())
BtnBatch.OnEvent("Click",   (*) => DoBatch())
BtnStop.OnEvent("Click",    (*) => RequestStop())
BtnMin.OnEvent("Click",     (*) => MinimizePanel())
BtnAbout.OnEvent("Click",   (*) => ShowAbout())
ChkSlow.Value := SlowMode
ChkSlow.OnEvent("Click", (*) => SetSlowMode(ChkSlow.Value = 1))
MainGui.OnEvent("Close", (*) => ExitApp())

LoadTraceList()
UpdateUi()
MainGui.Show("x40 y40")
LogLine "===== Vision64 Export Helper v" AppVersion " by " AppAuthor " - started ====="
if (OpenBtnX != "" && PlotX != "" && CopyBtnX != "" && OutputDir != "")
    SetStatus("Setup restored from last time: folder, all 3 calibrations"
        . (TraceNames.Length ? " and " TraceNames.Length " trace files." : ".")
        . "`n(Use 'Redo calibration' or 'Pick trace files...' to change anything.)")

; Errors are logged and shown in the panel - never a modal box that
; would freeze a batch waiting for a click.
OnError HandleScriptError

;=============================================================================
;  HOTKEYS
;=============================================================================
Esc:: {
    if Busy
        RequestStop()
    else
        ExitApp
}
F7::DoBatch()
F8::DoExportCurrent()

F6:: {                                   ; bring the panel back
    MainGui.Restore()
    MainGui.Show()
    try WinActivate "ahk_id " MainGui.Hwnd
}

F9:: {
    MsgBox "Title:  " WinGetTitle("A") "`nExe:    " WinGetProcessName("A"), "Window info"
}

F10:: {
    global PlotX, PlotY
    MouseGetPos &PlotX, &PlotY
    IniWrite PlotX, IniFile, "Calib", "PlotX"
    IniWrite PlotY, IniFile, "Calib", "PlotY"
    SetStatus("Plot position saved.")
    UpdateUi()
}

F11:: {
    global CopyBtnX, CopyBtnY
    MouseGetPos &CopyBtnX, &CopyBtnY
    IniWrite CopyBtnX, IniFile, "Calib", "CopyBtnX"
    IniWrite CopyBtnY, IniFile, "Calib", "CopyBtnY"
    SetStatus("Copy To Clipboard arrow position saved.")
    UpdateUi()
}

F12:: {
    global OpenBtnX, OpenBtnY
    MouseGetPos &OpenBtnX, &OpenBtnY
    IniWrite OpenBtnX, IniFile, "Calib", "OpenBtnX"
    IniWrite OpenBtnY, IniFile, "Calib", "OpenBtnY"
    SetStatus("Open button position saved.")
    UpdateUi()
}

;=============================================================================
;  PANEL LOGIC
;=============================================================================
UpdateUi() {
    global
    FolderText.Text := (OutputDir = "") ? "(not chosen yet)" : OutputDir
    if (TraceNames.Length = 0)
        NamesText.Text := "(none picked yet)"
    else if (NameIndex > TraceNames.Length)
        NamesText.Text := "all " TraceNames.Length " done - F7 starts over"
    else
        NamesText.Text := "next:  " TraceNames[NameIndex] "   (" NameIndex " of " TraceNames.Length ")"

    CalibText.Text := "Calibration:   Open button " ((OpenBtnX = "") ? "[ NOT SET ]" : "[ ok ]")
        . "      plot " ((PlotX = "") ? "[ NOT SET ]" : "[ ok ]")
        . "      Copy arrow " ((CopyBtnX = "") ? "[ NOT SET ]" : "[ ok ]")

    ready := true
    if (OpenBtnX = "") {
        StepText.Text := "STEP 1 of 6:  Show me the Open button.`n`nMove the mouse over the ribbon 'Open' button in Vision64 (don't click), then press  F12."
        ready := false
    } else if (OutputDir = "") {
        StepText.Text := "STEP 2 of 6:  Choose where the CSV and BMP files are saved.`n`nClick 'Choose folder...' below."
        ready := false
    } else if (PlotX = "") {
        StepText.Text := "STEP 3 of 6:  Show me the trace plot.`n`nWith a trace open in Data Analysis, move the mouse over the MIDDLE of the graph (don't click), then press  F10."
        ready := false
    } else if (CopyBtnX = "") {
        StepText.Text := "STEP 4 of 6:  Show me the Copy To Clipboard menu.`n`nMove the mouse over the LITTLE ARROW of the 'Copy To Clipboard' ribbon button (don't click), then press  F11."
        ready := false
    } else if (TraceNames.Length = 0) {
        StepText.Text := "STEP 5 of 6:  Pick the trace files to export.`n`nClick 'Pick trace files...' and select them (Ctrl+A selects all). Their names become the CSV/BMP names."
    } else {
        StepText.Text := "STEP 6 of 6:  Ready!`n`nPress  F7  (Batch export all) - the script opens and exports every file by itself.`nOr per file: show a trace in Vision64 and press  F8."
    }
    BtnExport.Enabled := ready
    BtnBatch.Enabled  := ready
}

SetStatus(msg) {
    global StatusText, EtaSuffix
    StatusText.Text := msg . EtaSuffix
}

SetSlowMode(on) {
    global SlowMode, IniFile
    SlowMode := on
    IniWrite SlowMode ? "1" : "0", IniFile, "Settings", "SlowMode"
}

MinimizePanel() {
    global MainGui
    MainGui.Minimize()
    try TrayTip "Vision64 Export Helper", "Minimized - press F6 to bring it back.`nF7 / F8 still work while minimized.", 1
}

ShowAbout() {
    global AppVersion, AppAuthor
    MsgBox "Vision64 Export Helper  v" AppVersion "`n"
         . "Developed by " AppAuthor "`n`n"
         . "Batch-exports Bruker Vision64 (DektakXT) traces:`n"
         . "   -  <name>.csv   via right-click > Export Data`n"
         . "   -  <name>.bmp   via Copy To Clipboard > Save As Bitmap`n"
         . "   -  plot image left on the clipboard`n`n"
         . "Requires AutoHotkey v2. Settings, file list and log are kept`n"
         . "next to the script.", "About", "Iconi"
}

RequestStop() {
    global Busy, StopFlag
    if Busy {
        StopFlag := true
        SetStatus("Stopping - finishing the current action ...")
        LogLine "STOP requested by user"
    }
}

ChooseFolder() {
    global OutputDir, IniFile
    start := (OutputDir != "") ? "*" OutputDir : "*" A_MyDocuments
    picked := DirSelect(start, 3, "Choose the folder for the exported CSV and BMP files:")
    if (picked = "")
        return
    OutputDir := RTrim(picked, "\")
    IniWrite OutputDir, IniFile, "Settings", "OutputDir"
    SetStatus("Export folder set.")
    UpdateUi()
}

PickTraceFiles() {
    global TraceNames, TracePaths, NameIndex, SourceDir, IniFile
    start := (SourceDir != "") ? "*" SourceDir : ""
    sel := FileSelect("M3", start, "Select the trace files to export",
                      "Trace files (*.OPDx; *.opd; *.dat; *.csv)")
    if !IsObject(sel) || sel.Length = 0
        return
    pairs := []
    for p in sel {
        SplitPath p, , &dir, , &base
        pairs.Push([base, p])
        SourceDir := dir
    }
    IniWrite SourceDir, IniFile, "Settings", "SourceDir"
    NaturalSortPairs(pairs)
    TraceNames := [], TracePaths := []
    for pr in pairs {
        TraceNames.Push(pr[1])
        TracePaths.Push(pr[2])
    }
    NameIndex := 1
    SaveTraceList()
    SetStatus(pairs.Length " trace file(s) loaded (remembered for next time).")
    UpdateUi()
}

RestartNames() {
    global NameIndex
    NameIndex := 1
    SetStatus("Name list restarted from the first file.")
    UpdateUi()
}

ResetCalibration() {
    global PlotX, PlotY, CopyBtnX, CopyBtnY, OpenBtnX, OpenBtnY, IniFile
    PlotX := "", PlotY := "", CopyBtnX := "", CopyBtnY := "", OpenBtnX := "", OpenBtnY := ""
    IniDelete IniFile, "Calib"
    SetStatus("Calibration cleared - follow the steps above.")
    UpdateUi()
}

;=============================================================================
;  EXPORT ACTIONS
;=============================================================================
DoExportCurrent() {
    global Busy, StopFlag, BtnStop, EtaSuffix
    if Busy
        return
    Busy := true, StopFlag := false, EtaSuffix := ""
    BtnStop.Enabled := true
    name := ProcessCurrentDataset()
    if (name != "")
        SetStatus("Done:  " name ".csv  +  " name ".bmp  saved.")
    else if StopFlag
        SetStatus("Stopped.`n(Close any dialog still open in Vision64 before continuing.)")
    Busy := false
    BtnStop.Enabled := false
    UpdateUi()
}

DoBatch() {
    global Busy, StopFlag, BtnStop, EtaSuffix, TraceNames, TracePaths, NameIndex
    global OpenBtnX, Vision64Win, OutputDir, AvgSecs, IniFile, ShortDelay, NextDelay
    if Busy
        return
    if (TraceNames.Length = 0) {
        SetStatus("Pick the trace files first ('Pick trace files...').")
        return
    }
    if (NameIndex > TraceNames.Length)
        NameIndex := 1                                  ; finished list: start over
    n := TraceNames.Length - NameIndex + 1
    est := ""
    if (AvgSecs > 0)
        est := "`n`nEstimated time:  about " FormatSecs(AvgSecs * n)
             . "  (finishing around "
             . FormatTime(DateAdd(A_Now, Round(AvgSecs * n), "Seconds"), "HH:mm") ")."
    if MsgBox("Export " n " trace(s), starting from '" TraceNames[NameIndex] "'?" est
            . "`n`nThe script opens each file in Vision64 itself."
            . "`nDon't touch mouse or keyboard until it finishes (STOP or Esc aborts).",
            "Batch export", "YesNo Icon?") != "Yes"
        return
    if (OpenBtnX = "") {
        SetStatus("Batch needs the Open button: hover it in Vision64 and press F12, then F7 again.")
        return
    }
    if (Vision64Win = "" || !WinExist(Vision64Win))
        Vision64Win := FindVision64Window()
    if (Vision64Win = "") {
        SetStatus("Vision64 window not found - is Vision64 running?")
        return
    }

    Busy := true, StopFlag := false
    BtnStop.Enabled := true
    LogLine "----- Batch started: " n " file(s) -----"
    ok := 0, t0 := A_TickCount, firstSecs := 0
    EtaSuffix := (AvgSecs > 0)
        ? "`nEstimated total: about " FormatSecs(AvgSecs * n) " for " n " file(s)"
        : ""
    Loop n {
        if StopFlag
            break
        SetStatus("Batch (" A_Index " of " n "):  opening " TraceNames[NameIndex] " ...")
        if !OpenTraceFile(TracePaths[NameIndex]) {
            SetStatus("PROBLEM: could not open " TraceNames[NameIndex] " via Open > Dataset."
                . "`nCheck the F12 calibration, then press F7 to resume."
                . "`nDetails in Vision64_ExportLog.txt.")
            break
        }
        SetStatus("Batch (" A_Index " of " n "):  exporting " TraceNames[NameIndex] " ...")
        name := ProcessCurrentDataset()
        if (name = "")
            break
        ok += 1
        elapsed := (A_TickCount - t0) / 1000
        if (ok = 1)
            firstSecs := elapsed                        ; first file sets the estimate
        EtaSuffix := EtaText(elapsed, firstSecs, ok, n)
        UpdateUi()
        SetStatus("Batch:  " ok " of " n " done (" name ").")
    }
    Busy := false
    BtnStop.Enabled := false
    took := (A_TickCount - t0) / 1000
    if (ok > 0) {
        AvgSecs := took / ok
        IniWrite Round(AvgSecs, 2), IniFile, "Settings", "AvgSecs"
    }
    EtaSuffix := ""
    UpdateUi()
    LogLine "----- Batch ended: " ok " of " n " done in " Round(took) "s -----"
    if StopFlag
        SetStatus("Stopped after " ok " of " n " file(s) - " FormatSecs(took) "."
            . "`nF7 resumes from the next trace.")
    else if (ok = n)
        SetStatus("Batch finished:  " ok " of " n " files in " FormatSecs(took)
            . "  (" Round(AvgSecs, 1) "s per file)`nSaved to " OutputDir)
    else
        SetStatus(StatusText.Text "`nStopped after " ok " of " n
            . ". See Vision64_ExportLog.txt.")
}

;=============================================================================
;  CORE  -  one trace: CSV + BMP + clipboard
;=============================================================================
ProcessCurrentDataset() {
    global OutputDir, PlotX, PlotY, CopyBtnX, CopyBtnY, Vision64Win, StopFlag
    global TraceNames, TracePaths, NameIndex, NameCounter
    global CsvMenuKeys, BitmapItemKeys, ExportDlgTitles, BmpDlgTitles
    global ShortDelay, MenuDelay, DlgTimeout

    if (OutputDir = "" || PlotX = "" || CopyBtnX = "") {
        SetStatus("Not ready - finish the steps shown above first.")
        UpdateUi()
        return ""
    }
    if (Vision64Win = "" || !WinExist(Vision64Win))
        Vision64Win := FindVision64Window()
    if (Vision64Win = "") {
        SetStatus("Vision64 window not found - is Vision64 running?")
        LogLine "ERROR: Vision64 window not found"
        return ""
    }
    if StopFlag
        return ""
    DirCreate OutputDir
    MoveGuiOutOfTheWay()

    if (TraceNames.Length > 0 && NameIndex <= TraceNames.Length)
        name := TraceNames[NameIndex]
    else
        name := Format("trace_{:03}", NameCounter + 1)
    LogLine "--- Exporting '" name "' ---"

    ; ---------- 1) right-click the plot -> Export Data (retried) ------------
    SetStatus("Working (" name "):  opening Export Data ...")
    dlg := 0
    Loop 3 {
        LogLine "Step 1: right-click plot at " PlotX "," PlotY " (attempt " A_Index ")"
        WinActivate Vision64Win
        Z(ShortDelay)
        Click PlotX, PlotY, "Right"
        Z(MenuDelay)
        Send CsvMenuKeys
        dlg := WaitAnyDialog(ExportDlgTitles, (A_Index = 1) ? 5 : DlgTimeout)
        if (dlg != 0)
            break
        Send "{Esc}"                       ; clear a stuck context menu
        Z(400)
        if StopFlag
            return ""
    }
    if (dlg = 0) {
        SetStatus("PROBLEM: the CSV save dialog never appeared after 3 tries."
            . "`nIf no menu opens where it right-clicks, redo the F10 calibration.")
        LogLine "ERROR: CSV save dialog never appeared"
        return ""
    }
    LogLine "Step 1 ok: dialog '" WinGetTitle(dlg) "'"

    ; ---------- 2) save the CSV --------------------------------------------
    SetStatus("Working (" name "):  saving CSV ...")
    ClearTarget(OutputDir "\" name ".csv")                 ; silent overwrite
    if !FillSaveDialog(dlg, OutputDir "\" name ".csv") {
        SetStatus("PROBLEM: the CSV save dialog did not close - check Vision64.")
        LogLine "ERROR: CSV save dialog did not close"
        return ""
    }
    if WaitForFile(OutputDir "\" name ".csv", 8)
        LogLine "Step 2 ok: " name ".csv saved"
    else
        LogLine "WARNING: " name ".csv not on disk yet (continuing)"
    Z(ShortDelay)
    if StopFlag {
        LogLine "Aborted after CSV of '" name "'"
        return ""
    }

    ; ---------- 3) Copy To Clipboard dropdown -> Save As Bitmap ------------
    SetStatus("Working (" name "):  saving BMP ...")
    bmpDlg := 0
    Loop 3 {
        LogLine "Step 3: click Copy arrow at " CopyBtnX "," CopyBtnY " (attempt " A_Index ")"
        WinActivate Vision64Win
        Z(ShortDelay)
        Click CopyBtnX, CopyBtnY
        Z(MenuDelay)
        Send BitmapItemKeys
        bmpDlg := WaitAnyDialog(BmpDlgTitles, (A_Index = 1) ? 5 : DlgTimeout)
        if (bmpDlg != 0)
            break
        Send "{Esc}"
        Z(400)
        if StopFlag
            return ""
    }
    if (bmpDlg = 0) {
        SetStatus("PROBLEM: 'Save As Bitmap' never opened after 3 tries."
            . "`nRedo the F11 calibration (the LITTLE ARROW of Copy To Clipboard).")
        LogLine "ERROR: Save As Bitmap dialog never appeared"
        return ""
    }
    LogLine "Step 3 ok: dialog '" WinGetTitle(bmpDlg) "'"
    ClearTarget(OutputDir "\" name ".bmp")
    if !FillSaveDialog(bmpDlg, OutputDir "\" name ".bmp") {
        SetStatus("PROBLEM: the bitmap save dialog did not close - check Vision64.")
        LogLine "ERROR: bitmap save dialog did not close"
        return ""
    }
    if !WaitForFile(OutputDir "\" name ".bmp", 8) {
        SetStatus("PROBLEM: " name ".bmp did not appear in the folder.")
        LogLine "ERROR: " name ".bmp not found after save"
        return ""
    }
    LogLine "Step 4 ok: " name ".bmp saved"

    ; ---------- 4) put the saved image on the clipboard --------------------
    if SetClipboardFromBmpFile(OutputDir "\" name ".bmp")
        LogLine "Step 5 ok: image on clipboard"

    if (TraceNames.Length > 0 && NameIndex <= TraceNames.Length)
        NameIndex += 1
    else
        NameCounter += 1
    LogLine "--- '" name "' done ---"
    return name
}

; Opens one trace file: ribbon Open button -> "Dataset" -> Open Dataset dialog.
OpenTraceFile(path) {
    global Vision64Win, OpenBtnX, OpenBtnY, OpenMenuKeys, OpenDlgTitles
    global ShortDelay, MenuDelay, NextDelay, StopFlag
    if (Vision64Win = "" || !WinExist(Vision64Win)) {
        Vision64Win := FindVision64Window()
        if (Vision64Win = "") {
            LogLine "ERROR: Vision64 window not found (open)"
            return false
        }
    }
    MoveGuiOutOfTheWay()
    dlg := 0
    Loop 3 {
        LogLine "Open: click Open button at " OpenBtnX "," OpenBtnY " -> Dataset (attempt " A_Index ")"
        WinActivate Vision64Win
        Z(ShortDelay)
        Click OpenBtnX, OpenBtnY
        Z(MenuDelay)
        Send OpenMenuKeys
        dlg := WaitAnyDialog(OpenDlgTitles, (A_Index = 1) ? 5 : 8)
        if (dlg != 0)
            break
        Send "{Esc}"
        Z(400)
        if StopFlag
            return false
    }
    if (dlg = 0) {
        LogLine "ERROR: Open Dataset dialog never appeared"
        return false
    }
    LogLine "Open: dialog '" WinGetTitle(dlg) "'"
    if !FillSaveDialog(dlg, path) {
        LogLine "ERROR: Open Dataset dialog did not close"
        return false
    }
    LogLine "Opened: " path
    Z(NextDelay)
    return true
}

;=============================================================================
;  DIALOG HANDLING
;=============================================================================
; Accepts ONLY a real dialog (class #32770) that belongs to VISION64's own
; process. This is what keeps the script from grabbing one of your other
; windows whose name happens to contain "Export" or "Save" - e.g. an Explorer
; folder called "BatchExport", which used to swallow the path and hang a run.
WaitAnyDialog(titles, timeoutSec) {
    global Vision64Win
    pid := 0
    try pid := WinGetPID(Vision64Win)
    deadline := A_TickCount + timeoutSec * 1000
    while (A_TickCount < deadline) {
        loose := 0
        for hwnd in WinGetList("ahk_class #32770") {
            if (pid) {
                wpid := 0
                try wpid := WinGetPID(hwnd)
                if (wpid != pid)
                    continue
            }
            t := ""
            try t := WinGetTitle(hwnd)
            for want in titles {
                if InStr(t, want)
                    return hwnd
            }
            if !loose
                loose := hwnd
        }
        if (loose && A_TickCount > deadline - 1500) {   ; Vision64 dialog, other name
            try LogLine "NOTE: using Vision64 dialog '" WinGetTitle(loose) "'"
            return loose
        }
        Sleep 80
    }
    return 0
}

; Types a full path into a save/open dialog and confirms it.
FillSaveDialog(dlg, fullPath) {
    global DlgTimeout, SlowMode
    WinActivate dlg
    WinWaitActive dlg, , 2
    Z(200)
    done := false
    try {
        ControlSetText fullPath, "Edit1", dlg
        Sleep 60
        done := (ControlGetText("Edit1", dlg) = fullPath)
    }
    if !done {
        Send "!n"                       ; Alt+N = File name box
        Z(120)
        Send "^a"
        Z(60)
        SendText fullPath
        Z(100)
    }
    Send "{Enter}"
    Sleep 150
    if WinExist(dlg)                    ; still open => something blocks it
        AnswerOverwritePrompt(dlg)
    return WinWaitClose(dlg, , DlgTimeout)
}

; Answers a blocking "file already exists / replace?" prompt with Yes.
; Targets are deleted beforehand, so this is only a safety net.
AnswerOverwritePrompt(dlg) {
    Loop 8 {
        hwnd := WinExist("ahk_class #32770")
        if (hwnd && hwnd != dlg) {
            txt := ""
            try txt := WinGetText(hwnd)
            if InStr(txt, "already exist") || InStr(txt, "eplace") || InStr(txt, "verwrite") {
                LogLine "Overwrite prompt answered: Yes"
                Send "!y"
                Sleep 120
                Send "{Enter}"
                return true
            }
        }
        Sleep 100
    }
    return false
}

;=============================================================================
;  HELPERS
;=============================================================================
Z(ms) {
    global SlowMode, StopFlag
    total := SlowMode ? ms * 3 : ms
    while (total > 0 && !StopFlag) {
        chunk := Min(total, 50)
        Sleep chunk
        total -= chunk
    }
}

LogLine(msg) {
    global LogFile
    try FileAppend FormatTime(, "HH:mm:ss") "  " msg "`n", LogFile
}

HandleScriptError(err, mode) {
    global Busy, BtnStop
    try LogLine "SCRIPT ERROR: " err.Message " (line " err.Line ")"
    try SetStatus("Unexpected error: " err.Message
        . "`nThe run stopped - details in Vision64_ExportLog.txt."
        . "`nPress F7 to continue from the next file.")
    try {
        Busy := false
        BtnStop.Enabled := false
    }
    return 1                            ; never show AHK's modal error box
}

; Deletes an existing output file so a repeat run overwrites without asking.
ClearTarget(path) {
    if !FileExist(path)
        return
    Loop 10 {
        try {
            FileDelete path
            return
        }
        Sleep 100
    }
    LogLine "NOTE: could not delete " path " (will answer the overwrite prompt)"
}

WaitForFile(path, timeoutSec) {
    global StopFlag
    deadline := A_TickCount + timeoutSec * 1000
    while (A_TickCount < deadline && !StopFlag) {
        if FileExist(path)
            return true
        Sleep 100
    }
    return false
}

; Time line based on the FIRST file's duration x the number of files.
EtaText(elapsed, firstSecs, done, total) {
    per := (firstSecs > 0) ? firstSecs : (done > 0 ? elapsed / done : 0)
    if (per <= 0)
        return ""
    left := per * (total - done)
    out := "`n" FormatSecs(elapsed) " elapsed"
    if (total - done > 0)
        out .= "  |  about " FormatSecs(left) " left  |  done around "
             . FormatTime(DateAdd(A_Now, Round(left), "Seconds"), "HH:mm")
    out .= "  (" Round(per, 1) "s per file)"
    return out
}

FormatSecs(s) {
    s := Round(s)
    if (s < 60)
        return s "s"
    return Format("{}m {:02}s", s // 60, Mod(s, 60))
}

; Sorts like Windows Explorer: D50 < D100 < D1000.
NaturalSortPairs(arr) {
    Loop arr.Length - 1 {
        i := A_Index + 1
        v := arr[i]
        j := i - 1
        while (j >= 1 && DllCall("shlwapi\StrCmpLogicalW", "wstr", arr[j][1], "wstr", v[1], "int") > 0) {
            arr[j + 1] := arr[j]
            j -= 1
        }
        arr[j + 1] := v
    }
    return arr
}

SaveTraceList() {
    global ListFile, TracePaths
    try {
        if FileExist(ListFile)
            FileDelete ListFile
        txt := ""
        for p in TracePaths
            txt .= p "`n"
        FileAppend txt, ListFile
    }
}

LoadTraceList() {
    global ListFile, TraceNames, TracePaths, NameIndex
    if !FileExist(ListFile)
        return
    try {
        TraceNames := [], TracePaths := []
        for line in StrSplit(FileRead(ListFile), "`n", "`r") {
            line := Trim(line)
            if (line = "" || !FileExist(line))
                continue
            SplitPath line, , , , &base
            TracePaths.Push(line)
            TraceNames.Push(base)
        }
        NameIndex := 1
    }
}

; Keeps the panel from covering a spot the script has to click.
MoveGuiOutOfTheWay() {
    global MainGui, PlotX, PlotY, CopyBtnX, CopyBtnY, OpenBtnX, OpenBtnY
    try {
        if (WinGetMinMax("ahk_id " MainGui.Hwnd) = -1)
            return                       ; minimized - out of the way already
        MainGui.GetPos(&gx, &gy, &gw, &gh)
        pad := 10
        hit(px, py) => (px != "" && px >= gx - pad && px <= gx + gw + pad
                     && py >= gy - pad && py <= gy + gh + pad)
        if !(hit(PlotX, PlotY) || hit(CopyBtnX, CopyBtnY) || hit(OpenBtnX, OpenBtnY))
            return
        for pos in [[A_ScreenWidth - gw - 20, A_ScreenHeight - gh - 60],
                    [20, A_ScreenHeight - gh - 60],
                    [A_ScreenWidth - gw - 20, 20], [20, 20]] {
            gx := pos[1], gy := pos[2]
            if !(hit(PlotX, PlotY) || hit(CopyBtnX, CopyBtnY) || hit(OpenBtnX, OpenBtnY)) {
                MainGui.Move(gx, gy)
                LogLine "Panel moved to " gx "," gy
                Sleep 250
                return
            }
        }
    }
}

FindVision64Window() {
    for crit in ["ahk_exe Vision64.exe", "ahk_exe Vision.exe",
                 "ahk_exe Vision64App.exe", "Vision64", "Vision 64", "Dektak"] {
        if WinExist(crit, , "Export Helper")
            return crit
    }
    titles := [], exes := []
    for id in WinGetList() {
        t := WinGetTitle("ahk_id " id)
        if (t = "" || t = "Program Manager" || InStr(t, "Export Helper"))
            continue
        e := ""
        try e := WinGetProcessName("ahk_id " id)
        if (e = "")
            continue
        titles.Push(t), exes.Push(e)
    }
    if (titles.Length = 0)
        return ""
    display := []
    for i, t in titles
        display.Push(t "    [" exes[i] "]")
    choice := 0, done := false
    g := Gui("+AlwaysOnTop", "Which window is Vision64?")
    g.Add("Text", , "Couldn't find Vision64 automatically. Pick its window:")
    lb := g.Add("ListBox", "w560 r14 Choose1", display)
    g.Add("Button", "Default w80", "OK").OnEvent("Click",
        (*) => (choice := lb.Value, done := true, g.Destroy()))
    g.Add("Button", "x+10 w80", "Cancel").OnEvent("Click", (*) => (done := true, g.Destroy()))
    g.OnEvent("Close", (*) => done := true)
    g.OnEvent("Escape", (*) => (done := true, g.Destroy()))
    g.Show()
    while !done
        Sleep 100
    return (choice = 0) ? "" : "ahk_exe " exes[choice]
}

; Reads a saved .bmp and puts it on the clipboard. Waits out the file lock
; Vision64 can still hold right after writing (this used to crash a repeat run).
SetClipboardFromBmpFile(path) {
    f := 0
    Loop 40 {
        try {
            f := FileOpen(path, "r")
            if (f)
                break
        }
        f := 0
        Sleep 100
    }
    if !f {
        LogLine "NOTE: " path " locked - clipboard copy skipped"
        return false
    }
    ok := false
    try {
        size := f.Length
        if (size > 14) {
            buf := Buffer(size)
            f.RawRead(buf, size)
            f.Close()
            f := 0
            dibSize := size - 14
            hMem := DllCall("GlobalAlloc", "uint", 0x42, "uptr", dibSize, "ptr")
            if hMem {
                pMem := DllCall("GlobalLock", "ptr", hMem, "ptr")
                DllCall("RtlMoveMemory", "ptr", pMem, "ptr", buf.Ptr + 14, "uptr", dibSize)
                DllCall("GlobalUnlock", "ptr", hMem)
                if DllCall("OpenClipboard", "ptr", 0) {
                    DllCall("EmptyClipboard")
                    r := DllCall("SetClipboardData", "uint", 8, "ptr", hMem, "ptr")
                    DllCall("CloseClipboard")
                    if r
                        ok := true
                    else
                        DllCall("GlobalFree", "ptr", hMem)
                } else {
                    DllCall("GlobalFree", "ptr", hMem)
                }
            }
        }
    }
    try {
        if (f)
            f.Close()
    }
    return ok
}
