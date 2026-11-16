# NativeHTMLKit UI qualification gallery (PowerShell). Test tooling, not part of the module.
# Run: pwsh -NoProfile -File ps_gallery.ps1   (or powershell.exe -NoProfile -File ps_gallery.ps1)
# Env: NHKUI_CHANNEL (command channel dir), NHKUI_TITLE, NHKUI_THEME. Same semantics as py_gallery.py.
# State updates from the command loop run OUTSIDE SDK callbacks on the owner runspace (the path
# where an SDK RPC wait can pump events while the UI writes).
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI -ErrorAction Stop
$app = Start-NativeHTMLKitScript -Name 'NHKUI'
$channel = $env:NHKUI_CHANNEL
$title = if ($env:NHKUI_TITLE) { $env:NHKUI_TITLE } else { 'NHKUI-ps' }
$theme = if ($env:NHKUI_THEME) { $env:NHKUI_THEME } else { 'cobalt' }
$size = if ($env:NHKUI_SIZE) { $env:NHKUI_SIZE } else { '1000x700' }
$width = [int]$size.Split('x')[0]; $height = [int]$size.Split('x')[1]
$null = New-Item -ItemType Directory -Force -Path $channel

function Write-AppLog([string]$Kind, [hashtable]$Fields = @{}) {
    $Fields.kind = $Kind; $Fields.t = [Math]::Round(([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) / 1000.0, 3)
    [IO.File]::AppendAllText((Join-Path $channel 'app.jsonl'), (ConvertTo-Json $Fields -Compress -Depth 6) + "`n")
}

$g = [pscustomobject]@{
    Count = (New-NHKUiState -Value 0); Name = (New-NHKUiState -Value ''); Show = (New-NHKUiState -Value $true)
    Busy = (New-NHKUiState -Value $false); Choice = (New-NHKUiState -Value 'b')
    History = (New-NHKUiState -Value @('Ready')); Clicks = 0; DisabledClicks = 0; Ids = @{}
}
$g | Add-Member -NotePropertyName Message -NotePropertyValue (New-NHKUiComputed -DependsOn @($g.Name, $g.Count) -Data $g -Compute {
    param($s) $n = if ($s.Name.Value) { $s.Name.Value } else { 'Nobody' }; "${n}: $($s.Count.Value) clicks" })
$g | Add-Member -NotePropertyName Mirror -NotePropertyValue (New-NHKUiComputed -DependsOn @($g.Name) -Data $g -Compute { param($s) "Mirror: $($s.Name.Value)" })
$g | Add-Member -NotePropertyName ChoiceMirror -NotePropertyValue (New-NHKUiComputed -DependsOn @($g.Choice) -Data $g -Compute { param($s) "Choice: $($s.Choice.Value)" })
$g | Add-Member -NotePropertyName AlertText -NotePropertyValue (New-NHKUiComputed -DependsOn @($g.Count) -Data $g -Compute { param($s) "Native reactive updates: $($s.Count.Value)" })
$g | Add-Member -NotePropertyName BadgeText -NotePropertyValue (New-NHKUiComputed -DependsOn @($g.Count) -Data $g -Compute { param($s) [string]$s.Count.Value })

$ui = New-NHKUi -Title $title -Theme $theme -Density compact -Width $width -Height $height
$ids = $g.Ids
$null = Add-NHKUiColumn -UI $ui -Content {
    $ids.heading = (Add-NHKUiHeading -UI $ui -Text 'NativeHTMLKit UI gallery' -Level 1).Id
    $null = Add-NHKUiText -UI $ui -Text 'PowerShell SDK - qualification build' -Muted
    $ids.grid = (Add-NHKUiGrid -UI $ui -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'State'
            $ids.message = (Add-NHKUiText -UI $ui -Bind $g.Message).Id
            $null = Add-NHKUiRow -UI $ui -Content {
                $ids.increment = (Add-NHKUiButton -UI $ui -Text 'Increment' -Data $g -OnClick {
                    param($e, $s)
                    $s.Clicks++
                    $s.Count.Set([int]$s.Count.Value + 1)
                    $s.History.Set(@(@("Count became $($s.Count.Value)") + @($s.History.Value) | Select-Object -First 8))
                }).Id
                $ids.reset = (Add-NHKUiButton -UI $ui -Text 'Reset' -Variant secondary -Data $g -OnClick { param($e, $s) $s.Count.Set(0) }).Id
                $ids.disabled = (Add-NHKUiButton -UI $ui -Text 'Busy action' -Variant quiet -DisabledState $g.Busy -Data $g -OnClick { param($e, $s) $s.DisabledClicks++ }).Id
            }
            $ids.badge = (Add-NHKUiBadge -UI $ui -Bind $g.BadgeText).Id
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Input'
            $ids.name = (Add-NHKUiInput -UI $ui -Bind $g.Name -Label 'Your name' -Placeholder 'Type here').Id
            $ids.mirror = (Add-NHKUiText -UI $ui -Bind $g.Mirror).Id
            $ids.show = (Add-NHKUiCheckbox -UI $ui -Bind $g.Show -Label 'Show recent events').Id
            $ids.choice = (Add-NHKUiSelect -UI $ui -Bind $g.Choice -Label 'Choice' -Options @(
                @{Value='a';Label='Alpha'}, @{Value='b';Label='Bravo'}, @{Value='c';Label='Charlie'})).Id
            $ids.choice_mirror = (Add-NHKUiText -UI $ui -Bind $g.ChoiceMirror).Id
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Lists'
            $ids.region = (Add-NHKUiWhen -UI $ui -Bind $g.Show -Content {
                $ids.list = (Add-NHKUiTextList -UI $ui -Bind $g.History).Id
            }).Id
        }
    }).Id
    $ids.alert = (Add-NHKUiAlert -UI $ui -Bind $g.AlertText).Id
}

