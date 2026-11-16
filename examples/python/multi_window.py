"""Notes editor with live inspector windows that share the editor's state.

Teaches: several UI objects in one application, each in its own native window; binding two
windows to the same State; opening a window from a button handler; tracking windows the user
closes with app.on_window_event (marshalled to the UI owner with ui.post); closing a window
from code. Each inspector is a new UI; mounting one registers an SDK shutdown callback, so this
example caps the number of inspectors (see the B-0003 limitation).

Run:  uv run multi_window.py      (uv add nativehtmlkit_ui)
"""
from nativehtmlkit_ui import UI, computed, state

MAX_INSPECTORS = 3


# Workaround for a UI 0.1.1 stylesheet defect: a field placed directly in a column gets a
# 200px flex basis (meant for rows) and therefore 200px of height. See docs/LIMITATIONS.md.
FIELD_FIX = ".nhk-col > .nhk-field { flex: 0 0 auto; }"

def main(app):
    note = state("")
    edits = state(0)
    open_inspectors = state(0)
    words = computed(lambda: len(note.value.split()))

    main_ui = UI(title="Notes", width=640, height=480, extra_css=FIELD_FIX)

    def changed() -> None:
        edits.set(edits.value + 1)
    note.subscribe(changed)          # runs on whichever thread set the note (here: the UI owner)

    def open_inspector(_event):
        if open_inspectors.value >= MAX_INSPECTORS:
            return
        number = open_inspectors.value + 1
        inspector = UI(title=f"Inspector {number}", width=420, height=320, theme="graphite")
        with inspector.column():
            inspector.heading(f"Inspector {number}", level=2)
            inspector.text(lambda: f"Note: {note.value}")
            inspector.text(lambda: f"{words.value} words, {len(note.value)} characters")
            inspector.badge(lambda: f"{edits.value} edits")
            inspector.button("Close inspector", variant="secondary",
                             on_click=lambda _e: inspector.window.request_close())
        inspector.mount(app)
        window_id = inspector.window.id
        open_inspectors.set(number)

        def on_window(event: dict) -> None:          # SDK event thread: hand over to the owner
            if event.get("window_id") == window_id and event.get("type") == "closed":
                unsubscribe()
                main_ui.post(lambda: open_inspectors.set(open_inspectors.value - 1))
        unsubscribe = app.on_window_event(on_window)

    with main_ui.column():
        main_ui.heading("Notes", level=1)
        main_ui.input(note, label="Shared note", placeholder="Type here and watch the inspectors")
        with main_ui.row():
            main_ui.button("Open inspector", on_click=open_inspector,
                           disabled=lambda: open_inspectors.value >= MAX_INSPECTORS)
            main_ui.badge(lambda: f"Inspectors open: {open_inspectors.value}")
        main_ui.text(lambda: f"{words.value} words", muted=True)
    main_ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Notes") as application:
        main(application)
        application.run()
