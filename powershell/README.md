# NativeHTMLKit.UI — PowerShell UI toolkit

A compact reactive component layer using only the public
[NativeHTMLKit PowerShell SDK](https://www.powershellgallery.com/packages/NativeHTMLKit):
native desktop windows rendered from HTML/CSS, with no browser and no JavaScript. PowerShell
7.2+ (Linux and Windows) and Windows PowerShell 5.1 (Windows).

```powershell
Install-Module NativeHTMLKit.UI -Scope CurrentUser    # installs the NativeHTMLKit SDK as a dependency
```

**Version 0.1.1 is an early (pre-1.0) release**; see the
[known limitations](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/LIMITATIONS.md).

```powershell
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Hello UI'
$ui = New-NHKUi -Title 'Hello' -Theme cobalt -Density compact
$name = New-NHKUiState -Value 'Ada'
$greeting = New-NHKUiComputed -DependsOn @($name) -Data $name -Compute { param($n) "Hi, $($n.Value)!" }
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Hello'
    $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Name'
    $null = Add-NHKUiText -UI $ui -Bind $greeting
    $null = Add-NHKUiButton -UI $ui -Text 'Clear' -Variant secondary -Data $name -OnClick { param($eventObject, $n) $n.Set('') }
}
try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $greeting.Dispose()
    Close-NativeHTMLKit -Application $app
}
```

- **States in, window out.** `New-NHKUiState` holds data, `New-NHKUiComputed -DependsOn`
  derives values, `-Bind` connects components, and button callbacks
  (`param($eventObject, $data)`) only change states.
- **Components:** `Add-NHKUiRow/Column/Grid/Card`, `Add-NHKUiHeading/Text/Badge/Alert`,
  `Add-NHKUiButton/Input/Checkbox/Select`, `Add-NHKUiWhen`, `Add-NHKUiTextList`, trusted
  `Add-NHKUiHtml`.
- **Owner runspace:** UI states change only on the runspace that started the UI; background
  work uses `Start-NativeHTMLKitTask`, whose completion callbacks run there.
- **Batching:** callbacks are batched automatically; `Invoke-NHKUiBatch` groups other changes.

The module does not create its own host or HTTP service; the application owns the SDK
lifecycle and disposes its computed states.

## Documentation

- [Tutorial: build an expense tracker](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/tutorials/powershell-expense-tracker.md)
- [How-to guides](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/guides/README.md)
- [PowerShell API reference](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/reference/powershell.md) and [CSS reference](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/reference/css.md)
- [Architecture](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/ARCHITECTURE.md)
- [Example scripts](https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/examples/powershell) — expense tracker, task list, sign-up form, settings, log viewer, background task with cancel, clipboard tool, file inspector, multi-window notes, dashboard and more
