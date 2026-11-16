# Public SDK contract used by the UI layer

Based on the **user-provided 2026-11-15 ZIP snapshots**. This is a bounded interface inventory, **not** a private Core protocol contract. Local agent must verify the current installed SDKs before qualification.

## Python SDK — `nativehtmlkit` 0.1.0 prerelease

| Call | Purpose |
|---|---|
| `Application.open_html(html, title=..., width=..., height=...)` | Create window and load document |
| `Application.on_shutdown(callback)` | SDK application lifecycle cleanup |
| `Application.on_window_event(callback) -> unsubscribe` | Dispose UI if owned window closes |
| `Window.document` | Generation-bound Document handle |
| `Document.on(type, callback, element=None) -> unsubscribe` | Post-native-dispatch event subscription |
| `Document.batch(operations)` | Atomic compatible DOM mutations |
| `Document.command(op, **fields)` | Public general document operation API |
| `Document.set_value`, `get_value`, `set_checked`, `get_checked` | Native form control properties |
| `Document.replace_html(element, html)` | Local structural region replacement |

SDK callbacks run on its event worker thread. `on_shutdown` callbacks run when the SDK's `Application.run()` drains shutdown. Native document event payloads include type, element, path, and sometimes value/checked. The SDK exposes public backpressure/diagnostics; UI queue losses are separately diagnosed. No direct use of `app.rpc` or `.client` internals.

## PowerShell SDK — `NativeHTMLKit` 0.1.0 prerelease

| Command | Purpose |
|---|---|
| `Start-NativeHTMLKitScript` | Existing host-first launcher/SDK connection |
| `New-NativeHTMLKitWindow` | Create window |
| `Open-NativeHTMLKitHtml` | Load document |
| `Register-NativeHTMLKitDocumentEvent` / `Unregister-*` | One callback per native event type |
| `Invoke-NativeHTMLKitBatch` | Bounded compatible document mutation |
| `Set-NativeHTMLKitDocumentValue`, `Get-NativeHTMLKitValue` | Input value |
| `Set-NativeHTMLKitChecked`, `Get-NativeHTMLKitChecked` | Input checked |
| `Set-NativeHTMLKitDocumentHtml` | Local structural region replacement |
| `Set-NativeHTMLKitReady` | SDK ready handshake |
| `Wait-NativeHTMLKit -UntilShutdown` | Existing runspace event pump |
| `Close-NativeHTMLKit` | SDK shutdown |
| `Start-NativeHTMLKitTask` | Optional background task, completion on owner runspace |

The UI module does **not** invoke `Invoke-NativeHTMLKitRpc` or call Core directly. Its `.psd1` requires the NativeHTMLKit module as a dependency. The PowerShell SDK may run the top-level script twice during host-first launch; keep side effects below `Start-NativeHTMLKitScript`.

## Known native SDK constraints

- 256 document handlers max: UI registers per **event type**, not per component.
- Bounded SDK callback/notification queues can drop events when full: UI cannot magically reconstruct lost events. Stress qualification and SDK-level fixes may be required.
- Some commands cannot be placed in a batch (`set_value`, `set_checked`); the UI issues those separately.
- Native callbacks are post-dispatch: default action suppression has to be registered **ahead of time** through public SDK APIs.
- Host/document handles become stale after load/unload, close and `app.shutdown`; no further updates may be sent.
- Document size, element count, batch and per-text-operation limits exist; avoid unbounded data/log surfaces.
- Core's current protocol is a release candidate (`1.0-rc`), despite the presence of working prerelease SDKs.

## Explicit exclusions

The UI must not import/call `nativehtmlkit.client`, `_bootstrap`, `RpcClient`, `app.rpc`, `document.window.app.rpc`, SDK private helpers, Rust crates, the CLI, low-level JSON-RPC, or host binaries directly.

If an SDK lacks a necessary public operation, create a minimal reproducer and file it in the parent Project bug register; do not route around the SDK.
