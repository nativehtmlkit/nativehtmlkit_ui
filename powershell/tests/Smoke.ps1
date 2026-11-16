# Run after installing the published NativeHTMLKit SDK and loading the UI module.
# Does not start Core and does not depend on Pester.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../NativeHTMLKit.UI/NativeHTMLKit.UI.psd1') -Force -ErrorAction Stop
$s = New-NHKUiState -Value 'A'
$ui = New-NHKUi -Title 'Smoke <safe>'
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Simple'
    $null = Add-NHKUiText -UI $ui -Bind $s
    $null = Add-NHKUiInput -UI $ui -Bind $s -Label 'Name'
    $null = Add-NHKUiButton -UI $ui -Text 'Click' -Data $s -OnClick { param($eventObject,$data) $data.Set('clicked') }
}
$markup = Get-NHKUiHtml -UI $ui
if (-not $markup.Contains('Smoke &lt;safe&gt;') -or -not $markup.Contains('Simple')) { throw 'Markup/escaping failed' }
$s.Set('B')
if ($s.Value -ne 'B') { throw 'State failed' }
$derived = New-NHKUiComputed -DependsOn @($s) -Data $s -Compute { param($x) "Value=$($x.Value)" }
$s.Set('C')
if ($derived.Value -ne 'Value=C') { throw 'Computed failed' }
$derived.Dispose()
Stop-NHKUi -UI $ui
Write-Output 'PASS: PowerShell UI smoke without native host'
