"""System dashboard: a responsive card grid with a live clock and disk usage, themed via CSS.

Teaches: ui.grid() (3 columns, 2 below 1000 px, 1 below 620 px), theme and density options,
extra_css with your own classes and token overrides, ui.element() for a custom-styled tag, and
a periodic timer thread that updates state through ui.post().

Run:  uv run dashboard.py [cobalt|graphite|daylight]      (uv add nativehtmlkit_ui)
"""
import os
import platform
import shutil
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

from nativehtmlkit_ui import UI, state

THEMES = ("cobalt", "graphite", "daylight")
CSS = """
.metric { font-size: 30px; font-weight: 700; letter-spacing: -0.02em; margin: 4px 0; }
.meter { height: 8px; border-radius: 99px; background: var(--nhk-panel-2); border: 1px solid var(--nhk-border); }
.nhk-card { border-top: 3px solid var(--nhk-accent); }
body.nhk-theme-daylight { --nhk-accent: #0f7b6c; --nhk-accent-strong: #0b6458; --nhk-focus: #0f7b6c; }
"""


def disk_text(path: Path) -> tuple[str, str]:
    usage = shutil.disk_usage(path)
    used = usage.used / usage.total * 100
    return f"{used:.0f} % used", f"{usage.free / 1024**3:.1f} GB free of {usage.total / 1024**3:.0f} GB"


def main(app):
    theme = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in THEMES else "cobalt"
    started = time.monotonic()
    clock = state("--:--:--")
    uptime = state("0 s")
    disk, disk_detail = state(""), state("")
    refreshed = state(0)

    def refresh() -> None:                        # runs on the UI owner (posted)
        clock.set(f"{datetime.now():%H:%M:%S}")
        seconds = int(time.monotonic() - started)
        uptime.set(f"{seconds // 60} min {seconds % 60} s" if seconds >= 60 else f"{seconds} s")
        used, detail = disk_text(Path.home())
        disk.set(used)
        disk_detail.set(detail)

    ui = UI(title="Dashboard", width=980, height=640, theme=theme, density="regular", extra_css=CSS)
    with ui.column():
        with ui.row():
            ui.heading("System dashboard", level=1)
            ui.badge(f"theme: {theme}")
        with ui.grid():
            with ui.card():
                ui.text("Local time", muted=True)
                ui.element("div", css_class="metric", text=clock)
            with ui.card():
                ui.text("Dashboard uptime", muted=True)
                ui.element("div", css_class="metric", text=uptime)
            with ui.card():
                ui.text("Home drive", muted=True)
                ui.element("div", css_class="metric", text=disk)
                ui.text(disk_detail, muted=True)
            with ui.card():
                ui.text("Processors", muted=True)
                ui.element("div", css_class="metric", text=str(os.cpu_count() or "?"))
            with ui.card():
                ui.text("Platform", muted=True)
                ui.element("div", css_class="metric", text=platform.system())
                ui.text(f"Python {platform.python_version()}", muted=True)
            with ui.card():
                ui.text("Manual refreshes", muted=True)
                ui.element("div", css_class="metric", text=refreshed)
                ui.button("Refresh now", variant="secondary",
                          on_click=lambda _e: (refresh(), refreshed.set(refreshed.value + 1)))
        ui.text("Resize the window: the grid uses 3, 2 or 1 columns.", muted=True)

    stop = threading.Event()

    def tick() -> None:
        while not stop.wait(1.0):
            try:
                ui.post(refresh)
            except RuntimeError:
                pass

    ui.mount(app)
    ui.post(refresh)
    threading.Thread(target=tick, name="dashboard-timer", daemon=True).start()
    app.on_shutdown(stop.set)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Dashboard") as application:
        main(application)
        application.run()