function Get-Rect($Doc, [string]$Id) { return (Invoke-NativeHTMLKitDocumentCommand -Document $Doc -Operation get_rect -Parameters @{ element = $Id }) }
function Get-Attr($Doc, [string]$Id, [string]$Name) {
    $r = Invoke-NativeHTMLKitDocumentCommand -Document $Doc -Operation get_attribute -Parameters @{ element = $Id; name = $Name }
    return $r.value
}

$extra = @{}
function Invoke-GalleryCommand($cmd) {
    $doc = $ui.Document
    $a = $cmd.args
    switch ($cmd.op) {
        'ids' { return @{ ids = $g.Ids; prefix = $ui.Prefix } }
        'rects' {
            $r = @{}
            foreach ($k in @($g.Ids.Keys)) { if ($g.Ids[$k]) { $r[$k] = Get-Rect $doc $g.Ids[$k] } }
            return @{ rects = $r }
        }
        'snapshot' {
            $texts = @{}
            foreach ($k in @('message','mirror','choice_mirror','alert','badge')) { $texts[$k] = Get-NativeHTMLKitDocumentText -Document $doc -Element $g.Ids[$k] }
            $focused = Get-NativeHTMLKitFocusedElement -Document $doc
            $snap = @{
                state = @{ count = $g.Count.Value; name = $g.Name.Value; show = $g.Show.Value; busy = $g.Busy.Value
                           choice = $g.Choice.Value; history = @($g.History.Value); message = $g.Message.Value }
                clicks = $g.Clicks; disabled_clicks = $g.DisabledClicks
                diagnostics = (Get-NHKUiDiagnostics -UI $ui); texts = $texts
                list_html = (Invoke-NativeHTMLKitDocumentCommand -Document $doc -Operation get_html -Parameters @{ element = $g.Ids.list }).html
                region_class = (Get-Attr $doc $g.Ids.region 'class'); disabled_attr = (Get-Attr $doc $g.Ids.disabled 'disabled')
                value = @{ name = (Get-NativeHTMLKitValue -Document $doc -Element $g.Ids.name); choice = (Get-NativeHTMLKitValue -Document $doc -Element $g.Ids.choice) }
                checked = @{ show = (Get-NativeHTMLKitChecked -Document $doc -Element $g.Ids.show) }
                focused = $focused
                name_selection = (Get-NativeHTMLKitSelection -Document $doc -Element $g.Ids.name)
                grid_columns = (Get-NativeHTMLKitComputedStyle -Document $doc -Element $g.Ids.grid -Properties @('grid-template-columns'))
                region_display = (Get-NativeHTMLKitComputedStyle -Document $doc -Element $g.Ids.region -Properties @('display'))
                window = (Get-NativeHTMLKitWindow -Window $ui.Window)
            }
            if ($focused -and $focused.element) {
                $snap.focused_outline = Get-NativeHTMLKitComputedStyle -Document $doc -Element $focused.element -Properties @('outline-style','outline-color')
            }
            return $snap
        }
        'set' {
            $target = switch ($a.name) { 'count' { $g.Count } 'name' { $g.Name } 'show' { $g.Show } 'busy' { $g.Busy } 'choice' { $g.Choice } }
            $target.Set($a.value)
            return @{}
        }
        'storm' {
            $n = [int]$a.n; $clock = [Diagnostics.Stopwatch]::StartNew()
            for ($i = 1; $i -le $n; $i++) { $g.Count.Set($i) }
            $unbatched = $clock.ElapsedMilliseconds
            $clock = [Diagnostics.Stopwatch]::StartNew()
            Invoke-NHKUiBatch -UI $ui -ScriptBlock { for ($i = 1; $i -le $n; $i++) { $g.Count.Set($n + $i) } }
            return @{ set_ms = $unbatched; settled_ms = $unbatched; batched_ms = $clock.ElapsedMilliseconds; final = $g.Count.Value; diagnostics = (Get-NHKUiDiagnostics -UI $ui) }
        }
        'storm_async' { $script:AsyncStorm = [int]$a.n; $script:AsyncAt = 0; return @{} }
        'resize' {
            $h = if ($a.height) { [int]$a.height } else { 700 }
            $null = Set-NativeHTMLKitWindow -Window $ui.Window -Width ([int]$a.width) -Height $h
            $deadline = [DateTime]::UtcNow.AddMilliseconds(600)
            while ([DateTime]::UtcNow -lt $deadline) { $null = Wait-NativeHTMLKit -Application $app -TimeoutMilliseconds 50 }
            return @{ window = (Get-NativeHTMLKitWindow -Window $ui.Window) }
        }
        'focus' { Set-NativeHTMLKitFocus -Document $doc -Element $g.Ids[$a.name]; return @{} }
        'open_second' {
            $t = New-NHKUiState -Value 'second: 0'
            $ctx = [pscustomobject]@{ Text = $t; N = 0 }
            $u2 = New-NHKUi -Title ($title + '-second') -Theme $theme -Width 520 -Height 360
            $tid = $null; $bid = $null
            $null = Add-NHKUiColumn -UI $u2 -Content {
                $null = Add-NHKUiHeading -UI $u2 -Text 'Second window'
                $script:tid = (Add-NHKUiText -UI $u2 -Bind $t).Id
                $script:bid = (Add-NHKUiButton -UI $u2 -Text 'Second +' -Data $ctx -OnClick { param($e, $c) $c.N++; $c.Text.Set("second: $($c.N)") }).Id
            }
            $null = Start-NHKUi -UI $u2 -Application $app -NoReady
            $extra.second = @{ UI = $u2; Ids = @{ button = $script:bid; text = $script:tid } }
            return @{ ids = $extra.second.Ids }
        }
        'second_state' {
            $s = $extra.second; $u2 = $s.UI
            $out = @{ diagnostics = @{ disposed = (Get-NHKUiDiagnostics -UI $u2).Disposed } }
            try {
                $out.text = Get-NativeHTMLKitDocumentText -Document $u2.Document -Element $s.Ids.text
                $out.rects = @{ button = (Get-Rect $u2.Document $s.Ids.button); text = (Get-Rect $u2.Document $s.Ids.text) }
                $out.window = Get-NativeHTMLKitWindow -Window $u2.Window
            } catch {
                # Like the Python UI, a closed window ends the UI; Sync-NHKUi stops it on the next write.
                $out.window_gone = $_.Exception.GetType().FullName
                $u2.Pending.Clear(); Stop-NHKUi -UI $u2
                $out.diagnostics.disposed = (Get-NHKUiDiagnostics -UI $u2).Disposed
            }
            return $out
        }
        'cycle' {
            $n = [int]$a.n; $clock = [Diagnostics.Stopwatch]::StartNew(); $errors = New-Object System.Collections.ArrayList
            for ($i = 0; $i -lt $n; $i++) {
                $s = New-NHKUiState -Value $i
                $u = New-NHKUi -Title ($title + '-cycle') -Theme $theme -Width 400 -Height 260
                $null = Add-NHKUiText -UI $u -Bind $s
                $null = Add-NHKUiButton -UI $u -Text 'x' -OnClick { }
                $w = Start-NHKUi -UI $u -Application $app -NoReady
                $s.Set($i + 1)
                Close-NativeHTMLKitWindow -Window $w
                Stop-NHKUi -UI $u
                $s.Set($i + 2)  # after dispose: must be a no-op
                if ($s.Listeners.Count -ne 0) { [void]$errors.Add("cycle ${i}: listener leak") }
                $null = Wait-NativeHTMLKit -Application $app -TimeoutMilliseconds 0
            }
            [GC]::Collect()
            return @{ n = $n; ms = $clock.ElapsedMilliseconds; errors = @($errors | Select-Object -First 10) }
        }
        'quit' { $null = Request-NativeHTMLKitQuit -Application $app; return @{} }
        default { throw "unknown op $($cmd.op)" }
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Write-AppLog 'ready' @{ title = $title; ids = $g.Ids; ps = $PSVersionTable.PSVersion.ToString(); edition = $PSVersionTable.PSEdition }
    $next = 1; $script:AsyncStorm = 0; $script:AsyncAt = 0
    while ($true) {
        $null = Wait-NativeHTMLKit -Application $app -TimeoutMilliseconds 30
        if ($app.Closed -or $app.ShutdownRequested) { break }
        if ($script:AsyncAt -lt $script:AsyncStorm) {
            for ($k = 0; $k -lt 5 -and $script:AsyncAt -lt $script:AsyncStorm; $k++) { $script:AsyncAt++; $g.Count.Set($script:AsyncAt) }
        }
        $path = Join-Path $channel "cmd-$next.json"
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try { $cmd = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { continue }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        try { $result = Invoke-GalleryCommand $cmd; $result.ok = $true }
        catch { $result = @{ ok = $false; error = $_.Exception.GetType().FullName; message = [string]$_.Exception.Message; trace = [string]$_.ScriptStackTrace } }
        $result.ms = $clock.ElapsedMilliseconds
        $tmp = Join-Path $channel "resp-$next.tmp"
        [IO.File]::WriteAllText($tmp, (ConvertTo-Json $result -Depth 8 -Compress))
        Move-Item -LiteralPath $tmp -Destination (Join-Path $channel "resp-$next.json") -Force
        $next++
    }
    $extraDiag = @{}; foreach ($k in $extra.Keys) { $extraDiag[$k] = Get-NHKUiDiagnostics -UI $extra[$k].UI }
    $sdk = $null
    try { $c = (Get-NativeHTMLKitDiagnosticReport -Application $app).Connection
          $sdk = @{ DroppedNotifications = $c.DroppedNotifications; DeferredDropped = $c.DeferredDropped; CallbackFailures = $c.CallbackFailures } } catch { $sdk = @{ error = $_.Exception.GetType().Name } }
    Write-AppLog 'shutdown' @{ diagnostics = (Get-NHKUiDiagnostics -UI $ui); extra = $extraDiag; sdk = $sdk }
} finally {
    Stop-NHKUi -UI $ui
    Close-NativeHTMLKit -Application $app
}
