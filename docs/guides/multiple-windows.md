# Multiple windows and multiple UIs

**Goal:** open more than one window, share state between them, and handle closing.

Each `UI` / `New-NHKUi` object is one window. Create as many as you need from one SDK
application; they may bind the same states, and every window updates when a shared state
changes (`examples/*/multi_window.*`).

## Python

```python
def open_inspector(_event):
    inspector = UI(title="Inspector 1", width=420, height=320, theme="graphite")
    with inspector.column():
        inspector.text(lambda: f"Note: {note.value}")            # same state as the main window
        inspector.button("Close inspector", variant="secondary",
                         on_click=lambda _e: inspector.window.request_close())
    inspector.mount(app)                                         # allowed from a handler
    window_id = inspector.window.id

    def on_window(event):                                        # SDK event thread
        if event.get("window_id") == window_id and event.get("type") == "closed":
            unsubscribe()
            main_ui.post(lambda: open_inspectors.set(open_inspectors.value - 1))
    unsubscribe = app.on_window_event(on_window)
```

- Each UI has its own owner thread; updates of different windows are independent.
- A UI disposes itself when its window closes (by the user or `window.request_close()`).
- `app.on_window_event` callbacks run on an SDK thread; hand work to a UI with `post()`.
- Closing the **last** window ends the application (Core asks for quit with reason
  `last_window`).
- Every mount registers an application shutdown callback that cannot be removed (defect
  **B-0003**). Cap the number of windows a long-running app creates, or reuse them.

## PowerShell

```powershell
$window = Start-NHKUi -UI $inspector -Application $s.App -NoReady
[void]$s.Inspectors.Add([pscustomobject]@{ UI = $inspector; WindowId = $window.Id })

Register-NativeHTMLKitNotification -Application $app -Method 'window.event' -Callback {
    param($notification)
    if ($notification.type -ne 'closed') { return }
    foreach ($entry in @($s.Inspectors)) {
        if ($entry.WindowId -eq $notification.window_id) {
            Stop-NHKUi -UI $entry.UI
            $s.Inspectors.Remove($entry)
            $s.Open.Set($s.Inspectors.Count)
        }
    }
}
```

- Start later UIs with `-NoReady` (readiness was announced by the first one; the SDK would
  ignore a second call anyway).
- `Close-NativeHTMLKitWindow -Window $ui.Window` asks the host to close a window. The UI module
  does not watch window events itself: without the notification handler above, a closed
  window's UI is stopped on its next write (`DiscardedAfterClose`).
- `Register-NativeHTMLKitNotification` holds one callback per method; combine all window-event
  handling in that one callback.
- In `finally`, stop every UI you started and dispose shared computed states once.
