# NativeHTMLKit UI

**A deliberately small reactive component layer for native desktop apps.** Two implementations:
Python (`nativehtmlkit_ui`) and PowerShell (`NativeHTMLKit.UI`), each depending only on its
public NativeHTMLKit SDK. No browser, JavaScript, plugin system or server.

[Tutorials](docs/tutorials/README.md) · [How-to guides](docs/guides/README.md) ·
[API reference](docs/API.md) · [Examples](examples/README.md) ·
[Python package](python/) · [PowerShell module](powershell/)

## Python

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state

with Application.start(name='UI Quick Start') as app:
    count = state(0)
    ui = UI(title='Counter', theme='cobalt', density='compact')
    with ui.column():
        ui.heading('My counter')
        ui.text(lambda: f'Count: {count.value}')
        ui.button('Add', on_click=lambda event: count.set(count.value + 1))
    ui.mount(app)
    app.run()
```

`python -m pip install nativehtmlkit_ui` (Python 3.10+, Linux and Windows).

## PowerShell

```powershell
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'UI Quick Start'
$ui = New-NHKUi -Title 'Counter' -Theme cobalt -Density compact
$count = New-NHKUiState -Value 0
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'My counter'
    $null = Add-NHKUiText -UI $ui -Bind $count
    $null = Add-NHKUiButton -UI $ui -Text 'Add' -Data $count -OnClick { param($eventObject, $s) $s.Set([int]$s.Value + 1) }
}
try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    Close-NativeHTMLKit -Application $app
}
```

`Install-Module NativeHTMLKit.UI -Scope CurrentUser` (PowerShell 7.2+ on Linux and Windows,
Windows PowerShell 5.1).

The UI library is an **early 0.1.1 release** (PyPI `nativehtmlkit_ui`, PowerShell Gallery
`NativeHTMLKit.UI`), not a promise of stable feature parity or fully qualified screen-reader
support. See [current limitations](docs/LIMITATIONS.md).

## What it offers

Layouts (row, column, responsive grid, card), headings, text, badges and alerts, buttons,
inputs, checkboxes and selects with two-way binding, conditional regions, reactive text lists,
three themes and three densities, and a scheduler that turns state changes into batched
document updates. It is not an application framework: no routing, modal wrappers, plugins or
HTTP endpoint. Native file dialogs, the clipboard, HTML dialogs and bitmaps remain SDK
capabilities that you call next to the UI.

## Documentation

| | |
|---|---|
| Learn | [Tutorial: expense tracker in Python](docs/tutorials/python-expense-tracker.md) · [in PowerShell](docs/tutorials/powershell-expense-tracker.md) |
| How-to | [State](docs/guides/reactive-state.md) · [Layouts](docs/guides/layouts.md) · [Forms](docs/guides/forms-and-inputs.md) · [Lists](docs/guides/lists-and-conditional-content.md) · [Theming](docs/guides/theming-and-custom-css.md) · [Background work](docs/guides/background-work.md) · [Windows](docs/guides/multiple-windows.md) · [SDK calls](docs/guides/mixing-ui-and-sdk-calls.md) · [Trusted content](docs/guides/trusted-and-untrusted-content.md) · [Testing](docs/guides/testing.md) |
| Reference | [API index](docs/API.md) · [Python](docs/reference/python.md) · [PowerShell](docs/reference/powershell.md) · [CSS](docs/reference/css.md) |
| Explanation | [Architecture](docs/ARCHITECTURE.md) |
| Examples | [12 apps per language](examples/README.md), verified by [`qualification/examples`](qualification/examples/run_examples.py) |
| Project | [Build and qualification](docs/BUILD.md) · [Known limitations](docs/LIMITATIONS.md) |

## Project navigation

- [Overview and tutorials](https://github.com/nativehtmlkit/nativehtmlkit) — public developer landing page.
- [Capability and platform matrix](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/docs/capabilities/matrix.md) — which API works where.
- [Known limitations](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/docs/capabilities/limitations.md) — known defects and qualification limits.
- Active private development work is tracked in `nativehtmlkit-project`, not in this repository's documentation.
