# NativeHTMLKit.UI — PowerShell UI toolkit

A compact component layer using only the public [NativeHTMLKit PowerShell SDK](https://www.powershellgallery.com/packages/NativeHTMLKit). PowerShell 7.2+ (Linux and Windows) and Windows PowerShell 5.1 (Windows). Install with `Install-Module NativeHTMLKit.UI -Scope CurrentUser` (installs the `NativeHTMLKit` SDK as a dependency). **Version 0.1.1 is an early (pre-1.0) release**; see the [known limitations](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/LIMITATIONS.md).

```powershell
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Hello UI'
$ui = New-NHKUi -Title 'Hello' -Theme cobalt -Density compact
$name = New-NHKUiState -Value 'Ada'
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Hello'
    $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Name'
}
try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    Close-NativeHTMLKit -Application $app
}
```

Use [counter.ps1](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/counter.ps1) for events and computed state. The module does not create its own host or HTTP service; the application remains responsible for SDK lifecycle and for disposing computed states.
