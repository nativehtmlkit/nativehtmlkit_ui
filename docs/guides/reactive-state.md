# Reactive state and computed values

**Goal:** keep application data in states, derive everything else, and let the UI follow.

Every example in this repository follows one rule: *the window shows state; event handlers
change state; nothing writes to the window directly.*

## Python

```python
from nativehtmlkit_ui import UI, computed, state

expenses = state([])                   # source data
show = state("all")                    # UI choice
visible = computed(lambda: [e for e in expenses.value if show.value in ("all", e["category"])])
total = computed(lambda: sum(e["amount"] for e in visible.value))

ui.heading(lambda: f"Total: {total.value:.2f}")      # bound expression
ui.badge(lambda: f"{len(visible.value)} of {len(expenses.value)} expenses")
```

- `computed()` tracks what its function reads, on every run. You never list dependencies.
- A bound lambda (`lambda: ...`) works like an anonymous computed for one element.
- Prefer a named `computed` when several places use the same derived value or when it is
  expensive; it is evaluated once per change, not once per element.

## PowerShell

```powershell
$s = @{ Expenses = (New-NHKUiState -Value @()); Show = (New-NHKUiState -Value 'all') }
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
- Pass states with `-Data` (one hashtable is convenient) instead of relying on variable capture.
- Return arrays with a leading comma (`, @(...)`), or an empty result becomes `$null`.
- PowerShell has no bound expressions: anything formatted is a computed state. Keep a list of
  them and call `.Dispose()` on each in `finally`.

## Change data by replacing it

Change detection compares values (`==` in Python, `[object]::Equals` in PowerShell, which is
reference equality for arrays and objects). Mutating in place is invisible:

```python
expenses.value.append(item)                     # WRONG: nobody is notified
expenses.set([*expenses.value, item])           # right: a new list
tasks.set([dict(t, done=not t["done"]) if t["id"] == task_id else t for t in tasks.value])
```

```powershell
$s.Tasks.Value += $item                         # WRONG: assignment bypasses notification
$s.Tasks.Set(@($s.Tasks.Value) + @($item))      # right
```

Store immutable-looking records (dicts/tuples, `[pscustomobject]`s you replace instead of
edit) and give list items an id when rows can be toggled or removed (`examples/*/todo.*`).

## Side effects: subscribe

When a change should trigger something that is not display (a counter, saving, logging), use
`subscribe`. It runs synchronously on the thread that set the state:

```python
note.subscribe(lambda: edits.set(edits.value + 1))     # examples/python/multi_window.py
```

```powershell
$null = $s.Note.Subscribe({ param($value, $ctx) $ctx.Edits.Set([int]$ctx.Edits.Value + 1) }, $s)
```

Keep subscribers short. Never block in them, and in Python never touch `ui.document` from a
subscriber that may run on a worker thread; set another state or use `ui.post()`.

## Dirty tracking and snapshots

A computed snapshot of several fields makes "unsaved changes" trivial
(`examples/*/settings.*`):

```python
current = computed(lambda: {key: s.value for key, s in fields.items()})
dirty = computed(lambda: current.value != saved.value)
ui.button("Save", on_click=save, disabled=lambda: not dirty.value)
```

PowerShell compares a text key instead, because hashtables compare by reference:

```powershell
$s.Key = New-NHKUiComputed -DependsOn @($s.Fields.Values) -Data $s -Compute {
    param($s) (@($s.Fields.Keys | ForEach-Object { $_ + '=' + [string]$s.Fields[$_].Value }) -join ';')
}
$s.Dirty = New-NHKUiComputed -DependsOn @($s.Key, $s.SavedKey) -Data $s -Compute { param($s) $s.Key.Value -ne $s.SavedKey.Value }
```

## Threads and runspaces

- Python states may be set from any thread, but a `Computed` whose dependencies are set from
  several threads at once is affected by the open defect **B-0002** (false "circular
  dependency" error, stale value). Make all writes that feed one computed on the UI owner:
  `ui.post(state.set, value)`. See [background work](background-work.md).
- PowerShell states bound to a UI must only be set on the owner runspace.

Related: [Python reference](../reference/python.md#reactive-values) ·
[PowerShell reference](../reference/powershell.md#state) ·
[architecture](../ARCHITECTURE.md#from-a-state-change-to-document-commands)
