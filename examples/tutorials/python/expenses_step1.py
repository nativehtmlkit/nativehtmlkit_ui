"""Expense tracker tutorial, step 1: a window with two bound inputs and a live preview.

Run:  python expenses_step1.py      (docs/python/tutorials/expense-tracker.md)
"""
from nativehtmlkit_ui import UI, state


def main(app):
    description = state("")
    amount = state("")

    ui = UI(title="Expenses", width=760, height=640)
    with ui.column():
        ui.heading("Expenses", level=1)
        with ui.card():
            with ui.row():
                ui.input(description, label="Description", placeholder="Coffee with Sam")
                ui.input(amount, label="Amount", placeholder="0.00")
            ui.text(lambda: f"New expense: {description.value or '...'}, {amount.value or '0.00'}", muted=True)
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Expenses") as application:
        main(application)
        application.run()
