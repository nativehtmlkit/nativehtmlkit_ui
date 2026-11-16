# Theming and custom CSS

**Goal:** pick a theme and density, adjust colours, and style your own elements.

```python
ui = UI(title="Dashboard", theme="graphite", density="regular", extra_css=CSS)
```

```powershell
$ui = New-NHKUi -Title 'Dashboard' -Theme graphite -Density regular -ExtraCss $css
```

- Themes: `cobalt` (dark blue, default), `graphite` (dark grey), `daylight` (light).
- Densities: `compact` (default), `regular`, `comfortable`.
- The [CSS reference](../reference/css.md) lists every token and class.

## Extra CSS

Extra CSS is appended after the built-in stylesheet. From `examples/python/dashboard.py`:

```python
CSS = """
.metric { font-size: 30px; font-weight: 700; letter-spacing: -0.02em; margin: 4px 0; }
.nhk-card { border-top: 3px solid var(--nhk-accent); }
body.nhk-theme-daylight { --nhk-accent: #0f7b6c; --nhk-accent-strong: #0b6458; --nhk-focus: #0f7b6c; }
"""
...
ui.element("div", css_class="metric", text=clock)
```

PowerShell has no generic element function, so `examples/powershell/dashboard.ps1` styles the
structure it creates instead: `.nhk-card h1.nhk-heading { font-size: 30px; }`.

Guidelines:

- Override **tokens** (`--nhk-accent`, `--nhk-radius`, ...) on `body.nhk-theme-<name>`; every
  component follows. Change `--nhk-accent`, `--nhk-accent-strong` and `--nhk-focus` together and
  check contrast against `--nhk-accent-text`.
- Use `var(--nhk-*)` in your own rules so they work in every theme.
- Target classes, never generated ids (they are random per run).
- Extra CSS is trusted developer input. Do not build it from user input.
- Core renders a defined CSS subset natively (no browser engine); test layouts on your target
  desktops, as the examples were.

## Choosing the theme at start

Theme and density are fixed when the window opens. The dashboard example takes the theme as a
command-line argument:

```text
python dashboard.py daylight
pwsh -File ./dashboard.ps1 graphite
```

To follow the desktop's light or dark setting, read it with the SDK before building the UI
(`app.desktop_preferences()` in Python, `Get-NativeHTMLKitPreferences` in PowerShell) and pick
`daylight` or a dark theme. Inspect the returned object on your systems first; the UI library
does not interpret it.
