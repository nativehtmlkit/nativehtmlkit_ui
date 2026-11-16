# NativeHTMLKit.UI 0.1: language-native UI state and public-SDK-only document adapter.
# PowerShell 5.1 and 7.2+ compatible. No C# helper, Core protocol, or separate event pump.
#
# Scoping rule for this module: never hand a scriptblock made with .GetNewClosure() to code that
# must call this module's private functions. GetNewClosure() binds the block to a NEW dynamic
# module whose parent is the global scope, so private helpers are not visible inside it.
# Internal callbacks are therefore module-bound literals that receive their context as an argument,
# and the one closure handed to the SDK (document events) re-enters this module explicitly.

# Depth of nested State.Set calls on this runspace and the UIs that have pending writes. A change
# that cascades through computed states is written once, when the outermost Set returns.
$script:NHKUiSetDepth = 0
$script:NHKUiDirty = New-Object System.Collections.ArrayList

function New-NHKUiState {
    [CmdletBinding()] param([AllowNull()]$Value)
    $s = [pscustomobject]@{ Value = $Value; Listeners = (New-Object System.Collections.ArrayList) }
    $s.PSObject.TypeNames.Insert(0, 'NativeHTMLKit.UI.State')
    $s | Add-Member -MemberType ScriptMethod -Name Set -Value {
        param($Next)
        if ([object]::Equals($this.Value, $Next)) { return }
        $this.Value = $Next
        $script:NHKUiSetDepth++
        try {
            foreach ($subscription in @($this.Listeners.ToArray())) {
                if ($subscription.Active) { $null = & $subscription.Callback $Next $subscription.Context }
            }
        } finally {
            $script:NHKUiSetDepth--
            if ($script:NHKUiSetDepth -eq 0 -and $script:NHKUiDirty.Count -gt 0) { Sync-NHKUiDirty }
        }
    }
    $s | Add-Member -MemberType ScriptMethod -Name Subscribe -Value {
        # The callback receives ($newValue, $Context).
        param([scriptblock]$Callback, $Context)
        $subscription = [pscustomobject]@{ Callback = $Callback; Context = $Context; Active = $true }
        [void]$this.Listeners.Add($subscription)
        return $subscription
    }
    $s | Add-Member -MemberType ScriptMethod -Name Unsubscribe -Value {
        param($Subscription)
        if ($null -eq $Subscription) { return }
        $Subscription.Active = $false
        [void]$this.Listeners.Remove($Subscription)
    }
    return $s
}

function Test-NHKUiState {
    param($Value)
    return ($null -ne $Value -and $Value -is [psobject] -and $Value.PSObject.TypeNames[0] -eq 'NativeHTMLKit.UI.State')
}

function New-NHKUiComputed {
    <# Explicit dependencies avoid PowerShell AST/proxy instrumentation. #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][scriptblock]$Compute,
        [Parameter(Mandatory)][object[]]$DependsOn,
        [AllowNull()]$Data
    )
    foreach ($dep in $DependsOn) {
        if (-not (Test-NHKUiState $dep)) { throw 'DependsOn must contain only NativeHTMLKit.UI.State objects' }
    }
    $s = New-NHKUiState -Value (& $Compute $Data)
    $tokens = New-Object System.Collections.ArrayList
    $context = [pscustomobject]@{ Computed = $s; Compute = $Compute; Data = $Data; Busy = $false }
    $recompute = {
        param($ignored, $ctx)
        if ($ctx.Busy) { throw 'Circular computed-state dependency' }
        $ctx.Busy = $true
        try { $ctx.Computed.Set((& $ctx.Compute $ctx.Data)) } finally { $ctx.Busy = $false }
    }
    foreach ($dep in $DependsOn) {
        $sub = $dep.Subscribe($recompute, $context)
        [void]$tokens.Add([pscustomobject]@{ State = $dep; Token = $sub })
    }
    $s | Add-Member -NotePropertyName DependencyTokens -NotePropertyValue $tokens
    $s | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        foreach ($entry in @($this.DependencyTokens.ToArray())) {
            $entry.State.Unsubscribe($entry.Token)
        }
        $this.DependencyTokens.Clear()
    }
    return $s
}

