# nativehtmlkit_ui — Python UI toolkit

Small reactive layouts and controls over the public
[nativehtmlkit Python SDK](https://pypi.org/project/nativehtmlkit/): native desktop windows
rendered from HTML/CSS by the NativeHTMLKit host, with no browser and no JavaScript. Python
3.10+, NativeHTMLKit SDK 0.1.x, Linux (KDE Plasma Wayland) and Windows.

```bash
python -m pip install nativehtmlkit_ui
```

**Version 0.1.1 is an early (pre-1.0) release**; see the
[known limitations](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/LIMITATIONS.md).

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, computed, state

with Application.start(name="Hello UI") as app:
    name = state("Ada")
    greeting = computed(lambda: f"Hi, {name.value or 'stranger'}!")
    ui = UI(title="Hello", theme="cobalt", density="compact")
    with ui.column():
        ui.heading("Hello")
        ui.input(name, label="Name")
        ui.text(greeting)
        ui.button("Clear", variant="secondary", on_click=lambda event: name.set(""))
    ui.mount(app)
    app.run()
```

- **State in, window out.** `state()` holds data, `computed()` derives values, components bind
  to either, and event handlers only change state. Updates are batched into document commands.
- **Components:** `row`, `column`, `grid` (responsive), `card`, `stack`, `heading`, `text`,
  `badge`, `alert`, `button`, `input`, `checkbox`, `select`, `when` (conditional region),
  `text_list`, plus `element` and trusted `raw_html` for custom markup.
- **Threads:** each window has its own UI owner thread; worker threads hand results over with
  `ui.post()`.
- **Themes:** `cobalt`, `graphite`, `daylight`; densities `compact`, `regular`, `comfortable`;
  your own CSS via `extra_css`.

Dialogs, the clipboard, live bitmaps and window management are SDK features you call next to
the UI. Known open defects: concurrent updates to one `Computed` from several threads (B-0002)
and accumulating shutdown callbacks with many mount cycles (B-0003).

## Documentation

- [Tutorial: build an expense tracker](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/tutorials/python-expense-tracker.md)
- [How-to guides](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/guides/README.md) — state, forms, lists, theming, background work, multiple windows, SDK calls, testing
- [Python API reference](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/reference/python.md) and [CSS reference](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/reference/css.md)
- [Architecture](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/ARCHITECTURE.md)
- [Example apps](https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/examples/python) — expense tracker, task list, sign-up form, settings, log viewer, clipboard tool, file inspector, multi-window notes, dashboard and more
- [NativeHTMLKit overview](https://github.com/nativehtmlkit/nativehtmlkit) and [public gallery](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/python-ui/gallery.py)

![Illustrative NativeHTMLKit component gallery, not an actual screenshot](https://raw.githubusercontent.com/nativehtmlkit/nativehtmlkit/main/assets/demo-placeholder.png)

*Documentation illustration, not a captured application. [Run the Python UI gallery](https://github.com/nativehtmlkit/nativehtmlkit/tree/main/examples/python-ui) to inspect its real current behavior.*
