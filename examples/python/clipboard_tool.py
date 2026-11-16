"""Text transformer with copy/paste: mixes UI state with direct SDK clipboard calls.

Teaches: calling public SDK services (app.set_clipboard_text / app.clipboard_text) from a UI
event handler, reporting SDK errors in the UI instead of crashing (the clipboard is
unavailable in headless test mode, error -32001), and a computed live preview.

Run:  uv run clipboard_tool.py      (uv add nativehtmlkit_ui)
"""
import re

from nativehtmlkit import RpcError
from nativehtmlkit_ui import UI, computed, state

TRANSFORMS = {
    "upper": ("UPPER CASE", str.upper),
    "lower": ("lower case", str.lower),
    "title": ("Title Case", str.title),
    "slug": ("slug-for-urls", lambda s: re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")),
    "squash": ("Collapse whitespace", lambda s: " ".join(s.split())),
    "reverse": ("Reverse word order", lambda s: " ".join(reversed(s.split()))),
}


def main(app):
    source = state("")
    mode = state("title")
    status = state("")

    result = computed(lambda: TRANSFORMS[mode.value][1](source.value))

    def copy(_event):
        try:
            app.set_clipboard_text(result.value)
            status.set(f"Copied {len(result.value)} characters to the clipboard.")
        except RpcError as error:
            status.set(f"Clipboard unavailable: {error}")

    def paste(_event):
        try:
            source.set(app.clipboard_text())
            status.set("Pasted from the clipboard.")
        except RpcError as error:
            status.set(f"Clipboard unavailable: {error}")

    ui = UI(title="Clipboard tool", width=680, height=520)
    with ui.column():
        ui.heading("Clipboard text tool", level=1)
        with ui.card():
            ui.input(source, label="Text", placeholder="Paste or type something")
            ui.select(mode, [(key, label) for key, (label, _) in TRANSFORMS.items()], label="Transform")
            with ui.row():
                ui.button("Paste", variant="secondary", on_click=paste)
                ui.button("Copy result", on_click=copy, disabled=lambda: not result.value)
        with ui.card():
            ui.heading("Result", level=3)
            ui.text(lambda: result.value or "(empty)")
            ui.text(lambda: f"{len(result.value)} characters", muted=True)
        with ui.when(status):
            ui.alert(status)
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Clipboard tool") as application:
        main(application)
        application.run()
