"""Settings panel with Save, Revert and Restore defaults, plus an "unsaved changes" indicator.

Teaches: one computed snapshot of many controls, dirty tracking by comparing it with the last
saved snapshot, writing state back into inputs/selects/checkboxes (Revert, Defaults) and
enabling buttons only when they would do something. Replace save() with your own persistence.

Run:  python settings.py      (pip install nativehtmlkit_ui)
"""
from datetime import datetime

from nativehtmlkit_ui import UI, computed, state

DEFAULTS = {"display_name": "", "language": "en", "font_size": "14", "autosave": True,
            "interval": "5", "telemetry": False}
LANGUAGES = [("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("ja", "日本語")]
FONT_SIZES = [("12", "Small (12 px)"), ("14", "Normal (14 px)"), ("16", "Large (16 px)")]


def main(app):
    fields = {key: state(value) for key, value in DEFAULTS.items()}
    saved = state(dict(DEFAULTS))
    status = state("Loaded defaults.")

    current = computed(lambda: {key: s.value for key, s in fields.items()})
    dirty = computed(lambda: current.value != saved.value)
    interval_ok = computed(lambda: fields["interval"].value.isdigit() and 1 <= int(fields["interval"].value) <= 60)

    def load(values: dict) -> None:
        for key, value in values.items():
            fields[key].set(value)

    def save(_event):
        if interval_ok.value:
            saved.set(dict(current.value))
            status.set(f"Saved at {datetime.now():%H:%M:%S}.")

    def revert(_event):
        load(saved.value)
        status.set("Reverted to the last saved settings.")

    def defaults(_event):
        load(DEFAULTS)
        status.set("Defaults restored (not saved yet).")

    ui = UI(title="Settings", width=700, height=640, density="regular")
    with ui.column():
        with ui.row():
            ui.heading("Settings", level=1)
            ui.badge(lambda: "Unsaved changes" if dirty.value else "All changes saved")
        with ui.grid():
            with ui.card():
                ui.heading("Profile", level=3)
                ui.input(fields["display_name"], label="Display name", placeholder="Shown in the title bar")
                ui.select(fields["language"], LANGUAGES, label="Language")
            with ui.card():
                ui.heading("Editor", level=3)
                ui.select(fields["font_size"], FONT_SIZES, label="Font size")
                ui.checkbox(fields["autosave"], label="Save documents automatically")
                with ui.when(fields["autosave"]):
                    ui.input(fields["interval"], label="Autosave every (minutes)", kind="number")
                    with ui.when(lambda: not interval_ok.value):
                        ui.alert("Use a whole number of minutes from 1 to 60.")
            with ui.card():
                ui.heading("Privacy", level=3)
                ui.checkbox(fields["telemetry"], label="Send anonymous usage statistics")
                ui.text("Off by default. Nothing is sent by this example.", muted=True)
        with ui.row():
            ui.button("Save", on_click=save, disabled=lambda: not dirty.value or not interval_ok.value)
            ui.button("Revert", variant="secondary", on_click=revert, disabled=lambda: not dirty.value)
            ui.button("Restore defaults", variant="quiet", on_click=defaults)
        ui.text(status, muted=True)
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Settings") as application:
        main(application)
        application.run()
