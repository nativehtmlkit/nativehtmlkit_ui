# UI library API — version 0.1.1

This is the entry point to the API documentation of the Python package `nativehtmlkit_ui` and
the PowerShell module `NativeHTMLKit.UI`, both version 0.1.1. Both depend solely on the
**public** API of their NativeHTMLKit SDK. Version 0.1.1 is an early (pre-1.0) release; its
packages passed the real-input GUI suite against Python/PowerShell SDK 0.1.2 and Core 1.0.3
(see [limitations](LIMITATIONS.md) for what was and was not re-run).

| Reference | Contents |
|---|---|
| [Python reference](python/reference.md) | `State`, `Computed`, `UI` and every component, mounting, scheduling, `post()`, `sync()`, diagnostics, disposal, errors |
| [PowerShell reference](powershell/reference.md) | All 24 exported functions, state objects, owner runspace, batching, diagnostics |
| [CSS reference](css.md) | Themes, density tokens, component classes, theming hooks |
| [Architecture](ARCHITECTURE.md) | Rendering model, how state changes become document commands, coalescing |

Learning the library, per language: **Python** [getting started](python/getting-started.md) ·
[tutorials](python/tutorials/README.md) · [how-to guides](python/guides/README.md) ·
[examples](python/examples.md) — **PowerShell** [getting started](powershell/getting-started.md) ·
[tutorials](powershell/tutorials/README.md) · [how-to guides](powershell/guides/README.md) ·
[examples](powershell/examples.md).

## Python quick start

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state, computed

with Application.start(name="Counter") as app:
    count = state(0)
    label = computed(lambda: f"Count: {count.value}")
    view = UI(title="Counter", theme="cobalt", density="compact")
    with view.column():
        view.heading("Counter")
        view.text(label)
        view.button("Increment", on_click=lambda event: count.set(count.value + 1))
    view.mount(app)
    app.run()
```

| Concept | Public API |
|---|---|
| Reactive data | `state(value)` / `State`: `.value`, `.set()`, `.subscribe()`; `computed(fn)` / `Computed`: `.value`, `.close()` |
| Root UI | `UI(title, width, height, theme, density, extra_css)`, `.mount(app)`, `.dispose()` / `.close()`, `.html()` |
| Layout | `with ui.row()`, `.column()`, `.grid()`, `.card()`, `.stack()`, `.container(tag, css_class, attrs)` |
| Display | `.heading()`, `.text()`, `.badge()`, `.alert()` |
| Controls | `.button()`, `.input()`, `.checkbox()`, `.select()` |
| Dynamic content | `with ui.when(condition)`, `.text_list(values, formatter)` |
| Events | `on_click=`, `.on(element, kind, callback)` |
| Custom / trusted markup | `.element(tag, css_class, attrs, text)`, `.raw_html(markup)` (trusted only) |
| Threads and diagnostics | `.post(fn, *args)`, `.sync(timeout)`, `.diagnostics` |
| SDK handles | `.app`, `.window`, `.document`, `element.id` |

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
| State | `New-NHKUiState`: `.Value`, `.Set()`, `.Subscribe()`, `.Unsubscribe()` |
| Computed state | `New-NHKUiComputed -Compute -DependsOn -Data`, `.Dispose()` |
| Root UI | `New-NHKUi -Title -Width -Height -Theme -Density -ExtraCss`, `Get-NHKUiHtml` |
| Layout | `Add-NHKUiRow`, `Add-NHKUiColumn`, `Add-NHKUiGrid`, `Add-NHKUiCard` |
| Display | `Add-NHKUiHeading`, `Add-NHKUiText`, `Add-NHKUiBadge`, `Add-NHKUiAlert` |
| Controls | `Add-NHKUiButton`, `Add-NHKUiInput`, `Add-NHKUiCheckbox`, `Add-NHKUiSelect` |
| Dynamic | `Add-NHKUiWhen`, `Add-NHKUiTextList` |
| Trusted markup | `Add-NHKUiHtml` (trusted only) |
| Lifecycle | `Start-NHKUi [-NoReady]`, `Stop-NHKUi`, `Sync-NHKUi`, `Invoke-NHKUiBatch` |
| Diagnostics | `Get-NHKUiDiagnostics` |

PowerShell callbacks receive `param($eventObject, $data)` where `$data` is the `-Data`
argument. Computed states list their dependencies explicitly. PowerShell 7.2+ on
Linux/Windows and Windows PowerShell 5.1 on Windows are the target hosts.

## Known issues

- **B-0002 (Python):** `Computed` can falsely raise a circular-dependency error and keep a stale value
  when its dependencies are set from several threads at once. Serialize such writes, for
  example through `ui.post()`.
- **B-0003 (Python):** every `mount()` registers an application shutdown callback that cannot be
  removed; avoid creating and discarding many UIs in a long-running application.
- **B-0014 (both languages):** labelled inputs placed directly in a column are 200 px tall;
  workaround `.nhk-col > .nhk-field { flex: 0 0 auto; }` as extra CSS.

Details: [Python reference, known defects](python/reference.md#known-defects) and
[limitations](LIMITATIONS.md).

## Where dialogs, clipboard and bitmaps belong

The UI deliberately does **not** wrap every SDK capability or add a modal, router or plugin
framework. File dialogs, the clipboard, HTML `<dialog>`, native window management, live
bitmaps and platform diagnostics are SDK functionality; call them next to the UI as shown in
the SDK interop guide ([Python](python/guides/mixing-ui-and-sdk-calls.md),
[PowerShell](powershell/guides/mixing-ui-and-sdk-calls.md)). SDK references:
[Python SDK](https://github.com/nativehtmlkit/nativehtmlkit-python) ·
[PowerShell SDK](https://github.com/nativehtmlkit/nativehtmlkit-powershell).

[Architecture](ARCHITECTURE.md) · [Build and qualification](BUILD.md) · [Examples](EXAMPLES.md) · [Limitations](LIMITATIONS.md)
