# nativehtmlkit_ui — Python UI toolkit

Small reactive layouts over the public [nativehtmlkit Python SDK](https://pypi.org/project/nativehtmlkit/). Python 3.10+, NativeHTMLKit SDK 0.1.x. Install with `python -m pip install nativehtmlkit_ui`. **Version 0.1.1 is an early (pre-1.0) release**; see [GitHub Releases](https://github.com/nativehtmlkit/nativehtmlkit_ui/releases) and the [known limitations](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/LIMITATIONS.md).

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state
with Application.start(name='Hello UI') as app:
    name = state('Ada')
    ui = UI(title='Hello', theme='cobalt', density='compact')
    with ui.column():
        ui.heading('Hello')
        ui.input(name, label='Name')
        ui.text(lambda: f'Hi, {name.value}!')
    ui.mount(app)
    app.run()
```

Use the [full examples](https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/examples/python) or the [public gallery](https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/python-ui/gallery.py). The toolkit supplies buttons, forms and state, not a generic background job scheduler. Use `ui.post()` to return background results to the UI owner. Known computed-state concurrency defect is documented in [limitations](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/LIMITATIONS.md). A UI `<dialog>` wrapper is not provided; use the SDK if you need a native HTML dialog.

![Illustrative NativeHTMLKit component gallery, not an actual screenshot](https://raw.githubusercontent.com/nativehtmlkit/nativehtmlkit/main/assets/demo-placeholder.png)

*Documentation illustration, not a captured application. [Run the Python UI gallery](https://github.com/nativehtmlkit/nativehtmlkit/tree/main/examples/python-ui) to inspect its real current behavior.*
