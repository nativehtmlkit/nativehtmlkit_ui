# Text transformer with copy/paste: mixes UI state with direct SDK clipboard calls.
#
# Teaches: calling public SDK cmdlets (Set-NativeHTMLKitClipboard / Get-NativeHTMLKitClipboard)
# from a UI button callback, reporting SDK errors in the UI instead of failing the callback
# (the clipboard is unavailable in headless test mode, error -32001), and a computed preview.
#
# Run:  pwsh -File ./clipboard_tool.ps1   |   powershell.exe -NoProfile -File .\clipboard_tool.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Clipboard tool'

$s = @{
    App = $app; Source = (New-NHKUiState -Value ''); Mode = (New-NHKUiState -Value 'title'); Status = (New-NHKUiState -Value '')
    TextInfo = [Globalization.CultureInfo]::InvariantCulture.TextInfo
}
$s.Result = New-NHKUiComputed -DependsOn @($s.Source, $s.Mode) -Data $s -Compute {
    param($s)
    $text = [string]$s.Source.Value
    switch ($s.Mode.Value) {
        'upper' { $text.ToUpperInvariant() }
        'lower' { $text.ToLowerInvariant() }
        'title' { $s.TextInfo.ToTitleCase($text.ToLowerInvariant()) }
        'slug' { ($text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-') }
        'squash' { (@($text -split '\s+' | Where-Object { $_ })) -join ' ' }
        'reverse' { $words = @($text -split '\s+' | Where-Object { $_ }); [array]::Reverse($words); $words -join ' ' }
    }
}
$s.Preview = New-NHKUiComputed -DependsOn @($s.Result) -Data $s -Compute { param($s) if ($s.Result.Value) { $s.Result.Value } else { '(empty)' } }
$s.Length = New-NHKUiComputed -DependsOn @($s.Result) -Data $s -Compute { param($s) '{0} characters' -f ([string]$s.Result.Value).Length }
$s.Empty = New-NHKUiComputed -DependsOn @($s.Result) -Data $s -Compute { param($s) -not $s.Result.Value }
$computeds = @($s.Result, $s.Preview, $s.Length, $s.Empty)

$ui = New-NHKUi -Title 'Clipboard tool' -Width 680 -Height 520
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Clipboard text tool' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $s.Source -Label 'Text' -Placeholder 'Paste or type something'
        $null = Add-NHKUiSelect -UI $ui -Bind $s.Mode -Label 'Transform' -Options @(
            @{ Value = 'upper'; Label = 'UPPER CASE' }, @{ Value = 'lower'; Label = 'lower case' },
            @{ Value = 'title'; Label = 'Title Case' }, @{ Value = 'slug'; Label = 'slug-for-urls' },
            @{ Value = 'squash'; Label = 'Collapse whitespace' }, @{ Value = 'reverse'; Label = 'Reverse word order' })
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiButton -UI $ui -Text 'Paste' -Variant secondary -Data $s -OnClick {
                param($eventObject, $s)
                try {
                    $s.Source.Set((Get-NativeHTMLKitClipboard -Application $s.App))
                    $s.Status.Set('Pasted from the clipboard.')
                } catch { $s.Status.Set('Clipboard unavailable: ' + $_.Exception.Message) }
            }
            $null = Add-NHKUiButton -UI $ui -Text 'Copy result' -DisabledState $s.Empty -Data $s -OnClick {
                param($eventObject, $s)
                try {
                    Set-NativeHTMLKitClipboard -Application $s.App -Text ([string]$s.Result.Value)
                    $s.Status.Set(('Copied {0} characters to the clipboard.' -f ([string]$s.Result.Value).Length))
                } catch { $s.Status.Set('Clipboard unavailable: ' + $_.Exception.Message) }
            }
        }
    }
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Result' -Level 3
        $null = Add-NHKUiText -UI $ui -Bind $s.Preview
        $null = Add-NHKUiText -UI $ui -Bind $s.Length -Muted
    }
    $null = Add-NHKUiWhen -UI $ui -Bind $s.Status -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.Status }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
