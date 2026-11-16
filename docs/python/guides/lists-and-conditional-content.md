# Lists and conditional content

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[lists and conditional content](../../powershell/guides/lists-and-conditional-content.md).*

**Goal:** show collections and optional parts of a window, given that the component tree is
fixed once the window opens.

## Conditional regions

```python
with ui.when(error):                       # str state: shown when non-empty
    ui.alert(error)
with ui.when(lambda: not visible.value):   # any truthy/falsy expression
    ui.text("No expenses to show yet.", muted=True)
```

A region is always in the document and only toggles `display: none` (class `nhk-hidden`).
Hidden inputs keep their values; showing the region again is instant. Regions nest (the
`settings` example hides the "autosave interval" field, and inside it an error alert). Typical
uses: empty states, validation messages, "paused" banners, swapping a form for a confirmation
(two regions with opposite conditions). The condition uses Python truthiness: `""`, `0`, `None`,
`[]` and `False` hide the region.

## Text lists

```python
ui.text_list(visible, formatter=lambda e: f"{e['description']} ({e['category']}): {e['amount']:.2f}")
```

- Items are always escaped text; markup in data is shown literally.
- A change replaces all `<li>` children at once. Show a bounded window of data (the log viewer
  shows the newest 14 of up to 500 lines) rather than thousands of rows.
- Filtering and sorting belong in a computed value, not in the list.

## Interactive rows: the slot pool

A text list cannot hold buttons. When each row needs actions, create a fixed number of row
"slots" at build time and bind each slot to "the item at position *i* of the visible list" (the
[`todo` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/todo.py)):

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

## When you outgrow this

For large tables, rich per-row markup or virtual scrolling, render that part yourself with the
SDK's document API (for example `ui.document.insert_html(element_id, html)`, with your own
escaping via `html.escape`) inside a container you created with `ui.container()` and own
completely. The UI library deliberately has no data grid.

## Related

[Python reference: dynamic regions](../reference.md#dynamic-regions) ·
[forms and inputs](forms-and-inputs.md) ·
[`log_viewer` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/log_viewer.py)
