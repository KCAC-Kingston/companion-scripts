@echo off
setlocal
set "SHUTDOWN_COUNTDOWN_BAT=%~f0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "$src = [System.IO.File]::ReadAllText($env:SHUTDOWN_COUNTDOWN_BAT); $tag = '# POWERSHELL_PAYLOAD_START'; $offset = $src.LastIndexOf($tag); if ($offset -lt 0) { exit 1 }; & ([ScriptBlock]::Create($src.Substring($offset + $tag.Length)))"
exit /b

# POWERSHELL_PAYLOAD_START
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Match executable process names (without .exe).
$appNames = @{
    'WINWORD'  = 'Microsoft Word'
    'EXCEL'    = 'Microsoft Excel'
    'POWERPNT' = 'Microsoft PowerPoint'
    'obs64'    = 'OBS Studio'
    'obs32'    = 'OBS Studio'
    'openlp'   = 'OpenLP'
}
$runningApps = @(
    Get-Process -ErrorAction SilentlyContinue |
        ForEach-Object { $appNames[$_.ProcessName] } |
        Where-Object { $_ } |
        Select-Object -Unique
)
$hasWarning = $runningApps.Count -gt 0
$countdownSeconds = if ($hasWarning) { 180 } else { 30 }

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Shutdown Countdown'
$formHeight = if ($hasWarning) { 310 } else { 225 }
$form.ClientSize = [System.Drawing.Size]::new(440, $formHeight)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true
$form.ShowInTaskbar = $true
$form.BackColor = [System.Drawing.Color]::White

$heading = New-Object System.Windows.Forms.Label
$heading.Text = 'Your computer will shut down in'
$heading.TextAlign = 'MiddleCenter'
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 12)
$heading.SetBounds(15, 19, 410, 34)
$form.Controls.Add($heading)

$remaining = New-Object System.Windows.Forms.Label
$remaining.Text = [TimeSpan]::FromSeconds($countdownSeconds).ToString('mm\:ss')
$remaining.TextAlign = 'MiddleCenter'
$remaining.Font = New-Object System.Drawing.Font('Segoe UI', 29, [System.Drawing.FontStyle]::Bold)
$remaining.ForeColor = [System.Drawing.Color]::FromArgb(173, 33, 33)
$remaining.SetBounds(15, 55, 410, 65)
$form.Controls.Add($remaining)

if ($hasWarning) {
    $warning = New-Object System.Windows.Forms.Label
    $warning.Text = "WARNING: These apps are running: $($runningApps -join ', ')`r`nSave your work and stop recordings/presentations before shutdown."
    $warning.TextAlign = 'MiddleCenter'
    $warning.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $warning.ForeColor = [System.Drawing.Color]::FromArgb(160, 70, 0)
    $warning.SetBounds(20, 130, 400, 88)
    $form.Controls.Add($warning)
}

$buttonY = if ($hasWarning) { 235 } else { 143 }
$shutdownNow = New-Object System.Windows.Forms.Button
$shutdownNow.Text = 'Shut Down Now'
$shutdownNow.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$shutdownNow.SetBounds(54, $buttonY, 152, 44)
$form.Controls.Add($shutdownNow)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$cancel.SetBounds(234, $buttonY, 152, 44)
$form.Controls.Add($cancel)
$form.CancelButton = $cancel

$script:deadline = [DateTime]::UtcNow.AddSeconds($countdownSeconds)
$script:shutdownStarted = $false
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200

$shutdownAction = {
    if ($script:shutdownStarted) { return }
    $script:shutdownStarted = $true
    $timer.Stop()
    $shutdownNow.Enabled = $false
    $cancel.Enabled = $false
    try {
        # /t 0 avoids forcing apps to close; unsaved work may block Windows shutdown.
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList @('/s', '/t', '0') -WindowStyle Hidden -ErrorAction Stop
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Unable to start shutdown:`r`n$($_.Exception.Message)", 'Shutdown Error', 'OK', 'Error') | Out-Null
        $form.Close()
    }
}

$shutdownNow.Add_Click($shutdownAction)
$cancel.Add_Click({ $timer.Stop(); $form.Close() })
$form.Add_FormClosing({ $timer.Stop() })
$timer.Add_Tick({
    $seconds = [int][Math]::Max(0, [Math]::Ceiling(($script:deadline - [DateTime]::UtcNow).TotalSeconds))
    $remaining.Text = [TimeSpan]::FromSeconds($seconds).ToString('mm\:ss')
    if ($seconds -eq 0) { & $shutdownAction }
})
$form.Add_Shown({
    $form.TopMost = $true
    $form.BringToFront()
    $form.Activate()
    $script:deadline = [DateTime]::UtcNow.AddSeconds($countdownSeconds)
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($form)
