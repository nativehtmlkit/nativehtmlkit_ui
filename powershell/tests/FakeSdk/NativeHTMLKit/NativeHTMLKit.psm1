# Test double of the public NativeHTMLKit SDK commands NativeHTMLKit.UI uses. PS 5.1 + 7.
if (-not ('NativeHTMLKit.StaleObjectException' -as [type])) {
    Add-Type -TypeDefinition @'
namespace NativeHTMLKit {
    public class StaleObjectException : System.InvalidOperationException { public StaleObjectException(string m) : base(m) {} }
    public class RpcException : System.Exception { public RpcException(string m) : base(m) {} }
    public class RpcTimeoutException : System.TimeoutException { public RpcTimeoutException(string m) : base(m) {} }
}
'@
}
$script:Fake = $null
function Reset-FakeNHK {
    $script:Fake = [pscustomobject]@{
        Log = (New-Object System.Collections.ArrayList); Windows = 0; Docs = 0; Ready = 0
        Fault = $null; Stale = $false; WriteHook = $null; Values = @{}; Checked = @{}; Dispatching = $false
    }
}
Reset-FakeNHK
function Get-FakeNHK { return $script:Fake }
function Write-FakeLog { param($Entry) [void]$script:Fake.Log.Add($Entry) }
function Assert-FakeWritable {
    param($Document)
    if ($script:Fake.Stale -or $Document.Retired) { throw (New-Object NativeHTMLKit.StaleObjectException 'This document was replaced, unloaded, or closed') }
    if ($null -ne $script:Fake.Fault) { $f = $script:Fake.Fault; throw $f }
    if ($null -ne $script:Fake.WriteHook -and -not $script:Fake.Dispatching) {
        # Emulates the SDK pumping host notifications while it waits for this write's reply.
        $hook = $script:Fake.WriteHook; $script:Fake.WriteHook = $null
        & $hook
    }
}
function New-FakeApplication { return [pscustomobject]@{ Name = 'fake' } }
function New-NativeHTMLKitWindow {
    [CmdletBinding()] param([Parameter(Mandatory)]$Application, [string]$Title='', [int]$Width=900, [int]$Height=600)
    $script:Fake.Windows++
    Write-FakeLog @{ cmd='window.create'; title=$Title; width=$Width; height=$Height }
    return [pscustomobject]@{ Application = $Application; Id = ('w' + $script:Fake.Windows); Document = $null; Closed = $false }
}
function Open-NativeHTMLKitHtml {
    [CmdletBinding()] param([Parameter(Mandatory)]$Window, [Parameter(Mandatory)][AllowEmptyString()][string]$Html)
    $script:Fake.Docs++
    Write-FakeLog @{ cmd='document.load'; html=$Html }
    $doc = [pscustomobject]@{ Window = $Window; Id = ('d' + $script:Fake.Docs); Retired = $false; Handlers = (New-Object System.Collections.ArrayList) }
    $Window.Document = $doc
    return $doc
}
function Register-NativeHTMLKitDocumentEvent {
    [CmdletBinding()] param([Parameter(Mandatory)]$Document, [Parameter(Mandatory)][string]$Type, [Parameter(Mandatory)][scriptblock]$Callback, [string]$Element)
    if ($Document.Handlers.Count -ge 256) { throw 'Document callback limit (256) reached' }
    $sub = [pscustomobject]@{ Document = $Document; Type = $Type; Element = $Element; Callback = $Callback }
    [void]$Document.Handlers.Add($sub)
    return $sub
}
function Unregister-NativeHTMLKitDocumentEvent {
    [CmdletBinding()] param([Parameter(Mandatory)]$Subscription)
    [void]$Subscription.Document.Handlers.Remove($Subscription)
}
function Send-FakeNHKEvent {
    # Delivers a document event like the SDK pump: callbacks run one at a time, isolated.
    param($Document, [hashtable]$Event)
    $obj = [pscustomobject]$Event
    $failures = 0
    foreach ($h in @($Document.Handlers.ToArray())) {
        if ($h.Type -ne $obj.type) { continue }
        $was = $script:Fake.Dispatching; $script:Fake.Dispatching = $true
        try { $null = & $h.Callback $obj } catch { $failures++; Write-FakeLog @{ cmd='callback.failed'; message=$_.Exception.Message } }
        finally { $script:Fake.Dispatching = $was }
    }
    return $failures
}
function Invoke-NativeHTMLKitBatch {
    [CmdletBinding()] param([Parameter(Mandatory)]$Document, [Parameter(Mandatory)][object[]]$Operations)
    Assert-FakeWritable $Document
    Write-FakeLog @{ cmd='batch'; ops=@($Operations) }
}
function Set-NativeHTMLKitDocumentValue {
    [CmdletBinding()] param([Parameter(Mandatory)]$Document, [Parameter(Mandatory)][string]$Element, [Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    Assert-FakeWritable $Document
    $script:Fake.Values[$Element] = $Value
    Write-FakeLog @{ cmd='set_value'; element=$Element; value=$Value }
}
function Get-NativeHTMLKitValue {
    [CmdletBinding()] param([Parameter(Mandatory)]$Document, [Parameter(Mandatory)][string]$Element)
    Write-FakeLog @{ cmd='get_value'; element=$Element }
    return [string]$script:Fake.Values[$Element]
}
function Set-NativeHTMLKitChecked {
    [CmdletBinding()] param([Parameter(Mandatory)]$Document, [Parameter(Mandatory)][string]$Element, [Parameter(Mandatory)][bool]$Checked)
    Assert-FakeWritable $Document
    $script:Fake.Checked[$Element] = $Checked
    Write-FakeLog @{ cmd='set_checked'; element=$Element; checked=$Checked }
}
function Get-NativeHTMLKitChecked {
    [CmdletBinding()] param([Parameter(Mandatory)]$Document, [Parameter(Mandatory)][string]$Element)
    Write-FakeLog @{ cmd='get_checked'; element=$Element }
    return [bool]$script:Fake.Checked[$Element]
}
function Set-NativeHTMLKitReady {
    [CmdletBinding()] param([Parameter(Mandatory)]$Application)
    $script:Fake.Ready++
    Write-FakeLog @{ cmd='app.ready' }
}
