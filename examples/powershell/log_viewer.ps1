# Live log viewer: a timer streams lines; filter by level and text, pause, clear.
#
# Teaches: periodic work on the owner runspace without blocking the window. A background task
# (Start-NativeHTMLKitTask) only waits; its -OnCompleted callback, which the SDK runs on this
# runspace, appends a line and schedules the next tick. Also: bounded history, a computed
# filtered view rendered by Add-NHKUiTextList (all text is encoded), counters, pausing
# without losing lines.
#
# Run:  pwsh -File ./log_viewer.ps1   |   powershell.exe -NoProfile -File .\log_viewer.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Log viewer'

$s = @{
    Lines = (New-NHKUiState -Value @())   # objects with Level and Text, newest last
    Held = (New-NHKUiState -Value @())    # lines that arrived while paused
    Paused = (New-NHKUiState -Value $false); Level = (New-NHKUiState -Value 'all'); Search = (New-NHKUiState -Value '')
    N = 0; Keep = 500; Show = 14
    Messages = @('request served in 12 ms', 'cache refreshed', 'user signed in', 'slow query (420 ms)',
                 'disk space below 15 %', 'retrying upstream connection', 'job finished', 'config reloaded')
}
$s.Shown = New-NHKUiComputed -DependsOn @($s.Lines, $s.Level, $s.Search) -Data $s -Compute {
    param($s)
    $match = @($s.Lines.Value | Where-Object {
        ($s.Level.Value -eq 'all' -or $_.Level -eq $s.Level.Value) -and
        $_.Text.IndexOf([string]$s.Search.Value, [StringComparison]::OrdinalIgnoreCase) -ge 0 } | ForEach-Object { $_.Text })
    $newest = @($match | Select-Object -Last $s.Show)
    [array]::Reverse($newest)
    , $newest
}
$s.Total = New-NHKUiComputed -DependsOn @($s.Lines) -Data $s -Compute { param($s) '{0} lines' -f @($s.Lines.Value).Count }
$s.Errors = New-NHKUiComputed -DependsOn @($s.Lines) -Data $s -Compute { param($s) '{0} errors' -f @($s.Lines.Value | Where-Object { $_.Level -eq 'ERROR' }).Count }
$s.PauseLabel = New-NHKUiComputed -DependsOn @($s.Paused) -Data $s -Compute { param($s) if ($s.Paused.Value) { 'Resume' } else { 'Pause' } }
$s.Waiting = New-NHKUiComputed -DependsOn @($s.Held) -Data $s -Compute { param($s) 'Paused: {0} new lines are waiting.' -f @($s.Held.Value).Count }
$s.NoMatch = New-NHKUiComputed -DependsOn @($s.Shown) -Data $s -Compute { param($s) @($s.Shown.Value).Count -eq 0 }
$computeds = @($s.Shown, $s.Total, $s.Errors, $s.PauseLabel, $s.Waiting, $s.NoMatch)

function Add-LogLine($s) {
    $s.N = $s.N + 1
    $level = if ($s.N % 11 -eq 0) { 'ERROR' } elseif ($s.N % 4 -eq 0) { 'WARN' } else { 'INFO' }
    $text = '#{0:D5} {1} {2,-5} {3}' -f $s.N, (Get-Date).ToString('HH:mm:ss'), $level, $s.Messages[$s.N % $s.Messages.Count]
    $entry = [pscustomobject]@{ Level = $level; Text = $text }
    $target = if ($s.Paused.Value) { $s.Held } else { $s.Lines }
    $target.Set(@(@($target.Value) + @($entry) | Select-Object -Last $s.Keep))
}
function Start-Tick {
    # The worker runs in its own runspace and only sleeps; the callback runs here, on the owner.
    $null = Start-NativeHTMLKitTask -Application $app -ScriptBlock { Start-Sleep -Milliseconds 200 } -OnCompleted {
        param($result)
        Add-LogLine $s
        Start-Tick
    }
}

$ui = New-NHKUi -Title 'Log viewer' -Width 820 -Height 620
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Service log' -Level 1
        $null = Add-NHKUiBadge -UI $ui -Bind $s.Total
        $null = Add-NHKUiBadge -UI $ui -Bind $s.Errors
    }
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiSelect -UI $ui -Bind $s.Level -Label 'Level' -Options @(
            @{ Value = 'all'; Label = 'All levels' }, @{ Value = 'INFO'; Label = 'Info' },
            @{ Value = 'WARN'; Label = 'Warnings' }, @{ Value = 'ERROR'; Label = 'Errors' })
        $null = Add-NHKUiInput -UI $ui -Bind $s.Search -Label 'Contains' -Type search -Placeholder 'Filter text'
        $null = Add-NHKUiButton -UI $ui -Bind $s.PauseLabel -Variant secondary -Data $s -OnClick {
            param($eventObject, $s)
            if ($s.Paused.Value) {
                $s.Lines.Set(@(@($s.Lines.Value) + @($s.Held.Value) | Select-Object -Last $s.Keep))
                $s.Held.Set(@())
            }
            $s.Paused.Set(-not $s.Paused.Value)
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Clear' -Variant quiet -Data $s -OnClick { param($eventObject, $s) $s.Lines.Set(@()) }
    }
    $null = Add-NHKUiWhen -UI $ui -Bind $s.Paused -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.Waiting }
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiWhen -UI $ui -Bind $s.NoMatch -Content { $null = Add-NHKUiText -UI $ui -Text 'No matching lines.' -Muted }
        $null = Add-NHKUiTextList -UI $ui -Bind $s.Shown
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Start-Tick
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app     # also stops a pending tick task
}
