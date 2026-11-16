# Multiple windows and multiple UIs

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[multiple windows](../../powershell/guides/multiple-windows.md).*

**Goal:** open more than one window, share state between them, and handle closing.

## One UI per window

Each `UI` object is one window. Create as many as you need from one SDK application; they may
bind the same states, and every window updates when a shared state changes (the
[`multi_window` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/multi_window.py)).
Each UI has its own owner thread; updates of different windows are independent.

## Open a window from a handler

```python
def open_inspector(_event):
    inspector = UI(title="Inspector 1", width=420, height=320, theme="graphite")
    with inspector.column():
        inspector.text(lambda: f"Note: {note.value}")            # same state as the main window
        inspector.button("Close inspector", variant="secondary",
                         on_click=lambda _e: inspector.window.request_close())
    inspector.mount(app)                                         # allowed from a handler
```

Mounting from an event handler of another UI is allowed. Build the new UI completely before
`mount()`.

## Notice closed windows

```python
    window_id = inspector.window.id

    def on_window(event):                                        # SDK event thread
        if event.get("window_id") == window_id and event.get("type") == "closed":
            unsubscribe()
            main_ui.post(lambda: open_inspectors.set(open_inspectors.value - 1))
    unsubscribe = app.on_window_event(on_window)
```

- A UI disposes itself when its window closes (by the user or `window.request_close()`).
- `app.on_window_event` callbacks run on an SDK thread; hand work to a UI with `post()`.
- Closing the **last** window ends the application (Core asks for quit with reason
  `last_window`).

## Limits (known defect B-0003)

Every `mount()` registers an application shutdown callback that cannot be removed (open defect
**B-0003**). Cap the number of windows a long-running app creates, or reuse them; the example
allows three inspectors at a time.

## Clean up

Dispose every UI you created in `finally` (`ui.dispose()` is idempotent). Window and
application lifecycle (`request_close`, `request_quit`) always belongs to your code.

## Related

[Python reference: mounting and the UI owner](../reference.md#mounting-and-the-ui-owner) ·
[SDK calls](mixing-ui-and-sdk-calls.md)
