# Mixing the UI with direct SDK calls

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[mixing the UI with SDK calls](../../powershell/guides/mixing-ui-and-sdk-calls.md).*

**Goal:** use SDK services (dialogs, clipboard, window control, DOM queries) from a UI app.

## The handles

The UI library covers components and state. Everything else belongs to the
[Python SDK](https://github.com/nativehtmlkit/nativehtmlkit-python), and a UI app calls it
directly. The handles you need are on the UI object after mounting:

| Python | Use |
|---|---|
| `ui.app` (or the `app` you passed) | Clipboard, quit, preferences, window events |
| `ui.window` | Dialogs, `request_close`, window state |
| `ui.document` | Reading DOM state, focus, scrolling, stylesheets |
| `element.id` | Target id for document calls (every component returns its `Element`) |

## Clipboard

```python
from nativehtmlkit import RpcError

def copy(_event):
    try:
        app.set_clipboard_text(result.value)
        status.set(f"Copied {len(result.value)} characters to the clipboard.")
    except RpcError as error:
        status.set(f"Clipboard unavailable: {error}")
```

Always handle the error: the clipboard is not available everywhere. In the host's headless test
mode it fails with code -32001 ("Clipboard requires a native event loop"), which is the path the
example harness verifies (the [`clipboard_tool` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/clipboard_tool.py)).

## File dialogs

Start the dialog without blocking the owner thread and post the result back (the
[`file_picker` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/file_picker.py)):

```python
def choose(_event):
    busy.set(True)
    future = ui.window.open_files(multiple=True, title="Choose files to inspect", wait=False)
    future.add_done_callback(lambda f: ui.post(chosen, f))

def chosen(future):                         # on the UI owner
    busy.set(False)
    try:
        result = future.result()            # {"cancelled": bool, "paths": [...]}
    except RpcError as error:
        status.set(f"File dialogs are unavailable here: {error}")
        return
    ...
```

Dialogs are unavailable in headless mode (-32001), so the harness verifies the error path; the
interactive dialog path was not part of the automated run.

## Reading the DOM

The UI's states are the source of truth, but SDK reads are useful for focus management and
tests:

```python
el = ui.input(name, label="Name")
...
ui.document.focus(el.id)                     # after mount
ui.document.get_value(el.id)                 # what the native control holds
```

## Rules

- Do not change bound properties behind the UI's back (`set_text` on an element whose text is
  bound): the next flush may overwrite it, and the UI cannot know. Change the state.
- Do not add elements into managed containers with raw document calls; the UI's tree would no
  longer describe the document. Use a `raw_html` container you own, or a separate window.
- SDK calls from a handler run on the owner thread and block it while they wait. Prefer
  `wait=False` futures for anything user-operated (dialogs).
- Window and application lifecycle (`request_close`, `request_quit`) always belongs to your
  code.

## Related

[Python reference: mounting](../reference.md#mounting-and-the-ui-owner) ·
[background work](background-work.md) · [testing](testing.md)
