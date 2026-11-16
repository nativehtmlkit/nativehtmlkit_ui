# Python reference: `nativehtmlkit_ui` 0.1.1

This page is the complete reference for the Python package `nativehtmlkit_ui` 0.1.1. It is
derived from the released source (`python/src/nativehtmlkit_ui`). The package depends only on
the public API of the NativeHTMLKit Python SDK (`nativehtmlkit` 0.1.x; qualified with 0.1.2 and
Core 1.0.3).

```python
from nativehtmlkit_ui import UI, State, Computed, state, computed
```

`nativehtmlkit_ui.__all__` is exactly `["UI", "State", "Computed", "state", "computed"]`, and
`nativehtmlkit_ui.__version__` is `"0.1.1"`.

Contents: [Reactive values](#reactive-values) · [UI construction](#ui) ·
[Layout containers](#layout-containers) · [Display components](#display-components) ·
[Controls](#controls) · [Dynamic regions](#dynamic-regions) · [Events](#events) ·
[Custom and trusted markup](#custom-and-trusted-markup) · [Mounting](#mounting-and-the-ui-owner) ·
[Update scheduling](#update-scheduling-and-batching) · [`post()` and `sync()`](#post-and-sync) ·
[Diagnostics](#diagnostics) · [Disposal](#disposal) · [Errors](#errors-raised-by-the-library) ·
[Known defects](#known-defects)

---

## Reactive values

### `state(value)` and `State`

```python
count = state(0)            # same as State(0)
count.value                 # read (records a dependency, see below)
count.value = 5             # same as count.set(5)
changed = count.set(6)      # True if the value changed
remove = count.subscribe(lambda: print("changed"))
remove()                    # unsubscribe
```

| Member | Description |
|---|---|
| `State(value)` | Observable holder of one value of any type. |
| `.value` (property) | Returns the current value. Reading it inside a computed function or a bound lambda records the state as a dependency of that function. |
| `.value = x` | Calls `.set(x)`. |
| `.set(value) -> bool` | Stores `value` and notifies subscribers, unless the new value is the same object (`is`) or compares equal (`==`) to the current one; then it does nothing and returns `False`. Returns `True` when it changed. |
| `.subscribe(callback) -> remove` | Registers `callback()` (no arguments). Returns a function that removes it. Subscribers are held in a set, so their order is not defined, and the same callable is registered only once. |

Semantics:

- **Change detection is by equality.** Mutating a list or dict in place and setting the same
  object again does not notify anyone. Always build a new value:
  `items.set([*items.value, new_item])`, `items.set(items.value[:-1])`.
- **Notification is synchronous** on the thread that called `set()`. Subscribers, computed
  values that depend on the state, and the UI scheduler run before `set()` returns. The UI
  scheduler only marks bindings dirty and queues a flush; it never writes to the window on the
  calling thread (see [Update scheduling](#update-scheduling-and-batching)).
- `set()` may be called from any thread. State itself is protected by a re-entrant lock.
  See [Known defects](#known-defects) for computed values updated from several threads.

### `computed(fn)` and `Computed`

```python
total = computed(lambda: sum(e["amount"] for e in expenses.value))
total.value
total.close()
```

| Member | Description |
|---|---|
| `Computed(fn)` / `computed(fn)` | Calls `fn()` immediately (eager) and records every `State`/`Computed` whose `.value` it read as a dependency. |
| `.value` (property) | The last computed value. Reading it records the computed as a dependency of an enclosing computed/binding. |
| `.subscribe(callback)` | As for `State`. |
| `.close()` | Unsubscribes from all dependencies and drops all subscribers. After `close()` the value no longer changes. |

Semantics:

- When any dependency notifies, `fn()` runs again **synchronously** on the notifying thread.
  Dependencies are re-collected on every run, so conditional reads (`a.value if flag.value else
  b.value`) track exactly what the last run read.
- Subscribers of the computed are notified only when the new result differs (`is` / `==`)
  from the previous one.
- A computed that reads itself raises `RuntimeError("Computed value depends on itself")`; a
  re-entrant recomputation raises `RuntimeError("Circular computed-state dependency")`.
- Exceptions raised by `fn()` propagate to the caller of `set()` that triggered the
  recomputation (inside a UI event handler they are recorded in
  [`diagnostics["errors"]`](#diagnostics)).
- A computed is not disposed by `UI.dispose()`. Call `.close()` when it should stop
  following its dependencies (for example a computed created per window).
- A computed can be used anywhere a `State` is accepted for display (`ui.text(total)`), but
  two-way controls (`input`, `checkbox`, `select`) require a real `State`.

### Bound expressions

Every component argument documented as "text-like" accepts:

- a plain `str` (static; escaped once at render time),
- a `State` or `Computed` (shows `.value`),
- a zero-argument callable such as `lambda: f"Total: {total.value}"`.

A callable is evaluated once when the component is created, and again on the UI owner thread
whenever one of the states it read changes. `None` is shown as an empty string; any other value
is converted with `str()`.

---

## `UI`

```python
UI(*, title="NativeHTMLKit UI", width=940, height=660, theme="cobalt",
   density="compact", extra_css="")
```

| Parameter | Default | Meaning |
|---|---|---|
| `title` | `"NativeHTMLKit UI"` | Native window title and HTML `<title>`. |
| `width`, `height` | `940`, `660` | Requested window size in CSS pixels, passed to `Application.open_html`. |
| `theme` | `"cobalt"` | `"cobalt"` (dark blue), `"graphite"` (dark grey) or `"daylight"` (light). Anything else raises `ValueError`. |
| `density` | `"compact"` | `"compact"`, `"regular"` or `"comfortable"`; sets control height, font size, gaps and padding. Anything else raises `ValueError`. |
| `extra_css` | `""` | CSS appended after the built-in stylesheet inside the same `<style>` element. It is trusted developer input and is not validated. See [CSS reference](css.md). |

Public attributes:

| Attribute | Description |
|---|---|
| `title`, `width`, `height`, `theme`, `density`, `extra_css` | The constructor values. Changing them after `mount()` has no effect. |
| `prefix` | `"nhkui-"` + 12 random hex digits. Every generated element id is `f"{prefix}-{n}"`, so several UIs never collide. |
| `root` | The root `Element` (`<main class="nhk-app">`). |
| `app`, `window`, `document` | `None` until `mount()`; then the SDK `Application`, `Window` and `Document` handles. Use them for SDK calls such as dialogs or reading DOM state. |
| `diagnostics` | Property; see [Diagnostics](#diagnostics). |

Construct the UI and all of its components first, then call `mount(app)`. After `mount()` (or
after disposal) adding components raises `RuntimeError`; change state instead.

### `Element`

Every component method returns an `Element` (a dataclass). Its fields are `tag`, `id`
(generated), `attrs` (dict), `children` (list of `Element` or `str`) and `bindings`. The most
useful field is `id`: pass it to SDK document methods, for example
`ui.document.get_text(el.id)` or `ui.document.focus(el.id)`. `Element.html()` renders a
standalone, escaped HTML string for the element (used by tests). Treat the other fields as
read-only; editing them after `mount()` does not change the window.

---

## Layout containers

All containers are context managers. Components created inside the `with` block become their
children. Each returns (from `__enter__`) the container `Element`.

| Method | Element and class | Layout |
|---|---|---|
| `ui.container(tag="div", *, css_class="", attrs=None)` | any [allowed tag](#allowed-tags) | Generic container; the others are shortcuts for it. |
| `ui.row()` | `div.nhk-row` | Horizontal flex row, wraps, centred vertically, gap `--nhk-gap`. |
| `ui.column()` | `div.nhk-col` | Vertical flex column, gap `--nhk-gap`. |
| `ui.stack()` | `div.nhk-stack` | Vertical flex column with a tighter 6 px gap. |
| `ui.grid()` | `div.nhk-grid` | CSS grid: 3 equal columns; 2 when the window is at most 1000 px wide; 1 at most 620 px (the app padding also shrinks to 14 px). |
| `ui.card()` | `div.nhk-card` | Panel with background, border, radius and 16 px padding. |

```python
with ui.grid():
    with ui.card():
        ui.heading("Disk", level=3)
        ui.text(disk_text)
```

`ui.html()` raises `RuntimeError("An open container context is not closed")` if a container
block is still open.

---

## Display components

| Method | Renders | Notes |
|---|---|---|
| `ui.heading(value, *, level=2)` | `<hN class="nhk-heading">` | `level` 1-4, else `ValueError`. `value` is text-like. |
| `ui.text(value, *, muted=False)` | `<p class="nhk-text">` (+ `nhk-muted`) | Text-like; long words wrap anywhere. |
| `ui.badge(value)` | `<span class="nhk-badge">` | Small pill for counts and status. |
| `ui.alert(value)` | `<div class="nhk-alert" role="status">` | Callout with an accent border. Combine with `ui.when()` to show it only when needed. |

All four escape their text. Updating a bound value sends one `set_text` document command.

---

## Controls

### `ui.button(label, *, on_click=None, variant="primary", disabled=False)`

Renders `<button type="button" class="nhk-button nhk-{variant}">`.

| Parameter | Description |
|---|---|
| `label` | Text-like. A bound label (`lambda: "Resume" if paused.value else "Pause"`) is updated with `set_text`. |
| `on_click` | `callback(event: dict)`, run on the UI owner thread. See [Events](#events). |
| `variant` | `"primary"`, `"secondary"`, `"danger"` or `"quiet"`; else `ValueError`. |
| `disabled` | `bool`, a `State`, a `Computed` or a callable returning a truthy value. When bound, the `disabled` attribute is added or removed as the value changes. |

A disabled native button does not deliver clicks, but handlers that perform an irreversible
action should still re-check their precondition (the examples do).

### `ui.input(value, *, label="", placeholder="", kind="text")`

Renders `<input class="nhk-input">` with a two-way binding to `value`.

| Parameter | Description |
|---|---|
| `value` | Must be a `State` (`TypeError` otherwise; a `Computed` is not accepted). Its value is shown with `str()`; `None` shows as empty. |
| `label` | When non-empty, the input is wrapped in `div.nhk-field` and preceded by `<label class="nhk-label" for=...>`. Without a label there is no wrapper; provide another accessible name. |
| `placeholder` | Placeholder attribute. Not a replacement for a label. |
| `kind` | `"text"`, `"password"`, `"search"`, `"email"` or `"number"`; else `ValueError`. The state always holds a **string**, also for `"number"`. |

Behaviour: every native `input` event stores the control's text in the state (`value.set(str)`),
so the state follows each keystroke and IME commit. Setting the state from code writes the
control with `set_value`; the binding remembers the value it just received from the control,
so typing never causes an echo write that would move the caret or break an IME composition.

### `ui.checkbox(value, *, label)`

Renders `div.nhk-checkrow` containing `<input type="checkbox" class="nhk-checkbox">` and a
`<label for>` after it. `value` must be a `State`; it receives `bool` on every `change` event.
`label` is required (keyword-only). Setting the state writes the control with `set_checked`.

### `ui.select(value, choices, *, label="")`

Renders `div.nhk-field` containing an optional `<label class="nhk-label">` and
`<select class="nhk-select">`.

| Parameter | Description |
|---|---|
| `value` | A `State` holding the selected option's value as a string. |
| `choices` | Iterable of `(value, text)` pairs, for example `[("a", "Alpha"), ("b", "Bravo")]`, or `dict.items()`. Values and texts are converted with `str()`. The option list is fixed at build time. |
| `label` | Optional visible label. |

The option whose value equals `str(value.value)` is marked `selected` at render time. A
`change` event stores the new value; setting the state from code writes `set_value`. Setting
a value that matches no option is passed to the SDK unchanged; what the native control then
shows is up to the host.

All three two-way controls return the control `Element` (not the wrapper). Its `id` is the
target for SDK calls such as `ui.document.focus(el.id)`.

---

## Dynamic regions

### `ui.when(condition)`

```python
with ui.when(lambda: not items.value):
    ui.text("Nothing here.", muted=True)
```

Context manager that creates `div.nhk-region` around its children. `condition` is a `State`,
`Computed` or callable; truthiness uses `bool()`. The region is **always mounted**: when the
condition becomes false the class `nhk-hidden` (`display: none !important`) is added, when it
becomes true it is removed. Controls inside keep their value, focus history and native state
while hidden; nothing is rebuilt. Regions may be nested.

### `ui.text_list(values, *, formatter=str)`

Renders `<ul class="nhk-list">` whose `<li>` items are the escaped results of
`formatter(item)` for each item of `values` (a `State`, `Computed` or callable returning an
iterable). When the formatted tuple changes, the list's children are replaced in one
`replace_children_html` command. It is text only and not virtualized; keep it to a few hundred
items (the examples show the newest N). For per-row buttons use the
[slot pool pattern](../guides/lists-and-conditional-content.md).

---

## Events

### `ui.on(element, kind, callback)`

Registers `callback(event: dict)` for `kind` on `element` (an `Element`). `kind` must be one
of `"click"`, `"input"`, `"change"`, `"keydown"`, `"submit"`, `"auxclick"`,
`"contextmenu"`; else `ValueError`. Registration must happen before `mount()`.

- There is **one callback per (kind, element)**; registering again replaces the previous one.
  Two-way controls already register `"input"` (input) or `"change"` (checkbox, select) on their
  element, so do not register that kind on them yourself: it would replace the binding. Observe
  the state instead (`value.subscribe(...)` or a computed).
- On mount the UI subscribes once per event kind to the SDK document (`Document.on`). For each
  native event it looks at the target `event["element"]` and then the ids in
  `event["path"]` (the bubbling route), and calls the callback of the **nearest** registered
  element only, like a delegated handler. A click on a `<span>` inside a registered card
  therefore reaches the card's handler.
- The event `dict` is the SDK's document event: `type`, `element`, `path`, `window_id`,
  `document_id`, and type-specific members such as `value`, `checked`, `key`, `code`,
  `button`, `x`, `y` and modifier flags, as delivered by Core 1.0.3.
- Callbacks run on the [UI owner thread](#mounting-and-the-ui-owner), one at a time, in event
  order. An exception is logged with `logging` (logger `nativehtmlkit_ui.engine`), recorded in
  `diagnostics["errors"]` and does not stop the UI.
- `on_click` of `button()` is a shortcut for `ui.on(el, "click", on_click)`.

`keydown`, `submit`, `auxclick` and `contextmenu` registration is available, but the 0.1.1
GUI qualification exercised click, input and change; verify other kinds in your own app.

---

## Custom and trusted markup

### `ui.element(tag, *, css_class="", attrs=None, text=None)`

Adds one element with library-generated id. Use it for styling hooks the components do not
cover (for example `ui.element("div", css_class="metric", text=clock)`).

- <a id="allowed-tags"></a>`tag` must be one of: `div section main header footer article nav
  aside p span h1 h2 h3 h4 small strong em button label input select option textarea form ul li
  table thead tbody tr th td dialog pre code hr`; anything else raises `ValueError` (use
  `raw_html` for other tags).
- `attrs` values are escaped. Attribute names must match `[A-Za-z_:][A-Za-z0-9_:.-]*` and
  must not start with `on` (no inline event handlers), else `ValueError` at render time.
  `None`/`False` omit the attribute, `True` renders a boolean attribute. Passing `"id"`
  raises `ValueError`: ids are always generated.
- `text` is text-like and escaped. `css_class` is appended to any `class` in `attrs`.
- Use it as a container with `ui.container(tag, ...)`.
- The library does not bind values of `textarea`, `form` or `dialog` created this way; use SDK
  document methods on `el.id` if you need them.

### `ui.raw_html(markup)`

Adds `div.nhk-custom` whose content is `markup` **verbatim, without sanitization**. Only pass
static markup written by the developer. Never pass user input, file contents or network data;
show those with text components, which escape them. See the
[trusted content guide](../guides/trusted-and-untrusted-content.md).

---

## Mounting and the UI owner

### `ui.mount(app) -> UI`

`app` is a connected SDK `Application` (from `Application.start()` or the
`python -m nativehtmlkit run module:main` entry point). `mount()`:

1. Renders the document (`ui.html()`), and opens one window with
   `app.open_html(markup, title=, width=, height=)`.
2. Writes the live value of every input/select (`set_value`) and checkbox (`set_checked`).
3. Subscribes once per used event kind to the document.
4. Registers `app.on_shutdown(...)` (holding the UI weakly) and an `app.on_window_event`
   listener that disposes the UI when its window is closed.
5. Starts the **UI owner**: one daemon thread named `nativehtmlkit-ui` per UI.
6. If state changed between building and mounting, queues one flush.

It returns the UI. It does **not** call `app.ready()` or `app.run()`: `app.run()` announces
readiness and waits for shutdown. If any step fails, the UI is disposed, the window is asked
to close, and the exception propagates. Calling `mount()` twice raises
`RuntimeError("UI already mounted")`; after disposal `RuntimeError("UI already disposed")`.

The owner thread runs event callbacks, posted functions and DOM flushes. SDK event worker
threads only enqueue events and never block on DOM requests. Mount may be called from any
thread, including another UI's event callback (see `examples/python/multi_window.py`).

### `ui.html() -> str`

Returns the complete HTML document: doctype, `<meta charset>`, viewport meta, `<title>`, one
`<style>` with the built-in CSS followed by `extra_css`, and
`<body class="nhk-theme-{theme} nhk-density-{density}">` containing the root `<main>`.
Useful for tests and snapshots; it does not need a host.

---

## Update scheduling and batching

- When a state read by a binding changes, the binding is marked dirty and one flush is queued
  on the owner (only one flush is outstanding at a time).
- The flush re-evaluates each dirty binding on the owner thread, compares the result with the
  last written value, and skips unchanged ones. It turns the rest into document operations:
  `set_text` (text and labels), `add_class`/`remove_class nhk-hidden` (`when`),
  `set_attribute`/`remove_attribute disabled`, `replace_children_html` (`text_list`). These are
  sent through `Document.batch` in chunks of at most 128 operations (a single operation is sent
  with `Document.command`). Control values follow as `set_value`/`set_checked` calls.
- **Batching is automatic**: all state changes made inside one event callback or posted
  function are coalesced, because the flush is queued behind the running callback. Many
  `set()` calls from a worker thread in quick succession are coalesced the same way. There is
  no separate batch API in Python.
- Only the latest value is written: intermediate values that were overwritten before the
  flush ran are never sent.

---

## `post()` and `sync()`

### `ui.post(fn, *args)`

Queues `fn(*args)` to run on the UI owner thread, after work queued earlier. Use it to hand
results from worker threads, executors, timers or SDK futures back to the UI:

```python
future.add_done_callback(lambda f: ui.post(show_result, f))
```

- Safe from any thread, including the owner itself (it still queues, which preserves
  batching).
- After disposal it silently does nothing.
- The queue holds 4096 items. When it is full, `post()` raises
  `RuntimeError("NativeHTMLKit UI queue full: event not delivered; inspect diagnostics")` and
  increments `diagnostics["event_queue_dropped"]`. Producers that can outpace the UI should
  catch it and drop or merge work (see `examples/python/log_viewer.py`).
- Before `mount()` there is no owner thread yet; queued work runs once the UI is mounted.

### `ui.sync(timeout=10.0)`

Blocks until the owner has processed everything queued before the call (including the flush
those changes queued). Intended for tests and explicit synchronization from other threads.
Called on the owner thread itself it flushes immediately. Raises
`RuntimeError("UI not mounted")`, `RuntimeError("UI already disposed")`,
`TimeoutError` if the owner did not reach the marker in time, and `RuntimeError` when the DOM
state is uncertain (see below).

---

## Diagnostics

`ui.diagnostics` returns a new `dict`:

| Key | Type | Meaning |
|---|---|---|
| `errors` | `tuple[str, ...]` | The last 64 failures of callbacks, posted functions and flushes, as `"TypeName: message"`. |
| `event_queue_dropped` | `int` | Events and `post()` calls lost because the 4096-item queue was full. |
| `pending_updates` | `int` | Bindings marked dirty and not yet flushed. |
| `dom_uncertain` | `bool` | A document write failed in a way whose outcome is unknown (for example a timeout). Managed updates stop; `sync()` raises. Not set when the window simply closed. |
| `updates` | `int` | Flushes that wrote at least one operation. |
| `operations` | `int` | Document operations written in total. |
| `subscriptions` | `int` | Active SDK subscriptions (one per event kind, plus one window-event listener); 0 after disposal. |
| `disposed` | `bool` | `True` after `dispose()`. |
| `discarded_after_close` | `int` | Flushes dropped because the window/document was already gone (closed window, replaced document or application shutdown; host codes -32004 and -32008). |

A healthy UI has an empty `errors`, `event_queue_dropped == 0` and `dom_uncertain == False`.
The example harness checks exactly these.

---

## Disposal

`ui.dispose()` (alias `ui.close()`) is idempotent. It unsubscribes all SDK document event
subscriptions and the window-event listener, closes every binding (so later state changes no
longer reach this UI), stops the owner thread (joining it for up to 2 s when called from
another thread) and discards queued work.

It is called automatically when the UI's window closes and when the application shuts down.
It does **not** close the window, end the application or close `Computed` objects; the SDK
owns the window and application lifecycle (`ui.window.request_close()`, `app.request_quit()`).
States stay usable after disposal; they simply no longer drive this UI.

---

## Errors raised by the library

| Situation | Exception |
|---|---|
| Unknown theme, density, button variant, input kind, heading level, event kind or tag | `ValueError` |
| Unsafe attribute name or an `id` in `attrs` | `ValueError` |
| Two-way control bound to something that is not a `State` | `TypeError` |
| Adding components after `mount()` or disposal | `RuntimeError` |
| `mount()` twice or after disposal; `sync()` before mount or after disposal | `RuntimeError` |
| `post()` with a full queue | `RuntimeError` |
| Self or circular computed dependency | `RuntimeError` |

SDK errors (for example `nativehtmlkit.RpcError` with code -32001 when the clipboard or a
dialog is unavailable) come from your own SDK calls and are not wrapped.

---

## Known defects

These are recorded, open defects of 0.1.1 (see [limitations](../LIMITATIONS.md)):

- **B-0002, `Computed` under concurrent updates.** When dependencies of the same computed are
  set from several threads at the same time, a recomputation can falsely raise
  `RuntimeError("Circular computed-state dependency")` and keep a stale value. Serialize
  writes that affect the same computed: make them on the UI owner (`ui.post(state.set, value)`)
  or from a single worker thread.
- **B-0003, shutdown callback retention.** Each `mount()` registers an
  `Application.on_shutdown` callback, and the SDK offers no way to remove it. The callback holds
  the UI only weakly, but the registrations accumulate. Avoid creating and discarding many UIs
  in a long-running application; reuse windows or cap their number (as
  `examples/python/multi_window.py` does).
