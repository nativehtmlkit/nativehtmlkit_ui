"""Expense tracker tutorial, step 2: add expenses to a list state and remove the last one.

Run:  python expenses_step2.py      (docs/tutorials/python-expense-tracker.md)
"""
from nativehtmlkit_ui import UI, state


def main(app):
    expenses = state([])
    description = state("")
    amount = state("")

    def add(_event):
        expenses.set([*expenses.value, {"description": description.value.strip(), "amount": amount.value.strip()}])
        description.set("")
        amount.set("")

    def remove_last(_event):
        expenses.set(expenses.value[:-1])

    ui = UI(title="Expenses", width=760, height=640)
    with ui.column():
        ui.heading("Expenses", level=1)
        with ui.card():
            with ui.row():
                ui.input(description, label="Description", placeholder="Coffee with Sam")
                ui.input(amount, label="Amount", placeholder="0.00")
            with ui.row():
                ui.button("Add expense", on_click=add)
                ui.button("Remove last", variant="secondary", on_click=remove_last,
                          disabled=lambda: not expenses.value)
        with ui.card():
            ui.text_list(expenses, formatter=lambda e: f"{e['description']}: {e['amount']}")
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Expenses") as application:
        main(application)
        application.run()
