# UI limitations and qualification

UI 0.1.1 is an early (pre-1.0) release. Its 0.1.1 packages passed the real-input GUI suite (state, input, keyboard focus, select, disabled bindings, responsive widths, two windows, 1000-update load, 100 mount/close cycles) at 100% scaling against Python SDK 0.1.2 / PowerShell SDK 0.1.2 / Core 1.0.3 on KDE Plasma 6.6 Wayland (Python, PowerShell 7) and Windows Server 2022 (Python, PowerShell 7, Windows PowerShell 5.1). IME, 125%/150% scaling and theme checks were last run with UI 0.1.0 on SDK 0.1.0 / Core 1.0.2. Screen-reader validation is incomplete and Core's select/Orca announcement issue remains open.

**Known UI bugs recorded in the Project register:** Python `Computed` can falsely raise a circular dependency error and retain a stale value during concurrent updates; disposing many UI windows can accumulate SDK shutdown callbacks. Until fixed, serialize writes affecting the same computed state, use background worker handoff via `ui.post`, and avoid rapidly creating/discarding many UIs in long-lived applications.

**Inputs placed directly in a column are 200px tall (0.1.1 stylesheet defect).** The built-in rule `.nhk-field { flex: 1 1 200px }` is meant for fields in a row, but in a column (`ui.column()`, `ui.stack()`, `Add-NHKUiColumn`) the 200px basis applies to the field's height, so a single input followed by more content leaves a large empty gap. Inputs inside a row or directly inside a card (a plain block) are not affected. Workaround: pass

```css
.nhk-col > .nhk-field { flex: 0 0 auto; }
```

as `extra_css=` (Python; add `.nhk-stack > .nhk-field` for `ui.stack()`) or `-ExtraCss` (PowerShell). The `signup_form` and `multi_window` examples do this. Guides: [Python layouts](python/guides/layouts.md), [PowerShell layouts](powershell/guides/layouts.md).

There is no UI modal wrapper, router, plugin system, arbitrary widget gallery, virtualized data grid, video/audio player, JS runtime, or HTTP server. The SDK may expose underlying HTML dialogs and bitmap surfaces; do not claim them as UI components.
