# NativeHTMLKit.UI 0.1: language-native UI state and public-SDK-only document adapter.
# PowerShell 5.1 and 7.2+ compatible. No C# helper, Core protocol, or separate event pump.

function New-NHKUiState {
    [CmdletBinding()] param([AllowNull()]$Value)
    $s = [pscustomobject]@{ Value = $Value; Listeners = (New-Object System.Collections.ArrayList) }
    $s.PSObject.TypeNames.Insert(0, 'NativeHTMLKit.UI.State')
    $s | Add-Member -MemberType ScriptMethod -Name Set -Value {
        param($Next)
        if ([object]::Equals($this.Value, $Next)) { return }
        $this.Value = $Next
        foreach ($subscription in @($this.Listeners.ToArray())) {
            if ($subscription.Active) { $null = & $subscription.Callback $Next }
        }
    }
    $s | Add-Member -MemberType ScriptMethod -Name Subscribe -Value {
        param([scriptblock]$Callback)
        $subscription = [pscustomobject]@{ Callback = $Callback; Active = $true }
        [void]$this.Listeners.Add($subscription)
        return $subscription
    }
    $s | Add-Member -MemberType ScriptMethod -Name Unsubscribe -Value {
        param($Subscription)
        $Subscription.Active = $false
        [void]$this.Listeners.Remove($Subscription)
    }
    return $s
}

function New-NHKUiComputed {
    <# Explicit dependencies avoid PowerShell AST/proxy instrumentation. #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][scriptblock]$Compute,
        [Parameter(Mandatory)][object[]]$DependsOn,
        [AllowNull()]$Data
    )
    $s = New-NHKUiState -Value (& $Compute $Data)
    $tokens = New-Object System.Collections.ArrayList
    foreach ($dep in $DependsOn) {
        if ($null -eq $dep -or $dep.PSObject.TypeNames[0] -notmatch '^NativeHTMLKit.UI.State$') {
            throw 'DependsOn must contain only NativeHTMLKit.UI.State objects'
        }
        $computed = $s
        $fn = $Compute
        $context = $Data
        $callback = { param($ignored) $computed.Set((& $fn $context)) }.GetNewClosure()
        $sub = $dep.Subscribe($callback)
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
        Handlers = @{}; Pending = @{}; Subscriptions = (New-Object System.Collections.ArrayList)
        Window = $null; Document = $null; Application = $null
        InEvent = 0; Disposed = $false; LastError = $null; DomUncertain = $false
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

function Add-NHKUiBindingInternal {
    param($UI, $Node, $State, [string]$Kind, [string]$Name='')
    if ($null -eq $State -or $State.PSObject.TypeNames[0] -ne 'NativeHTMLKit.UI.State') {
        throw "A -Bind argument must be created with New-NHKUiState or New-NHKUiComputed"
    }
    $binding = [pscustomobject]@{
        Id = $Node.Id; Kind = $Kind; Name = $Name; State = $State
        Last = $State.Value; Subscription = $null
    }
    $localUi = $UI; $localBinding = $binding
    $onChange = {
        param($ignored)
        if ($localUi.Disposed) { return }
        Assert-NHKUiOwner $localUi
        $localUi.Pending[$localBinding.Id + '|' + $localBinding.Kind + '|' + $localBinding.Name] = $localBinding
        if ($null -ne $localUi.Document -and $localUi.InEvent -eq 0) { Sync-NHKUi -UI $localUi }
    }.GetNewClosure()
    $binding.Subscription = $State.Subscribe($onChange)
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
    if (-not $UI.Handlers.ContainsKey($Kind)) { $UI.Handlers[$Kind] = @{} }
    $UI.Handlers[$Kind][$Node.Id] = [pscustomobject]@{ Callback = $Callback; Data = $Data }
}

function Invoke-NHKUiEventInternal {
    param($UI, [string]$Kind, $Event)
    if ($UI.Disposed) { return }
    Assert-NHKUiOwner $UI
    $handlers = $UI.Handlers[$Kind]
    if ($null -eq $handlers) { return }
    $path = New-Object System.Collections.ArrayList
    $target = [string]$Event.element
    if ($target) { [void]$path.Add($target) }
    foreach ($item in @($Event.path)) { if ($item) { [void]$path.Add([string]$item) } }
    foreach ($id in $path) {
        if ($handlers.ContainsKey([string]$id)) {
            $UI.InEvent++
            try {
                $entry = $handlers[[string]$id]
                $null = & $entry.Callback $Event $entry.Data
            } catch {
                $UI.LastError = $_.Exception.Message
                throw
            } finally {
                $UI.InEvent--
                if (-not $UI.Disposed -and $UI.InEvent -eq 0) { Sync-NHKUi -UI $UI }
            }
            break
        }
    }
}

function Sync-NHKUi {
    <# Apply only changed bound properties. Call from the owning runspace. #>
    [CmdletBinding()] param([Parameter(Mandatory)]$UI)
    Assert-NHKUiOwner $UI
    if ($null -eq $UI.Document) { return }
    if ($UI.DomUncertain) { throw 'UI DOM state is uncertain after a failed operation; do not continue managed updates' }
    if ($UI.Pending.Count -eq 0) { return }
    $pending = @($UI.Pending.Values)
    $UI.Pending.Clear()
    $ops = New-Object System.Collections.ArrayList
    $special = New-Object System.Collections.ArrayList
    foreach ($b in $pending) {
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
            default { [void]$special.Add([pscustomobject]@{Binding=$b;Value=$next}) }
        }
    }
    # The public SDK's batch is limited; failed batches must not be silently ignored.
    try {
    for ($i=0; $i -lt $ops.Count; $i+=128) {
        $len = [Math]::Min(128, $ops.Count-$i)
        $block = New-Object 'object[]' $len
        for ($j=0; $j -lt $len; $j++) { $block[$j] = $ops[$i+$j] }
        Invoke-NativeHTMLKitBatch -Document $UI.Document -Operations $block
    }
    foreach ($entry in $special) {
        switch ($entry.Binding.Kind) {
            'value' { Set-NativeHTMLKitDocumentValue -Document $UI.Document -Element $entry.Binding.Id -Value ([string]$entry.Value) }
            'checked' { Set-NativeHTMLKitChecked -Document $UI.Document -Element $entry.Binding.Id -Checked ([bool]$entry.Value) }
            'list' { Set-NativeHTMLKitDocumentHtml -Document $UI.Document -Element $entry.Binding.Id -Html (ConvertTo-NHKUiListMarkup $entry.Value) }
        }
    }
    } catch {
        $UI.DomUncertain = $true
        $UI.LastError = $_.Exception.Message
        throw
    }
}

