# GResizer 2.0

GResizer is a lightweight window-resizing utility intended for **Battlefield 6**.  
It allows you to play in **windowed mode** with precise control over resolution, aspect ratio, and taskbar-safe positioning.

> ⚠️ This tool does **not** modify game files and does **not** bypass anti-cheat.  
> It simply resizes an already-running game window using Windows APIs.

---

## Features

- Preset aspect ratios (16:9, 21:9, 32:9)
- Common resolution presets
- Taskbar-safe resizing (auto-detects taskbar position)
- Gap correction for invisible Windows borders
- GUI-based — no command line usage required

---

## Requirements

- Windows 10 or Windows 11
- Battlefield 6 running in **Windowed** or **Borderless Windowed** mode
- (For `.ps1` version) PowerShell 5.1+ or PowerShell 7+

---

## Option 1: Run the EXE (Recommended)

### Steps

1. Download **`GResizer2.exe`**
2. Double-click to launch
3. Start Battlefield 6 and wait until you reach the **main menu**
4. In GResizer:
   - Select aspect ratio
   - Select resolution
   - (Optional) Enable **Taskbar-safe**
   - Adjust **Gap correction** if needed
5. Click **Execute**

The window will resize and center automatically.

### Notes
- If Windows SmartScreen appears, click **More info → Run anyway**
- The tool will minimize itself after execution (by design)

---

## Option 2: Run the PowerShell Script (`.ps1`)

### Step 1: Allow script execution (one-time)

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
cd path\to\gresizer
.\resizebf6gui_v2.ps1
```

### Enjoying GResizer?
If it helped your Battlefield 6 experience, you can show some love [here](https://buymeacoffee.com/andydoes). ❤️