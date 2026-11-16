---
name: nativehtmlkit-ui-powershell
description: Build compact reactive PowerShell desktop UIs through NativeHTMLKit.UI and the public NativeHTMLKit SDK.
---

# NativeHTMLKit PowerShell UI

Use `Import-Module NativeHTMLKit.UI` with a supported public `NativeHTMLKit` SDK. This UI is a **0.1.1 prerelease**. State changes occur on the SDK owner runspace.

```powershell
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Counter'
$ui = New-NHKUi -Title 'Counter'
$count = New-NHKUiState -Value 0
$null = Add-NHKUiColumn -UI $ui -Content {
  $null = Add-NHKUiText -UI $ui -Bind $count
  $null = Add-NHKUiButton -UI $ui -Text 'Add' -Data $count -OnClick {
    param($eventObject,$state) $state.Set([int]$state.Value+1)
  }
}
try {
  $null = Start-NHKUi -UI $ui -Application $app
  Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
  Stop-NHKUi -UI $ui
  Close-NativeHTMLKit -Application $app
}
```

Use `New-NHKUiState`, `New-NHKUiComputed -DependsOn -Data -Compute`, `Add-NHKUi*`, `Invoke-NHKUiBatch` and `Stop-NHKUi`. UI button callbacks accept `param($eventObject,$data)` passed via `-Data`, unlike raw SDK `Register-NativeHTMLKitDocumentEvent` callbacks. Dispose computed values explicitly. No direct Core RPC, HTTP, or plugins.

[Examples](references/examples.md) and [API](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/API.md).
