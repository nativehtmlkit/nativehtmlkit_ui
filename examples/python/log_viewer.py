"""Live log viewer: a background producer streams lines; filter by level and text, pause, clear.

Teaches: a worker thread that hands every result to the UI owner with ui.post(), bounded
history, a computed filtered view rendered with text_list (all text is escaped), counters,
pausing without losing lines, and stopping the worker from app.on_shutdown().

Run:  python log_viewer.py      (pip install nativehtmlkit_ui)
"""
import threading
from datetime import datetime

from nativehtmlkit_ui import UI, computed, state

KEEP = 500           # lines kept in memory
SHOW = 14            # newest matching lines shown
MESSAGES = ["request served in 12 ms", "cache refreshed", "user signed in", "slow query (420 ms)",
            "disk space below 15 %", "retrying upstream connection", "job finished", "config reloaded"]


def level_for(n: int) -> str:
    return "ERROR" if n % 11 == 0 else "WARN" if n % 4 == 0 else "INFO"


def main(app):
    lines = state([])            # newest last; each line is (level, text)
    paused = state(False)
    held = state([])             # lines that arrived while paused
    level = state("all")
    search = state("")

    def matches(lvl: str, text: str) -> bool:
        return (level.value == "all" or lvl == level.value) and search.value.lower() in text.lower()

    shown = computed(lambda: [text for lvl, text in lines.value if matches(lvl, text)][-SHOW:][::-1])
    errors = computed(lambda: sum(1 for lvl, _ in lines.value if lvl == "ERROR"))

    def receive(entry) -> None:                      # runs on the UI owner (posted)
        if paused.value:
            held.set([*held.value, entry][-KEEP:])
        else:
            lines.set([*lines.value, entry][-KEEP:])

    def toggle_pause(_event):
        if paused.value:
            lines.set([*lines.value, *held.value][-KEEP:])
            held.set([])
        paused.set(not paused.value)

    ui = UI(title="Log viewer", width=820, height=620)
    with ui.column():
        with ui.row():
            ui.heading("Service log", level=1)
            ui.badge(lambda: f"{len(lines.value)} lines")
            ui.badge(lambda: f"{errors.value} errors")
        with ui.row():
            ui.select(level, [("all", "All levels"), ("INFO", "Info"), ("WARN", "Warnings"), ("ERROR", "Errors")],
                      label="Level")
            ui.input(search, label="Contains", kind="search", placeholder="Filter text")
            ui.button(lambda: "Resume" if paused.value else "Pause", variant="secondary", on_click=toggle_pause)
            ui.button("Clear", variant="quiet", on_click=lambda _e: lines.set([]))
        with ui.when(paused):
            ui.alert(lambda: f"Paused: {len(held.value)} new lines are waiting.")
        with ui.card():
            with ui.when(lambda: not shown.value):
                ui.text("No matching lines.", muted=True)
            ui.text_list(shown)

    stop = threading.Event()

    def produce() -> None:                           # worker thread: never touches the UI directly
        n = 0
        while not stop.wait(0.2):
            n += 1
            lvl = level_for(n)
            text = f"#{n:05d} {datetime.now():%H:%M:%S} {lvl:<5} {MESSAGES[n % len(MESSAGES)]}"
            try:
                ui.post(receive, (lvl, text))
            except RuntimeError:                     # queue full: skip a line rather than block
                pass

    ui.mount(app)
    worker = threading.Thread(target=produce, name="log-producer", daemon=True)
    worker.start()
    app.on_shutdown(stop.set)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Log viewer") as application:
        main(application)
        application.run()
