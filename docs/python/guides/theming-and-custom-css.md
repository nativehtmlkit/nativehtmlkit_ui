# Theming and custom CSS

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[theming and custom CSS](../../powershell/guides/theming-and-custom-css.md).*

**Goal:** pick a theme and density, adjust colours, and style your own elements.

## Themes and densities

```python
ui = UI(title="Dashboard", theme="graphite", density="regular", extra_css=CSS)
```

- Themes: `cobalt` (dark blue, default), `graphite` (dark grey), `daylight` (light).
- Densities: `compact` (default), `regular`, `comfortable`.
- The [CSS reference](../../css.md) lists every token and class.

To see them all, run the
[`theme_preview` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/theme_preview.py)
with different arguments. It uses `Application.start(instance="multiple")`, so several previews
can run side by side:

```text
uv run theme_preview.py cobalt compact
uv run theme_preview.py daylight comfortable "#0f7b6c"
```

## Override design tokens

Extra CSS is appended after the built-in stylesheet, so the same selector wins. Override
**tokens** on `body.nhk-theme-<name>`; every component follows. From `theme_preview.py`:

```python
extra = (f"body.nhk-theme-{theme} {{ --nhk-accent: {accent}; --nhk-accent-strong: {accent}; "
         f"--nhk-focus: {accent}; }}") if accent else ""
ui = UI(title=f"Theme preview: {theme}/{density}", theme=theme, density=density, extra_css=extra)
```

Change `--nhk-accent`, `--nhk-accent-strong` and `--nhk-focus` together and check contrast
against `--nhk-accent-text`.

## Style your own elements

`ui.element()` creates an allowed tag with your own class (from the
[`dashboard` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/dashboard.py)):

```python
CSS = """
.metric { font-size: 30px; font-weight: 700; letter-spacing: -0.02em; margin: 4px 0; }
.nhk-card { border-top: 3px solid var(--nhk-accent); }
body.nhk-theme-daylight { --nhk-accent: #0f7b6c; --nhk-accent-strong: #0b6458; --nhk-focus: #0f7b6c; }
"""
...
ui.element("div", css_class="metric", text=clock)
```

Guidelines:

- Use `var(--nhk-*)` in your own rules so they work in every theme.
- Target classes, never generated ids (they are random per run).
- Extra CSS is trusted developer input. Do not build it from user input (the preview only
  accepts an accent that matches `#RRGGBB`).
- Core renders a defined CSS subset natively (no browser engine); test layouts on your target
  desktops. See Core's [HTML/CSS support](https://github.com/nativehtmlkit/nativehtmlkit-core/blob/main/docs/guides/html-css-support.md).

## Choose the theme at start

Theme and density are fixed when the window opens. Take them from the command line (the
dashboard and theme preview), from a saved setting (the
[settings-editor tutorial](../tutorials/settings-editor.md) starts in the saved theme), or from
the desktop: read `app.desktop_preferences()` before building the UI and pick `daylight` or a
dark theme. Inspect the returned dictionary on your systems first; the UI library does not
interpret it.

## Related

[CSS reference](../../css.md) · [layouts](layouts.md) ·
[Python reference: `UI`](../reference.md#ui)
