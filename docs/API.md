# API 0.1 — small public toolkit

Both bindings provide similar **capabilities**, not identical syntax. New controls should be added only when needed by a real application and must pass cross-language tests.

## Python

```python
from nativehtmlkit_ui import UI, state, computed

name = state('Ada')
message = computed(lambda: f'Hello {name.value}')
ui = UI(title='Hello', theme='cobalt', density='compact')

with ui.column():
    ui.heading('Title', level=1)
    ui.text(message)
    ui.input(name, label='Name')
    ui.button('Reset', on_click=lambda event: name.set('Ada'), variant='secondary')

# An SDK `Application` object is passed from main(app) or Application.start().
ui.mount(app)
# If using an SDK direct script: app.run() on the main thread.
```

| Area | API |
|---|---|
| State | `state(value) -> State`, `.value`, `.set(value)`, `.subscribe(callback) -> unsubscribe` |
| Computed | `computed(fn) -> Computed`, `.value`, `.close()` |
| UI construct | `UI(title=...,width=...,height=...,theme=...,density=...,extra_css=...)` |
| Layout | `with ui.row()/column()/grid()/card()/stack():` |
| Display | `ui.heading(value,level=1..4)`, `ui.text(value,muted=False)`, `ui.badge(value)`, `ui.alert(value)` |
| Inputs | `ui.button(label,on_click,variant,disabled)`, `ui.input(state,label,placeholder,kind)`, `ui.checkbox(state,label)`, `ui.select(state, choices=[(value,label)], label='')` |
| Dynamic | `with ui.when(condition):`, `ui.text_list(state_or_fn,formatter=str)` |
| Native custom | `ui.raw_html(trusted_markup)`, `ui.element(allowed_tag,attrs,text)` |
| Lifecycle | `ui.mount(app)`, `ui.dispose()/close()`, `ui.post(fn,*args)`, `ui.sync()`, `ui.diagnostics` |
| Diagnostics keys | `errors`, `event_queue_dropped`, `pending_updates`, `dom_uncertain`, `updates`, `operations`, `subscriptions`, `disposed`, `discarded_after_close` |

`value` arguments support literal strings, `State`, `Computed` and functions (lambda) for display/heading/badge/alert. Only `State` supports two-way form inputs. `ui.text_list` always escapes item strings and reconstructs its local `<ul>` when the source collection changes. `ui.when` hides/shows a permanently mounted region.

Do not mutate the layout tree after `mount`; use state bindings. Public SDK handles remain available as `ui.window`, `ui.document`, and `ui.app` for operations outside managed subtrees. The UI never owns the SDK application shutdown.

The Python UI owner serializes SDK writes; `ui.post()` is a lightweight queue, not a general-purpose task scheduler. Schedule blocking work in standard Python threads/futures and return results via `ui.post()`. `State.set()` may also be called from any thread: bindings coalesce changes and write them on the UI owner (1000 background updates settled in about 6 ms in qualification, two SDK calls).

Failure semantics (both languages): a write the host definitely rejected because the document is gone (`StaleDocumentError`, RPC `-32004` closed, `-32008` shutting down) **disposes the UI quietly** and is counted in `discarded_after_close`; a timeout, disconnect or any other failure marks `dom_uncertain`, stops managed writes, is logged, and is re-raised by `ui.sync()`. Event-queue overflow (4096 pending events) drops the event, counts it in `event_queue_dropped` and logs once; it never raises into the SDK event worker and lost events are not reconstructed.

## PowerShell

```powershell
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Hello'
$name = New-NHKUiState -Value 'Ada'
$message = New-NHKUiComputed -DependsOn @($name) -Data $name -Compute {
    param($source) "Hello $($source.Value)"
}
$ui = New-NHKUi -Title 'Hello'
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Title' -Level 1
    $null = Add-NHKUiText -UI $ui -Bind $message
    $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Name'
    $null = Add-NHKUiButton -UI $ui -Text 'Reset' -Data $name -OnClick {
        param($eventObject,$state) $state.Set('Ada')
    }
}
try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $message.Dispose()
    Close-NativeHTMLKit -Application $app
}
```

| Area | API |
|---|---|
| State | `New-NHKUiState -Value`, `.Value`, `.Set()`, `.Subscribe()`, `.Unsubscribe()` |
| Computed | `New-NHKUiComputed -Compute -DependsOn -Data`, `.Dispose()` |
| Construct | `New-NHKUi -Title -Width -Height -Theme -Density -ExtraCss` |
| Layout | `Add-NHKUiRow`, `Column`, `Grid`, `Card` with `-UI` and `-Content` |
| Display | `Add-NHKUiHeading`, `Text`, `Badge`, `Alert` (`-Text` / `-Bind`) |
| Inputs | `Add-NHKUiButton -Text/-Bind -OnClick -Data -Variant -DisabledState`, `Add-NHKUiInput`, `Checkbox`, `Select` (`-Bind`) |
| Dynamic | `Add-NHKUiWhen -Bind -Content`, `Add-NHKUiTextList -Bind` |
| Native custom | `Add-NHKUiHtml -Markup` (trusted) |
| Lifecycle | `Start-NHKUi -UI -Application [-NoReady]`, `Stop-NHKUi`, `Sync-NHKUi`, `Invoke-NHKUiBatch -UI -ScriptBlock`, `Get-NHKUiHtml`, `Get-NHKUiDiagnostics` |
| Diagnostics | `DomUncertain`, `LastError`, `Errors`, `PendingUpdates`, `Updates`, `Operations`, `Subscriptions`, `DiscardedAfterClose`, `Disposed` |

PowerShell bindings require explicit state dependencies for computed values. Event handlers are scriptblocks that accept `param($eventObject, $data)`, with `-Data` supplied when registered. State changes must happen on the SDK owner runspace; use SDK task completion callbacks to deliver background results. `Start-NHKUi` calls SDK `Set-NativeHTMLKitReady` unless `-NoReady` is specified. The caller owns `Wait-NativeHTMLKit` and SDK shutdown.

`Add-NHKUiSelect -Options` expects records like `@(@{Value='a';Label='A'}, @{Value='b';Label='B'})`.

Write timing in PowerShell: changes made inside a UI event callback are written once, after the callback. A `State.Set()` made elsewhere is written when that `Set` (including every computed state it cascades into) returns: one SDK call per `Set`, about 5 ms each with a real host. For loops, wrap the changes in `Invoke-NHKUiBatch -UI $ui -ScriptBlock { ... }` to write them once (1000 changes in about 120 ms in qualification). `.Subscribe($callback, $context)` callbacks receive `($newValue, $context)`.

## Native behavior and limitations

- Component events are native events delivered **after** host dispatch. To prevent default form/keyboard behavior use the SDK's existing public prevent-default API in advance.
- Input bindings avoid echo updates. Real IME/caret behavior must be qualified in interactive desktops.
- UI component markup and structure are deliberately retained after mount, not arbitrarily rebuilt.
- A failed DOM batch or command makes UI DOM state uncertain; inspect diagnostics rather than silently continuing.
- The complete Core/SDK method set remains accessible to applications through the SDK, outside the UI-managed subtree. No direct Core protocol calls from the UI package.
