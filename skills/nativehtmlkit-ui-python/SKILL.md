---
name: nativehtmlkit-ui-python
description: Build compact reactive desktop components using nativehtmlkit_ui over the public NativeHTMLKit Python SDK.
---

# NativeHTMLKit Python UI

This is an optional **0.1.0 prerelease** component layer using the public `nativehtmlkit` SDK. Use it for state, layouts, inputs and lists, not for private Core operations.

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state
with Application.start(name='Counter') as app:
    count = state(0)
    ui = UI(title='Counter', theme='cobalt', density='compact')
    with ui.column():
        ui.heading('Counter')
        ui.text(lambda: str(count.value))
        ui.button('Add', on_click=lambda e: count.set(count.value + 1))
    ui.mount(app)
    app.run()
```

Before mount, use `with ui.row()/column()/grid()/card()`; `ui.text`, `heading`, `badge`, `alert`, `button`, `input`, `checkbox`, `select`, `when`, `text_list`. After mount use bound state, not edits to layout tree. Worker threads send results with `ui.post` to the owner. **Known defect:** computed state can race under concurrent changes; serialize such changes until fixed.

Dialogs/clipboard/live bitmap are public SDK operations, not UI components. No routing or plugins. [Examples](references/examples.md) and [API](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/API.md).
