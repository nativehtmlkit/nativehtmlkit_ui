# NativeHTMLKit.UI unit tests against a FAKE SDK module (tests/FakeSdk). No host, no Pester.
# Run: pwsh -NoProfile -File powershell/tests/Unit.Tests.ps1   (and powershell.exe 5.1 on Windows)
# Exit code = number of failed tests. Proves UI logic only; native behavior needs the real SDK.
$ErrorActionPreference = 'Stop'
$fakeRoot = Join-Path $PSScriptRoot 'FakeSdk'
$env:PSModulePath = $fakeRoot + [IO.Path]::PathSeparator + $env:PSModulePath
Import-Module (Join-Path $fakeRoot 'NativeHTMLKit/NativeHTMLKit.psd1') -Force
Import-Module (Join-Path $PSScriptRoot '../NativeHTMLKit.UI/NativeHTMLKit.UI.psd1') -Force
if ((Get-Module NativeHTMLKit).Description -notmatch 'Fake') { throw 'Unit tests must run against the fake SDK' }

$script:Passed = 0; $script:Failed = 0
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    Reset-FakeNHK
    try { & $Body; $script:Passed++; Write-Output "PASS $Name" }
    catch { $script:Failed++; Write-Output "FAIL $Name :: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)" }
}
function Assert-True { param($Condition, [string]$Message) if (-not $Condition) { throw "Assertion failed: $Message" } }
function Get-Writes { return @((Get-FakeNHK).Log | Where-Object { $_.cmd -in @('batch','set_value','set_checked') }) }
function Get-Ops { $o = @(); foreach ($w in (Get-Writes)) { if ($w.cmd -eq 'batch') { $o += $w.ops } }; return ,$o }
function Get-Html { return (@((Get-FakeNHK).Log | Where-Object { $_.cmd -eq 'document.load' })[0]).html }

