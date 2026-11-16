"""Hello UI: the first window of the getting-started page.

Teaches: Application.start(), state() and computed(), a heading bound to a computed value, a
two-way input, a button that sets state, mount/run/dispose behind the script entry point.
Run:     uv run hello.py      (uv add nativehtmlkit_ui)
Guide:   docs/python/getting-started.md
"""
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