function New-NHKUi {
    [CmdletBinding()] param(
        [string]$Title = 'NativeHTMLKit UI', [ValidateRange(100,8192)][int]$Width = 940,
        [ValidateRange(100,8192)][int]$Height = 660,
        [ValidateSet('cobalt','graphite','daylight')][string]$Theme = 'cobalt',
        [ValidateSet('compact','regular','comfortable')][string]$Density = 'compact',
        [string]$ExtraCss = ''
    )
    $ui = [pscustomobject]@{
        Title = $Title; Width = $Width; Height = $Height; Theme = $Theme; Density = $Density
        ExtraCss = $ExtraCss; Prefix = ('nhkui-' + [guid]::NewGuid().ToString('N').Substring(0,12))
        NextId = 0; Root = $null; Stack = (New-Object System.Collections.ArrayList)
        Bindings = (New-Object System.Collections.ArrayList)
        Handlers = @{}; Pending = (New-Object System.Collections.Specialized.OrderedDictionary)
        Subscriptions = (New-Object System.Collections.ArrayList)
        Window = $null; Document = $null; Application = $null
        InEvent = 0; Syncing = $false; Disposed = $false; LastError = $null; DomUncertain = $false
        Errors = [long]0; Updates = [long]0; Operations = [long]0; Discarded = [long]0
        OwnerRunspaceId = $null
    }
    $ui.PSObject.TypeNames.Insert(0, 'NativeHTMLKit.UI.App')
    $ui.NextId++
    $ui.Root = [pscustomobject]@{
        Tag='main'; Id=($ui.Prefix + '-' + $ui.NextId); Attrs=@{ class='nhk-app' }
        Children=(New-Object System.Collections.ArrayList); Text=$null; Raw=$null
    }
    [void]$ui.Stack.Add($ui.Root)
    return $ui
}

function Assert-NHKUiOwner {
    param($UI)
    if ($UI.Disposed) { throw 'NativeHTMLKit UI has been disposed' }
    if ($UI.OwnerRunspaceId -and [runspace]::DefaultRunspace.InstanceId -ne $UI.OwnerRunspaceId) {
        throw 'UI updates must run on the SDK owning runspace (use SDK task completion callbacks)'
    }
}

function Add-NHKUiElementInternal {
    param($UI, [string]$Tag, [hashtable]$Attrs=@{}, [AllowNull()]$Text=$null, [AllowNull()]$Raw=$null)
    Assert-NHKUiOwner $UI
    if ($null -ne $UI.Document) { throw 'The UI tree is already mounted; change State rather than adding components' }
    if ($Tag -notin @('div','section','main','header','footer','article','nav','aside','p','span',
                     'h1','h2','h3','h4','button','label','input','select','option','ul','li',
                     'table','thead','tbody','tr','th','td','dialog','pre','code','small','strong')) {
        throw "Unsupported element '$Tag'; use Add-NHKUiHtml for trusted custom markup"
    }
    $UI.NextId++
    $node = [pscustomobject]@{
        Tag = $Tag; Id = ($UI.Prefix + '-' + $UI.NextId); Attrs = $Attrs
        Children = (New-Object System.Collections.ArrayList); Text = $Text; Raw = $Raw
    }
    $parent = $UI.Stack[$UI.Stack.Count-1]
    [void]$parent.Children.Add($node)
    return $node
}

function Move-NHKUiNodeBefore {
    # Reorders two siblings so that $Node comes directly before $Before (labels precede controls).
    param($Parent, $Node, $Before)
    $Parent.Children.Remove($Node)
    $Parent.Children.Insert($Parent.Children.IndexOf($Before), $Node)
}

# Runs on the state's owner when a bound State changes; $ctx = @{UI; Binding}.
$script:NHKUiBindingChanged = {
    param($ignored, $ctx)
    $ui = $ctx.UI
    if ($ui.Disposed) { return }
    Assert-NHKUiOwner $ui
    $b = $ctx.Binding
    $ui.Pending[$b.Key] = $b
    if ($null -ne $ui.Document -and $ui.InEvent -eq 0 -and -not $script:NHKUiDirty.Contains($ui)) {
        [void]$script:NHKUiDirty.Add($ui)  # written when the outermost State.Set returns
    }
}

