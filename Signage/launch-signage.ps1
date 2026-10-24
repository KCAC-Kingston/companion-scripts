Add-Type -AssemblyName System.Windows.Forms

# Find Chrome
$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

$chrome = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Google Chrome could not be found.")
    exit 1
}

# Find Windows DISPLAY2
$screen = [System.Windows.Forms.Screen]::AllScreens |
    Where-Object { $_.DeviceName -eq '\\.\DISPLAY2' } |
    Select-Object -First 1

# If DISPLAY2 isn't found, use the second detected monitor
if (-not $screen) {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    if ($screens.Count -ge 2) {
        $screen = $screens[1]
    }
    else {
        $screen = $screens[0]
    }
}

$x = $screen.Bounds.X
$y = $screen.Bounds.Y
$width = $screen.Bounds.Width
$height = $screen.Bounds.Height

$url = "https://servicemanager.kcac.ca/signage/announcements"

$args = @(
    "--user-data-dir=C:\ChromeSignage"
    "--no-first-run"
    "--disable-session-crashed-bubble"
    "--new-window"
    "--kiosk"
    "--window-position=$x,$y"
    "--window-size=$width,$height"
    $url
)

Start-Process -FilePath $chrome -ArgumentList $args