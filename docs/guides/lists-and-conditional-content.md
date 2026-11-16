# Lists and conditional content

**Goal:** show collections and optional parts of a window, given that the component tree is
fixed once the window opens.

## Conditional regions: `when`

```python
with ui.when(error):                       # str state: shown when non-empty
    ui.alert(error)
with ui.when(lambda: not visible.value):   # any truthy/falsy expression
    ui.text("No expenses to show yet.", muted=True)
```

```powershell
$null = Add-NHKUiWhen -UI $ui -Bind $s.Error -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.Error }
$null = Add-NHKUiWhen -UI $ui -Bind $s.NothingVisible -Content {
    $null = Add-NHKUiText -UI $ui -Text 'No expenses to show yet.' -Muted
}
```

A region is always in the document and only toggles `display: none` (class `nhk-hidden`).
Hidden inputs keep their values; showing the region again is instant. Regions nest (the
settings example hides the "autosave interval" field, and inside it an error alert). Typical
uses: empty states, validation messages, "paused" banners, swapping a form for a confirmation
(two regions with opposite conditions). In PowerShell remember that `[bool]'False'` is true;
bind booleans or a computed `-not ...`.

## Text lists: `text_list`

```python
ui.text_list(visible, formatter=lambda e: f"{e['description']} ({e['category']}): {e['amount']:.2f}")
```

```powershell
$s.Lines = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute {
    param($s) , @($s.Visible.Value | ForEach-Object { '{0}: {1}' -f $_.Description, $_.Amount })
}
$null = Add-NHKUiTextList -UI $ui -Bind $s.Lines
```

- Items are always escaped/encoded text; markup in data is shown literally.
- A change replaces all `<li>` children at once. Show a bounded window of data (the log viewer
  shows the newest 14 of up to 500 lines) rather than thousands of rows.
- Filtering and sorting belong in a computed value, not in the list.

## Interactive rows: the slot pool

A text list cannot hold buttons. When each row needs actions, create a fixed number of row
"slots" at build time and bind each slot to "the item at position *i* of the visible list"
(`examples/python/todo.py`, `examples/powershell/todo.ps1`):

```python
MAX_TASKS = 8

def task_at(row):
    rows = visible.value
    return rows[row] if row < len(rows) else None

for row in range(MAX_TASKS):
    with ui.when(lambda row=row: task_at(row) is not None):
        with ui.row():
            ui.text(lambda row=row: task_at(row)["title"] if task_at(row) else "")
            ui.button(lambda row=row: "Reopen" if task_at(row) and task_at(row)["done"] else "Done",
                      variant="secondary", on_click=lambda _e, row=row: toggle(row))
            ui.button("Remove", variant="quiet", on_click=lambda _e, row=row: remove(row))
```

- Bind `row=row` as a default argument, or every lambda sees the last loop value.
- Handlers look the item up **at click time** (`task_at(row)`) and act on its id, so they stay
  correct when the filter or order changes.
- Cap the model at the number of slots and say so in the UI (`Add` is disabled and an alert
  appears when the list is full).

The PowerShell version gives each slot its own hashtable with the row index, three small
computed states (present, text, button label) and passes the slot to the buttons with `-Data`:

```powershell
$slot = @{ S = $s; Row = $row }
$slot.Present = New-NHKUiComputed -DependsOn @($s.Visible) -Data $slot -Compute { param($t) $t.Row -lt @($t.S.Visible.Value).Count }
$null = Add-NHKUiWhen -UI $ui -Bind $slot.Present -Content {
    $null = Add-NHKUiButton -UI $ui -Text 'Remove' -Variant quiet -Data $slot -OnClick {
        param($eventObject, $t)
        $items = @($t.S.Visible.Value)
        if ($t.Row -ge $items.Count) { return }
        $id = $items[$t.Row].Id
        $t.S.Tasks.Set(@($t.S.Tasks.Value | Where-Object { $_.Id -ne $id }))
    }
}
```

## When you outgrow this

For large tables, rich per-row markup or virtual scrolling, render that part yourself with the
SDK's document API (for example `Document.insert_html` / `Set-NativeHTMLKitDocumentHtml`, with
your own escaping) inside a container whose id you take from the UI element. The UI library
deliberately has no data grid.
