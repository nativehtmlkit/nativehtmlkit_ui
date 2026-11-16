# Examples and demos

The example applications live in [`examples/`](../examples/README.md): twelve apps, each in
Python and PowerShell, with a one-line purpose per app in that README. In short:

| Example | Python | PowerShell |
|---|---|---|
| Counter gallery | [`counter.py`](../examples/python/counter.py) | [`counter.ps1`](../examples/powershell/counter.ps1) |
| Expense tracker (tutorial app) | [`expenses.py`](../examples/python/expenses.py) | [`expenses.ps1`](../examples/powershell/expenses.ps1) |
| Task list with per-row actions | [`todo.py`](../examples/python/todo.py) | [`todo.ps1`](../examples/powershell/todo.ps1) |
| Sign-up form with validation | [`signup_form.py`](../examples/python/signup_form.py) | [`signup_form.ps1`](../examples/powershell/signup_form.ps1) |
| Settings panel | [`settings.py`](../examples/python/settings.py) | [`settings.ps1`](../examples/powershell/settings.ps1) |
| Live log viewer | [`log_viewer.py`](../examples/python/log_viewer.py) | [`log_viewer.ps1`](../examples/powershell/log_viewer.ps1) |
| Background calculation | [`background.py`](../examples/python/background.py) | [`background.ps1`](../examples/powershell/background.ps1) |
| Clipboard text tool | [`clipboard_tool.py`](../examples/python/clipboard_tool.py) | [`clipboard_tool.ps1`](../examples/powershell/clipboard_tool.ps1) |
| File inspector (open dialog) | [`file_picker.py`](../examples/python/file_picker.py) | [`file_picker.ps1`](../examples/powershell/file_picker.ps1) |
| Notes with inspector windows | [`multi_window.py`](../examples/python/multi_window.py) | [`multi_window.ps1`](../examples/powershell/multi_window.ps1) |
| System dashboard (grid, themes) | [`dashboard.py`](../examples/python/dashboard.py) | [`dashboard.ps1`](../examples/powershell/dashboard.ps1) |
| Message composer (escaping) | [`message_preview.py`](../examples/python/message_preview.py) | [`message_preview.ps1`](../examples/powershell/message_preview.ps1) |

## Verification

```bash
# from the repository root; see docs/guides/testing.md for setup
python qualification/examples/run_examples.py --python /path/to/venv/bin/python \
    --ps-module-path "/path/to/sdk-modules:$PWD/powershell"
```

Recorded run for this documentation (Core 1.0.3 host in headless test mode, Python SDK 0.1.2
wheel + this UI from source, PowerShell SDK 0.1.2 module + this UI module from source):

| Platform | Runtimes | Result |
|---|---|---|
| Linux x64 | Python 3.13, PowerShell 7.7 | 30 PASS, 0 FAIL (12 + 3 tutorial steps per language) |
| Windows Server 2022 | Python 3.13, Windows PowerShell 5.1 | 30 PASS, 0 FAIL |

This is integration evidence, not GUI evidence: there is no native input or rendering check,
and dialogs/clipboard are unavailable in headless mode. Real-input GUI qualification of the
UI libraries is described in [LIMITATIONS.md](LIMITATIONS.md).

## Public galleries

The public landing repository also has interactive galleries:
[Python UI gallery](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/python-ui/gallery.py) and
[PowerShell UI gallery](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/powershell-ui/gallery.ps1).
