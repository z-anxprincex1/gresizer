Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------- Win32: Enumerate windows + MoveWindow ----------------
if (-not ("Win32" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
}
"@
}

# ---------------- Taskbar: SHAppBarMessage(ABM_GETTASKBARPOS) ----------------
if (-not ("Taskbar" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Taskbar {
    public const int ABM_GETTASKBARPOS = 5;

    // uEdge: 0=left, 1=top, 2=right, 3=bottom
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int left, top, right, bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct APPBARDATA {
        public int cbSize;
        public IntPtr hWnd;
        public uint uCallbackMessage;
        public uint uEdge;
        public RECT rc;
        public int lParam;
    }

    [DllImport("shell32.dll")]
    public static extern uint SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);
}
"@
}

function Get-TaskbarInfo {
    $abd = New-Object Taskbar+APPBARDATA
    $abd.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($abd)
    $ret = [Taskbar]::SHAppBarMessage([Taskbar]::ABM_GETTASKBARPOS, [ref]$abd)

    [pscustomobject]@{
        Ok   = ($ret -ne 0)
        Edge = [int]$abd.uEdge
        Rect = $abd.rc
    }
}

function Get-WindowHandleByTitleContains([string]$contains) {
    $script:found = [IntPtr]::Zero

    $delegate = [Win32+EnumWindowsProc]{
        param($hWnd, $lParam)
        if (-not [Win32]::IsWindowVisible($hWnd)) { return $true }

        $sb = New-Object System.Text.StringBuilder 512
        [void][Win32]::GetWindowText($hWnd, $sb, $sb.Capacity)
        $title = $sb.ToString()

        if ($title -and $title -like "*$contains*") {
            $script:found = $hWnd
            return $false
        }
        return $true
    }

    [Win32]::EnumWindows($delegate, [IntPtr]::Zero) | Out-Null
    return $script:found
}

function Parse-Resolution([string]$res) {
    if ($res -notmatch "^\s*(\d+)\s*x\s*(\d+)\s*$") { return $null }
    return @([int]$matches[1], [int]$matches[2])
}

# ---------------- Presets ----------------
$presets = [ordered]@{
    "16:9" = @("1920x1080","2560x1440","3840x2160","1600x900","1280x720")
    "21:9" = @("2560x1080","3440x1440","3840x1600","3200x1350","2880x1200","1920x800")
    "32:9" = @("3840x1080","5120x1440","5120x2160")
}

# ---------------- GUI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "GResizer 2.0"
$form.Size = New-Object System.Drawing.Size(640, 340)
$form.StartPosition = "CenterScreen"
$form.TopMost = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
)
$font = New-Object System.Drawing.Font("Segoe UI", 10)

# Aspect
$lblAspect = New-Object System.Windows.Forms.Label
$lblAspect.Text = "Aspect ratio:"
$lblAspect.Location = New-Object System.Drawing.Point(20, 20)
$lblAspect.AutoSize = $true
$lblAspect.Font = $font
$form.Controls.Add($lblAspect)

$cmbAspect = New-Object System.Windows.Forms.ComboBox
$cmbAspect.Location = New-Object System.Drawing.Point(180, 16)
$cmbAspect.Size = New-Object System.Drawing.Size(400, 30)
$cmbAspect.DropDownStyle = "DropDownList"
$cmbAspect.Font = $font
[void]$cmbAspect.Items.AddRange(@($presets.Keys))
$cmbAspect.SelectedItem = "21:9"
$form.Controls.Add($cmbAspect)

# Resolution
$lblRes = New-Object System.Windows.Forms.Label
$lblRes.Text = "Resolution:"
$lblRes.Location = New-Object System.Drawing.Point(20, 65)
$lblRes.AutoSize = $true
$lblRes.Font = $font
$form.Controls.Add($lblRes)

$cmbRes = New-Object System.Windows.Forms.ComboBox
$cmbRes.Location = New-Object System.Drawing.Point(180, 61)
$cmbRes.Size = New-Object System.Drawing.Size(400, 30)
$cmbRes.DropDownStyle = "DropDownList"
$cmbRes.Font = $font
$form.Controls.Add($cmbRes)

# Taskbar-safe checkbox
$chkTaskbarSafe = New-Object System.Windows.Forms.CheckBox
$chkTaskbarSafe.Text = "Taskbar-safe (auto-detect taskbar and shrink if needed)"
$chkTaskbarSafe.Location = New-Object System.Drawing.Point(20, 110)
$chkTaskbarSafe.Size = New-Object System.Drawing.Size(560, 28)
$chkTaskbarSafe.Checked = $true
$chkTaskbarSafe.Font = $font
$form.Controls.Add($chkTaskbarSafe)

# Gap correction (can be negative)
$lblGap = New-Object System.Windows.Forms.Label
$lblGap.Text = "Gap correction (px)  (use 8 if you still see a gap):"
$lblGap.Location = New-Object System.Drawing.Point(20, 150)
$lblGap.AutoSize = $true
$lblGap.Font = $font
$form.Controls.Add($lblGap)

$numGap = New-Object System.Windows.Forms.NumericUpDown
$numGap.Location = New-Object System.Drawing.Point(20, 180)
$numGap.Size = New-Object System.Drawing.Size(120, 30)
$numGap.Minimum = -50
$numGap.Maximum = 50
$numGap.Value = 8
$numGap.Font = $font
$form.Controls.Add($numGap)

