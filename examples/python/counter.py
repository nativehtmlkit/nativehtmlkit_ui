"""Run: python -m nativehtmlkit run counter:main --name Counter (with PYTHONPATH set here)."""
from nativehtmlkit_ui import UI, state, computed


def main(app):
    count = state(0)
    name = state("NativeHTMLKit")
    show = state(True)
    history = state(["Ready"])
    message = computed(lambda: f"{name.value}: {count.value} clicks")
    ui = UI(title="NativeHTMLKit UI Gallery", theme="cobalt", density="compact")

    def add(_event):
        count.set(count.value + 1)
        history.set([f"Count became {count.value}", *history.value][:10])

    with ui.column():
        ui.heading("NativeHTMLKit UI", level=1)
        ui.text("Browserless • native HTML/CSS • Python SDK only", muted=True)
        with ui.grid():
            with ui.card():
                ui.heading("State")
                ui.text(message)
                with ui.row():
                    ui.button("Increment", on_click=add)
                    ui.button("Reset", variant="secondary", on_click=lambda e: count.set(0))
            with ui.card():
                ui.heading("Input")
                ui.input(name, label="Your name", placeholder="Enter a name")
                ui.checkbox(show, label="Show recent events")
            with ui.card():
                ui.heading("Lists")
                with ui.when(show):
                    ui.text_list(history)
        ui.alert(lambda: f"Native reactive updates: {count.value}")
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="NativeHTMLKit UI") as application:
        main(application)
        application.run()