function Sync-NHKUiDirty {
    $uis = @($script:NHKUiDirty.ToArray())
    $script:NHKUiDirty.Clear()
    $failure = $null
    foreach ($ui in $uis) {
        if ($ui.Disposed -or $ui.InEvent -gt 0) { continue }
        try { Sync-NHKUi -UI $ui } catch { if ($null -eq $failure) { $failure = $_ } }
    }
    if ($null -ne $failure) { throw $failure }
}

function Invoke-NHKUiBatch {
    <#
    .SYNOPSIS
    Runs a scriptblock and writes all resulting UI changes once at the end (one batched update).
    .DESCRIPTION
    Event callbacks are batched automatically. Use this for many State changes made outside a
    callback (for example in a loop after a task completed). Runs on the owning runspace.
    #>
    [CmdletBinding()] param([Parameter(Mandatory)]$UI, [Parameter(Mandatory)][scriptblock]$ScriptBlock)
    Assert-NHKUiOwner $UI
    $UI.InEvent++
    try { & $ScriptBlock }
    finally {
        $UI.InEvent--
        if (-not $UI.Disposed -and $UI.InEvent -eq 0) { Sync-NHKUi -UI $UI }
    }
}

function Add-NHKUiBindingInternal {
    param($UI, $Node, $State, [string]$Kind, [string]$Name='')
    if (-not (Test-NHKUiState $State)) {
        throw "A -Bind argument must be created with New-NHKUiState or New-NHKUiComputed"
    }
    $binding = [pscustomobject]@{
        Id = $Node.Id; Kind = $Kind; Name = $Name; State = $State; Key = ($Node.Id + '|' + $Kind + '|' + $Name)
        Last = $State.Value; Subscription = $null
    }
    $binding.Subscription = $State.Subscribe($script:NHKUiBindingChanged, [pscustomobject]@{ UI = $UI; Binding = $binding })
    [void]$UI.Bindings.Add($binding)
    return $binding
}

function ConvertTo-NHKUiEncoded {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-NHKUiListMarkup {
    param([AllowNull()]$Value)
    $result = New-Object System.Text.StringBuilder
    if ($null -eq $Value) { return '' }
    foreach ($entry in @($Value)) {
        [void]$result.Append('<li>')
        [void]$result.Append((ConvertTo-NHKUiEncoded $entry))
        [void]$result.Append('</li>')
    }
    return $result.ToString()
}

function ConvertTo-NHKUiNodeHtml {
    param($Node)
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('<').Append($Node.Tag)
    $attrs = @{}; foreach ($key in $Node.Attrs.Keys) { $attrs[[string]$key] = $Node.Attrs[$key] }
    $attrs.id = $Node.Id
    foreach ($name in ($attrs.Keys | Sort-Object)) {
        if ($name -cnotmatch '^[A-Za-z_:][A-Za-z0-9_:.-]*$' -or $name -match '^(?i:on)') {
            throw "Unsafe HTML attribute name '$name'"
        }
        $value = $attrs[$name]
        if ($null -eq $value -or ($value -is [bool] -and -not $value)) { continue }
        if ($value -is [bool]) { [void]$builder.Append(' ').Append($name) }
        else {
            [void]$builder.Append(' ').Append($name).Append('="')
            [void]$builder.Append((ConvertTo-NHKUiEncoded $value)).Append('"')
        }
    }
    [void]$builder.Append('>')
    if ($Node.Tag -eq 'input') { return $builder.ToString() }
    if ($null -ne $Node.Raw) { [void]$builder.Append($Node.Raw) }
    elseif ($null -ne $Node.Text) { [void]$builder.Append((ConvertTo-NHKUiEncoded $Node.Text)) }
    foreach ($child in $Node.Children) { [void]$builder.Append((ConvertTo-NHKUiNodeHtml $child)) }
    [void]$builder.Append('</').Append($Node.Tag).Append('>')
    return $builder.ToString()
}

function Get-NHKUiHtml {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI)
    if ($UI.Stack.Count -ne 1) { throw 'UI contains an unclosed container' }
    $cssFile = Join-Path $script:NHKUiModuleRoot 'assets/ui.css'
    $css = [IO.File]::ReadAllText($cssFile, [Text.Encoding]::UTF8)
    return ('<!doctype html><html lang="en"><head><meta charset="utf-8">' +
        '<meta name="viewport" content="width=device-width,initial-scale=1">' +
        '<title>' + (ConvertTo-NHKUiEncoded $UI.Title) + '</title><style>' + $css + "`n" +
        $UI.ExtraCss + '</style></head><body class="nhk-theme-' + $UI.Theme +
        ' nhk-density-' + $UI.Density + '">' + (ConvertTo-NHKUiNodeHtml $UI.Root) + '</body></html>')
}

