# Reactive state and computed values

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[reactive state](../../powershell/guides/reactive-state.md).*

**Goal:** keep application data in states, derive everything else, and let the window follow.

Every example in this library follows one rule: *the window shows state; event handlers change
state; nothing writes to the window directly.*

## Model data as state

```python
from nativehtmlkit_ui import UI, computed, state

expenses = state([])        # source data
show = state("all")         # a choice the user makes
```

`state(value)` returns a `State`. Read it with `.value`, change it with `.set(new)`. Components
bound to it (`ui.text(expenses)`, `ui.input(show)`) update themselves.

## Derive values with computed

```python
visible = computed(lambda: [e for e in expenses.value if show.value in ("all", e["category"])])
total = computed(lambda: sum(e["amount"] for e in visible.value))

ui.heading(lambda: f"Total: {total.value:.2f}")              # bound expression
ui.badge(lambda: f"{len(visible.value)} of {len(expenses.value)} expenses")
```

- `computed()` records which states its function reads, on every run. You never list
  dependencies.
- A bound lambda (`lambda: ...`) works like an anonymous computed for one element.
- Prefer a named `computed` when several places use the same derived value or when it is
  expensive: it is evaluated once per change, not once per element. Handlers can read it too
  (`cannot_add.value`).
- Computed values can depend on computed values (`total` reads `visible`).

## Change data by replacing it

Change detection compares values with `==`. Mutating in place is invisible:

```python
expenses.value.append(item)                     # WRONG: nobody is notified
expenses.set([*expenses.value, item])           # right: a new list
tasks.set([dict(t, done=not t["done"]) if t["id"] == task_id else t for t in tasks.value])
```

Store records as dicts or tuples that you replace instead of edit, and give list items an id when
rows can be toggled or removed (the [`todo` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/todo.py)).

## Side effects: subscribe

When a change should trigger something that is not display (a counter, saving, logging), use
`subscribe`. It runs synchronously on the thread that set the state:

```python
note.subscribe(lambda: edits.set(edits.value + 1))     # examples/python/multi_window.py
```

Keep subscribers short. Never block in them, and never touch `ui.document` from a subscriber
that may run on a worker thread; set another state or use `ui.post()`.

## Dirty tracking and snapshots

A computed snapshot of several fields makes "unsaved changes" trivial (the
[`settings` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/settings.py)
and the [settings-editor tutorial](../tutorials/settings-editor.md)):

```python
current = computed(lambda: {key: s.value for key, s in fields.items()})
saved = state(current.value)
dirty = computed(lambda: current.value != saved.value)
ui.button("Save", on_click=save, disabled=lambda: not dirty.value)
```

Dicts compare by content in Python, so the snapshot can be compared directly.

## Where states may be changed

States may be set from any thread; the window update always happens on the UI owner thread.
However, a `Computed` whose dependencies are set from several threads at once is affected by the
open computed-concurrency defect (a false "circular dependency" error and a stale value). Make all writes
that feed one computed on the UI owner: `ui.post(state.set, value)`. See
[background work](background-work.md).

## Related

[Python reference: reactive values](../reference.md#reactive-values) ·
[architecture](../../ARCHITECTURE.md#from-a-state-change-to-document-commands) ·
[`expenses` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/expenses.py)
