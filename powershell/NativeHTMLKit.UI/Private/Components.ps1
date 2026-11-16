# Tiny compositional control layer. Explicit -UI keeps component ownership obvious.

function Add-NHKUiContainerInternal {
    param($UI,[string]$Class,[scriptblock]$Content)
    $node = Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class=$Class}
    [void]$UI.Stack.Add($node)
    try { $null = & $Content }
    finally { $UI.Stack.RemoveAt($UI.Stack.Count-1) }
    return $node
}
function Add-NHKUiColumn {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)][scriptblock]$Content)
    return (Add-NHKUiContainerInternal $UI 'nhk-col' $Content)
}
function Add-NHKUiRow {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)][scriptblock]$Content)
    return (Add-NHKUiContainerInternal $UI 'nhk-row' $Content)
}
function Add-NHKUiGrid {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)][scriptblock]$Content)
    return (Add-NHKUiContainerInternal $UI 'nhk-grid' $Content)
}
function Add-NHKUiCard {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)][scriptblock]$Content)
    return (Add-NHKUiContainerInternal $UI 'nhk-card' $Content)
}
function Add-NHKUiHeading {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[string]$Text='', [ValidateRange(1,4)][int]$Level=2, $Bind)
    $node = Add-NHKUiElementInternal -UI $UI -Tag ('h'+$Level) -Attrs @{class='nhk-heading'} -Text $Text
    if ($null -ne $Bind) {
        $b = Add-NHKUiBindingInternal $UI $node $Bind text
        $node.Text = [string]$b.Last
    }
    return $node
}
function Add-NHKUiText {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[AllowEmptyString()][string]$Text='', $Bind,[switch]$Muted)
    $class = 'nhk-text'; if ($Muted) { $class += ' nhk-muted' }
    $node = Add-NHKUiElementInternal -UI $UI -Tag p -Attrs @{class=$class} -Text $Text
    if ($null -ne $Bind) {
        $b = Add-NHKUiBindingInternal $UI $node $Bind text
        $node.Text = [string]$b.Last
    }
    return $node
}
function Add-NHKUiBadge {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[string]$Text='', $Bind)
    $node = Add-NHKUiElementInternal -UI $UI -Tag span -Attrs @{class='nhk-badge'} -Text $Text
    if ($null -ne $Bind) {
        $b = Add-NHKUiBindingInternal $UI $node $Bind text
        $node.Text = [string]$b.Last
    }
    return $node
}
function Add-NHKUiAlert {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[string]$Text='', $Bind)
    $node = Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class='nhk-alert';role='status'} -Text $Text
    if ($null -ne $Bind) {
        $b = Add-NHKUiBindingInternal $UI $node $Bind text
        $node.Text = [string]$b.Last
    }
    return $node
}
function Add-NHKUiButton {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[string]$Text='',
        [ValidateSet('primary','secondary','danger','quiet')][string]$Variant='primary',
        [scriptblock]$OnClick, [AllowNull()]$Data, $DisabledState, $Bind)
    if (-not $Text -and $null -eq $Bind) { throw 'Add-NHKUiButton needs -Text or a bound -Bind label' }
    $attrs = @{class=('nhk-button nhk-'+$Variant);type='button'}
    $node = Add-NHKUiElementInternal -UI $UI -Tag button -Attrs $attrs -Text $Text
    if ($null -ne $Bind) {
        $b = Add-NHKUiBindingInternal $UI $node $Bind text
        $node.Text = [string]$b.Last
    }
    if ($null -ne $DisabledState) {
        $b = Add-NHKUiBindingInternal $UI $node $DisabledState disabled
        if ([bool]$b.Last) { $node.Attrs.disabled = $true }
    }
    if ($null -ne $OnClick) { Register-NHKUiActionInternal $UI $node click $OnClick $Data }
    return $node
}
function Add-NHKUiInput {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)]$Bind,
        [string]$Label='', [string]$Placeholder='',
        [ValidateSet('text','search','email','password','number')][string]$Type='text')
    if ($Label) {
        $field = Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class='nhk-field'}
        [void]$UI.Stack.Add($field)
    }
    try {
        $node = Add-NHKUiElementInternal -UI $UI -Tag input -Attrs @{class='nhk-input';type=$Type;placeholder=$Placeholder}
        $binding = Add-NHKUiBindingInternal $UI $node $Bind value
        $node.Attrs.value = [string]$binding.Last
        if ($Label) {
            # A native <label for> names the control; it precedes the control in reading order.
            $labelNode = Add-NHKUiElementInternal -UI $UI -Tag label -Attrs @{class='nhk-label';for=$node.Id} -Text $Label
            Move-NHKUiNodeBefore $field $labelNode $node
        }
        Register-NHKUiActionInternal $UI $node input $script:NHKUiControlChanged ([pscustomobject]@{
            UI = $UI; State = $Bind; Binding = $binding; Target = $node.Id; Kind = 'value' })
    } finally {
        if ($Label) { $UI.Stack.RemoveAt($UI.Stack.Count-1) }
    }
    return $node
}
function Add-NHKUiCheckbox {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)]$Bind,
        [Parameter(Mandatory)][string]$Label)
    $wrap = Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class='nhk-checkrow'}
    [void]$UI.Stack.Add($wrap)
    try {
        $node = Add-NHKUiElementInternal -UI $UI -Tag input -Attrs @{class='nhk-checkbox';type='checkbox'}
        $binding = Add-NHKUiBindingInternal $UI $node $Bind checked
        if ([bool]$binding.Last) { $node.Attrs.checked = $true }
        $null = Add-NHKUiElementInternal -UI $UI -Tag label -Attrs @{for=$node.Id} -Text $Label
    } finally { $UI.Stack.RemoveAt($UI.Stack.Count-1) }
    Register-NHKUiActionInternal $UI $node change $script:NHKUiControlChanged ([pscustomobject]@{
        UI = $UI; State = $Bind; Binding = $binding; Target = $node.Id; Kind = 'checked' })
    return $node
}
function Add-NHKUiSelect {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)]$Bind,
        [Parameter(Mandatory)][object[]]$Options, [string]$Label='')
    $field = Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class='nhk-field'}
    [void]$UI.Stack.Add($field)
    try {
        $node = Add-NHKUiElementInternal -UI $UI -Tag select -Attrs @{class='nhk-select'}
        $binding = Add-NHKUiBindingInternal $UI $node $Bind value
        [void]$UI.Stack.Add($node)
        try {
            foreach ($option in $Options) {
                # Options are ordinary @{Value='...';Label='...'} hashtables or objects.
                $v=[string]$option.Value; $t=[string]$option.Label
                $attrs=@{value=$v}
                if ($v -eq [string]$binding.Last) { $attrs.selected=$true }
                $null = Add-NHKUiElementInternal -UI $UI -Tag option -Attrs $attrs -Text $t
            }
        } finally { $UI.Stack.RemoveAt($UI.Stack.Count-1) }
        if ($Label) {
            $labelNode = Add-NHKUiElementInternal -UI $UI -Tag label -Attrs @{for=$node.Id;class='nhk-label'} -Text $Label
            Move-NHKUiNodeBefore $field $labelNode $node
        }
        Register-NHKUiActionInternal $UI $node change $script:NHKUiControlChanged ([pscustomobject]@{
            UI = $UI; State = $Bind; Binding = $binding; Target = $node.Id; Kind = 'value' })
    } finally { $UI.Stack.RemoveAt($UI.Stack.Count-1) }
    return $node
}
function Add-NHKUiWhen {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)]$Bind,[Parameter(Mandatory)][scriptblock]$Content)
    $node = Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class='nhk-region'}
    $b = Add-NHKUiBindingInternal $UI $node $Bind visible
    if (-not [bool]$b.Last) { $node.Attrs.class = 'nhk-region nhk-hidden' }
    [void]$UI.Stack.Add($node)
    try { $null = & $Content } finally { $UI.Stack.RemoveAt($UI.Stack.Count-1) }
    return $node
}
function Add-NHKUiTextList {
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)]$Bind)
    $node = Add-NHKUiElementInternal -UI $UI -Tag ul -Attrs @{class='nhk-list'}
    $b = Add-NHKUiBindingInternal $UI $node $Bind list
    $node.Raw = ConvertTo-NHKUiListMarkup $b.Last
    return $node
}
function Add-NHKUiHtml {
    <# Trusted static markup ONLY. Never pass user/remote HTML. #>
    [CmdletBinding()] param([Parameter(Mandatory)]$UI,[Parameter(Mandatory)][AllowEmptyString()][string]$Markup)
    return (Add-NHKUiElementInternal -UI $UI -Tag div -Attrs @{class='nhk-custom'} -Raw $Markup)
}
