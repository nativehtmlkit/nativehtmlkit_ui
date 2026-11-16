# Public SDK contract used by the UI layer

Verified on 2026-11-16 against the **published** SDK prereleases and their source, and exercised with real
hosts (headless and interactive). This is the bounded interface the UI depends on, not a Core protocol contract.

| Component | Version | Evidence of identity |
|---|---|---|
| Python SDK `nativehtmlkit` | 0.1.0 (GitHub prerelease, tag `v0.1.0` = commit `7559b5b`) | wheels `3073066c…642d` (manylinux_2_39_x86_64), `183ba566…67fc` (win_amd64); local `dist/SHA256SUMS` == release `SHA256SUMS` |
| PowerShell SDK `NativeHTMLKit` | 0.1.0 (GitHub prerelease, tag `v0.1.0` = commit `5734a3a`) | `NativeHTMLKit-0.1.0-linux-x64+win-x64.zip` `8e1fe37f…397b`, matches release `SHA256SUMS` |
| Core host bundled by both SDKs | 1.0.2 (source `8a09875`), protocol 1 | linux-x64 `702adafc…741d2a`, windows-x64 `64d4502f…38f4` (`HOST-MANIFEST.json`, `nativehtmlkit-python version`: `manifest_match: true`) |
| Forward check (unreleased) | Python SDK 0.1.1 `f0b9290`, PowerShell SDK 0.1.1 `215f75a`, Core 1.0.3 dev host `1cd4e9de…999f` | headless gallery suites 18/18 each (`evidence/04-forward/`) |

## Python SDK - calls used

| Call | Use in the UI | Verified behavior |
|---|---|---|
| `Application.open_html(html, title=, width=, height=)` | create the UI window and load its document | closes the window itself if the load fails |
| `Application.on_shutdown(callback)` | dispose the UI after `app.shutdown` | **no unsubscribe**: the UI registers a weak callback so disposed UIs are not retained |
| `Application.on_window_event(callback) -> unsubscribe` | dispose when its window gets `closed` | the **last** window gets no `closed` event (protocol v1 section 7); `app.shutdown` retires all handles instead |
| `Window.document`, `Window.closed`, `Window.request_close()` | handle, staleness check, cleanup of a failed mount | public attributes/methods |
| `Document.on(type, callback) -> unsubscribe` | one subscription per event type (limit 256 per document) | callbacks run on the SDK event worker; the UI only enqueues there |
| `Document.batch(ops)`, `Document.command(op, **fields)` | `set_text`, `add_class`/`remove_class`, `set_attribute`/`remove_attribute`, `replace_children_html` | all are batchable (Core schema `BatchOp`, max 1024 ops); the UI sends at most 128 per batch |
| `Document.set_value/get_value/set_checked/get_checked` | form controls | not batchable; issued separately |
| `nativehtmlkit.StaleDocumentError`, `RpcError.code/.local` | failure classification | matched by name/attribute, so the UI imports nothing from the SDK at import time |

## PowerShell SDK - commands used

| Command | Use | Verified behavior |
|---|---|---|
| `New-NativeHTMLKitWindow`, `Open-NativeHTMLKitHtml` | window + document | |
| `Register-/Unregister-NativeHTMLKitDocumentEvent` | one subscription per event type | callback receives only the event object; it runs on the owning runspace with `Dispatching` set, so notifications are **deferred** while it runs |
| `Invoke-NativeHTMLKitBatch`, `Set-NativeHTMLKitDocumentValue`, `Set-NativeHTMLKitChecked`, `Get-NativeHTMLKitValue`, `Get-NativeHTMLKitChecked` | writes and fallbacks | every call waits for its reply **while pumping**; outside a callback that pump can run document callbacks (handled by the UI's re-entrancy guard) |
| `Set-NativeHTMLKitReady`, `Wait-NativeHTMLKit`, `Close-NativeHTMLKit`, `Start-NativeHTMLKitTask -OnCompleted` | lifecycle, owned by the application | the UI never pumps or closes the SDK application |
| `NativeHTMLKit.StaleObjectException`, `NativeHTMLKit.RpcException.Code` | failure classification | matched by type name (documented in the SDK README) |

The module declares `RequiredModules = NativeHTMLKit >= 0.1.0`; it loads with the released 0.1.0 module and with the 0.1.1 tree.

## Native event payload (Core 1.0.2 `document.rs`)

A `document.event` carries `type`, `element` (nearest ancestor with an `id`), `path` (ids on the bubbling route) and, **for the event target's own control state**, `value` (text controls and `<select>`) and `checked` (checkable inputs), plus `is_composing`, `input_type`, `key`, etc. Clicking a `<label for>` delivers `change` with the checkbox as target. The UI therefore reads `value`/`checked` from the payload and uses the public getters only as a fallback.

## Failure semantics the UI relies on

| Situation | SDK signal | UI behavior |
|---|---|---|
| Window closed / document replaced / `app.shutdown` delivered | `StaleDocumentError` (Python), `StaleObjectException` (PowerShell), `Window.closed` | dispose quietly; count `discarded_after_close` |
| Quit or close already started on the host, `app.shutdown` not yet received | host RPC error `-32008` (invalid state) or `-32004` (closed); definite rejection, the write was not applied | same as above (seen in real runs when closing with pending updates) |
| Timeout, disconnect, other RPC error, local client error | `RpcTimeoutError`/`RpcTimeoutException`, `DisconnectedError`, other codes | `dom_uncertain`, managed writes stop, error logged and re-raised by `sync()`; never retried or reported as success |

## Known SDK constraints (unchanged)

- Callbacks are post-dispatch; prevent defaults ahead of time with the SDK's `prevent_default`/`Set-NativeHTMLKitPreventDefault`.
- Bounded SDK queues can drop events (SDK counters: Python `rpc.dropped_notifications`, PowerShell `DroppedNotifications`); the UI cannot recover them and does not read those private counters. The UI's own queue reports `event_queue_dropped`.
- Protocol v1 is still labelled `1.0-rc` in the Core 1.0.2 manifest.

## Explicit exclusions (enforced by `tools/verify_boundaries.py`)

No `nativehtmlkit.client`/`_bootstrap`/`_contract`/`launcher` imports, no `app.rpc`/`document.rpc`, no SDK private attributes (`_handlers`, `_windows`, `_retire`, ...), no subprocess/HTTP; in PowerShell no `Invoke-NativeHTMLKitRpc`, `Start-NativeHTMLKitRpc`, `Start-NativeHTMLKitHost`, `Register-NativeHTMLKitNotification`, `Add-Type`, `.Transport`, pump or `Retired/ShutdownRequested/Dispatching/Deferred` fields, no PS7-only syntax and no non-ASCII characters.

If an SDK lacks a necessary public operation, file a minimal reproducer in the parent Project bug register; do not route around the SDK. No SDK or Core defect blocking the UI was found in this round.
