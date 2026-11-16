# Lists and conditional content

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [lists and conditional content](../../python/guides/lists-and-conditional-content.md).*

**Goal:** show collections and optional parts of a window, given that the component tree is
fixed once the window opens.

## Conditional regions

```powershell
$null = Add-NHKUiWhen -UI $ui -Bind $s.Error -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.Error }
$s.NothingVisible = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute { param($s) @($s.Visible.Value).Count -eq 0 }
$null = Add-NHKUiWhen -UI $ui -Bind $s.NothingVisible -Content {
    $null = Add-NHKUiText -UI $ui -Text 'No expenses to show yet.' -Muted
}
```

A region is always in the document and only toggles `display: none` (class `nhk-hidden`).
Hidden inputs keep their values; showing the region again is instant. Regions nest (the
`settings` example hides the "autosave interval" field, and inside it an error alert). Typical
uses: empty states, validation messages, "paused" banners, swapping a form for a confirmation
(two regions with opposite conditions). The condition uses `[bool]`: `''`, `$null`, `0`,
`$false` and empty arrays hide the region, but the string `'False'` is **true**; bind booleans
or a computed `-not ...`.

## Text lists

```powershell
$s.Lines = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute {
    param($s) , @($s.Visible.Value | ForEach-Object { '{0}: {1}' -f $_.Description, $_.Amount })
}
$null = Add-NHKUiTextList -UI $ui -Bind $s.Lines
```

- Items are always encoded text; markup in data is shown literally.
- The list shows `@($state.Value)`; format the strings in a computed state.
- A change replaces all `<li>` children at once. Show a bounded window of data (the log viewer
  shows the newest 14 of up to 500 lines) rather than thousands of rows.
- Filtering and sorting belong in a computed state, not in the list.

## Interactive rows: the slot pool

A text list cannot hold buttons. When each row needs actions, create a fixed number of row
"slots" at build time and bind each slot to "the item at position *i* of the visible list" (the
[`todo` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/todo.ps1)).
Each slot gets its own hashtable with the row index and small computed states (present, text,
button label), and passes itself to the buttons with `-Data`:

```powershell
for ($row = 0; $row -lt $maxTasks; $row++) {
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
}
```

- Pass the slot with `-Data` instead of relying on the loop variable inside the callback.
- Callbacks look the item up **at click time** and act on its id, so they stay correct when the
  filter or order changes.
- Cap the model at the number of slots and say so in the UI.
- Keep every slot's computed states in your disposal list.

## When you outgrow this

For large tables, rich per-row markup or virtual scrolling, render that part yourself with the
SDK's document API (`Set-NativeHTMLKitDocumentHtml`, with your own encoding via
`[System.Net.WebUtility]::HtmlEncode`) inside an `Add-NHKUiHtml` container that you own
completely. The UI module deliberately has no data grid.

## Related

[PowerShell reference: dynamic content](../reference.md#dynamic-content) ·
[forms and inputs](forms-and-inputs.md) ·
[`log_viewer` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/log_viewer.ps1)
