"""Settings editor tutorial, step 1: a form whose controls are bound to UI state.

Teaches: UI, state(), two-way ui.input / ui.select / ui.checkbox, computed() with automatic
         dependency tracking, a bound ui.text, mount/run/dispose.
Run:     uv run settings_editor_step1.py
Guide:   docs/python/tutorials/settings-editor.md (step 1 of 2)
"""
from nativehtmlkit import Application
from nativehtmlkit_ui import UI, computed, state

THEMES = [("cobalt", "Cobalt"), ("graphite", "Graphite"), ("daylight", "Daylight")]


def main():
    with Application.start(name="Settings editor") as app:
        name = state("Ada")
        email = state("ada@example.org")
        theme = state("cobalt")
        notify = state(True)
        summary = computed(lambda: f"{name.value} <{email.value}>, {theme.value} theme, "
                                   + ("with e-mail notifications" if notify.value else "without notifications"))

        ui = UI(title="Settings editor", theme="cobalt", density="regular", width=560, height=520)
        with ui.column():
            ui.heading("Settings", level=1)
            with ui.card():
                ui.input(name, label="Display name")
                ui.input(email, label="E-mail", kind="email")
                ui.select(theme, THEMES, label="Theme")
                ui.checkbox(notify, label="Send me e-mail notifications")
            ui.text(summary, muted=True)
        try:
            ui.mount(app)
            app.run()
        finally:
            ui.dispose()


if __name__ == "__main__":
    main()
