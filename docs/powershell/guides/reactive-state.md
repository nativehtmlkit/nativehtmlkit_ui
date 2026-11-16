# Reactive state and computed values

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [reactive state](../../python/guides/reactive-state.md).*

**Goal:** keep application data in states, derive everything else, and let the window follow.

Every example in this module follows one rule: *the window shows state; button callbacks change
state; nothing writes to the window directly.*

## Model data as state

```powershell
$s = @{
    Expenses = (New-NHKUiState -Value @())    # source data
    Show     = (New-NHKUiState -Value 'all')  # a choice the user makes
}
```

`New-NHKUiState` returns a state object. Read it with `.Value`, change it with `.Set($new)`.
Components bound to it (`-Bind $s.Show`) update themselves. Assigning `.Value` directly notifies
nobody; always call `.Set()`. Keeping all states in one hashtable (`$s`) makes it easy to pass
them to callbacks with `-Data`.

## Derive values with computed

```powershell
$s.Visible = New-NHKUiComputed -DependsOn @($s.Expenses, $s.Show) -Data $s -Compute {
    param($s)
    , @($s.Expenses.Value | Where-Object { $s.Show.Value -eq 'all' -or $_.Category -eq $s.Show.Value })
}
$s.Count = New-NHKUiComputed -DependsOn @($s.Visible, $s.Expenses) -Data $s -Compute {
    param($s) '{0} of {1} expenses' -f @($s.Visible.Value).Count, @($s.Expenses.Value).Count
}
$null = Add-NHKUiBadge -UI $ui -Bind $s.Count
```

- List **every** state the scriptblock reads in `-DependsOn`; there is no automatic tracking.
- Pass states with `-Data` (one hashtable is convenient); the scriptblock receives it as its
  first parameter.
- Return arrays with a leading comma (`, @(...)`), or an empty result becomes `$null` and a
  one-element result a scalar.
- There are no bound expressions: anything formatted is a computed state. Keep a list of them
  and call `.Dispose()` on each in `finally`; `Stop-NHKUi` does not dispose them.
- Computed states can depend on computed states (`Count` depends on `Visible`).

## Change data by replacing it

Change detection uses `[object]::Equals`, which is reference equality for arrays, hashtables and
objects. Changing them in place is invisible:

```powershell
$s.Tasks.Value += $item                         # WRONG: assignment bypasses notification
$s.Tasks.Set(@($s.Tasks.Value) + @($item))      # right: a new array
```

Store records as `[pscustomobject]`s that you replace instead of edit, and give list items an id
when rows can be toggled or removed (the [`todo` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/todo.ps1)).

## Side effects: subscribe

When a change should trigger something that is not display (a counter, saving, logging), use
`.Subscribe()`. It runs synchronously inside `.Set()`:

```powershell
$null = $s.Note.Subscribe({ param($value, $ctx) $ctx.Edits.Set([int]$ctx.Edits.Value + 1) }, $s)
```

The callback receives the new value and the context object you passed as the second argument.
Keep subscribers short and remove them with `.Unsubscribe($subscription)` when no longer needed.

## Dirty tracking and snapshots

Hashtables compare by reference, so compare a **text key** of the fields instead (the
[`settings` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/settings.ps1);
the [settings-editor tutorial](../tutorials/settings-editor.md) uses compressed JSON the same way):

```powershell
$s.Key = New-NHKUiComputed -DependsOn @($s.Fields.Values) -Data $s -Compute {
    param($s) (@($s.Fields.Keys | ForEach-Object { $_ + '=' + [string]$s.Fields[$_].Value }) -join ';')
}
$s.SavedKey = New-NHKUiState -Value $s.Key.Value
$s.Dirty = New-NHKUiComputed -DependsOn @($s.Key, $s.SavedKey) -Data $s -Compute { param($s) $s.Key.Value -ne $s.SavedKey.Value }
```

## Where states may be changed

A state bound to a UI may only be set on the runspace that started the UI (the *owner
runspace*): in button callbacks, in SDK task `-OnCompleted`/`-OnFailed` callbacks, in
notification callbacks, or in the script itself. From any other runspace the module throws
`UI updates must run on the SDK owning runspace`. See [background work](background-work.md).
Computed states are synchronous on the owner runspace; the Python defect B-0002 does not apply.

## Related

[PowerShell reference: state](../reference.md#state) ·
[architecture](../../ARCHITECTURE.md#from-a-state-change-to-document-commands) ·
[`expenses` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/expenses.ps1)
