# NativeHTMLKit UI

**A deliberately small reactive component layer for native desktop apps.** Two implementations:
Python (`nativehtmlkit_ui`) and PowerShell (`NativeHTMLKit.UI`), each depending only on its
public NativeHTMLKit SDK. No browser, JavaScript, plugin system or server.

Docs: [Python](docs/python/README.md) · [PowerShell](docs/powershell/README.md) ·
[API index](docs/API.md) · [Examples](examples/README.md) ·
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

In a uv project (`uv init --app myapp && cd myapp`): `uv add nativehtmlkit_ui`, then `uv run app.py` (Python 3.10+, Linux and Windows).

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
| | Python | PowerShell |
|---|---|---|
| Start | [Getting started](docs/python/getting-started.md) | [Getting started](docs/powershell/getting-started.md) |
| Learn | Tutorials: [expense tracker](docs/python/tutorials/expense-tracker.md) · [settings editor](docs/python/tutorials/settings-editor.md) | Tutorials: [expense tracker](docs/powershell/tutorials/expense-tracker.md) · [settings editor](docs/powershell/tutorials/settings-editor.md) |
| How-to | [10 guides](docs/python/guides/README.md) | [the same 10 guides](docs/powershell/guides/README.md) |
| Examples | [16 apps with source](docs/python/examples.md) | [the same 16 apps](docs/powershell/examples.md) |
| Reference | [Python API](docs/python/reference.md) | [PowerShell API](docs/powershell/reference.md) |

| | |
|---|---|
| Shared | [API index](docs/API.md) · [CSS reference](docs/css.md) |
| Explanation | [Architecture](docs/ARCHITECTURE.md) |
| Examples | [Catalogue](examples/catalog.toml) and [overview](examples/README.md), verified by [`qualification/examples`](qualification/examples/run_examples.py) |
| Project | [Build and qualification](docs/BUILD.md) · [Known limitations](docs/LIMITATIONS.md) |

## Project navigation

- [Overview and tutorials](https://github.com/nativehtmlkit/nativehtmlkit) — public developer landing page.
- [Capability and platform matrix](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/docs/capabilities/matrix.md) — which API works where.
- [Known limitations](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/docs/capabilities/limitations.md) — known defects and qualification limits.
- Active private development work is tracked in `nativehtmlkit-project`, not in this repository's documentation.
