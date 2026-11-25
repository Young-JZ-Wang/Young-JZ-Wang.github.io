# Vision64 Export Helper

**Developed by Young Wang** · Version 1.1 · November 2026

A guided Windows helper that batch-exports traces from Bruker **Vision64**
(DektakXT, Data Analysis view). For every trace file it saves, into a folder
you choose:

- `<original name>.csv` — via right-click → **Export Data**
- `<original name>.bmp` — via **Copy To Clipboard → Save As Bitmap…**
- and leaves the plot image on the clipboard, ready to paste

So `D500_100p_1.OPDx` becomes `D500_100p_1.csv` + `D500_100p_1.bmp`.

Vision64 has no scripting API, so the helper drives its menus exactly as a
person would — but deterministically, and with a log of every step.

## Getting AutoHotkey v2 (one time)

**Option A — portable, no installation, no admin rights (best for lab PCs)**

1. Download the AutoHotkey **v2 ZIP** from https://www.autohotkey.com/download/
   (the .zip, not the setup .exe).
2. Extract it and copy **`AutoHotkey64.exe`** next to `Vision64_BatchExport.ahk`.
3. Double-click **`Run_Vision64_Export.bat`** — it finds the portable exe (or an
   installed AutoHotkey) and starts the helper. Nothing is written to Windows.

**Option B — normal install:** run the AutoHotkey v2 setup, then double-click
`Vision64_BatchExport.ahk`.

**Option C — single .exe:** if the extracted ZIP has a `Compiler` folder, run
`Ahk2Exe.exe` with `Vision64_BatchExport.ahk` as the source and base file
`AutoHotkey64.exe`. The resulting .exe needs nothing installed at all.

## Setup — the panel walks you through it

| Step | What to do |
|------|------------|
| 1 | Hover the ribbon **Open** button in Vision64 → press **F12** |
| 2 | **Choose folder…** — where CSV/BMP files are saved |
| 3 | With a trace displayed, hover the **middle of the plot** → press **F10** |
| 4 | Hover the **little arrow** of **Copy To Clipboard** → press **F11** |
| 5 | **Pick trace files…** — select your files (Ctrl+A for all) |
| 6 | Press **F7** — the batch runs by itself |

All of it (folder, three calibrations, file list) is remembered, so later runs
open straight at **Step 6: Ready**. Redo any part with *Redo calibration* or
*Pick trace files…*.

## Running

- **F7 — Batch export all.** Opens each trace file itself (Open → Dataset →
  types the path), exports CSV + BMP, moves on. Files don't need to be open
  beforehand, and the displayed trace can never drift out of sync with the
  name being saved.
- **F8 — Export current trace.** Exports whatever trace is on screen.
- **STOP / Esc.** Aborts at the next safe point; the list resumes where it
  stopped. Esc quits the helper when nothing is running.
- **Minimize / F6.** Tuck the panel away; hotkeys keep working, F6 brings it
  back.
- **Slow mode.** Triples every delay if a PC needs more time.

## Time estimates

When the first file finishes, its duration × the number of files drives the
estimate, shown under the status line for the rest of the run:

```
Batch (3 of 20): exporting D150_100p_1 ...
32s elapsed  |  about 2m 40s left  |  done around 11:42  (8.0s per file)
```

Before the first file completes it uses the previous run's pace (remembered
between sessions). The final message reports the actual total.

## Re-running / overwriting

Existing `.csv` / `.bmp` files are replaced silently — targets are deleted
immediately before saving, so no "file already exists" prompt can appear. When
the whole list is finished, F7 simply starts over from the first file.

## Files kept next to the script

| File | Purpose |
|------|---------|
| `Vision64_BatchExport.ini` | folder, calibrations, slow mode, pace |
| `Vision64_TraceList.txt` | the trace files picked last time |
| `Vision64_ExportLog.txt` | every step, with timestamps |

## Troubleshooting

The status line explains problems in plain language; the log gives the detail.

- **A dialog never appears** — each menu step is retried 3×; if it still fails,
  redo the matching calibration (F10 plot, F11 copy arrow, F12 Open button).
  Recalibrate after moving/resizing the Vision64 window or changing resolution.
- **Names out of order** — click *Restart name list* and run F7 again.
- **F9** prints the active window's title and process, for diagnosing detection.

## Version history

**v1.1**
- Dialogs are matched only when they are real dialogs (class `#32770`)
  **belonging to Vision64's own process**. Previously a window of yours whose
  title merely contained "Export" — an Explorer folder named `BatchExport` —
  could be mistaken for the save dialog, which swallowed the file path and
  hung the run. This was the single biggest cause of instability.
- Every menu step (Export Data, Save As Bitmap, Open → Dataset) is retried up
  to 3 times before giving up.
- **Minimize** button plus **F6** to restore.
- Clipboard copy waits out Vision64's file lock instead of crashing.
- Silent overwrite; errors are logged, never shown as modal boxes.

**v1.0** — first working version: guided calibration, batch open/export,
CSV + BMP with original names, STOP, time estimates, persistent settings.

---

**Vision64 Export Helper — developed by Young Wang.** Built with AutoHotkey v2
for Bruker Vision64 (DektakXT).
