"""Task list with per-row Done/Remove buttons and an All/Open/Done filter.

Teaches: the "slot pool" pattern. The UI tree is fixed once mounted, so the app creates
MAX_TASKS rows up front and shows, hides and relabels them from state (ui.when + bound text +
bound button labels). Also: computed counts, a disabled Add button and "Clear done".

Run:  python todo.py      (pip install nativehtmlkit_ui)
"""
from itertools import count

from nativehtmlkit_ui import UI, computed, state

MAX_TASKS = 8


def main(app):
    next_id = count(1)
    tasks = state([])          # [{"id": 1, "title": "...", "done": False}, ...]
    title = state("")
    show = state("all")

    visible = computed(lambda: [t for t in tasks.value
                                if show.value == "all" or t["done"] == (show.value == "done")])
    open_count = computed(lambda: sum(not t["done"] for t in tasks.value))
    full = computed(lambda: len(tasks.value) >= MAX_TASKS)

    def task_at(row):
        rows = visible.value
        return rows[row] if row < len(rows) else None

    def add(_event):
        text = title.value.strip()
        if text and not full.value:
            tasks.set([*tasks.value, {"id": next(next_id), "title": text, "done": False}])
            title.set("")

    def toggle(row):
        task = task_at(row)
        if task:
            tasks.set([dict(t, done=not t["done"]) if t["id"] == task["id"] else t for t in tasks.value])

    def remove(row):
        task = task_at(row)
        if task:
            tasks.set([t for t in tasks.value if t["id"] != task["id"]])

    ui = UI(title="Tasks", width=640, height=620)
    with ui.column():
        ui.heading("Tasks", level=1)
        with ui.row():
            ui.input(title, label="New task", placeholder="Water the plants")
            ui.button("Add", on_click=add, disabled=lambda: full.value or not title.value.strip())
        with ui.when(full):
            ui.alert(f"The list is full ({MAX_TASKS} tasks). Remove or clear some first.")
        with ui.row():
            ui.select(show, [("all", "All"), ("open", "Open"), ("done", "Done")], label="Show")
            ui.badge(lambda: f"{open_count.value} open, {len(tasks.value) - open_count.value} done")
        with ui.card():
            with ui.when(lambda: not visible.value):
                ui.text("Nothing here.", muted=True)
            for row in range(MAX_TASKS):
                with ui.when(lambda row=row: task_at(row) is not None):
                    with ui.row():
                        ui.text(lambda row=row: ("[x] " if task_at(row)["done"] else "[ ] ") + task_at(row)["title"]
                                if task_at(row) else "")
                        ui.button(lambda row=row: "Reopen" if task_at(row) and task_at(row)["done"] else "Done",
                                  variant="secondary", on_click=lambda _e, row=row: toggle(row))
                        ui.button("Remove", variant="quiet", on_click=lambda _e, row=row: remove(row))
        ui.button("Clear done", variant="danger", disabled=lambda: open_count.value == len(tasks.value),
                  on_click=lambda _e: tasks.set([t for t in tasks.value if not t["done"]]))
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Tasks") as application:
        main(application)
        application.run()