function Register-NHKUiActionInternal {
    param($UI, $Node, [string]$Kind, [scriptblock]$Callback, [AllowNull()]$Data)
    if ($Kind -notin @('click','input','change','keydown','submit','auxclick','contextmenu')) {
        throw "Unsupported event type '$Kind'"
    }
    if (-not $UI.Handlers.ContainsKey($Kind)) { $UI.Handlers[$Kind] = @{} }
    $UI.Handlers[$Kind][$Node.Id] = [pscustomobject]@{ Callback = $Callback; Data = $Data }
}

function Get-NHKUiEventField {
    # Event objects are PSCustomObjects from the SDK's JSON reader; tolerate missing members.
    param($EventObject, [string]$Name)
    if ($null -eq $EventObject) { return $null }
    if ($EventObject -is [System.Collections.IDictionary]) { return $EventObject[$Name] }
    $property = $EventObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Invoke-NHKUiEventInternal {
    param($UI, [string]$Kind, $EventObject)
    if ($UI.Disposed) { return }
    Assert-NHKUiOwner $UI
    $handlers = $UI.Handlers[$Kind]
    if ($null -eq $handlers) { return }
    $path = New-Object System.Collections.ArrayList
    $target = [string](Get-NHKUiEventField $EventObject 'element')
    if ($target) { [void]$path.Add($target) }
    foreach ($item in @(Get-NHKUiEventField $EventObject 'path')) { if ($item) { [void]$path.Add([string]$item) } }
    foreach ($id in $path) {
        if ($handlers.ContainsKey([string]$id)) {
            $UI.InEvent++
            try {
                $entry = $handlers[[string]$id]
                $null = & $entry.Callback $EventObject $entry.Data
            } catch {
                $UI.Errors++
                $UI.LastError = $_.Exception.Message
                throw
            } finally {
                $UI.InEvent--
                if (-not $UI.Disposed -and $UI.InEvent -eq 0) { Sync-NHKUi -UI $UI }
            }
            break  # nearest registered element on the route, like a delegated handler
        }
    }
}

function Test-NHKUiStaleError {
    # True when an SDK call failed because the window/document is no longer current (closed,
    # replaced, or app.shutdown): the SDK's documented NativeHTMLKit.StaleObjectException.
    param($ErrorRecordOrException)
    $e = $ErrorRecordOrException
    if ($e -is [System.Management.Automation.ErrorRecord]) { $e = $e.Exception }
    while ($null -ne $e) {
        $type = $e.GetType().FullName
        if ($type -eq 'NativeHTMLKit.StaleObjectException') { return $true }
        # Definite host rejections (not outcome-unknown): -32004 window/document gone, -32008 the
        # application is shutting down (protocol v1 section 5). The write was not applied.
        if ($type -eq 'NativeHTMLKit.RpcException' -and $null -ne $e.PSObject.Properties['Code'] -and
            (@(-32004, -32008) -contains [int]$e.Code)) { return $true }
        $e = $e.InnerException
    }
    return $false
}

function Sync-NHKUi {
    <# Apply only changed bound properties. Call from the owning runspace. #>
    [CmdletBinding()] param([Parameter(Mandatory)]$UI)
    if ($UI.Disposed) { return }
    Assert-NHKUiOwner $UI
    if ($null -eq $UI.Document) { return }
    if ($UI.DomUncertain) { throw 'UI DOM state is uncertain after a failed operation; do not continue managed updates' }
    # An SDK RPC wait outside a callback pumps host messages, so a document event (and its state
    # changes) can run while this function is writing. Such a nested call only queues; the outer
    # loop below applies its changes afterwards, so an older value never overwrites a newer one.
    if ($UI.Syncing) { return }
    $UI.Syncing = $true
    try {
        while ($UI.Pending.Count -gt 0 -and -not $UI.Disposed) {
            $pending = @($UI.Pending.Values)
            $UI.Pending.Clear()
            Invoke-NHKUiWrites -UI $UI -Pending $pending
        }
    } finally { $UI.Syncing = $false }
}

function Invoke-NHKUiWrites {
    param($UI, [object[]]$Pending)
    $ops = New-Object System.Collections.ArrayList
    $special = New-Object System.Collections.ArrayList
    foreach ($b in $Pending) {
        $next = $b.State.Value
        if ([object]::Equals($next, $b.Last)) { continue }
        $b.Last = $next
        switch ($b.Kind) {
            'text' { [void]$ops.Add(@{op='set_text';element=$b.Id;text=[string]$next}) }
            'visible' {
                $op = if ([bool]$next) { 'remove_class' } else { 'add_class' }
                [void]$ops.Add(@{op=$op;element=$b.Id;name='nhk-hidden'})
            }
            'disabled' {
                if ([bool]$next) { [void]$ops.Add(@{op='set_attribute';element=$b.Id;name='disabled';value=''}) }
                else { [void]$ops.Add(@{op='remove_attribute';element=$b.Id;name='disabled'}) }
            }
            'list' { [void]$ops.Add(@{op='replace_children_html';element=$b.Id;html=(ConvertTo-NHKUiListMarkup $next)}) }
            default { [void]$special.Add([pscustomobject]@{Binding=$b;Value=$next}) }
        }
    }
    if ($ops.Count -eq 0 -and $special.Count -eq 0) { return }
    $UI.Updates++
    # Failed or outcome-unknown writes are never retried or ignored: the DOM may differ from state.
    try {
        for ($i=0; $i -lt $ops.Count; $i+=128) {
            $len = [Math]::Min(128, $ops.Count-$i)
            $block = New-Object 'object[]' $len
            for ($j=0; $j -lt $len; $j++) { $block[$j] = $ops[$i+$j] }
            Invoke-NativeHTMLKitBatch -Document $UI.Document -Operations $block
            $UI.Operations += $len
        }
        foreach ($entry in $special) {
            switch ($entry.Binding.Kind) {
                'value' { Set-NativeHTMLKitDocumentValue -Document $UI.Document -Element $entry.Binding.Id -Value ([string]$entry.Value) }
                'checked' { Set-NativeHTMLKitChecked -Document $UI.Document -Element $entry.Binding.Id -Checked ([bool]$entry.Value) }
            }
            $UI.Operations++
        }
    } catch {
        if (Test-NHKUiStaleError $_) {
            # A closed window, replaced document or shut-down application ends managed updates
            # quietly: no DOM is left to keep in sync, so this is disposal, not an uncertain state.
            # (A timeout or disconnect is different: its outcome is unknown and is reported below.)
            $UI.Discarded++
            Stop-NHKUi -UI $UI
            return
        }
        $UI.DomUncertain = $true
        $UI.Errors++
        $UI.LastError = $_.Exception.Message
        throw
    }
}

function Get-NHKUiDiagnostics {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI)
    return [pscustomobject]@{
        DomUncertain = [bool]$UI.DomUncertain
        LastError = $UI.LastError
        Errors = [long]$UI.Errors
        PendingUpdates = [int]$UI.Pending.Count
        Updates = [long]$UI.Updates
        Operations = [long]$UI.Operations
        Subscriptions = [int]$UI.Subscriptions.Count
        DiscardedAfterClose = [long]$UI.Discarded
        Disposed = [bool]$UI.Disposed
    }
}

