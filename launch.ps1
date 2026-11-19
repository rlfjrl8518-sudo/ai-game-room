# AI 대국실 실행기: 게임 창을 띄우고, 투명도·항상 위 조절 패널을 붙인다.
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr h, uint k, byte a, uint f);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  public static IntPtr Find(string prefix) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => { var sb = new System.Text.StringBuilder(256); GetWindowText(h, sb, 256);
      if (IsWindowVisible(h) && sb.ToString().StartsWith(prefix)) { found = h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
}
"@

$title = 'AI 대국실 데스크톱'
$edge  = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
$page  = 'file:///' + ("$PSScriptRoot\index.html" -replace '\\','/')

$hwnd = [W]::Find($title)
if ($hwnd -eq [IntPtr]::Zero) {
  Start-Process $edge "--app=`"$page`" --window-size=1000,780"
  for ($i = 0; $i -lt 50 -and $hwnd -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 200; $hwnd = [W]::Find($title) }
}
if ($hwnd -eq [IntPtr]::Zero) { [Windows.Forms.MessageBox]::Show('게임 창을 찾지 못했습니다. 다시 실행해 주세요.') | Out-Null; exit }

[W]::ShowWindow($hwnd, 9) | Out-Null; [W]::SetForegroundWindow($hwnd) | Out-Null
# 투명 창 스타일 켜기
[W]::SetWindowLong($hwnd, -20, ([W]::GetWindowLong($hwnd, -20) -bor 0x80000)) | Out-Null
function Set-Alpha($pct) { [W]::SetLayeredWindowAttributes($hwnd, 0, [byte][math]::Round(255 * $pct / 100), 2) | Out-Null }
function Set-Top($on)    { [W]::SetWindowPos($hwnd, [IntPtr]$(if ($on) { -1 } else { -2 }), 0, 0, 0, 0, 3) | Out-Null }

$f = New-Object Windows.Forms.Form
$f.Text = '대국실 창 조절'; $f.TopMost = $true; $f.FormBorderStyle = 'FixedToolWindow'
$f.ClientSize = '260,110'; $f.StartPosition = 'Manual'
$f.Location = New-Object Drawing.Point(([Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Right - 280), 40)
$f.Font = New-Object Drawing.Font('Malgun Gothic', 9)

$lbl = New-Object Windows.Forms.Label; $lbl.Text = '투명도 100%'; $lbl.Location = '12,10'; $lbl.AutoSize = $true
$bar = New-Object Windows.Forms.TrackBar; $bar.Minimum = 20; $bar.Maximum = 100; $bar.Value = 100
$bar.TickFrequency = 10; $bar.Location = '8,30'; $bar.Width = 244
$bar.Add_ValueChanged({ Set-Alpha $bar.Value; $lbl.Text = "투명도 $($bar.Value)%" })
$chk = New-Object Windows.Forms.CheckBox; $chk.Text = '항상 위에 표시'; $chk.Checked = $true; $chk.Location = '12,80'; $chk.AutoSize = $true
$chk.Add_CheckedChanged({ Set-Top $chk.Checked })
$f.Controls.AddRange(@($lbl, $bar, $chk))

Set-Alpha 100; Set-Top $true
# 게임 창을 닫으면 패널도 닫힘
$t = New-Object Windows.Forms.Timer; $t.Interval = 1000; $t.Add_Tick({ if (-not [W]::IsWindow($hwnd)) { $f.Close() } }); $t.Start()
[Windows.Forms.Application]::Run($f)
