# Python UI example notes

`ui.select(state, [(value,label), ...], label='Choice')`; state must be `State`, not a raw string. `ui.text_list(state)` and `with ui.when(condition):` are reactive. Set states to NEW values (`items.set([*items.value, x])`); in-place mutation does not notify. Use `ui.dispose()` for explicit release when the SDK app remains open. The public SDK still owns shutdown.

Verified example apps (each also exists in PowerShell): https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/examples — expenses (tutorial app), todo (slot pool for rows with buttons), signup_form (validation), settings (dirty tracking), log_viewer and background (`ui.post` from threads), clipboard_tool and file_picker (SDK calls), multi_window, dashboard (grid/themes/extra_css), message_preview (escaping vs `raw_html`).

Reference: https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/reference/python.md
Full gallery: https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/python-ui/gallery.py
