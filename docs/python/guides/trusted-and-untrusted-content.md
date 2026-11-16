# Trusted and untrusted content

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[trusted and untrusted content](../../powershell/guides/trusted-and-untrusted-content.md).*

**Goal:** show user, file and network data safely, and know when raw HTML is acceptable.

## The rule

| Content | Use | Escaped? |
|---|---|---|
| Anything a user typed, a file contained, a process printed or a server returned | `text`, `heading`, `badge`, `alert`, `text_list`, button labels | **Yes**, always |
| Attribute values passed to `ui.element(attrs=...)` | `ui.element`, `ui.container` | Yes (`"` and `<` encoded) |
| Static markup you wrote and ship with the app | `ui.raw_html(markup)` | **No**, inserted verbatim |
| Extra CSS | `UI(extra_css=...)` | No (trusted) |

Text components never interpret markup. In the
[`message_preview` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/message_preview.py),
typing `<b>bold</b> & <i>x</i>` into the message field shows exactly those characters in the
preview and in the sent list; the harness reads the element text back through the SDK and
checks it.

```python
ui.text(lambda: message.value or "Nothing typed yet.")     # safe for any input
ui.raw_html(HELP)                                          # HELP is a constant in the source
```

## Why raw HTML is dangerous even without JavaScript

NativeHTMLKit runs no JavaScript, but injected markup can still restyle or hide your interface,
fake buttons and labels, add elements whose ids clash with managed ones, or reference images
and other resources. Treat `raw_html` like code: only constants, reviewed like code.

If you must display structured untrusted data (a table of records), build it from text
components or escape every value yourself with `html.escape` before composing markup, and render
it into a container you own.

## Other built-in guards

- Element ids are generated; passing `id` in `attrs` raises `ValueError`.
- Attribute names must be plain names and may not start with `on` (no inline handlers).
- `ui.element` only accepts an allow-list of tags; anything else must go through `raw_html`,
  which makes trusted markup explicit in review.
- Logs: the examples never log typed values. Keep secrets (passwords) out of `print`, logs and
  diagnostics you export.

## Related

[Python reference: custom and trusted markup](../reference.md#custom-and-trusted-markup) ·
[theming](theming-and-custom-css.md)
