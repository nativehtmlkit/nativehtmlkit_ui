# NativeHTMLKit.UI — PowerShell

Pure PowerShell UI toolkit using only public [`NativeHTMLKit`](https://github.com/nativehtmlkit/nativehtmlkit-powershell) SDK cmdlets. PowerShell 7.2+ and Windows PowerShell 5.1. No Python or browser.

Install a locally qualified `NativeHTMLKit` SDK module first, then copy `NativeHTMLKit.UI` to a folder on `$env:PSModulePath`, or import `NativeHTMLKit.UI.psd1` by absolute path.

See `examples/powershell/counter.ps1` for the complete executable example. The SDK launcher starts the host; `Start-NHKUi` creates a window, loads markup, subscribes to events and calls `Set-NativeHTMLKitReady`. `Wait-NativeHTMLKit -Application $app -UntilShutdown` is still the SDK's event pump. Close the UI with `Stop-NHKUi` before closing the SDK application.

State changes must happen on the owning PowerShell runspace. Use `Start-NativeHTMLKitTask` and `-OnCompleted` callbacks for background work; do not pass SDK objects or reactive states into a task worker. `New-NHKUiComputed` uses explicit `-DependsOn` states and receives `-Data` instead of automatic Python-style dependency tracking. Event handlers receive `param($eventObject,$data)`; `-Data` is a convenient alternative to repeated `.GetNewClosure()` usage.

`Add-NHKUiHtml` and `-ExtraCss` accept **trusted** content only; the rest of the public components escape text and attributes. `Add-NHKUiWhen` hides/shows a persistently mounted region. `Add-NHKUiTextList` is a bounded text list, not a virtualized grid. The module does not install or execute plugins.
