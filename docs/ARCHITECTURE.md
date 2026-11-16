# Architecture decision record — NativeHTMLKit UI 0.1

Date: 2026-11-16. Status: **0.1.0 release candidate**, natively qualified on KDE Plasma Wayland and Windows Server 2022 with the published SDK 0.1.0 prereleases (see `docs/VERIFICATION.md`).

## Problem and scope

Provide a compact, attractive, responsive and reactive native desktop UI surface for Python and PowerShell applications. The runtime must be easy for a developer or coding agent to understand, require no JavaScript/web stack, and remain genuinely decoupled from Core.

## Hard dependency chain

```
App (Python) -> nativehtmlkit_ui -> public nativehtmlkit SDK -> Core host
App (PowerShell) -> NativeHTMLKit.UI -> public NativeHTMLKit SDK -> Core host
```

The UI packages never invoke Core's RPC protocol directly. They are independently versioned. Both ship their own copy of shared CSS, with no runtime dependency on the sibling language.

### Why not reuse UI4ME internals?

UI4ME 2.1 was inspiration and evidence of feasible features, not an obligation. The present implementation is new and deliberately smaller. It does not include UI4ME's old ownership tree, server assumptions, router, plugin infrastructure or a virtual DOM.

## Python runtime

- UI constructed before mount in a lightweight `Element` tree. The tree is rendered once into HTML with generated unique IDs and escaped text/attrs.
- Each dynamic property has a `Binding` holding a dependency-tracked expression. `State` and `Computed` are SDK-independent and synchronous; a binding subscribes to signals it read, including expressions that switch dependencies.
- When state changes, only affected bindings become dirty. Changes are coalesced and sent as SDK DOM mutations. Batch-compatible changes are grouped (up to 128 operations per call; a conservative subset of the SDK's limit). `set_value` and `set_checked` remain separate public SDK calls.
- An SDK document callback runs on the SDK's own event worker, **never** on the UI owner. The callback merely enqueues `(event, handler)` into the UI queue. One Python thread per mounted UI instance serializes UI callbacks and document writes. This is **not** a second Core connection or asyncio loop.
- `UI.post()` lets application background threads schedule UI state changes safely. `UI.sync()` is for test synchronization. Application management and native host lifecycle remain with `nativehtmlkit.Application`.
- One `Document.on(type,...)` subscription per used event type; internal event delegation chooses the nearest handler matching `event.element` or `event.path`.
- `UI.dispose()` unsubscribes document/window events, closes bindings, and stops the UI owner. After SDK shutdown, handles are retired and no further writes should occur.
- An SDK write failure marks the managed DOM state **uncertain**. Further managed writes are suspended instead of pretending the DOM and state are synchronized. `ui.diagnostics` reports this condition. Exception: a definite "document is gone" outcome (stale handle, RPC `-32004`, `-32008` once shutdown began) disposes the UI quietly (`discarded_after_close`).
- `on_shutdown` has no unsubscribe in SDK 0.1.0, so the UI registers a weak callback; the window observer is removed on dispose. Repeated mount/dispose cycles retain nothing.
- SDK event callbacks never block or raise: on queue overflow the event is counted (`event_queue_dropped`) and logged once.

### Python tradeoffs

One owner thread/window and a small queue are intentionally simpler than a generalized asyncio/virtual DOM architecture, but they need interactive load qualification. A long-running UI callback still blocks this window's updates; send expensive work to ordinary Python threads and return using `ui.post()`. Native event delivery and host request policies are controlled by the SDK, not by this queue. The UI does not reconstruct dropped events.

## PowerShell runtime

- Script functions build a lightweight element tree. `New-NHKUiState` offers `.Value`, `.Set()` and `.Subscribe()`; computed values declare their `-DependsOn` explicitly.
- State listeners mark bindings dirty. During one native event callback, mutations are deferred until `finally`, then compatible operations are batched. A change made outside a callback is written once when the outermost `State.Set()` returns (so a cascade through computed states is one write); `Invoke-NHKUiBatch` defers a whole block of changes into one write.
- SDK commands wait for their reply while pumping host messages. Outside a callback that pump can run a document callback in the middle of a UI write; `Sync-NHKUi` is therefore re-entrancy safe (nested calls only queue, the outer call drains in order, so an older value never overwrites a newer one).
- **Closure scoping rule:** a scriptblock made with `.GetNewClosure()` is bound to a new dynamic module and cannot see this module's private functions. Internal callbacks are module-bound literals that receive a context object; the single closure passed to the SDK re-enters the module explicitly (`& $module Invoke-NHKUiEventInternal ...`). The supplied 0.1.0 candidate violated this rule and every bound update failed.
- `Register-NativeHTMLKitDocumentEvent` is invoked once per relevant event type; one internal event router handles the component registry for that window (not an application extension registry).
- All UI callbacks execute on the **existing owning SDK runspace**; the SDK's `Wait-NativeHTMLKit` pumps events and task completions. No second runspace/event loop/compiled helper is included.
- Event callbacks receive `param($event, $data)`; `-Data` avoids requiring every consumer to create lexical closures for trivial tasks.
- `Stop-NHKUi` releases event/state subscriptions but does not close the SDK window/application. `Get-NHKUiDiagnostics` reports update failures and uncertain DOM state.
- SDK `Start-NativeHTMLKitTask` remains the background-work API; use `-OnCompleted` callbacks to apply state. Never cross runspace boundaries with SDK handles.

### PowerShell tradeoffs

PowerShell uses explicit computed dependencies, not implicit AST instrumentation. Updates initiated outside an event callback are written per outermost `Set` (about 5 ms per write with a real host); `Invoke-NHKUiBatch` is the explicit coalescing tool. This is a language-appropriate simplification rather than a full duplicate of Python's scheduler. Verified on PowerShell 7.7 (Linux and Windows) and Windows PowerShell 5.1 with real windows.

## Component model

A small set of layout helpers, display/input primitives and a text-only list supports most early admin tools. CSS applies responsive layout using Flexbox, Grid and media queries. Themed CSS values are shared under `shared/css/ui.css`; copy exactly into both distributions. No mandatory renderer in the UI package.

`when` / `Add-NHKUiWhen` is a **visibility** region, not dynamically mounted content. `text_list` / `Add-NHKUiTextList` rebuilds only its own text list and intentionally has no child event handlers, virtualization, row identity or advanced selection. Applications requiring more can use public SDK methods on independent, unowned subtrees or propose a focused new component.

`raw_html()` / `Add-NHKUiHtml` is a trusted escape hatch. It is **not sanitized**, and must not contain interpolated untrusted strings. Ordinary text/binding paths escape HTML and attribute values. The code rejects event-handler attributes (e.g. `onclick`) when using managed element attributes.

## Lifetime and failure invariants

1. UI instances own exactly one SDK window/document and have unique element ID prefixes.
2. The tree is immutable after mount; only declared binding positions may update.
3. Native editor controls are authoritative: on `input`/`change`, record the new value before mutating state, preventing echo writes that would reset caret/IME composition.
4. Event delivery is post-native-dispatch. Set prevent-default policies through the SDK ahead of time; a callback cannot retrospectively cancel a native default action.
5. All UI subscriptions are released on disposal; stale SDK handles must not be reused after window close or document replacement.
6. A failed native batch is observable and halts managed updates rather than silently continuing with uncertain state.
7. No automatic retries on timeouts/disconnects or outcome-unknown native operations.
8. No actual plugins or package discovery are built into the UI.

## Deliberate non-goals

No event sourcing, HTTP/SSE, universal forms/router, plugin contribution system, ViewSpec, virtual DOM/diff engine, browser, JavaScript, application storage, native binary repackaging or cross-language bridge. Those belong to applications or higher-level optional projects when justified.

## Questions answered by native qualification (2026-11-16)

- Ordering/latency: clicks, typing (including 6 ms/key bursts) and 1000-update bursts kept order with no drops; a click after a burst reached state within ~0.1-0.6 s (`docs/VERIFICATION.md`).
- CSS: every selector/property used is supported by Core 1.0.2 (`get_computed_style` reports `supported` and the expected values for all themes; breakpoints at 1300/900/620/360 px; `display:none`; focus outline).
- PowerShell 5.1 closure capture: fixed (see the scoping rule above) and verified with real windows on 5.1 and 7.
- Event payloads: `value`/`checked` are present for the target control; the getter fallback is kept.
- Caret: a mid-text edit keeps the caret (no echo write) on both platforms. IME composition was **not** exercised (no IME on the lab desktops).
- Multiple windows and `app.shutdown` retirement dispose UIs correctly; closing with pending updates exits cleanly.

Any required SDK/Core change must be filed in the parent Project bug register with a minimal reproduction, observed/expected behavior, and clear ownership. Do not conceal shortcomings with private SDK access.
