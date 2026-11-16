# System dashboard: a responsive card grid with a live clock and disk usage, themed via CSS.
#
# Teaches: Add-NHKUiGrid (3 columns, 2 below 1000 px, 1 below 620 px), -Theme and -Density,
# -ExtraCss with selectors for the UI's own classes and theme token overrides, and a 1-second
# timer built from a sleeping background task whose -OnCompleted callback refreshes state.
#
# Run:  pwsh -File ./dashboard.ps1 [cobalt|graphite|daylight]
#       powershell.exe -NoProfile -File .\dashboard.ps1 daylight
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Dashboard'

$theme = 'cobalt'
if ($args.Count -gt 0 -and @('cobalt', 'graphite', 'daylight') -contains $args[0]) { $theme = [string]$args[0] }
$css = @'
.nhk-card h1.nhk-heading { font-size: 30px; margin: 4px 0; }
.nhk-card { border-top: 3px solid var(--nhk-accent); }
body.nhk-theme-daylight { --nhk-accent: #0f7b6c; --nhk-accent-strong: #0b6458; --nhk-focus: #0f7b6c; }
'@

$s = @{
    Started = [Diagnostics.Stopwatch]::StartNew(); Refreshed = (New-NHKUiState -Value '0')
    Clock = (New-NHKUiState -Value '--:--:--'); Uptime = (New-NHKUiState -Value '0 s')
    Disk = (New-NHKUiState -Value ''); DiskDetail = (New-NHKUiState -Value ''); UI = $null
}
function Update-Dashboard($s) {
    # Several states change at once: write them as one batched update.
    Invoke-NHKUiBatch -UI $s.UI -ScriptBlock {
        $s.Clock.Set((Get-Date).ToString('HH:mm:ss'))
        $sec = [int]$s.Started.Elapsed.TotalSeconds
        $text = if ($sec -ge 60) { '{0} min {1} s' -f [Math]::Floor($sec / 60), ($sec % 60) } else { "$sec s" }
        $s.Uptime.Set($text)
        $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot([Environment]::GetFolderPath('UserProfile')))
        $s.Disk.Set(('{0:N0} % used' -f (100.0 * ($drive.TotalSize - $drive.AvailableFreeSpace) / $drive.TotalSize)))
        $s.DiskDetail.Set(('{0:N1} GB free of {1:N0} GB' -f ($drive.AvailableFreeSpace / 1GB), ($drive.TotalSize / 1GB)))
    }
}
function Start-Tick {
    $null = Start-NativeHTMLKitTask -Application $app -ScriptBlock { Start-Sleep -Milliseconds 1000 } -OnCompleted {
        param($result)
        Update-Dashboard $s
        Start-Tick
    }
}

$ui = New-NHKUi -Title 'Dashboard' -Width 980 -Height 640 -Theme $theme -Density regular -ExtraCss $css
$s.UI = $ui
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'System dashboard' -Level 1
        $null = Add-NHKUiBadge -UI $ui -Text "theme: $theme"
    }
    $null = Add-NHKUiGrid -UI $ui -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiText -UI $ui -Text 'Local time' -Muted
            $null = Add-NHKUiHeading -UI $ui -Bind $s.Clock -Level 1
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiText -UI $ui -Text 'Dashboard uptime' -Muted
            $null = Add-NHKUiHeading -UI $ui -Bind $s.Uptime -Level 1
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiText -UI $ui -Text 'Home drive' -Muted
            $null = Add-NHKUiHeading -UI $ui -Bind $s.Disk -Level 1
            $null = Add-NHKUiText -UI $ui -Bind $s.DiskDetail -Muted
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiText -UI $ui -Text 'Processors' -Muted
            $null = Add-NHKUiHeading -UI $ui -Text ([string][Environment]::ProcessorCount) -Level 1
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiText -UI $ui -Text 'Platform' -Muted
            $null = Add-NHKUiHeading -UI $ui -Text ([string][Environment]::OSVersion.Platform) -Level 1
            $null = Add-NHKUiText -UI $ui -Text ('PowerShell {0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition) -Muted
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiText -UI $ui -Text 'Manual refreshes' -Muted
            $null = Add-NHKUiHeading -UI $ui -Bind $s.Refreshed -Level 1
            $null = Add-NHKUiButton -UI $ui -Text 'Refresh now' -Variant secondary -Data $s -OnClick {
                param($eventObject, $s)
                Update-Dashboard $s
                $s.Refreshed.Set([string]([int]$s.Refreshed.Value + 1))
            }
        }
    }
    $null = Add-NHKUiText -UI $ui -Text 'Resize the window: the grid uses 3, 2 or 1 columns.' -Muted
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Update-Dashboard $s
    Start-Tick
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    Close-NativeHTMLKit -Application $app
}
