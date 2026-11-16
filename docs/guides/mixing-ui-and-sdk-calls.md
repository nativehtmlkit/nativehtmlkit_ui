# Mixing the UI with direct SDK calls

**Goal:** use SDK services (dialogs, clipboard, window control, DOM queries) from a UI app.

The UI library covers components and state. Everything else is the SDK's, and a UI app calls
it directly. The handles you need are on the UI object after mounting:

| Python | PowerShell | Use |
|---|---|---|
| `ui.app` (or the `app` you passed) | `$ui.Application` / `$app` | Clipboard, quit, preferences, window events |
| `ui.window` | `$ui.Window` (also returned by `Start-NHKUi`) | Dialogs, `request_close`, `set`/`state` |
| `ui.document` | `$ui.Document` | Reading DOM state, focus, scrolling, stylesheets |
| `element.id` | `$node.Id` | Target id for document calls |

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

```powershell
try {
    Set-NativeHTMLKitClipboard -Application $s.App -Text ([string]$s.Result.Value)
    $s.Status.Set(('Copied {0} characters to the clipboard.' -f ([string]$s.Result.Value).Length))
} catch { $s.Status.Set('Clipboard unavailable: ' + $_.Exception.Message) }
```

Always handle the error: the clipboard is not available everywhere. In the host's headless
test mode it fails with code -32001 ("Clipboard requires a native event loop"), which is the
path the example harness verifies (`examples/*/clipboard_tool.*`).

## File dialogs

Python: start the dialog without blocking the owner thread and post the result back
(`examples/python/file_picker.py`):

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

PowerShell: call the dialog from the button callback; the call waits (while the SDK keeps
processing host messages) until the user closes it, and the callback's state changes are
written when it returns (`examples/powershell/file_picker.ps1`):

```powershell
try {
    $result = Show-NativeHTMLKitFileDialog -Window $s.UI.Window -Kind OpenFiles -Multiple $true -Title 'Choose files to inspect'
} catch { $s.Status.Set('File dialogs are unavailable here: ' + $_.Exception.Message); return }
if ($result.cancelled -or @($result.paths).Count -eq 0) { $s.Status.Set('No files chosen.'); return }
```

Dialogs are unavailable in headless mode (-32001), so the harness verifies the error path; the
interactive dialog path of these two examples was not part of the automated run.

## Reading the DOM

The UI's states are the source of truth, but SDK reads are useful for focus management and
tests:

```python
el = ui.input(name, label="Name")
...
ui.document.focus(el.id)                     # after mount
ui.document.get_value(el.id)                 # what the native control holds
```

```powershell
$node = Add-NHKUiInput -UI $ui -Bind $name -Label 'Name'
...
Set-NativeHTMLKitFocus -Document $ui.Document -Element $node.Id
Get-NativeHTMLKitValue -Document $ui.Document -Element $node.Id
```

## Rules

- Do not change bound properties behind the UI's back (`set_text` on an element whose text is
  bound): the next flush may overwrite it, and the UI cannot know. Change the state.
- Do not add elements into managed containers with raw document calls; the UI's tree would no
  longer describe the document. Use a `raw_html`/`Add-NHKUiHtml` container you own, or a
  separate window.
- Python: SDK calls from a handler run on the owner thread and block it while they wait.
  Prefer `wait=False` futures for anything user-operated (dialogs).
- Window and application lifecycle (`request_close`, `request_quit`, `Close-NativeHTMLKit`)
  always belongs to your code.
