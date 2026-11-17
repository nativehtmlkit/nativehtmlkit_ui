# PowerShell reference: `NativeHTMLKit.UI` 0.1.1

This page is the complete reference for the PowerShell module `NativeHTMLKit.UI` 0.1.1, derived
from the released source (`powershell/NativeHTMLKit.UI`). The module requires the
`NativeHTMLKit` SDK module (manifest: `ModuleVersion 0.1.0` or later; qualified with 0.1.2 and
Core 1.0.3) and uses only its public cmdlets. The Python package is documented in the
[Python reference](../python/reference.md); themes and classes in the [CSS reference](../css.md). It runs on Windows PowerShell 5.1 (Windows) and
PowerShell 7.2+ (Linux and Windows).

```powershell
Import-Module NativeHTMLKit.UI    # also imports the NativeHTMLKit SDK
```

Exported functions (24, no cmdlets, aliases or variables):

| Group | Functions |
|---|---|
| State | [`New-NHKUiState`](#new-nhkuistate), [`New-NHKUiComputed`](#new-nhkuicomputed) |
| UI lifecycle | [`New-NHKUi`](#new-nhkui), [`Start-NHKUi`](#start-nhkui), [`Stop-NHKUi`](#stop-nhkui), [`Sync-NHKUi`](#sync-nhkui), [`Invoke-NHKUiBatch`](#invoke-nhkuibatch), [`Get-NHKUiHtml`](#get-nhkuihtml), [`Get-NHKUiDiagnostics`](#get-nhkuidiagnostics) |
| Layout | [`Add-NHKUiColumn`, `Add-NHKUiRow`, `Add-NHKUiGrid`, `Add-NHKUiCard`](#layout-containers) |
| Display | [`Add-NHKUiHeading`, `Add-NHKUiText`, `Add-NHKUiBadge`, `Add-NHKUiAlert`](#display-components) |
| Controls | [`Add-NHKUiButton`](#add-nhkuibutton), [`Add-NHKUiInput`](#add-nhkuiinput), [`Add-NHKUiCheckbox`](#add-nhkuicheckbox), [`Add-NHKUiSelect`](#add-nhkuiselect) |
| Dynamic | [`Add-NHKUiWhen`](#add-nhkuiwhen), [`Add-NHKUiTextList`](#add-nhkuitextlist) |
| Trusted markup | [`Add-NHKUiHtml`](#add-nhkuihtml) |

Every `Add-NHKUi*` function takes the UI explicitly with `-UI` and returns the created node
(see [Nodes](#nodes)). Assign the result to `$null` (or keep the node to read its `.Id`) so it
does not end up in your script's output.

---

## State

### `New-NHKUiState`

```powershell
$count = New-NHKUiState -Value 0
$count.Value              # read
$count.Set(5)             # change and notify
$sub = $count.Subscribe({ param($newValue, $context) ... }, $context)
$count.Unsubscribe($sub)
```

| Parameter | Description |
|---|---|
| `-Value` | Initial value of any type; `$null` allowed. |

Returns a `[pscustomobject]` whose first type name is `NativeHTMLKit.UI.State`, with:

| Member | Description |
|---|---|
| `.Value` | The current value. **Assigning `.Value` directly does not notify anyone**; always use `.Set()`. |
| `.Set($next)` | If `[object]::Equals($current, $next)` it does nothing. Otherwise stores `$next` and calls every active subscription with `($next, $context)`. No return value. |
| `.Subscribe([scriptblock]$Callback, $Context)` | Registers a callback that receives `param($newValue, $context)`; returns a subscription object. |
| `.Unsubscribe($subscription)` | Deactivates and removes a subscription (`$null` is ignored). |
| `.Listeners` | The subscription list (for diagnostics; do not edit). |

Semantics:

- **Equality is `[object]::Equals`.** Numbers and strings compare by value; arrays, hashtables
  and objects compare by reference. Build a new array to signal a change:
  `$items.Set(@($items.Value) + @($new))`. Changing an element in place and setting the same
  array again is ignored.
- Notification is synchronous. Subscribers run inside `.Set()`, in registration order.
- **Batching depth:** the module counts nested `.Set()` calls. Outside a UI callback or
  `Invoke-NHKUiBatch`, the UIs affected by a change are written once, when the *outermost*
  `.Set()` returns. One external change that cascades through several computed states is
  therefore one document write.
- UI-bound states must only be changed on the runspace that started the UI; see
  [the owner runspace](#the-owner-runspace).

### `New-NHKUiComputed`

```powershell
$total = New-NHKUiComputed -DependsOn @($items, $filter) -Data $s -Compute {
    param($s)
    , @($s.Items.Value | Where-Object { $_.Kind -eq $s.Filter.Value })
}
...
$total.Dispose()
```

| Parameter | Description |
|---|---|
| `-Compute` (mandatory) | Scriptblock that returns the value. It is invoked as `& $Compute $Data`, so its first parameter receives `-Data`. |
| `-DependsOn` (mandatory) | Array of states (or other computed states). Anything else throws `DependsOn must contain only NativeHTMLKit.UI.State objects`. |
| `-Data` | Any object passed to `-Compute` on every run (typically a hashtable of states). |

Returns a state object (type name `NativeHTMLKit.UI.State`) with an extra `.Dispose()` method
and a `DependencyTokens` list. It can be bound and used as a dependency like any state.

Semantics:

- Dependencies are **explicit and static**: the module does not inspect the scriptblock.
  Every state the computation reads must be listed in `-DependsOn`.
- `-Compute` runs once immediately and again, synchronously, every time a dependency's
  `.Set()` notifies. The result is stored with `.Set()`, so subscribers (and bound UI
  elements) are notified only when it differs by `[object]::Equals`.
- **Return arrays with a leading comma** (`, @(...)`). PowerShell unrolls pipeline output: an
  empty result would otherwise become `$null` and a one-element result a scalar.
- A computation that triggers itself again while it is running throws
  `Circular computed-state dependency`. Errors in `-Compute` propagate to the `.Set()` call
  that caused the recomputation.
- `.Dispose()` unsubscribes from every dependency. Computed states are **not** disposed by
  `Stop-NHKUi`; dispose them yourself (all examples do this in `finally`).
- Do not call `.Set()` on a computed state yourself; the next dependency change overwrites it.

---

## UI lifecycle

### `New-NHKUi`

```powershell
$ui = New-NHKUi -Title 'Expenses' -Width 760 -Height 640 -Theme cobalt -Density compact -ExtraCss $css
```

| Parameter | Default | Validation / meaning |
|---|---|---|
| `-Title` | `'NativeHTMLKit UI'` | Window title and HTML `<title>`. |
| `-Width`, `-Height` | `940`, `660` | 100-8192; requested window size in CSS pixels. |
| `-Theme` | `cobalt` | `cobalt`, `graphite`, `daylight`. |
| `-Density` | `compact` | `compact`, `regular`, `comfortable`. |
| `-ExtraCss` | `''` | Trusted CSS appended after the built-in stylesheet. See [CSS reference](../css.md). |

Returns a `[pscustomobject]` with type name `NativeHTMLKit.UI.App`. Properties you may read:

| Property | Description |
|---|---|
| `Title`, `Width`, `Height`, `Theme`, `Density`, `ExtraCss` | Constructor values (no effect when changed after start). |
| `Prefix` | `'nhkui-'` + 12 hex digits; every generated element id is `"$Prefix-<n>"`. |
| `Root` | Root node (`<main class="nhk-app">`). |
| `Window`, `Document`, `Application` | `$null` until `Start-NHKUi`; then the SDK window, document and application objects, for direct SDK calls. |

Other properties (`Stack`, `Bindings`, `Handlers`, `Pending`, `Subscriptions`, counters, ...)
are internal state; read them through [`Get-NHKUiDiagnostics`](#get-nhkuidiagnostics).

### `Start-NHKUi`

```powershell
$window = Start-NHKUi -UI $ui -Application $app [-NoReady]
```

| Parameter | Description |
|---|---|
| `-UI` (mandatory) | The UI built with `New-NHKUi` and `Add-NHKUi*`. |
| `-Application` (mandatory) | The SDK application, from `Start-NativeHTMLKitScript` or `Connect-NativeHTMLKit`. |
| `-NoReady` | Do not call `Set-NativeHTMLKitReady`. Use it when you start further UIs later, or when you announce readiness yourself. |

Steps: records the current runspace as the UI's [owner](#the-owner-runspace), renders the
document (`Get-NHKUiHtml`), creates the window with
`New-NativeHTMLKitWindow -Title -Width -Height`, loads it with `Open-NativeHTMLKitHtml`, writes
the live value of every input/select and checkbox, writes any state that changed after its
component was built, registers **one** `Register-NativeHTMLKitDocumentEvent` subscription per
used event kind and finally calls `Set-NativeHTMLKitReady` (the SDK ignores repeated calls).
Returns the SDK window object.

Throws `UI already started`, `UI contains an unclosed container`, and anything the SDK throws.
On failure it records the message in `LastError`, calls `Stop-NHKUi` and rethrows; a window
that was already created is left to the SDK lifecycle.

### `Stop-NHKUi`

```powershell
Stop-NHKUi -UI $ui
```

Idempotent. Unregisters the UI's document event subscriptions, unsubscribes every binding
from its state (later `.Set()` calls no longer touch this UI) and clears pending writes. It
does **not** close the window, the application or computed states. Call it in `finally`, and
when you close a secondary window yourself.

If the window was closed, its document replaced or the application shut down, the next write
fails with the SDK's stale-object error (or host code -32004/-32008); the module then calls
`Stop-NHKUi` itself and counts it in `DiscardedAfterClose`. To react to a user closing a
window immediately, handle the SDK's `window.event` notification (see
`examples/powershell/multi_window.ps1`).

### `Sync-NHKUi`

```powershell
Sync-NHKUi -UI $ui
```

Writes all pending binding changes now. Normally not needed: UI callbacks,
`Invoke-NHKUiBatch` and outermost `.Set()` calls already sync. Does nothing before start or
after stop. Throws `UI DOM state is uncertain after a failed operation; do not continue managed
updates` once [`DomUncertain`](#get-nhkuidiagnostics) is set. Re-entrant calls (an event that
runs while an SDK request inside a write is waiting) only queue their changes; the outer call
writes them afterwards, so an older value never overwrites a newer one.

### `Invoke-NHKUiBatch`

```powershell
Invoke-NHKUiBatch -UI $ui -ScriptBlock {
    for ($i = 1; $i -le 1000; $i++) { $count.Set($i) }
}
```

Runs the scriptblock and writes the resulting changes once, at the end (only the final value
of each binding is written). Use it for several `.Set()` calls made **outside** a UI callback,
for example in a task `-OnCompleted` callback, a notification callback or a custom loop.
UI button/input callbacks are batched automatically. Calls may be nested; the write happens
when the outermost batch ends. The scriptblock's output is returned.

### `Get-NHKUiHtml`

Returns the complete HTML document: doctype, charset and viewport metas, `<title>`, one
`<style>` with the built-in CSS followed by `-ExtraCss`, and
`<body class="nhk-theme-<theme> nhk-density-<density>">` containing the root. Throws
`UI contains an unclosed container` if called from inside a `-Content` block. Needs no host;
useful in tests.

### `Get-NHKUiDiagnostics`

Returns a `[pscustomobject]`:

| Property | Type | Meaning |
|---|---|---|
| `DomUncertain` | bool | A document write failed with an unknown outcome (for example a timeout or disconnect). Managed updates stop; `Sync-NHKUi` throws. Not set when the window simply closed. |
| `LastError` | string | Message of the last callback or write failure (or start failure). |
| `Errors` | long | Number of failed UI callbacks and writes. |
| `PendingUpdates` | int | Bindings waiting to be written. |
| `Updates` | long | Write rounds that produced at least one operation. |
| `Operations` | long | Document operations written. |
| `Subscriptions` | int | Active SDK document event subscriptions (one per event kind); 0 after stop. |
| `DiscardedAfterClose` | long | Writes dropped because the window/document/application was gone. |
| `Disposed` | bool | `True` after `Stop-NHKUi`. |

Combine with the SDK's `Get-NativeHTMLKitDiagnosticReport -Application $app` (connection
counters such as `CallbackFailures`) when diagnosing an app; the example harness checks both.

---

## The owner runspace

`Start-NHKUi` records `[runspace]::DefaultRunspace.InstanceId`. After that, starting, syncing,
batching, building and every write caused by a bound state's `.Set()` must happen on that
runspace; otherwise the module throws
`UI updates must run on the SDK owning runspace (use SDK task completion callbacks)`. A
`.Set()` from another runspace stores the value and then throws, leaving the UI out of date, so
never share UI states with `Start-NativeHTMLKitTask` workers, `ForEach-Object -Parallel`,
thread jobs or raw runspaces. Pass plain data to the worker and set states in the SDK's
`-OnCompleted`/`-OnFailed` callbacks, which run on the owner during `Wait-NativeHTMLKit`.
See the [background work guide](guides/background-work.md).

---

## Layout containers

```powershell
$null = Add-NHKUiCard -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Disk' -Level 3
}
```

| Function | Element and class | Layout |
|---|---|---|
| `Add-NHKUiColumn -UI -Content` | `div.nhk-col` | Vertical flex column, gap `--nhk-gap`. |
| `Add-NHKUiRow -UI -Content` | `div.nhk-row` | Horizontal flex row that wraps; items centred vertically. |
| `Add-NHKUiGrid -UI -Content` | `div.nhk-grid` | 3 equal columns; 2 at most 1000 px wide; 1 at most 620 px. |
| `Add-NHKUiCard -UI -Content` | `div.nhk-card` | Panel with background, border, radius and padding. |

`-Content` is invoked immediately; components added inside it become children of the
container. Output of the block is discarded. All parameters are mandatory. There is no
PowerShell equivalent of Python's `stack()` or generic `element()`.

---

## Display components

| Function | Parameters | Renders |
|---|---|---|
| `Add-NHKUiHeading` | `-UI`, `-Text` (default `''`), `-Level` (1-4, default 2), `-Bind` | `<hN class="nhk-heading">` |
| `Add-NHKUiText` | `-UI`, `-Text` (empty allowed), `-Bind`, `-Muted` | `<p class="nhk-text">` (+ `nhk-muted`) |
| `Add-NHKUiBadge` | `-UI`, `-Text`, `-Bind` | `<span class="nhk-badge">` |
| `Add-NHKUiAlert` | `-UI`, `-Text`, `-Bind` | `<div class="nhk-alert" role="status">` |

With `-Bind <state>` the element shows `[string]$state.Value` (replacing `-Text`) and is
updated with one `set_text` operation when the state changes. Text is HTML-encoded with
`[System.Net.WebUtility]::HtmlEncode`. A `-Bind` argument that is not a state throws
`A -Bind argument must be created with New-NHKUiState or New-NHKUiComputed`.

---

## Controls

### `Add-NHKUiButton`

```powershell
$null = Add-NHKUiButton -UI $ui -Text 'Save' -Variant primary -DisabledState $cannotSave -Data $s -OnClick {
    param($eventObject, $s)
    ...
}
```

| Parameter | Description |
|---|---|
| `-UI` (mandatory) | The UI. |
| `-Text` | Static label. Either `-Text` or `-Bind` is required (`Add-NHKUiButton needs -Text or a bound -Bind label`). |
| `-Bind` | State whose value is the label (for example `'Pause'`/`'Resume'`). |
| `-Variant` | `primary` (default), `secondary`, `danger`, `quiet`. |
| `-OnClick` | Scriptblock run on the owner runspace with `param($eventObject, $data)`. |
| `-Data` | Any object (often a hashtable of states) passed as the callback's second argument. |
| `-DisabledState` | State interpreted with `[bool]`; adds/removes the `disabled` attribute. |

Renders `<button type="button" class="nhk-button nhk-<variant>">`.

### `Add-NHKUiInput`

| Parameter | Description |
|---|---|
| `-UI`, `-Bind` (mandatory) | `-Bind` is the state that holds the text. |
| `-Label` | Visible `<label class="nhk-label" for>` placed before the input inside `div.nhk-field`. Without a label there is no wrapper. |
| `-Placeholder` | Placeholder attribute. |
| `-Type` | `text` (default), `search`, `email`, `password`, `number`. The state always receives a `[string]`. |

Every native `input` event sets the state to the control's text. Setting the state writes the
control with `Set-NativeHTMLKitDocumentValue`; the value received from the control is
remembered first, so typing never triggers an echo write that would reset the caret,
selection or IME composition.

### `Add-NHKUiCheckbox`

`-UI`, `-Bind`, `-Label` (all mandatory). Renders `div.nhk-checkrow` with
`<input type="checkbox" class="nhk-checkbox">` followed by its `<label for>`. A `change`
event sets the state to `[bool]`; setting the state writes `Set-NativeHTMLKitChecked`.

### `Add-NHKUiSelect`

```powershell
$null = Add-NHKUiSelect -UI $ui -Bind $plan -Label 'Plan' -Options @(
    @{ Value = 'free'; Label = 'Free' }, @{ Value = 'team'; Label = 'Team' })
```

| Parameter | Description |
|---|---|
| `-UI`, `-Bind`, `-Options` (mandatory) | `-Options` is an array of hashtables or objects with `Value` and `Label`; both are converted to strings. The list is fixed at build time. |
| `-Label` | Optional visible label. |

The option whose `Value` equals `[string]$state.Value` is marked `selected`. A `change` event
sets the state to the selected value string; setting the state writes
`Set-NativeHTMLKitDocumentValue`.

All three two-way controls return the control node; its `.Id` is the element id for SDK calls
such as `Set-NativeHTMLKitFocus -Document $ui.Document -Element $node.Id`.

---

## Dynamic content

### `Add-NHKUiWhen`

`-UI`, `-Bind`, `-Content` (all mandatory). Creates `div.nhk-region` around the content.
When `[bool]$state.Value` is false the class `nhk-hidden` (`display: none !important`) is
added; when true it is removed. The content is always present, so controls keep their values
while hidden. Note PowerShell truthiness: `''`, `$null`, `0`, `$false` and empty arrays are
false, but the string `'False'` is **true**.

### `Add-NHKUiTextList`

`-UI`, `-Bind` (mandatory). Renders `<ul class="nhk-list">` with one encoded `<li>` per element
of `@($state.Value)` (`$null` gives an empty list, a scalar one item). A change replaces the
list's children with one `replace_children_html` operation. Text only, not virtualized; format
the strings in a computed state.

---

## Trusted markup

### `Add-NHKUiHtml`

`-UI`, `-Markup` (mandatory; empty allowed). Adds `div.nhk-custom` containing `-Markup`
**verbatim**. Only pass static markup that you wrote. Never pass user input, file contents or
data from the network; bind those to text components, which encode them. See the
[trusted content guide](guides/trusted-and-untrusted-content.md).

---

## Nodes

Each `Add-NHKUi*` call returns a node object with `Tag`, `Id`, `Attrs`, `Children`, `Text` and
`Raw`. Use `.Id` for SDK document calls (`Get-NativeHTMLKitDocumentText`,
`Get-NativeHTMLKitValue`, `Set-NativeHTMLKitFocus`, ...). Editing node properties after
`Start-NHKUi` does not change the window; adding components after start throws
`The UI tree is already mounted; change State rather than adding components`.

Rendering rules: attribute names must match `^[A-Za-z_:][A-Za-z0-9_:.-]*$` and may not start
with `on`; attribute values and text are encoded; `$false`/`$null` attributes are omitted,
`$true` renders a boolean attribute; attributes are written in sorted order.

---

## Events and callbacks

- `Start-NHKUi` registers one SDK document subscription per event kind in use (`click` for
  buttons with `-OnClick`, `input` for inputs, `change` for checkboxes and selects).
- For each event the module walks `element` and then `path` (the bubbling route) and invokes
  the handler of the nearest element that has one.
- Callbacks run on the owner runspace while `Wait-NativeHTMLKit` (or another waiting SDK call)
  pumps host messages. State changes made inside them are written once, after the callback
  returns.
- A callback that throws increments `Errors`, sets `LastError` and rethrows into the SDK, which
  isolates it as a callback failure (counted in `Get-NativeHTMLKitDiagnosticReport` as
  `CallbackFailures`, described on stderr). Catch expected errors such as an unavailable
  clipboard inside the callback (see `examples/powershell/clipboard_tool.ps1`).
- Event objects come from the SDK's JSON reader (`type`, `element`, `path`, `window_id`,
  `document_id` and type-specific members such as `value` and `checked`).
- Unlike raw `Register-NativeHTMLKitDocumentEvent` callbacks (which receive only the event),
  UI callbacks receive `($eventObject, $data)`. Pass state through `-Data` instead of relying
  on variable capture.

---

## Known limitations specific to PowerShell

- Only buttons have a public event parameter (`-OnClick`); there is no public keydown, submit
  or context-menu hook in the UI module. Use SDK events on `$ui.Document` if you need them.
- There is no event queue: a long callback delays the next event (the SDK keeps pumping host
  requests while it waits).
- **Fields directly in a column are 200 px tall.** The stylesheet rule
  `.nhk-field { flex: 1 1 200px }` is meant for rows; in `Add-NHKUiColumn` the 200 px basis
  becomes the field's height. Fields in rows and cards are not affected. Workaround:
  `-ExtraCss '.nhk-col > .nhk-field { flex: 0 0 auto; }'` (see the
  [layouts guide](guides/layouts.md)).
- The Python computed-concurrency and shutdown-callback defects do not apply: computed values are synchronous on the
  owner runspace and `Start-NHKUi` registers no application shutdown callback.

See [limitations](../LIMITATIONS.md) for qualification status.
