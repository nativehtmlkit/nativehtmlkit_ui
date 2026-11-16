# NativeHTMLKit UI examples

Twelve small applications, each written in Python (`python/`) and PowerShell (`powershell/`)
with the same behaviour and the same visible text. Every file starts with a comment that says
what it teaches and how to run it. They use only the public UI and SDK APIs.

| Example | What it is | Teaches |
|---|---|---|
| `counter` | Counter gallery | State, computed text, button, input, checkbox, text list, `when`, grid |
| `expenses` | Expense tracker (the [tutorial](../docs/tutorials/README.md) app) | Two-way inputs and select, validation, computed totals and filter, empty state |
| `todo` | Task list with Done/Remove per row and a filter | The slot pool pattern for rows with buttons, bound button labels |
| `signup_form` | Sign-up form | Validation as computed state, guarded submit, form/confirmation swap, reset |
| `settings` | Settings panel | Dirty tracking, Save/Revert/Defaults writing back into controls, nested `when` |
| `log_viewer` | Live log viewer | Streaming background producer, filter/search, pause, bounded history |
| `background` | Background calculation | Python executor + `ui.post()`; PowerShell `Start-NativeHTMLKitTask` with cancel |
| `clipboard_tool` | Text transformer with copy/paste | SDK clipboard calls from UI handlers, error handling |
| `file_picker` | File inspector | SDK open-file dialog, result handling, cancel/error paths |
| `multi_window` | Notes with inspector windows | Several UIs sharing state, opening/closing windows, window events |
| `dashboard` | System dashboard | Responsive grid, themes, density, extra CSS, a 1 s timer |
| `message_preview` | Message composer | Escaped untrusted text vs. trusted static `raw_html` / `Add-NHKUiHtml` |

## Running

Python 3.10+:

```bash
python -m pip install nativehtmlkit_ui
python examples/python/expenses.py
```

PowerShell 7.2+ (Linux, Windows) or Windows PowerShell 5.1:

```powershell
Install-Module NativeHTMLKit.UI -Scope CurrentUser
pwsh -File ./examples/powershell/expenses.ps1
powershell.exe -NoProfile -File .\examples\powershell\expenses.ps1
```

`dashboard` takes an optional theme argument (`cobalt`, `graphite`, `daylight`). The SDK
starts the native host, which runs the script again as its backend, so the scripts keep all
work behind their entry point.

## Verification

All examples (and the tutorial steps in `docs/tutorials/code/`) are run by
[`qualification/examples/run_examples.py`](../qualification/examples/run_examples.py) against
the real NativeHTMLKit Core 1.0.3 host in headless test mode, with the released Python SDK
0.1.2 and PowerShell SDK 0.1.2. Each example follows a scenario from
[`scenarios.json`](../qualification/examples/scenarios.json): simulated clicks and typing
(delivered where the SDK delivers native events), DOM read-back through the SDK, clean UI and
SDK diagnostics, exit code 0 and no leftover processes. See the
[testing guide](../docs/guides/testing.md) for how to run it and what it does and does not
prove. Headless mode has no clipboard or file dialogs, so for `clipboard_tool` and
`file_picker` the harness verifies the "unavailable" error handling, not the dialogs
themselves.

## Screenshots

Real captures on KDE Plasma 6.6 Wayland (100% scaling) with Core 1.0.3, Python/PowerShell SDK 0.1.2 and UI 0.1.1, taken by running each example unchanged. Windows looks the same apart from the window frame.

### Python

| | |
|---|---|
| [background](python/background.py)<br>![background](../docs/images/examples/ui-py-background.png) | [clipboard_tool](python/clipboard_tool.py)<br>![clipboard_tool](../docs/images/examples/ui-py-clipboard_tool.png) |
| [counter](python/counter.py)<br>![counter](../docs/images/examples/ui-py-counter.png) | [dashboard](python/dashboard.py)<br>![dashboard](../docs/images/examples/ui-py-dashboard.png) |
| [expenses](python/expenses.py)<br>![expenses](../docs/images/examples/ui-py-expenses.png) | [file_picker](python/file_picker.py)<br>![file_picker](../docs/images/examples/ui-py-file_picker.png) |
| [log_viewer](python/log_viewer.py)<br>![log_viewer](../docs/images/examples/ui-py-log_viewer.png) | [message_preview](python/message_preview.py)<br>![message_preview](../docs/images/examples/ui-py-message_preview.png) |
| [multi_window](python/multi_window.py)<br>![multi_window](../docs/images/examples/ui-py-multi_window.png) | [settings](python/settings.py)<br>![settings](../docs/images/examples/ui-py-settings.png) |
| [signup_form](python/signup_form.py)<br>![signup_form](../docs/images/examples/ui-py-signup_form.png) | [todo](python/todo.py)<br>![todo](../docs/images/examples/ui-py-todo.png) |

### PowerShell

| | |
|---|---|
| [background](powershell/background.ps1)<br>![background](../docs/images/examples/ui-ps-background.png) | [clipboard_tool](powershell/clipboard_tool.ps1)<br>![clipboard_tool](../docs/images/examples/ui-ps-clipboard_tool.png) |
| [counter](powershell/counter.ps1)<br>![counter](../docs/images/examples/ui-ps-counter.png) | [dashboard](powershell/dashboard.ps1)<br>![dashboard](../docs/images/examples/ui-ps-dashboard.png) |
| [expenses](powershell/expenses.ps1)<br>![expenses](../docs/images/examples/ui-ps-expenses.png) | [file_picker](powershell/file_picker.ps1)<br>![file_picker](../docs/images/examples/ui-ps-file_picker.png) |
| [log_viewer](powershell/log_viewer.ps1)<br>![log_viewer](../docs/images/examples/ui-ps-log_viewer.png) | [message_preview](powershell/message_preview.ps1)<br>![message_preview](../docs/images/examples/ui-ps-message_preview.png) |
| [multi_window](powershell/multi_window.ps1)<br>![multi_window](../docs/images/examples/ui-ps-multi_window.png) | [settings](powershell/settings.ps1)<br>![settings](../docs/images/examples/ui-ps-settings.png) |
| [signup_form](powershell/signup_form.ps1)<br>![signup_form](../docs/images/examples/ui-ps-signup_form.png) | [todo](powershell/todo.ps1)<br>![todo](../docs/images/examples/ui-ps-todo.png) |
