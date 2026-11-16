# NativeHTMLKit UI

**A deliberately small reactive component layer for native desktop apps.** Two implementations: Python (`nativehtmlkit_ui`) and PowerShell (`NativeHTMLKit.UI`), each depending only on its public NativeHTMLKit SDK. No browser, JavaScript, plugin system or server.

[Developer tutorials](https://github.com/nativehtmlkit/nativehtmlkit) · [Python package](python/) · [PowerShell module](powershell/) · [API reference](docs/API.md)

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

The UI library is a **GitHub v0.1.0 prerelease**, not a promise of stable feature parity or fully qualified screen-reader support. See [current limitations](docs/LIMITATIONS.md).

## PowerShell

Use the [PowerShell UI counter example](examples/powershell/counter.ps1). The script creates state with `New-NHKUiState`, uses `Add-NHKUi*` components, calls `Start-NHKUi` and waits with `Wait-NativeHTMLKit`.

## Supported design goals

Layouts (row/column/grid/card), headings/text/badge/alert, button/input/checkbox/select, conditional display, reactive text lists, themes and density. This is not an application framework with routing, modal wrappers, plugin injection or an HTTP endpoint. Native file dialogs and HTML dialogs remain SDK capabilities.

| Guide | Read |
|---|---|
| Python UI reference | [API](docs/API.md) and [Python package](python/README.md) |
| PowerShell UI reference | [PowerShell module](powershell/README.md) |
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Demos and tests | [docs/EXAMPLES.md](docs/EXAMPLES.md) |
| Known caveats | [docs/LIMITATIONS.md](docs/LIMITATIONS.md) |

## Project navigation

- [Overview and tutorials](https://github.com/nativehtmlkit/nativehtmlkit) — public developer landing page.
- [Capability and platform matrix](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/docs/capabilities/matrix.md) — which API works where.
- [Known limitations](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/docs/capabilities/limitations.md) — known defects and qualification limits.
- Active private development work is tracked in `nativehtmlkit-project`, not in this repository's documentation.
