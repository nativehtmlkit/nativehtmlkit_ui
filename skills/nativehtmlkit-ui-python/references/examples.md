# Python UI example notes

`ui.select(state, [(value,label), ...], label='Choice')`; state must be `State`, not a raw string. `ui.text_list(state)` and `with ui.when(condition):` are reactive. Use `ui.dispose()` for explicit release when the SDK app remains open. The public SDK still owns shutdown.

Full gallery: https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/python-ui/gallery.py
