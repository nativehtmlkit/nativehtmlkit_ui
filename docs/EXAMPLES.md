# Examples and demos

The example applications live in [`examples/`](../examples/README.md) and are listed in
[`examples/catalog.toml`](../examples/catalog.toml): 16 apps, each in Python and
PowerShell with the same window title and behaviour. Each language section shows them with
screenshots and full source: [Python examples](python/examples.md),
[PowerShell examples](powershell/examples.md).

| Example | Python | PowerShell |
|---|---|---|
| Hello UI | [`hello.py`](../examples/python/hello.py) | [`hello.ps1`](../examples/powershell/hello.ps1) |
| Counter gallery | [`counter.py`](../examples/python/counter.py) | [`counter.ps1`](../examples/powershell/counter.ps1) |
| Expense tracker | [`expenses.py`](../examples/python/expenses.py) | [`expenses.ps1`](../examples/powershell/expenses.ps1) |
| Task list | [`todo.py`](../examples/python/todo.py) | [`todo.ps1`](../examples/powershell/todo.ps1) |
| Sign-up form | [`signup_form.py`](../examples/python/signup_form.py) | [`signup_form.ps1`](../examples/powershell/signup_form.ps1) |
| Settings panel | [`settings.py`](../examples/python/settings.py) | [`settings.ps1`](../examples/powershell/settings.ps1) |
| Settings editor | [`settings_editor.py`](../examples/python/settings_editor.py) | [`settings_editor.ps1`](../examples/powershell/settings_editor.ps1) |
| Live log viewer | [`log_viewer.py`](../examples/python/log_viewer.py) | [`log_viewer.ps1`](../examples/powershell/log_viewer.ps1) |
| Background calculation | [`background.py`](../examples/python/background.py) | [`background.ps1`](../examples/powershell/background.ps1) |
| Word counter | [`word_counter.py`](../examples/python/word_counter.py) | [`word_counter.ps1`](../examples/powershell/word_counter.ps1) |
| Clipboard text tool | [`clipboard_tool.py`](../examples/python/clipboard_tool.py) | [`clipboard_tool.ps1`](../examples/powershell/clipboard_tool.ps1) |
| File inspector | [`file_picker.py`](../examples/python/file_picker.py) | [`file_picker.ps1`](../examples/powershell/file_picker.ps1) |
| Notes with inspector windows | [`multi_window.py`](../examples/python/multi_window.py) | [`multi_window.ps1`](../examples/powershell/multi_window.ps1) |
| System dashboard | [`dashboard.py`](../examples/python/dashboard.py) | [`dashboard.ps1`](../examples/powershell/dashboard.ps1) |
| Theme preview | [`theme_preview.py`](../examples/python/theme_preview.py) | [`theme_preview.ps1`](../examples/powershell/theme_preview.ps1) |
| Message composer | [`message_preview.py`](../examples/python/message_preview.py) | [`message_preview.ps1`](../examples/powershell/message_preview.ps1) |

Tutorial steps (complete programs, verified like the examples):
[`examples/tutorials/python`](../examples/tutorials/python) and
[`examples/tutorials/powershell`](../examples/tutorials/powershell).

## Verification

```bash
# from the repository root; see the testing guide (python/guides/testing.md) for setup
python qualification/examples/run_examples.py --python /path/to/venv/bin/python \
    --ps-module-path "/path/to/sdk-modules:$PWD/powershell"
```

Recorded run for this documentation (Core 1.0.3 host in headless test mode, Python SDK 0.1.2
wheel + this UI from source, PowerShell SDK 0.1.2 module + this UI module from source): 16
examples and 4 tutorial steps per language.

| Platform | Runtimes | Result |
|---|---|---|
| Linux x64 | Python 3.13, PowerShell 7.7 | 40 PASS, 0 FAIL |
| Windows Server 2022 | Python 3.13, Windows PowerShell 5.1 | 40 PASS, 0 FAIL |

This is integration evidence, not GUI evidence: there is no native input or rendering check,
and dialogs/clipboard are unavailable in headless mode. Real-input GUI qualification of the
UI libraries is described in [LIMITATIONS.md](LIMITATIONS.md).

## Public galleries

The public landing repository also has interactive galleries:
[Python UI gallery](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/python-ui/gallery.py) and
[PowerShell UI gallery](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/powershell-ui/gallery.ps1).
