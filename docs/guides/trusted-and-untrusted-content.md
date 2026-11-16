# Trusted and untrusted content

**Goal:** show user, file and network data safely, and know when raw HTML is acceptable.

## The rule

| Content | Use | Escaped? |
|---|---|---|
| Anything a user typed, a file contained, a process printed or a server returned | `text`, `heading`, `badge`, `alert`, `text_list`, button labels (Python); `Add-NHKUiText/Heading/Badge/Alert/TextList`, `-Bind` labels (PowerShell) | **Yes**, always |
| Attribute values passed to `ui.element(attrs=...)` | Python only | Yes (`"` and `<` encoded) |
| Static markup you wrote and ship with the app | `ui.raw_html(markup)` / `Add-NHKUiHtml -Markup` | **No**, inserted verbatim |
| Extra CSS | `extra_css` / `-ExtraCss` | No (trusted) |

Text components never interpret markup. In `examples/*/message_preview.*`, typing
`<b>bold</b> & <i>x</i>` into the message field shows exactly those characters in the preview
and in the sent list; the harness reads the element text back through the SDK and checks it.

```python
ui.text(lambda: message.value or "Nothing typed yet.")     # safe for any input
ui.raw_html(HELP)                                          # HELP is a constant in the source
```

```powershell
$null = Add-NHKUiText -UI $ui -Bind $s.Preview              # safe for any input
$null = Add-NHKUiHtml -UI $ui -Markup $help                  # $help is a here-string in the script
```

## Why raw HTML is dangerous even without JavaScript

NativeHTMLKit runs no JavaScript, but injected markup can still restyle or hide your interface,
fake buttons and labels, add elements whose ids clash with managed ones, or reference
images and other resources. Treat `raw_html` like code: only constants, reviewed like code.

If you must display structured untrusted data (a table of records), build it from text
components or escape every value yourself (`html.escape` / `[System.Net.WebUtility]::HtmlEncode`)
before composing markup, and render it into a container you own.

## Other built-in guards

- Element ids are generated; passing `id` in Python `attrs` raises `ValueError`.
- Attribute names must be plain names and may not start with `on` (no inline handlers).
- Python `ui.element` only accepts an allow-list of tags; anything else must go through
  `raw_html`, which makes trusted markup explicit in review.
- Logs: the examples never log typed values. Keep secrets (passwords) out of `print`, logs and
  diagnostics you export.
