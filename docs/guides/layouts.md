# Layouts and the responsive grid

**Goal:** arrange components with rows, columns, cards and a grid that adapts to the window.

| Python | PowerShell | Use for |
|---|---|---|
| `with ui.column():` | `Add-NHKUiColumn -UI $ui -Content { }` | The main vertical flow of a window. |
| `with ui.row():` | `Add-NHKUiRow -UI $ui -Content { }` | Toolbars, a field next to its button, badges next to a heading. Wraps when narrow. |
| `with ui.card():` | `Add-NHKUiCard -UI $ui -Content { }` | Grouping related content on a panel. |
| `with ui.grid():` | `Add-NHKUiGrid -UI $ui -Content { }` | Dashboards and settings pages: equal-width cells. |
| `with ui.stack():` | (none) | Tight vertical groups (6 px gap). |
| `with ui.container("section", css_class="x"):` | (none) | Any allowed tag with your own class. |

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

```powershell
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Settings' -Level 1
        $null = Add-NHKUiBadge -UI $ui -Bind $s.Badge
    }
    $null = Add-NHKUiGrid -UI $ui -Content {
        $null = Add-NHKUiCard -UI $ui -Content { <# ... #> }
        $null = Add-NHKUiCard -UI $ui -Content { <# ... #> }
    }
}
```

The full versions are `examples/python/settings.py` and `examples/powershell/settings.ps1`.

## How the grid responds

`nhk-grid` uses three equal columns. When the window's viewport is at most **1000 px** wide it
switches to two columns, at most **620 px** to one column (and the app padding shrinks from the
density value to 14 px). Cells keep `min-width: 0`, so long text wraps instead of widening the
grid. There is no column-span API; for a wide cell put the content outside the grid, or add a
class with `grid-column: 1 / -1` (Python `ui.container(css_class=...)`).

Rows wrap: a labelled input or select is a flex item of at least 150 px that grows
(`flex: 1 1 200px`), so a row of three fields becomes two lines in a narrow window. The
dashboard example (`examples/*/dashboard.*`) shows six cards that reflow as you resize.

## Density and window size

`density` changes control height, font size, gaps and padding for the whole window
(`compact` 30 px controls / 13 px font, `regular` 36 / 14, `comfortable` 42 / 15). `width` and
`height` are the requested initial window size in CSS pixels (the host may clamp it to the
screen). Use `comfortable` for touch screens and forms that are read more than
written, `compact` for tool windows.

## Rules of thumb

- Exactly one outer `column()` per window keeps spacing consistent.
- Put a label on every input and select (`label=` / `-Label`); placeholders disappear.
- Headings: one `level=1` per window, `level=3` inside cards.
- The tree is fixed after mount. Plan every region you need up front and toggle it with
  [`when`](lists-and-conditional-content.md).