# Internal input/checkbox/select handler; $ctx = @{UI; State; Binding; Target; Kind}.
$script:NHKUiControlChanged = {
    param($eventObject, $ctx)
    $ui = $ctx.UI
    if ($ctx.Kind -eq 'checked') {
        $v = Get-NHKUiEventField $eventObject 'checked'
        if ($null -eq $v) { $v = Get-NativeHTMLKitChecked -Document $ui.Document -Element $ctx.Target }
        $v = [bool]$v
    } else {
        $v = Get-NHKUiEventField $eventObject 'value'
        if ($null -eq $v) { $v = Get-NativeHTMLKitValue -Document $ui.Document -Element $ctx.Target }
        $v = [string]$v
    }
    # Native input is authoritative: record it first so no echo write resets caret/selection/IME.
    $ctx.Binding.Last = $v
    $ctx.State.Set($v)
}

function Start-NHKUi {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI, [Parameter(Mandatory)]$Application, [switch]$NoReady)
    if ($null -ne $UI.Document) { throw 'UI already started' }
    Assert-NHKUiOwner $UI
    if ($UI.Stack.Count -ne 1) { throw 'UI contains an unclosed container' }
    $UI.OwnerRunspaceId = [runspace]::DefaultRunspace.InstanceId
    $UI.Application = $Application
    $html = Get-NHKUiHtml -UI $UI
    # NativeHTMLKit is an installed *SDK*, not an internal Core binding.
    $UI.Window = New-NativeHTMLKitWindow -Application $Application -Title $UI.Title -Width $UI.Width -Height $UI.Height
    try {
        $UI.Document = Open-NativeHTMLKitHtml -Window $UI.Window -Html $html
        foreach ($binding in @($UI.Bindings.ToArray())) {
            if ($binding.Kind -eq 'value') {
                Set-NativeHTMLKitDocumentValue -Document $UI.Document -Element $binding.Id -Value ([string]$binding.Last)
            } elseif ($binding.Kind -eq 'checked') {
                Set-NativeHTMLKitChecked -Document $UI.Document -Element $binding.Id -Checked ([bool]$binding.Last)
            }
        }
        # If a state changed after its markup was constructed, apply it now.
        foreach ($binding in @($UI.Bindings.ToArray())) { $UI.Pending[$binding.Key] = $binding }
        Sync-NHKUi -UI $UI
        $module = $ExecutionContext.SessionState.Module
        foreach ($kind in @($UI.Handlers.Keys)) {
            $localUi = $UI; $localKind = [string]$kind
            # The SDK only passes the event object, so this one callback is a closure; it re-enters
            # this module explicitly because a closure cannot see the module's private functions.
            $callback = {
                param($eventObject)
                & $module Invoke-NHKUiEventInternal -UI $localUi -Kind $localKind -EventObject $eventObject
            }.GetNewClosure()
            $sub = Register-NativeHTMLKitDocumentEvent -Document $UI.Document -Type $localKind -Callback $callback
            [void]$UI.Subscriptions.Add($sub)
        }
        if (-not $NoReady) { Set-NativeHTMLKitReady -Application $Application }
    } catch {
        $UI.LastError = $_.Exception.Message
        Stop-NHKUi -UI $UI
        throw
    }
    return $UI.Window
}

function Stop-NHKUi {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI)
    if ($UI.Disposed) { return }
    $UI.Disposed = $true
    foreach ($sub in @($UI.Subscriptions.ToArray())) {
        try { Unregister-NativeHTMLKitDocumentEvent -Subscription $sub } catch { }
    }
    $UI.Subscriptions.Clear()
    foreach ($binding in @($UI.Bindings.ToArray())) {
        $binding.State.Unsubscribe($binding.Subscription)
    }
    $UI.Pending.Clear()
    # Does not close SDK window/application; the caller controls SDK lifecycle.
}
