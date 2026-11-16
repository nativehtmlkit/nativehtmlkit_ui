# Trusted and untrusted content

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [trusted and untrusted content](../../python/guides/trusted-and-untrusted-content.md).*

**Goal:** show user, file and network data safely, and know when raw HTML is acceptable.

## The rule

| Content | Use | Escaped? |
|---|---|---|
| Anything a user typed, a file contained, a process printed or a server returned | `Add-NHKUiText`, `Add-NHKUiHeading`, `Add-NHKUiBadge`, `Add-NHKUiAlert`, `Add-NHKUiTextList`, `-Bind` button labels | **Yes**, always |
| Option values and labels of `Add-NHKUiSelect` | `-Options` | Yes |
| Static markup you wrote and ship with the app | `Add-NHKUiHtml -Markup` | **No**, inserted verbatim |
| Extra CSS | `New-NHKUi -ExtraCss` | No (trusted) |

Text components never interpret markup. In the
[`message_preview` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/message_preview.ps1),
typing `<b>bold</b> & <i>x</i>` into the message field shows exactly those characters in the
preview and in the sent list; the harness reads the element text back through the SDK and
checks it.

```powershell
$null = Add-NHKUiText -UI $ui -Bind $s.Preview              # safe for any input
$null = Add-NHKUiHtml -UI $ui -Markup $help                  # $help is a here-string in the script
```

## Why raw HTML is dangerous even without JavaScript

NativeHTMLKit runs no JavaScript, but injected markup can still restyle or hide your interface,
fake buttons and labels, add elements whose ids clash with managed ones, or reference images
and other resources. Treat `Add-NHKUiHtml` like code: only constants, reviewed like code.

If you must display structured untrusted data (a table of records), build it from text
components or encode every value yourself with `[System.Net.WebUtility]::HtmlEncode` before
composing markup, and render it into a container you own.

## Other built-in guards

- Element ids are generated (`$ui.Prefix` plus a counter); you cannot choose them.
- Attribute names must be plain names and may not start with `on` (no inline handlers).
- The module has no generic element function; anything beyond its components must go through
  `Add-NHKUiHtml`, which makes trusted markup explicit in review.
- Logs: the examples never log typed values. Keep secrets (passwords) out of `Write-Host`, logs
  and diagnostics you export.

## Related

[PowerShell reference: trusted markup](../reference.md#trusted-markup) ·
[theming](theming-and-custom-css.md)
