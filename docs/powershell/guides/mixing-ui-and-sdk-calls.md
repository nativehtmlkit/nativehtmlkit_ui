# Mixing the UI with direct SDK calls

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [mixing the UI with SDK calls](../../python/guides/mixing-ui-and-sdk-calls.md).*

**Goal:** use SDK services (dialogs, clipboard, window control, DOM queries) from a UI app.

## The handles

The UI module covers components and state. Everything else belongs to the
[PowerShell SDK](https://github.com/nativehtmlkit/nativehtmlkit-powershell), and a UI app calls
it directly. The handles you need are on the UI object after `Start-NHKUi`:

| PowerShell | Use |
|---|---|
| `$ui.Application` (or the `$app` you passed) | Clipboard, quit, preferences, window events |
| `$ui.Window` (also returned by `Start-NHKUi`) | Dialogs, `Close-NativeHTMLKitWindow`, window state |
| `$ui.Document` | Reading DOM state, focus, scrolling, stylesheets |
| `$node.Id` | Target id for document calls (every `Add-NHKUi*` returns its node) |

## Clipboard

```powershell
try {
    Set-NativeHTMLKitClipboard -Application $s.App -Text ([string]$s.Result.Value)
    $s.Status.Set(('Copied {0} characters to the clipboard.' -f ([string]$s.Result.Value).Length))
} catch { $s.Status.Set('Clipboard unavailable: ' + $_.Exception.Message) }
```

Always handle the error: the clipboard is not available everywhere. In the host's headless test
mode it fails with code -32001 ("Clipboard requires a native event loop"), which is the path the
example harness verifies (the [`clipboard_tool` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/clipboard_tool.ps1)).
An exception that escapes a UI callback is counted as a callback failure; catch expected errors
inside the callback.

## File dialogs

Call the dialog from the button callback; the call waits (while the SDK keeps processing host
messages) until the user closes it, and the callback's state changes are written when it
returns (the [`file_picker` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/file_picker.ps1)):

```powershell
try {
    $result = Show-NativeHTMLKitFileDialog -Window $s.UI.Window -Kind OpenFiles -Multiple $true -Title 'Choose files to inspect'
} catch { $s.Status.Set('File dialogs are unavailable here: ' + $_.Exception.Message); return }
if ($result.cancelled -or @($result.paths).Count -eq 0) { $s.Status.Set('No files chosen.'); return }
```

Dialogs are unavailable in headless mode (-32001), so the harness verifies the error path; the
interactive dialog path was not part of the automated run.

## Reading the DOM

The UI's states are the source of truth, but SDK reads are useful for focus management and
tests:

```powershell
$node = Add-NHKUiInput -UI $ui -Bind $name -Label 'Name'
...
Set-NativeHTMLKitFocus -Document $ui.Document -Element $node.Id      # after Start-NHKUi
Get-NativeHTMLKitValue -Document $ui.Document -Element $node.Id      # what the native control holds
```

## Rules

- Do not change bound properties behind the UI's back (`Set-NativeHTMLKitDocumentText` on an
  element whose text is bound): the next write may overwrite it, and the UI cannot know. Change
  the state.
- Do not add elements into managed containers with raw document calls; the UI's tree would no
  longer describe the document. Use an `Add-NHKUiHtml` container you own, or a separate window.
- A callback that waits for an SDK call delays the next UI event (there is no event queue).
- Window and application lifecycle (`Close-NativeHTMLKitWindow`, `Request-NativeHTMLKitQuit`,
  `Close-NativeHTMLKit`) always belongs to your code.

## Related

[PowerShell reference: events and callbacks](../reference.md#events-and-callbacks) ·
[background work](background-work.md) · [testing](testing.md)
