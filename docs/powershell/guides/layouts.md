# Layouts and the responsive grid

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [layouts](../../python/guides/layouts.md).*

**Goal:** arrange components with rows, columns, cards and a grid that adapts to the window.

## Containers

| PowerShell | Element | Use for |
|---|---|---|
| `Add-NHKUiColumn -UI $ui -Content { }` | `div.nhk-col` | The main vertical flow of a window. |
| `Add-NHKUiRow -UI $ui -Content { }` | `div.nhk-row` | Toolbars, a field next to its button, badges next to a heading. Wraps when narrow. |
| `Add-NHKUiCard -UI $ui -Content { }` | `div.nhk-card` | Grouping related content on a panel. |
| `Add-NHKUiGrid -UI $ui -Content { }` | `div.nhk-grid` | Dashboards and settings pages: equal-width cells. |

`-Content` runs immediately; components added inside it become children of the container. The
module has no equivalent of Python's `stack()` or generic `container()`/`element()`; style the
structure above with `-ExtraCss` instead.

## A typical window

```powershell
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Settings' -Level 1
        $null = Add-NHKUiBadge -UI $ui -Bind $s.Badge
    }
    $null = Add-NHKUiGrid -UI $ui -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Profile' -Level 3
            $null = Add-NHKUiInput -UI $ui -Bind $s.Fields.DisplayName -Label 'Display name'
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Editor' -Level 3
            $null = Add-NHKUiSelect -UI $ui -Bind $s.Fields.FontSize -Label 'Font size' -Options $fontSizes
        }
    }
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Save' -Data $s -OnClick { param($eventObject, $s) <# ... #> }
        $null = Add-NHKUiButton -UI $ui -Text 'Revert' -Variant secondary -Data $s -OnClick { param($eventObject, $s) <# ... #> }
    }
}
```

Assign every `Add-NHKUi*` result to `$null` so the nodes do not end up in the script's output.
The full version is the [`settings` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/settings.ps1).

## How the grid responds

`nhk-grid` uses three equal columns. When the window's viewport is at most **1000 px** wide it
switches to two columns, at most **620 px** to one column (and the app padding shrinks to
14 px). Cells keep `min-width: 0`, so long text wraps instead of widening the grid. There is no
column-span API; put wide content outside the grid.

Rows wrap: a labelled input or select is a flex item of at least 150 px that grows
(`flex: 1 1 200px`), so a row of three fields becomes two lines in a narrow window. The
[`dashboard` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/dashboard.ps1)
shows six cards that reflow as you resize.

## Fields directly in a column (known defect)

The 0.1.1 stylesheet applies the row rule `flex: 1 1 200px` to fields placed directly in a
column too, where the 200 px basis becomes the field's **height**: a labelled input followed by
more content leaves a large gap. Fields inside a row or a card are not affected. Until it is
fixed, add this extra CSS when you put labelled inputs directly in `Add-NHKUiColumn`:

```powershell
$fieldFix = '.nhk-col > .nhk-field { flex: 0 0 auto; }'
$ui = New-NHKUi -Title 'Create account' -ExtraCss $fieldFix
```

The `signup_form` and `multi_window` examples do this.

## Density and window size

`New-NHKUi -Density` changes control height, font size, gaps and padding for the whole window
(`compact` 30 px controls / 13 px font, `regular` 36 / 14, `comfortable` 42 / 15). `-Width` and
`-Height` (100-8192) are the requested initial window size in CSS pixels (the host may clamp it
to the screen). Use `comfortable` for touch screens and forms that are read more than written,
`compact` for tool windows. The [`theme_preview` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/theme_preview.ps1)
shows every density.

## Rules of thumb

- Exactly one outer `Add-NHKUiColumn` per window keeps spacing consistent.
- Put a label on every input and select (`-Label`); placeholders disappear.
- Headings: one `-Level 1` per window, `-Level 2` or `-Level 3` inside cards.
- The tree is fixed after `Start-NHKUi`; adding components later throws. Plan every region you
  need up front and toggle it with [`Add-NHKUiWhen`](lists-and-conditional-content.md).

## Related

[PowerShell reference: layout containers](../reference.md#layout-containers) ·
[CSS reference](../../css.md) · [theming](theming-and-custom-css.md)