function Get-NHKUiDiagnostics {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI)
    return [pscustomobject]@{
        DomUncertain = [bool]$UI.DomUncertain
        LastError = $UI.LastError
        PendingUpdates = [int]$UI.Pending.Count
        Disposed = [bool]$UI.Disposed
    }
}

function Start-NHKUi {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI, [Parameter(Mandatory)]$Application, [switch]$NoReady)
    if ($null -ne $UI.Document) { throw 'UI already started' }
    Assert-NHKUiOwner $UI
    $UI.OwnerRunspaceId = [runspace]::DefaultRunspace.InstanceId
    $UI.Application = $Application
    # NativeHTMLKit is an installed *SDK*, not an internal Core binding.
    $UI.Window = New-NativeHTMLKitWindow -Application $Application -Title $UI.Title -Width $UI.Width -Height $UI.Height
    try {
        $UI.Document = Open-NativeHTMLKitHtml -Window $UI.Window -Html (Get-NHKUiHtml -UI $UI)
        # If a state changed after its markup was constructed, apply it now.
        Sync-NHKUi -UI $UI
        foreach ($binding in @($UI.Bindings.ToArray())) {
            if ($binding.Kind -eq 'value') {
                Set-NativeHTMLKitDocumentValue -Document $UI.Document -Element $binding.Id -Value ([string]$binding.Last)
            } elseif ($binding.Kind -eq 'checked') {
                Set-NativeHTMLKitChecked -Document $UI.Document -Element $binding.Id -Checked ([bool]$binding.Last)
            }
        }
        foreach ($kind in @($UI.Handlers.Keys)) {
            $localUi = $UI; $localKind = [string]$kind
            $callback = {
                param($eventObject)
                Invoke-NHKUiEventInternal -UI $localUi -Kind $localKind -Event $eventObject
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
