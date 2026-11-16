"""File inspector: pick files with the native open dialog and list their sizes and a total.

Teaches: an SDK dialog started without blocking the UI (window.open_files(wait=False) returns a
future), handing its result back with ui.post(), a busy flag that disables the button while the
dialog is open, cancel and error handling (dialogs are unavailable in headless test mode).

Run:  python file_picker.py      (pip install nativehtmlkit_ui)
"""
from pathlib import Path

from nativehtmlkit import RpcError
from nativehtmlkit_ui import UI, computed, state


def human(size: int) -> str:
    for unit in ("bytes", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size} {unit}" if unit == "bytes" else f"{size:.1f} {unit}"
        size /= 1024
    return str(size)


def main(app):
    files = state([])             # [(name, size_in_bytes)]
    busy = state(False)
    status = state("Choose one or more files to see their sizes.")
    total = computed(lambda: sum(size for _, size in files.value))

    def chosen(future) -> None:                  # posted to the UI owner
        busy.set(False)
        try:
            result = future.result()
        except RpcError as error:
            status.set(f"File dialogs are unavailable here: {error}")
            return
        if result.get("cancelled") or not result.get("paths"):
            status.set("No files chosen.")
            return
        rows = []
        for raw in result["paths"]:
            path = Path(raw)
            try:
                rows.append((path.name, path.stat().st_size))
            except OSError as error:
                rows.append((f"{path.name} (unreadable: {error.strerror})", 0))
        files.set(rows)
        status.set(f"{len(rows)} file(s) chosen.")

    def choose(_event):
        busy.set(True)
        future = ui.window.open_files(multiple=True, title="Choose files to inspect", wait=False)
        future.add_done_callback(lambda f: ui.post(chosen, f))

    ui = UI(title="File inspector", width=720, height=560)
    with ui.column():
        ui.heading("File inspector", level=1)
        with ui.row():
            ui.button(lambda: "Waiting for the dialog..." if busy.value else "Choose files...",
                      on_click=choose, disabled=busy)
            ui.button("Clear", variant="secondary", disabled=lambda: not files.value,
                      on_click=lambda _e: files.set([]))
        ui.text(status, muted=True)
        with ui.when(files):
            with ui.card():
                ui.heading(lambda: f"{len(files.value)} files, {human(total.value)} in total", level=3)
                ui.text_list(files, formatter=lambda row: f"{row[0]}: {human(row[1])}")
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="File inspector") as application:
        main(application)
        application.run()