Test-Case 'state set notifies once and ignores equal values' {
    $s = New-NHKUiState -Value 1; $hits = New-Object System.Collections.ArrayList
    $null = $s.Subscribe({ param($v, $c) [void]$c.Add($v) }, $hits)
    $s.Set(1); $s.Set(2); $s.Set(2)
    Assert-True ($hits.Count -eq 1 -and $hits[0] -eq 2) "hits=$($hits -join ',')"
}
Test-Case 'computed follows dependencies and Dispose detaches' {
    $a = New-NHKUiState -Value 2; $b = New-NHKUiState -Value 3
    $c = New-NHKUiComputed -DependsOn @($a,$b) -Data @{A=$a;B=$b} -Compute { param($d) $d.A.Value * $d.B.Value }
    Assert-True ($c.Value -eq 6) 'initial'
    $a.Set(4); Assert-True ($c.Value -eq 12) 'after a'
    $c.Dispose(); $b.Set(10); Assert-True ($c.Value -eq 12) 'after dispose'
    Assert-True ($a.Listeners.Count -eq 0 -and $b.Listeners.Count -eq 0) 'listeners released'
}
Test-Case 'computed cycle is detected, not a stack overflow' {
    $a = New-NHKUiState -Value 1
    $c = New-NHKUiComputed -DependsOn @($a) -Data $a -Compute { param($x) $x.Value + 1 }
    # A computed whose compute writes its own dependency forms a cycle.
    $bad = New-NHKUiComputed -DependsOn @($a) -Data $a -Compute { param($x) $x.Set($x.Value + 1); $x.Value }
    $threw = $false
    try { $a.Set(100) } catch { $threw = $_.Exception.Message -match 'Circular' }
    Assert-True $threw 'cycle error expected'
    $c.Dispose(); $bad.Dispose()
}
Test-Case 'markup escapes text, title and attributes; labels precede controls' {
    $s = New-NHKUiState -Value '<b>"x"</b>'
    $ui = New-NHKUi -Title 'T <i>&'
    $null = Add-NHKUiColumn -UI $ui -Content {
        $null = Add-NHKUiText -UI $ui -Bind $s
        $null = Add-NHKUiInput -UI $ui -Bind $s -Label 'Name <x>' -Placeholder '"q"'
        $null = Add-NHKUiSelect -UI $ui -Bind (New-NHKUiState -Value 'b') -Label 'Pick' -Options @(@{Value='a';Label='A'},@{Value='b';Label='<B>'})
        $null = Add-NHKUiTextList -UI $ui -Bind (New-NHKUiState -Value @('<li>x', 'y'))
    }
    $html = Get-NHKUiHtml -UI $ui
    Assert-True ($html.Contains('<title>T &lt;i&gt;&amp;</title>')) 'title'
    Assert-True (-not $html.Contains('<b>"x"</b>')) 'raw text leaked'
    Assert-True ($html.Contains('&lt;b&gt;&quot;x&quot;&lt;/b&gt;')) 'text escaped'
    Assert-True ($html.Contains('placeholder="&quot;q&quot;"')) 'attr escaped'
    Assert-True ($html.Contains('<li>&lt;li&gt;x</li><li>y</li>')) 'list escaped'
    Assert-True ($html.IndexOf('>Name &lt;x&gt;</label>') -lt $html.IndexOf('class="nhk-input"')) 'label before input'
    Assert-True ($html.IndexOf('>Pick</label>') -lt $html.IndexOf('class="nhk-select"')) 'label before select'
    Assert-True ($html -match '<option[^>]*selected[^>]*value="b"') 'selected option'
    Stop-NHKUi -UI $ui
}
Test-Case 'event-handler attributes and unknown tags are rejected' {
    $ui = New-NHKUi
    $node = Add-NHKUiHtml -UI $ui -Markup '<p>trusted</p>'
    $node.Attrs.onclick = 'x'
    $threw = $false; try { $null = Get-NHKUiHtml -UI $ui } catch { $threw = $_.Exception.Message -match 'Unsafe' }
    Assert-True $threw 'onclick must be rejected'
    $threw = $false; try { $null = Add-NHKUiElementInternalProbe } catch { $threw = $true }
    Assert-True $threw 'private helper must not be exported'
}
Test-Case 'mount: one subscription per event kind, ready once, initial control values' {
    $name = New-NHKUiState -Value 'n'; $on = New-NHKUiState -Value $true; $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $null = Add-NHKUiColumn -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $name
        $null = Add-NHKUiInput -UI $ui -Bind $name
        $null = Add-NHKUiCheckbox -UI $ui -Bind $on -Label 'On'
        $null = Add-NHKUiButton -UI $ui -Text 'a' -OnClick { }
        $null = Add-NHKUiButton -UI $ui -Text 'b' -OnClick { }
    }
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    $types = @($win.Document.Handlers | ForEach-Object { $_.Type } | Sort-Object)
    Assert-True (($types -join ',') -eq 'change,click,input') "types=$($types -join ',')"
    Assert-True ((Get-FakeNHK).Ready -eq 1) 'ready'
    Assert-True (@((Get-Writes) | Where-Object { $_.cmd -eq 'set_value' }).Count -eq 2) 'initial values'
    Stop-NHKUi -UI $ui
    Assert-True ($win.Document.Handlers.Count -eq 0) 'handlers released'
    Assert-True ($name.Listeners.Count -eq 0 -and $on.Listeners.Count -eq 0) 'state listeners released'
}
Test-Case 'click handler changes are batched once after the callback' {
    $count = New-NHKUiState -Value 0; $label = New-NHKUiState -Value 'x'
    $ui = New-NHKUi
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Add-NHKUiText -UI $ui -Bind $label
    $btn = Add-NHKUiButton -UI $ui -Text 'Go' -Data @{C=$count;L=$label} -OnClick {
        param($e, $d) $d.C.Set(1); $d.C.Set(2); $d.L.Set('y')
    }
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Log.Clear()
    $fail = Send-FakeNHKEvent $win.Document @{ type='click'; element=$btn.Id; path=@($btn.Id, $ui.Root.Id) }
    Assert-True ($fail -eq 0) 'callback failed'
    $w = @(Get-Writes)
    Assert-True ($w.Count -eq 1 -and $w[0].cmd -eq 'batch' -and $w[0].ops.Count -eq 2) "writes=$($w.Count)"
    Assert-True (@($w[0].ops | Where-Object { $_.text -eq '2' }).Count -eq 1) 'latest count written'
    Stop-NHKUi -UI $ui
}
Test-Case 'delegation picks the nearest registered element on the path' {
    $hit = New-NHKUiState -Value ''
    $ui = New-NHKUi
    $outer = $null; $inner = $null
    $outer = Add-NHKUiButton -UI $ui -Text 'outer' -Data $hit -OnClick { param($e,$d) $d.Set('outer') }
    $inner = Add-NHKUiButton -UI $ui -Text 'inner' -Data $hit -OnClick { param($e,$d) $d.Set('inner') }
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    $null = Send-FakeNHKEvent $win.Document @{ type='click'; element='unrelated-span'; path=@('x', $inner.Id, $outer.Id) }
    Assert-True ($hit.Value -eq 'inner') "hit=$($hit.Value)"
    $null = Send-FakeNHKEvent $win.Document @{ type='click'; element='nothing'; path=@('nothing') }
    Assert-True ($hit.Value -eq 'inner') 'unmatched event ignored'
    Stop-NHKUi -UI $ui
}
Test-Case 'native input is authoritative: no echo write for typed value' {
    $name = New-NHKUiState -Value 'a'
    $ui = New-NHKUi
    $inp = Add-NHKUiInput -UI $ui -Bind $name -Label 'Name'
    $null = Add-NHKUiText -UI $ui -Bind $name
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Log.Clear()
    $null = Send-FakeNHKEvent $win.Document @{ type='input'; element=$inp.Id; path=@($inp.Id); value='ab'; is_composing=$true }
    Assert-True ($name.Value -eq 'ab') 'state updated'
    Assert-True (@((Get-Writes) | Where-Object { $_.cmd -eq 'set_value' }).Count -eq 0) 'no echo set_value'
    Assert-True (@((Get-Ops) | Where-Object { $_.op -eq 'set_text' -and $_.text -eq 'ab' }).Count -eq 1) 'mirror text updated'
    # A programmatic change still reaches the control.
    $name.Set('zz')
    Assert-True (@((Get-Writes) | Where-Object { $_.cmd -eq 'set_value' -and $_.value -eq 'zz' }).Count -eq 1) 'programmatic set_value'
    Stop-NHKUi -UI $ui
}
Test-Case 'event without value falls back to the public getter' {
    $name = New-NHKUiState -Value ''; $on = New-NHKUiState -Value $false
    $ui = New-NHKUi
    $inp = Add-NHKUiInput -UI $ui -Bind $name
    $cb = Add-NHKUiCheckbox -UI $ui -Bind $on -Label 'x'
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Values[$inp.Id] = 'from-getter'; (Get-FakeNHK).Checked[$cb.Id] = $true
    $null = Send-FakeNHKEvent $win.Document @{ type='input'; element=$inp.Id; path=@($inp.Id) }
    $null = Send-FakeNHKEvent $win.Document @{ type='change'; element=$cb.Id; path=@($cb.Id) }
    Assert-True ($name.Value -eq 'from-getter' -and $on.Value -eq $true) "name=$($name.Value) on=$($on.Value)"
    Stop-NHKUi -UI $ui
}
Test-Case 'checkbox change and visibility/list/disabled bindings' {
    $show = New-NHKUiState -Value $true; $items = New-NHKUiState -Value @('a'); $busy = New-NHKUiState -Value $false
    $ui = New-NHKUi
    $cb = Add-NHKUiCheckbox -UI $ui -Bind $show -Label 'Show'
    $region = Add-NHKUiWhen -UI $ui -Bind $show -Content { $null = Add-NHKUiTextList -UI $ui -Bind $items }
    $btn = Add-NHKUiButton -UI $ui -Text 'Run' -DisabledState $busy
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Log.Clear()
    $null = Send-FakeNHKEvent $win.Document @{ type='change'; element=$cb.Id; path=@($cb.Id); checked=$false }
    $ops = Get-Ops
    Assert-True (@($ops | Where-Object { $_.op -eq 'add_class' -and $_.element -eq $region.Id -and $_.name -eq 'nhk-hidden' }).Count -eq 1) 'hidden'
    Assert-True (@((Get-Writes) | Where-Object { $_.cmd -eq 'set_checked' }).Count -eq 0) 'no checked echo'
    (Get-FakeNHK).Log.Clear()
    $items.Set(@('<x>', 'y')); $busy.Set($true)
    $ops = Get-Ops
    Assert-True (@($ops | Where-Object { $_.op -eq 'replace_children_html' -and $_.html -eq '<li>&lt;x&gt;</li><li>y</li>' }).Count -eq 1) 'list'
    Assert-True (@($ops | Where-Object { $_.op -eq 'set_attribute' -and $_.name -eq 'disabled' }).Count -eq 1) 'disabled'
    Stop-NHKUi -UI $ui
}
Test-Case 'a nested event during a write never lets an older value win (re-entrancy)' {
    $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $txt = Add-NHKUiText -UI $ui -Bind $count
    $btn = Add-NHKUiButton -UI $ui -Text '+' -Data $count -OnClick { param($e,$d) $d.Set([int]$d.Value + 10) }
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Log.Clear()
    $doc = $win.Document; $id = $btn.Id
    # The first write's RPC wait pumps a click (as the real SDK does outside a callback).
    (Get-FakeNHK).WriteHook = { $null = Send-FakeNHKEvent $doc @{ type='click'; element=$id; path=@($id) } }.GetNewClosure()
    $count.Set(1)  # external update, outside any callback
    $texts = @((Get-Ops) | Where-Object { $_.op -eq 'set_text' } | ForEach-Object { $_.text })
    Assert-True ($count.Value -eq 11) "state=$($count.Value)"
    Assert-True ($texts[$texts.Count-1] -eq '11') "last written=$($texts -join ',')"
    Stop-NHKUi -UI $ui
}
Test-Case 'a failed write marks the DOM uncertain and is not hidden' {
    $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Fault = New-Object NativeHTMLKit.RpcTimeoutException 'timed out; outcome unknown'
    $threw = $false; try { $count.Set(1) } catch { $threw = $true }
    Assert-True $threw 'write failure must surface'
    $d = Get-NHKUiDiagnostics -UI $ui
    Assert-True ($d.DomUncertain -and $d.Errors -ge 1 -and $d.LastError -match 'outcome unknown') 'diagnostics'
    (Get-FakeNHK).Fault = $null
    $threw = $false; try { $count.Set(2) } catch { $threw = $_.Exception.Message -match 'uncertain' }
    Assert-True $threw 'later managed updates refuse to continue'
    Stop-NHKUi -UI $ui
}
Test-Case 'closed window / app shutdown (stale document) ends updates quietly' {
    $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Stale = $true
    $count.Set(1)   # must not throw
    $d = Get-NHKUiDiagnostics -UI $ui
    Assert-True ($d.Disposed -and -not $d.DomUncertain) 'disposed, not uncertain'
    Assert-True ($count.Listeners.Count -eq 0) 'listener released'
    $count.Set(2)
}
Test-Case 'a throwing handler is reported and later events still work' {
    $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $null = Add-NHKUiText -UI $ui -Bind $count
    $bad = Add-NHKUiButton -UI $ui -Text 'bad' -Data $count -OnClick { param($e,$d) $d.Set(5); throw 'boom' }
    $good = Add-NHKUiButton -UI $ui -Text 'good' -Data $count -OnClick { param($e,$d) $d.Set(6) }
    $win = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    $f = Send-FakeNHKEvent $win.Document @{ type='click'; element=$bad.Id; path=@($bad.Id) }
    Assert-True ($f -eq 1) 'failure propagated to SDK isolation'
    Assert-True (@((Get-Ops) | Where-Object { $_.text -eq '5' }).Count -eq 1) 'changes before the throw were still applied'
    $null = Send-FakeNHKEvent $win.Document @{ type='click'; element=$good.Id; path=@($good.Id) }
    Assert-True ($count.Value -eq 6 -and (Get-NHKUiDiagnostics -UI $ui).Errors -eq 1) 'recovered'
    Stop-NHKUi -UI $ui
}
Test-Case 'a State changed from another runspace never writes from that runspace' {
    # PowerShell runs a module-bound ScriptMethod on the runspace that defined it (or the UI refuses
    # the call); either way no SDK write may happen on the foreign runspace.
    $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    $owner = [runspace]::DefaultRunspace.InstanceId
    $seen = New-Object System.Collections.ArrayList
    $null = $count.Subscribe({ param($v, $c) [void]$c.Add([runspace]::DefaultRunspace.InstanceId) }, $seen)
    $ps = [powershell]::Create()
    try {
        $null = $ps.AddScript({ param($s) try { $s.Set(9); 'no-error' } catch { 'refused: ' + $_.Exception.Message } }).AddArgument($count)
        $result = [string](@($ps.Invoke()) -join ' ')
    } finally { $ps.Dispose() }
    if ($result -eq 'no-error') {
        Assert-True ($seen.Count -eq 1 -and $seen[0] -eq $owner) "ran on $($seen -join ',') not owner $owner"
        Assert-True (@((Get-Ops) | Where-Object { $_.text -eq '9' }).Count -eq 1) 'write applied on owner'
    } else {
        Assert-True ($result -match 'owning runspace') "result=$result"
    }
    Write-Output "INFO cross-runspace Set: $result"
    Stop-NHKUi -UI $ui
}
Test-Case 'mount/dispose 100 cycles leaks no state listeners or handlers' {
    $shared = New-NHKUiState -Value 0; $flag = New-NHKUiState -Value $true
    for ($i = 0; $i -lt 100; $i++) {
        $ui = New-NHKUi
        $null = Add-NHKUiText -UI $ui -Bind $shared
        $null = Add-NHKUiCheckbox -UI $ui -Bind $flag -Label 'f'
        $null = Add-NHKUiButton -UI $ui -Text 'x' -OnClick { }
        $win = Start-NHKUi -UI $ui -Application (New-FakeApplication) -NoReady
        $shared.Set($i + 1)
        Stop-NHKUi -UI $ui
        if ($win.Document.Handlers.Count -ne 0) { throw "handlers leaked at $i" }
    }
    Assert-True ($shared.Listeners.Count -eq 0 -and $flag.Listeners.Count -eq 0) "listeners=$($shared.Listeners.Count)"
}
Test-Case '1000 rapid external updates produce bounded, ordered writes' {
    $count = New-NHKUiState -Value 0
    $ui = New-NHKUi
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    (Get-FakeNHK).Log.Clear()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 1; $i -le 1000; $i++) { $count.Set($i) }
    $texts = @((Get-Ops) | ForEach-Object { $_.text })
    Assert-True ($texts.Count -eq 1000 -and $texts[999] -eq '1000') "writes=$($texts.Count)"
    Write-Output ("INFO 1000 external updates in {0} ms (fake SDK)" -f $clock.ElapsedMilliseconds)
    Stop-NHKUi -UI $ui
}
Test-Case 'bound button label and computed text' {
    $n = New-NHKUiState -Value 1
    $label = New-NHKUiComputed -DependsOn @($n) -Data $n -Compute { param($x) "Count $($x.Value)" }
    $ui = New-NHKUi
    $btn = Add-NHKUiButton -UI $ui -Bind $label
    $null = Start-NHKUi -UI $ui -Application (New-FakeApplication)
    Assert-True ((Get-Html).Contains('>Count 1</button>')) 'initial label'
    $n.Set(2)
    Assert-True (@((Get-Ops) | Where-Object { $_.element -eq $btn.Id -and $_.text -eq 'Count 2' }).Count -eq 1) 'label update'
    Stop-NHKUi -UI $ui; $label.Dispose()
}

Write-Output ("RESULT passed={0} failed={1}" -f $script:Passed, $script:Failed)
exit $script:Failed