# Title contains
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Window title contains:"
$lblTitle.Location = New-Object System.Drawing.Point(180, 150)
$lblTitle.AutoSize = $true
$lblTitle.Font = $font
$form.Controls.Add($lblTitle)

$txtTitle = New-Object System.Windows.Forms.TextBox
$txtTitle.Location = New-Object System.Drawing.Point(180, 180)
$txtTitle.Size = New-Object System.Drawing.Size(400, 30)
$txtTitle.Font = $font
$txtTitle.Text = "Battlefield"
$form.Controls.Add($txtTitle)

# Execute button
$btnExec = New-Object System.Windows.Forms.Button
$btnExec.Text = "Execute"
$btnExec.Location = New-Object System.Drawing.Point(20, 235)
$btnExec.Size = New-Object System.Drawing.Size(140, 42)
$btnExec.Font = $font
$form.Controls.Add($btnExec)

# Status
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Open Battlefield to the main menu, then click Execute."
$lblStatus.Location = New-Object System.Drawing.Point(180, 235)
$lblStatus.Size = New-Object System.Drawing.Size(400, 90)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($lblStatus)

function Update-ResolutionDropdown {
    $cmbRes.Items.Clear()
    $aspect = [string]$cmbAspect.SelectedItem
    if (-not $aspect) { return }
    [void]$cmbRes.Items.AddRange($presets[$aspect])

    $default = switch ($aspect) {
        "21:9" { "2560x1080" }
        "16:9" { "1920x1080" }
        "32:9" { "5120x1440" }
        default { $presets[$aspect][0] }
    }

    $idx = $cmbRes.Items.IndexOf($default)
    if ($idx -ge 0) { $cmbRes.SelectedIndex = $idx } else { $cmbRes.SelectedIndex = 0 }
}

$cmbAspect.Add_SelectedIndexChanged({ Update-ResolutionDropdown })
Update-ResolutionDropdown

# ---------------- Execute logic ----------------
$btnExec.Add_Click({
    try {
        $lblStatus.Text = "Searching for Battlefield window..."
        $lblStatus.Refresh()

        $titleContains = $txtTitle.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($titleContains)) { $titleContains = "Battlefield" }

        $hWnd = Get-WindowHandleByTitleContains $titleContains
        if ($hWnd -eq [IntPtr]::Zero) {
            $lblStatus.Text = "❌ Window not found. Is the game open & not minimized?"
            return
        }

        $res = [string]$cmbRes.SelectedItem
        $parsed = Parse-Resolution $res
        if (-not $parsed) {
            $lblStatus.Text = "❌ Invalid resolution."
            return
        }

        $w = $parsed[0]
        $h = $parsed[1]

        # Screen bounds (keep simple)
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds

        # Safe area starts as full screen
        $safeLeft   = $bounds.Left
        $safeTop    = $bounds.Top
        $safeRight  = $bounds.Right
        $safeBottom = $bounds.Bottom

        $gapCorrection = [int]$numGap.Value

        if ($chkTaskbarSafe.Checked) {
            $tb = Get-TaskbarInfo
            if ($tb.Ok) {
                $r = $tb.Rect

                # overlap check with correct PowerShell operators
                $overlaps =
                    ($r.right  -gt $bounds.Left)  -and
                    ($r.left   -lt $bounds.Right) -and
                    ($r.bottom -gt $bounds.Top)   -and
                    ($r.top    -lt $bounds.Bottom)

                if ($overlaps) {
                    switch ($tb.Edge) {
                        0 { $safeLeft   = [Math]::Max($safeLeft,  $r.right  - $gapCorrection) }
                        1 { $safeTop    = [Math]::Max($safeTop,   $r.bottom - $gapCorrection) }
                        2 { $safeRight  = [Math]::Min($safeRight, $r.left   + $gapCorrection) }
                        3 { $safeBottom = [Math]::Min($safeBottom,$r.top    + $gapCorrection) }
                    }
                }
            }
        }

        $safeW = $safeRight - $safeLeft
        $safeH = $safeBottom - $safeTop

        if ($safeW -le 0 -or $safeH -le 0) {
            $lblStatus.Text = "❌ Safe area invalid."
            return
        }

        # Keep width fixed as much as possible; shrink if it doesn't fit
        if ($w -gt $safeW) { $w = $safeW }

        # Shrink HEIGHT to fit safe area (your requirement)
        if ($h -gt $safeH) { $h = $safeH }
        if ($h -lt 200) { $h = 200 }

        # Center inside safe area
        $x = [math]::Round($safeLeft + ($safeW - $w) / 2)
        $y = [math]::Round($safeTop  + ($safeH - $h) / 2)

        $ok = [Win32]::MoveWindow($hWnd, $x, $y, $w, $h, $true)
        if ($ok) {
            $lblStatus.Text = "✅ Done: ${w}x${h} | taskbarSafe=$($chkTaskbarSafe.Checked) | gapCorr=$gapCorrection"
        } else {
            $lblStatus.Text = "❌ MoveWindow failed. Try running PowerShell as Administrator."
        }
    } catch {
        $lblStatus.Text = "❌ Error: $($_.Exception.Message)"
    }
})

[void]$form.ShowDialog()
