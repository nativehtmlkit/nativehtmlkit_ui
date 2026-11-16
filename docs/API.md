# UI library public API — version 0.1.1

This reference documents the **actual small component surface**, not future roadmap concepts. It covers the Python `nativehtmlkit_ui` and PowerShell `NativeHTMLKit.UI` packages. Both depend solely on their respective **public** NativeHTMLKit SDK APIs. Version 0.1.1 is an early (pre-1.0) release; its packages passed the real-input GUI suite against Python/PowerShell SDK 0.1.2 and Core 1.0.3 (see [limitations](LIMITATIONS.md) for what was and was not re-run).

## Python quick start

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state, computed

with Application.start(name="Counter") as app:
    count = state(0)
    view = UI(title="Counter", theme="cobalt", density="compact")
    with view.column():
        view.heading("Counter")
        view.text(lambda: f"Count: {count.value}")
        view.button("Increment", on_click=lambda event: count.set(count.value + 1))
    view.mount(app)
    app.run()
    view.dispose()
```

| Concept | Public API |
|---|---|
| Reactive data | `state(value)`, `.set()`, `.subscribe()`; `computed(lambda: ...)`, `.close()` |
| Root UI | `UI(title, width, height, theme, density, extra_css)`, `.mount(app)`, `.dispose()` |
| Layout | `with ui.row()`, `.column()`, `.grid()`, `.card()`, `.stack()` |
| Display | `.heading()`, `.text()`, `.badge()`, `.alert()` |
| Form controls | `.button()`, `.input()`, `.checkbox()`, `.select()` |
| Dynamic content | `with ui.when(condition)`, `.text_list()` |
| Trusted markup | `.raw_html(markup)`, `.element(tag, attrs, text)` |
| Diagnostics | `.sync()`, `.post(callable, *args)`, `.diagnostics` |

All visual writes pass through the UI's public SDK document handle. Use `.post()` to marshal worker results into the UI owner context. **Known issue:** the current Python `Computed` implementation can lose updates under concurrent recomputation; avoid concurrent cross-thread updates to the same computed state until bug B-0002 is resolved and verified. UI teardown can leave registered application shutdown callbacks (B-0003).

## PowerShell quick start

```powershell
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Counter'
$ui = New-NHKUi -Title 'Counter' -Theme cobalt -Density compact
$count = New-NHKUiState -Value 0
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Counter'
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Add-NHKUiButton -UI $ui -Text 'Increment' -Data $count -OnClick {
        param($eventObject,$s) $s.Set([int]$s.Value + 1)
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

| Concept | Public API |
|---|---|
| State | `New-NHKUiState`, `.Value`, `.Set()`, `.Subscribe()` |
| Computed state | `New-NHKUiComputed -DependsOn ... -Data ... -Compute ...`, `.Dispose()` |
| Layout | `New-NHKUi`, `Add-NHKUiRow`, `Add-NHKUiColumn`, `Add-NHKUiGrid`, `Add-NHKUiCard` |
| Display | `Add-NHKUiHeading`, `Add-NHKUiText`, `Add-NHKUiBadge`, `Add-NHKUiAlert` |
| Inputs | `Add-NHKUiButton`, `Add-NHKUiInput`, `Add-NHKUiCheckbox`, `Add-NHKUiSelect` |
| Dynamic | `Add-NHKUiWhen`, `Add-NHKUiTextList` |
| Lifecycle | `Start-NHKUi`, `Stop-NHKUi`, `Sync-NHKUi`, `Invoke-NHKUiBatch` |
| Diagnostics | `Get-NHKUiDiagnostics` |

PowerShell event handlers receive `param($eventObject, $data)` when the helper's `-Data` argument is supplied. Computed values specify dependencies explicitly. PowerShell 7.2+ on Linux/Windows and Windows PowerShell 5.1 on Windows are the target hosts, not an assurance of full component parity in every environment.

## Where native dialogs and bitmap surfaces belong

The UI package deliberately does **not** wrap every SDK capability or add a generic modal/router/plugin framework. File dialogs, HTML `<dialog>`, native window management, bitmap resources and platform diagnostics remain **SDK-level** functionality. Use the [Python SDK](https://github.com/nativehtmlkit/nativehtmlkit-python) or [PowerShell SDK](https://github.com/nativehtmlkit/nativehtmlkit-powershell) API directly. See the [four source galleries](https://github.com/nativehtmlkit/nativehtmlkit/tree/main/examples) for practical demonstrations.

## Known limits

- The prerelease is not fully screen-reader qualified.
- Multi-monitor and mixed-DPI behavior require additional native GUI qualification.
- Python computed-state concurrency and shutdown callback retention are open issues.
- Always confirm behavior against the exact host/SDK versions being distributed.

[Architecture](ARCHITECTURE.md) · [Build and qualification](BUILD.md) · [Examples](EXAMPLES.md) · [Limitations](LIMITATIONS.md)
