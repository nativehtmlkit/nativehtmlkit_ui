# Getting started with the Python UI library

`nativehtmlkit_ui` builds native desktop windows from Python with components (headings, inputs,
buttons, lists, cards, a grid) bound to reactive state. It runs on the NativeHTMLKit native host,
without a browser engine or JavaScript, and uses only the public API of the
[Python SDK](https://github.com/nativehtmlkit/nativehtmlkit-python). This page covers version
0.1.1. The same page for PowerShell: [getting started](../powershell/getting-started.md).

## Install

You need Python 3.10 or later on Linux x64 (KDE Plasma Wayland is the primary desktop) or
Windows x64.

```bash
python -m venv .venv
. .venv/bin/activate                         # Windows: .venv\Scripts\activate
python -m pip install nativehtmlkit_ui       # also installs the nativehtmlkit SDK with its native host
python -c "import nativehtmlkit_ui; print(nativehtmlkit_ui.__version__)"    # 0.1.1
```

## Your first window

Save this as `hello.py` (it is the
[`hello` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/hello.py)):

```python
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, computed, state


def main():
    with Application.start(name="Hello UI") as app:
        name = state("world")
        greeting = computed(lambda: f"Hello, {name.value}!")

        ui = UI(title="Hello UI", width=480, height=320)
        with ui.column():
            ui.heading(greeting, level=1)
            with ui.row():
                ui.input(name, label="Your name")
                ui.button("Reset", variant="secondary", on_click=lambda _event: name.set("world"))
        try:
            ui.mount(app)
            app.run()
        finally:
            ui.dispose()


if __name__ == "__main__":
    main()
```

Run it:

```bash
python hello.py
```

Type a name: the heading follows every keystroke. **Reset** sets the state back, and the input
follows too.

## How it works

- `state("world")` is an observable value. `ui.input(name, ...)` binds it both ways: typing sets
  the state, setting the state changes the field.
- `computed(lambda: ...)` derives a value and records which states it read; the heading bound to
  it updates when `name` changes.
- `with ui.column():` and `with ui.row():` arrange components. You build the whole component tree
  first; `ui.mount(app)` opens the window. After that you only change state.
- Handlers such as `on_click` run on the UI's own thread and change state, never the window.
- `Application.start()` starts the native host, which runs **this same script again** as its
  backend. Keep all work inside `main()` behind `if __name__ == "__main__":`; code at module
  level would run twice.
- `app.run()` returns when the window is closed; `ui.dispose()` releases the UI.

## Where to go next

- Tutorials: [build an expense tracker](tutorials/expense-tracker.md), then
  [build a settings editor](tutorials/settings-editor.md).
- [How-to guides](guides/README.md): state, layouts, forms, lists, theming, background work,
  multiple windows, SDK calls, trusted content, testing.
- [Examples](examples.md): sixteen small applications, each also available in PowerShell.
- [API reference](reference.md) and [CSS reference](../css.md).
- [Known limitations](../LIMITATIONS.md) of 0.1.1.
