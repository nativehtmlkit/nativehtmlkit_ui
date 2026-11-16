# `nativehtmlkit_ui` — Python

Pure Python UI primitives over the public [`nativehtmlkit`](https://github.com/nativehtmlkit/nativehtmlkit-python) SDK.
No dependency on Rust sources, Core internals, the CLI, Qt, Chromium, JavaScript, Node or web servers.

- Python >=3.10; SDK prerelease `0.1.x` is required.
- Install a qualified `nativehtmlkit` platform wheel first, then `python -m pip install --no-index --no-deps ./dist/nativehtmlkit_ui-0.1.0-py3-none-any.whl`.
- Host-first runner: `python -m nativehtmlkit run mymodule:main --name MyApp`; `main(app)` builds/mounts UI then returns; the SDK runner owns `app.run()`.
- For a script using direct `Application.start()`, keep side effects after `start()`; SDK re-executes the script in its backend process.

```python
from nativehtmlkit_ui import UI, state, computed

def main(app):
    counter = state(0)
    name = state("world")
    greeting = computed(lambda: f"Hello, {name.value} ({counter.value})")
    ui = UI(title="Hello", theme="cobalt", density="compact")
    with ui.column():
        ui.heading("Hello")
        ui.text(greeting)
        ui.input(name, label="Name")
        ui.button("Add", on_click=lambda e: counter.set(counter.value + 1))
    ui.mount(app)
```

Text and attribute values are escaped. `ui.raw_html()` and `extra_css` accept **trusted** source content only. Runtime values should go through `state`/bindings, never raw markup.

One UI `UI` instance owns one SDK window/document. Create another UI instance for another window. `ui.post(callback, *args)` safely marshals work from background Python threads to the UI owner thread. `ui.sync()` is a test/explicit flush helper; `ui.dispose()` unsubscribes and stops the UI owner (it does not terminate the underlying SDK application).

See the repository root docs for SDK integration, limitations, packaging and qualification. The initial `text_list` replaces its local region; it is not a virtualized/keyed data grid. `when` toggles visibility but keeps its subtree mounted. No router, extension system, dynamic DOM reconciliation or generic persistence layer is included.
