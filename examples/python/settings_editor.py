"""Settings editor: edit, validate and save a JSON settings file (settings-editor tutorial, final code).

Teaches: loading initial state from a file, a computed validation message and an "unsaved
changes" badge, buttons that save (atomically) and revert, a status alert, and starting the UI
in the theme the user saved.
Run:     uv run settings_editor.py [PATH]
         (default file: nativehtmlkit-settings.json in your application-data folder:
         %APPDATA% on Windows, $XDG_CONFIG_HOME or ~/.config on Linux)
Guide:   docs/python/tutorials/settings-editor.md (step 2 of 2)
"""
import json
import os
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from nativehtmlkit import Application
from nativehtmlkit_ui import UI, computed, state

DEFAULTS = {"DisplayName": "", "Email": "", "Theme": "cobalt", "RefreshSeconds": 60, "Notifications": False}
THEMES = [("cobalt", "Cobalt"), ("graphite", "Graphite"), ("daylight", "Daylight")]
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def default_path() -> Path:
    if os.name == "nt":
        base = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming")
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return base / "nativehtmlkit-settings.json"


def read_settings(path: Path) -> dict:
    """Start from the defaults and copy known keys, so a partial or older file still works."""
    result = dict(DEFAULTS)
    if path.is_file():
        data = json.loads(path.read_text(encoding="utf-8"))
        result.update({key: data[key] for key in DEFAULTS if key in data})
    if result["Theme"] not in dict(THEMES):
        result["Theme"] = "cobalt"
    return result


def write_settings(path: Path, values: dict) -> None:
    """Write a temporary file next to the target and replace the target with it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".settings-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(values, stream, indent=2)
        os.replace(temporary, path)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def main():
    with Application.start(name="Settings editor") as app:
        path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else default_path()
        loaded = read_settings(path)

        name = state(str(loaded["DisplayName"]))
        email = state(str(loaded["Email"]))
        theme = state(str(loaded["Theme"]))
        interval = state(str(loaded["RefreshSeconds"]))
        notify = state(bool(loaded["Notifications"]))
        status = state(f"Editing {path}")

        # The values as they would be saved; also used to detect unsaved changes.
        snapshot = computed(lambda: {"DisplayName": name.value.strip(), "Email": email.value.strip(),
                                     "Theme": theme.value, "RefreshSeconds": interval.value.strip(),
                                     "Notifications": notify.value})
        saved = state(snapshot.value)

        def find_problem(values):
            seconds = values["RefreshSeconds"]
            if not values["DisplayName"]:
                return "Enter a display name."
            if not EMAIL.match(values["Email"]):
                return "The e-mail address looks invalid."
            if not (seconds.isdigit() and 5 <= int(seconds) <= 3600):
                return "Refresh interval must be a whole number from 5 to 3600."
            return ""

        problem = computed(lambda: find_problem(snapshot.value))
        changes = computed(lambda: "All changes saved" if snapshot.value == saved.value else "Unsaved changes")

        def save(_event):
            if problem.value:
                status.set("Fix the problem above before saving.")
                return
            values = dict(snapshot.value, RefreshSeconds=int(snapshot.value["RefreshSeconds"]))
            try:
                write_settings(path, values)
            except OSError as error:
                status.set(f"Could not save: {error.strerror or error}")
                return
            saved.set(snapshot.value)
            status.set(f"Saved {datetime.now():%H:%M:%S}")

        def revert(_event):
            try:
                fresh = read_settings(path)
            except (OSError, ValueError) as error:
                status.set(f"Could not read the file: {error}")
                return
            name.set(str(fresh["DisplayName"]))
            email.set(str(fresh["Email"]))
            theme.set(str(fresh["Theme"]))
            interval.set(str(fresh["RefreshSeconds"]))
            notify.set(bool(fresh["Notifications"]))
            status.set("Reverted to the saved file")

        ui = UI(title="Settings editor", theme=loaded["Theme"], density="regular", width=600, height=640)
        with ui.column():
            with ui.row():
                ui.heading("Settings", level=1)
                ui.badge(changes)
            with ui.card():
                ui.input(name, label="Display name")
                ui.input(email, label="E-mail", kind="email")
                ui.input(interval, label="Refresh interval (seconds)", kind="number")
                ui.select(theme, THEMES, label="Theme (applies on next start)")
                ui.checkbox(notify, label="Send me e-mail notifications")
            with ui.when(problem):
                ui.text(problem)
            with ui.row():
                ui.button("Save", on_click=save)
                ui.button("Revert", variant="secondary", on_click=revert)
            ui.alert(status)
        try:
            ui.mount(app)
            app.run()
        finally:
            ui.dispose()


if __name__ == "__main__":
    main()
