"""Expense tracker tutorial, step 3: categories, validated Decimal amounts and a guarded button.

Run:  python expenses_step3.py      (docs/python/tutorials/expense-tracker.md)
"""
from decimal import Decimal, InvalidOperation

from nativehtmlkit_ui import UI, computed, state

CATEGORIES = {"food": "Food", "transport": "Transport", "home": "Home", "other": "Other"}


def main(app):
    expenses = state([])
    description = state("")
    amount = state("")
    category = state("food")
    error = state("")
    cannot_add = computed(lambda: not description.value.strip() or not amount.value.strip())

    def add(_event):
        try:
            value = Decimal(amount.value.strip().replace(",", "."))
        except InvalidOperation:
            error.set("Amount must be a number, for example 12.50")
            return
        if value <= 0:
            error.set("Amount must be greater than zero")
            return
        expenses.set([*expenses.value, {"description": description.value.strip(),
                                        "amount": value.quantize(Decimal("0.01")),
                                        "category": category.value}])
        description.set("")
        amount.set("")
        error.set("")

    ui = UI(title="Expenses", width=760, height=640)
    with ui.column():
        ui.heading("Expenses", level=1)
        with ui.card():
            with ui.row():
                ui.input(description, label="Description", placeholder="Coffee with Sam")
                ui.input(amount, label="Amount", placeholder="0.00")
                ui.select(category, list(CATEGORIES.items()), label="Category")
            with ui.when(error):
                ui.alert(error)
            with ui.row():
                ui.button("Add expense", on_click=add, disabled=cannot_add)
                ui.button("Remove last", variant="secondary", on_click=lambda _e: expenses.set(expenses.value[:-1]),
                          disabled=lambda: not expenses.value)
        with ui.card():
            ui.text_list(expenses, formatter=lambda e: (
                f"{e['description']} ({CATEGORIES[e['category']]}): {e['amount']:,.2f}"))
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Expenses") as application:
        main(application)
        application.run()
