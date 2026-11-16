# Example probe (PowerShell). Test tooling for run_examples.py, not part of the module.
# usage: pwsh -NoProfile -File ps_probe.ps1 EXAMPLE.ps1 MARKER   (or powershell.exe 5.1)
#
# Runs EXAMPLE.ps1 unchanged. Global aliases (which win over module functions in command lookup)
# route three calls through this probe:
#   Start-NativeHTMLKitScript  re-runs THIS probe as the host's backend (with the example as argument)
#   Start-NHKUi                records every started UI
#   Wait-NativeHTMLKit         executes the scenario from NHKUI_EXAMPLE_SPEC on the owner runspace,
#                              a few steps per call, then requests an orderly quit
# Events are injected at the UI module's SDK-callback entry point; this proves application logic
# and DOM writes against the real host, not native input. Windows PowerShell 5.1 compatible.
param([Parameter(Mandatory)][string]$Example, [string]$Marker = '')
$ErrorActionPreference = 'Stop'
$global:NHKProbe = [pscustomobject]@{
    Example = [IO.Path]::GetFullPath($Example); Self = $PSCommandPath; Marker = $Marker
    Uis = (New-Object System.Collections.ArrayList); App = $null; Steps = @(); Index = 0
    Results = (New-Object System.Collections.ArrayList); Started = $null; StepStarted = $null
    Finished = $false; Ready = $false; Failed = $false; QuitRequested = $false; Error = $null; Sdk = $null
}
if ($env:NHKUI_EXAMPLE_SPEC) {
    # Windows PowerShell 5.1 emits a JSON array as ONE object; enumerate it explicitly.
    $parsed = Get-Content -LiteralPath $env:NHKUI_EXAMPLE_SPEC -Raw -Encoding UTF8 | ConvertFrom-Json
    $global:NHKProbe.Steps = @($parsed | ForEach-Object { $_ })
}

