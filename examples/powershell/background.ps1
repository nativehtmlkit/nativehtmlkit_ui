# Background calculation: run slow work in an SDK task and report the result on the owner runspace.
#
# Teaches: UI states may only change on the runspace that started the UI. Slow work runs in
# Start-NativeHTMLKitTask (a separate runspace that receives plain data only); its -OnCompleted
# and -OnFailed callbacks run later on this runspace, where they may set states. Also: a busy
# flag that disables the button, Cancel via Stop-NativeHTMLKitTask, and a task timeout.
#
# Run:  pwsh -File ./background.ps1   |   powershell.exe -NoProfile -File .\background.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'NativeHTMLKit Background'

$s = @{ App = $app; Status = (New-NHKUiState -Value 'Idle'); Busy = (New-NHKUiState -Value $false); Task = $null }
$s.Idle = New-NHKUiComputed -DependsOn @($s.Busy) -Data $s -Compute { param($s) -not $s.Busy.Value }

$ui = New-NHKUi -Title 'Background example'
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Background work'
    $null = Add-NHKUiText -UI $ui -Bind $s.Status
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Calculate' -DisabledState $s.Busy -Data $s -OnClick {
            param($eventObject, $s)
            $s.Busy.Set($true)
            $s.Status.Set('Running')
            # The worker sees only its arguments: no UI, state or SDK objects.
            $s.Task = Start-NativeHTMLKitTask -Application $s.App -ArgumentList @(500000) -TimeoutMilliseconds 60000 -ScriptBlock {
                param([int]$n)
                $sum = [long]0
                for ($i = 0; $i -lt $n; $i++) { $sum += $i }
                $sum
            } -OnCompleted {
                param($result)
                $s.Status.Set('Done: ' + $result[0])
                $s.Busy.Set($false)
            } -OnFailed {
                param($failure)
                $s.Status.Set('Failed: ' + $failure.GetType().Name)
                $s.Busy.Set($false)
            }
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Cancel' -Variant secondary -DisabledState $s.Idle -Data $s -OnClick {
            param($eventObject, $s)
            if ($null -ne $s.Task) { Stop-NativeHTMLKitTask -Task $s.Task }   # -OnFailed then reports the cancellation
        }
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $s.Idle.Dispose()
    Close-NativeHTMLKit -Application $app      # also stops a task that is still running
}
