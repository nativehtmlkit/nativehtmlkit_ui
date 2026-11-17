# Tutorial (Python): build a settings editor

*Python (`nativehtmlkit_ui` 0.1.1). The same tutorial for PowerShell:
[build a settings editor](../../powershell/tutorials/settings-editor.md).*

You will build **Settings editor**, a small editor for a JSON settings file: bound inputs, live
validation, an "Unsaved changes" badge, Save and Revert buttons, and a theme the app itself uses
on the next start.

**Time:** about 25 minutes. **You need:** `nativehtmlkit_ui` installed and the first window from
[getting started](../getting-started.md) working. Both steps are complete programs, verified by
the repository's example harness against the real NativeHTMLKit host:
[`examples/tutorials/python/settings_editor_step1.py`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/tutorials/python/settings_editor_step1.py)
and the final app [`examples/python/settings_editor.py`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/settings_editor.py).

## Step 1: a form bound to state

Create `settings_editor.py`:

```python
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
```

Run `uv run settings_editor.py` and edit the fields: the summary below follows every change.

- Each `state()` holds one setting. `ui.input(name, ...)` is two-way; `kind="email"` gives an
  e-mail field.
- `ui.select(theme, THEMES, ...)` takes `(value, text)` pairs; `ui.checkbox()` binds a `bool`.
- `computed(lambda: ...)` records which states it reads (all four here) and recomputes when any
  of them changes. You never list dependencies.
- The summary contains `<` and `>` around the e-mail address; `ui.text()` always escapes text,
  so this is safe.
- The inputs are inside a card, so they keep their natural height. Labelled inputs placed
  directly in a column need the column field-height workaround from the [layouts guide](../guides/layouts.md).

## Step 2: load, validate, save and revert

Replace the file with the final version:

```python
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
```

Run it with `uv run settings_editor.py` or with a file of your choice:
`uv run settings_editor.py ./my-settings.json`.

- Without an argument the file is `nativehtmlkit-settings.json` in your application-data folder
  (`%APPDATA%` on Windows, `$XDG_CONFIG_HOME` or `~/.config` on Linux). The PowerShell version of
  this tutorial uses the same folder and the same JSON keys, so both apps edit the same file.
- `read_settings()` starts from defaults and copies known keys from the file, so a partial or
  older file still works.
- `snapshot` is a computed dict of the values as they would be saved. Two computed values use it:
  `problem` (a validation message or `""`) and `changes`, which compares the snapshot with
  `saved`, the snapshot of the last save. Dicts compare by content, so `==` is enough.
- `with ui.when(problem):` shows the message only when there is one.
- **Save** refuses to write while there is a problem, writes a temporary file in the same folder
  and replaces the real one with `os.replace()`, then updates `saved`, so the badge returns to
  "All changes saved". Errors become a status message instead of a traceback.
- **Revert** reads the file again and sets every state; the bound inputs update themselves.
- `UI(theme=loaded["Theme"])`: the theme is chosen when the UI is built, so a changed theme
  applies on the next start.
- Everything runs inside `main()` because `Application.start()` runs the script a second time
  as the backend.

Try it: clear **Display name** (the message appears and Save refuses), type an e-mail without a
dot after the `@`, set the refresh interval to `2`. Fix everything, press **Save**, change a
field and press **Revert**.

## What you learned

| Concept | Where |
|---|---|
| Bind inputs, selects and checkboxes; derive a summary with `computed()` | Step 1 |
| Initial state from a file, computed validation and unsaved-changes tracking | Step 2 |
| Atomic save, revert from disk, theme chosen at start | Step 2 |

## Where next

- [Theming and custom CSS](../guides/theming-and-custom-css.md): what the saved theme changes.
- [Forms, inputs and validation](../guides/forms-and-inputs.md).
- Add "Save as..." with the SDK's save dialog: [mixing the UI with SDK calls](../guides/mixing-ui-and-sdk-calls.md).
- [Python API reference](../reference.md).