function global:Write-NHKProbeResult([string]$Phase) {
    if (-not $env:NHKUI_EXAMPLE_OUT) { return }
    $p = $global:NHKProbe
    $diag = @(); foreach ($u in $p.Uis) { $diag += (Get-NHKUiDiagnostics -UI $u) }
    if ($null -ne $p.App -and -not $p.App.Closed) {
        try {
            $c = (Get-NativeHTMLKitDiagnosticReport -Application $p.App).Connection
            $p.Sdk = @{ DroppedNotifications = $c.DroppedNotifications; DeferredDropped = $c.DeferredDropped; CallbackFailures = $c.CallbackFailures }
        } catch { if ($null -eq $p.Sdk) { $p.Sdk = @{ unavailable = $_.Exception.GetType().Name } } }
    }
    $sdk = $p.Sdk
    $doc = @{ phase = $Phase; ready = $p.Ready; finished = $p.Finished; steps = @($p.Results); diagnostics = $diag
              sdk = $sdk; error = $p.Error; ps = $PSVersionTable.PSVersion.ToString(); edition = $PSVersionTable.PSEdition }
    $tmp = $env:NHKUI_EXAMPLE_OUT + '.tmp'
    [IO.File]::WriteAllText($tmp, (ConvertTo-Json $doc -Depth 8), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $env:NHKUI_EXAMPLE_OUT -Force
}

function global:Get-NHKProbeNodes($Node) {
    $Node
    foreach ($child in $Node.Children) { Get-NHKProbeNodes $child }
}
function global:Find-NHKProbeControl($UI, [string]$Label, [int]$Nth) {
    $nodes = @(Get-NHKProbeNodes $UI.Root)
    $hits = @($nodes | Where-Object { $_.Tag -eq 'label' -and [string]$_.Text -eq $Label } | ForEach-Object { $_.Attrs['for'] })
    $hits += @($nodes | Where-Object { $_.Tag -eq 'input' -and $_.Attrs['placeholder'] -eq $Label } | ForEach-Object { $_.Id })
    if ($hits.Count -le $Nth) { throw "no control labelled '$Label' (#$Nth)" }
    return [string]$hits[$Nth]
}
function global:Find-NHKProbeButton($UI, [string]$Label, [int]$Nth) {
    $hits = @(Get-NHKProbeNodes $UI.Root | Where-Object { $_.Tag -eq 'button' -and [string]$_.Text -eq $Label } | ForEach-Object { $_.Id })
    if ($hits.Count -le $Nth) { throw "no button '$Label' (#$Nth)" }
    return [string]$hits[$Nth]
}
function global:Get-NHKProbeVisibleText($UI) {
    $parts = New-Object System.Collections.ArrayList
    $visit = $null
    $visit = {
        param($n)
        if ([string]$n.Attrs['class'] -match '\bnhk-region\b') {
            $cls = (Invoke-NativeHTMLKitDocumentCommand -Document $UI.Document -Operation get_attribute -Parameters @{ element = $n.Id; name = 'class' }).value
            if (([string]$cls -split ' ') -contains 'nhk-hidden') { return }
        }
        if ($n.Children.Count -eq 0 -or $n.Tag -eq 'select' -or $null -ne $n.Raw) {
            if ($n.Tag -ne 'input' -and $n.Tag -ne 'select') {
                $t = Get-NativeHTMLKitDocumentText -Document $UI.Document -Element $n.Id
                if ($t) { [void]$parts.Add($t) }
            }
            return
        }
        foreach ($c in $n.Children) { & $visit $c }
    }
    & $visit $UI.Root
    return ($parts -join ' | ')
}
function global:Send-NHKProbeEvent($UI, [string]$Kind, [string]$Element, [hashtable]$Fields = @{}) {
    $ev = @{ type = $Kind; element = $Element; path = @() }
    foreach ($k in $Fields.Keys) { $ev[$k] = $Fields[$k] }
    $module = Get-Module NativeHTMLKit.UI
    & $module Invoke-NHKUiEventInternal -UI $UI -Kind $Kind -EventObject ([pscustomobject]$ev)
}
function global:Get-NHKProbeField($Step, [string]$Name, $Default) {
    $prop = $Step.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    return $prop.Value
}

# Returns 'done' (step finished), 'wait' (retry on a later pump) and records the outcome.
function global:Invoke-NHKProbeStep($Step) {
    $p = $global:NHKProbe
    $ui = $p.Uis[[int](Get-NHKProbeField $Step 'ui' 0)]
    $nth = [int](Get-NHKProbeField $Step 'nth' 0)
    $label = [string](Get-NHKProbeField $Step 'label' '')
    $outcome = @{ ok = $true }
    switch ($Step.op) {
        'click' { Send-NHKProbeEvent $ui 'click' (Find-NHKProbeButton $ui $label $nth) }
        'type' {
            $id = Find-NHKProbeControl $ui $label $nth
            Set-NativeHTMLKitDocumentValue -Document $ui.Document -Element $id -Value ([string]$Step.value)
            Send-NHKProbeEvent $ui 'input' $id @{ value = [string]$Step.value }
        }
        'check' {
            $id = Find-NHKProbeControl $ui $label $nth
            Set-NativeHTMLKitChecked -Document $ui.Document -Element $id -Checked ([bool]$Step.value)
            Send-NHKProbeEvent $ui 'change' $id @{ checked = [bool]$Step.value }
        }
        'choose' {
            $id = Find-NHKProbeControl $ui $label $nth
            Set-NativeHTMLKitDocumentValue -Document $ui.Document -Element $id -Value ([string]$Step.value)
            Send-NHKProbeEvent $ui 'change' $id @{ value = [string]$Step.value }
        }
        { $_ -in @('expect_text', 'wait_text') } {
            $text = Get-NHKProbeVisibleText $ui
            $missing = @(@(Get-NHKProbeField $Step 'contains' @()) | Where-Object { $text.IndexOf([string]$_, [StringComparison]::Ordinal) -lt 0 })
            $present = @(@(Get-NHKProbeField $Step 'absent' @()) | Where-Object { $text.IndexOf([string]$_, [StringComparison]::Ordinal) -ge 0 })
            $good = ($missing.Count -eq 0 -and $present.Count -eq 0)
            if (-not $good -and $Step.op -eq 'wait_text') {
                $timeout = [double](Get-NHKProbeField $Step 'timeout' 15)
                if (([DateTime]::UtcNow - $p.StepStarted).TotalSeconds -lt $timeout) { return 'wait' }
            }
            $len = [Math]::Min(1500, $text.Length)
            $outcome = @{ ok = $good; missing = $missing; unexpected = $present; text = $text.Substring(0, $len) }
        }
        'expect_value' {
            $id = Find-NHKProbeControl $ui $label $nth
            if ($null -ne $Step.PSObject.Properties['checked']) {
                $got = [bool](Get-NativeHTMLKitChecked -Document $ui.Document -Element $id)
                $outcome = @{ ok = ($got -eq [bool]$Step.checked); checked = $got }
            } else {
                $got = [string](Get-NativeHTMLKitValue -Document $ui.Document -Element $id)
                $outcome = @{ ok = ($got -ceq [string]$Step.value); value = $got }
            }
        }
        'expect_disabled' {
            $id = Find-NHKProbeButton $ui $label $nth
            $got = (Invoke-NativeHTMLKitDocumentCommand -Document $ui.Document -Operation get_attribute -Parameters @{ element = $id; name = 'disabled' }).value
            $outcome = @{ ok = (($null -ne $got) -eq [bool]$Step.value); attribute = $got }
        }
        'expect_uis' {
            $live = @($p.Uis | Where-Object { -not (Get-NHKUiDiagnostics -UI $_).Disposed }).Count
            $outcome = @{ ok = ($live -eq [int]$Step.count); live = $live; mounted = $p.Uis.Count }
        }
        'close_window' {
            Close-NativeHTMLKitWindow -Window $ui.Window
            $outcome = @{ ok = $true }
        }
        'sleep' {
            if (([DateTime]::UtcNow - $p.StepStarted).TotalSeconds -lt [double](Get-NHKProbeField $Step 'seconds' 0.5)) { return 'wait' }
        }
        default { throw "unknown step '$($Step.op)'" }
    }
    $outcome.step = $Step
    [void]$p.Results.Add($outcome)
    if (-not $outcome.ok) { $p.Failed = $true }
    return 'done'
}

# Runs scenario steps until one must wait; requests quit once all steps ran (or one failed).
function global:Step-NHKProbe {
    $p = $global:NHKProbe
    if ($p.QuitRequested -or $p.Uis.Count -eq 0 -or $null -eq $p.App) { return }
    if ($null -eq $p.Started) { $p.Started = [DateTime]::UtcNow; return }
    if (([DateTime]::UtcNow - $p.Started).TotalMilliseconds -lt 300) { return }  # let startup settle
    $p.Ready = [bool]$p.App.Ready
    while (-not $p.Failed -and $p.Index -lt $p.Steps.Count) {
        if ($null -eq $p.StepStarted) { $p.StepStarted = [DateTime]::UtcNow }
        try { $state = Invoke-NHKProbeStep $p.Steps[$p.Index] }
        catch {
            [void]$p.Results.Add(@{ ok = $false; step = $p.Steps[$p.Index]; error = ($_.Exception.GetType().FullName + ': ' + $_.Exception.Message); trace = [string]$_.ScriptStackTrace })
            $p.Failed = $true; $state = 'done'
        }
        if ($state -eq 'wait') { return }
        $p.Index++; $p.StepStarted = $null
    }
    $p.Finished = $true
    $p.QuitRequested = $true
    Write-NHKProbeResult 'steps'
    $null = Request-NativeHTMLKitQuit -Application $p.App
}

function global:Start-NHKProbeScript {
    [CmdletBinding()] param([string]$Name, [string]$AppId, [string]$Version, [string]$Icon, [string]$Instance,
        [int]$StartupTimeoutMilliseconds, [int]$ShutdownTimeoutMilliseconds, [int]$MaxWindows, [string[]]$ArgumentList,
        [string]$ScriptPath, [string]$Diagnostics)
    $p = @{}; foreach ($k in $PSBoundParameters.Keys) { $p[$k] = $PSBoundParameters[$k] }
    $p.ScriptPath = $global:NHKProbe.Self
    $p.ArgumentList = @($global:NHKProbe.Example, $global:NHKProbe.Marker)
    $app = NativeHTMLKit\Start-NativeHTMLKitScript @p
    $global:NHKProbe.App = $app
    return $app
}
function global:Start-NHKProbeUi {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI, [Parameter(Mandatory)]$Application, [switch]$NoReady)
    $window = NativeHTMLKit.UI\Start-NHKUi @PSBoundParameters
    [void]$global:NHKProbe.Uis.Add($UI)
    return $window
}
function global:Wait-NHKProbe {
    [CmdletBinding(DefaultParameterSetName = 'Pump')]
    param([Parameter(Mandatory)]$Application,
          [Parameter(ParameterSetName = 'Pump')][int]$TimeoutMilliseconds = 100,
          [Parameter(ParameterSetName = 'Pump')][switch]$Once,
          [Parameter(ParameterSetName = 'Run')][switch]$UntilShutdown)
    if ($UntilShutdown) {
        while (-not $global:NHKProbe.QuitRequested -and -not $Application.ShutdownRequested -and -not $Application.Closed) {
            Step-NHKProbe
            $null = NativeHTMLKit\Wait-NativeHTMLKit -Application $Application -TimeoutMilliseconds 50
        }
        NativeHTMLKit\Wait-NativeHTMLKit -Application $Application -UntilShutdown
        return
    }
    Step-NHKProbe
    return (NativeHTMLKit\Wait-NativeHTMLKit @PSBoundParameters)
}

Set-Alias -Name Start-NativeHTMLKitScript -Value Start-NHKProbeScript -Scope Global
Set-Alias -Name Start-NHKUi -Value Start-NHKProbeUi -Scope Global
Set-Alias -Name Wait-NativeHTMLKit -Value Wait-NHKProbe -Scope Global
Import-Module NativeHTMLKit.UI -ErrorAction Stop
try {
    & $global:NHKProbe.Example
} catch {
    $global:NHKProbe.Error = $_.Exception.GetType().FullName + ': ' + $_.Exception.Message
    if ($null -ne $global:NHKProbe.App) { Write-NHKProbeResult 'error' }
    throw
}
if ($null -ne $global:NHKProbe.App) { Write-NHKProbeResult 'exit' }
