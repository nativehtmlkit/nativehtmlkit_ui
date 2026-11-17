# Layouts and the responsive grid

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[layouts](../../powershell/guides/layouts.md).*

**Goal:** arrange components with rows, columns, cards and a grid that adapts to the window.

## Containers

| Python | Element | Use for |
|---|---|---|
| `with ui.column():` | `div.nhk-col` | The main vertical flow of a window. |
| `with ui.row():` | `div.nhk-row` | Toolbars, a field next to its button, badges next to a heading. Wraps when narrow. |
| `with ui.card():` | `div.nhk-card` | Grouping related content on a panel. |
| `with ui.grid():` | `div.nhk-grid` | Dashboards and settings pages: equal-width cells. |
| `with ui.stack():` | `div.nhk-stack` | Tight vertical groups (6 px gap). Python only. |
| `with ui.container("section", css_class="x"):` | any allowed tag | Your own structure and classes. Python only. |

Containers are context managers; components created inside the `with` block become children.

## A typical window

```python
with ui.column():
    with ui.row():
        ui.heading("Settings", level=1)
        ui.badge(lambda: "Unsaved changes" if dirty.value else "All changes saved")
    with ui.grid():
        with ui.card():
            ui.heading("Profile", level=3)
            ui.input(name, label="Display name")
        with ui.card():
            ui.heading("Editor", level=3)
            ui.select(font_size, FONT_SIZES, label="Font size")
    with ui.row():
        ui.button("Save", on_click=save)
        ui.button("Revert", variant="secondary", on_click=revert)
```

The full version is the [`settings` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/settings.py).

## How the grid responds

`nhk-grid` uses three equal columns. When the window's viewport is at most **1000 px** wide it
switches to two columns, at most **620 px** to one column (and the app padding shrinks to
14 px). Cells keep `min-width: 0`, so long text wraps instead of widening the grid. There is no
column-span API; for a wide cell put the content outside the grid, or wrap it in
`ui.container(css_class="wide")` with extra CSS `.wide { grid-column: 1 / -1; }`.

Rows wrap: a labelled input or select is a flex item of at least 150 px that grows
(`flex: 1 1 200px`), so a row of three fields becomes two lines in a narrow window. The
[`dashboard` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/dashboard.py)
shows six cards that reflow as you resize.

## Fields directly in a column (known defect)

The 0.1.1 stylesheet applies the row rule `flex: 1 1 200px` to fields placed directly in a
column too, where the 200 px basis becomes the field's **height**: a labelled input followed by
more content leaves a large gap. Fields inside a row or a card are not affected. Until it is
fixed, add this extra CSS when you put labelled inputs directly in `ui.column()` or
`ui.stack()`:

```python
FIELD_FIX = ".nhk-col > .nhk-field, .nhk-stack > .nhk-field { flex: 0 0 auto; }"
ui = UI(title="Create account", extra_css=FIELD_FIX)
```

The `signup_form` and `multi_window` examples do this (with the `.nhk-col` selector).

## Density and window size

`UI(density=...)` changes control height, font size, gaps and padding for the whole window
(`compact` 30 px controls / 13 px font, `regular` 36 / 14, `comfortable` 42 / 15). `width` and
`height` are the requested initial window size in CSS pixels (the host may clamp it to the
screen). Use `comfortable` for touch screens and forms that are read more than written,
`compact` for tool windows. The [`theme_preview` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/theme_preview.py)
shows every density.

## Rules of thumb

- Exactly one outer `column()` per window keeps spacing consistent.
- Put a label on every input and select (`label=`); placeholders disappear.
- Headings: one `level=1` per window, `level=2` or `level=3` inside cards.
- The tree is fixed after mount. Plan every region you need up front and toggle it with
  [`when`](lists-and-conditional-content.md).

## Related

[Python reference: layout containers](../reference.md#layout-containers) ·
[CSS reference](../../css.md) · [theming](theming-and-custom-css.md)
