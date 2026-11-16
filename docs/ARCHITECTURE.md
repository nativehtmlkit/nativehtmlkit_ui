# Architecture decision record — NativeHTMLKit UI 0.1

Date: 2026-11-16. Status: **implementation candidate** until qualified in the user's lab.

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
- An SDK write failure marks the managed DOM state **uncertain**. Further managed writes are suspended instead of pretending the DOM and state are synchronized. `ui.diagnostics` reports this condition.

### Python tradeoffs

One owner thread/window and a small queue are intentionally simpler than a generalized asyncio/virtual DOM architecture, but they need interactive load qualification. A long-running UI callback still blocks this window's updates; send expensive work to ordinary Python threads and return using `ui.post()`. Native event delivery and host request policies are controlled by the SDK, not by this queue. The UI does not reconstruct dropped events.

## PowerShell runtime

- Script functions build a lightweight element tree. `New-NHKUiState` offers `.Value`, `.Set()` and `.Subscribe()`; computed values declare their `-DependsOn` explicitly.
- State listeners mark bindings dirty. During one native event callback, mutations are deferred until `finally`, then compatible operations are batched. External state updates on the runspace flush synchronously.
- `Register-NativeHTMLKitDocumentEvent` is invoked once per relevant event type; one internal event router handles the component registry for that window (not an application extension registry).
- All UI callbacks execute on the **existing owning SDK runspace**; the SDK's `Wait-NativeHTMLKit` pumps events and task completions. No second runspace/event loop/compiled helper is included.
- Event callbacks receive `param($event, $data)`; `-Data` avoids requiring every consumer to create lexical closures for trivial tasks.
- `Stop-NHKUi` releases event/state subscriptions but does not close the SDK window/application. `Get-NHKUiDiagnostics` reports update failures and uncertain DOM state.
- SDK `Start-NativeHTMLKitTask` remains the background-work API; use `-OnCompleted` callbacks to apply state. Never cross runspace boundaries with SDK handles.

### PowerShell tradeoffs

PowerShell uses explicit computed dependencies, not implicit AST instrumentation. Updates initiated outside an event callback flush immediately. This is a language-appropriate simplification rather than a full duplicate of Python's scheduler. Its runtime behavior must be verified on PowerShell 7.2+ and Windows PowerShell 5.1; only source-level checks were possible in the preparation environment.

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

## Open questions to resolve in real GUI qualification

- Will the Python owner-thread dispatcher preserve interaction latency and ordering under bursty input, high update rates, and shutdown races? Measure and adjust only if evidenced.
- Does the native renderer support all chosen CSS selectors/properties exactly as expected, including focus, layout breakpoints and `display:none` behavior?
- Is PowerShell 5.1 closure capture reliable under the new module's delegated event handlers? Test actual SDK notifications and callbacks on Windows.
- Are event payloads `value` and `checked` reliable for all supported control types? Fallback uses documented public getters.
- Does native focus/caret/IME remain correct across programmatic and user-driven bound updates?
- Does multiple-window lifetime/SDK `app.shutdown` retirement reliably dispose UI handles?
- What SDK version constraints are appropriate after an actual compatibility matrix? Current prerelease `0.1.x` bounds are conservative.

Any required SDK/Core change must be filed in the parent Project bug register with a minimal reproduction, observed/expected behavior, and clear ownership. Do not conceal shortcomings with private SDK access.
