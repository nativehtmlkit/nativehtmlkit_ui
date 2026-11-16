"""Expense tracker: add expenses, remove the last one, filter by category, see totals.

Teaches: state + computed values, two-way input/select binding, a disabled button driven by a
computed value, a filtered text list, an empty-state region with ui.when(), and Decimal input
validation. This is the finished app of docs/python/tutorials/expense-tracker.md.

Run:  python expenses.py      (pip install nativehtmlkit_ui)
"""
from decimal import Decimal, InvalidOperation

from nativehtmlkit_ui import UI, computed, state

CATEGORIES = {"food": "Food", "transport": "Transport", "home": "Home", "other": "Other"}


def money(value: Decimal) -> str:
    return f"{value:,.2f}"


def main(app):
    expenses = state([])                 # list of dicts; always replaced, never mutated in place
    description = state("")
    amount = state("")
    category = state("food")
    show = state("all")
    error = state("")

    visible = computed(lambda: [e for e in expenses.value if show.value in ("all", e["category"])])
    total = computed(lambda: sum((e["amount"] for e in visible.value), Decimal("0")))
    by_category = computed(lambda: [
        f"{label}: {money(sum((e['amount'] for e in expenses.value if e['category'] == key), Decimal('0')))}"
        for key, label in CATEGORIES.items() if any(e["category"] == key for e in expenses.value)])
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
        description.set("")          # writes back into the native inputs
        amount.set("")
        error.set("")

    def remove_last(_event):
        expenses.set(expenses.value[:-1])

    ui = UI(title="Expenses", width=760, height=640)
    with ui.column():
        ui.heading("Expenses", level=1)
        with ui.card():
            ui.heading("New expense", level=3)
            with ui.row():
                ui.input(description, label="Description", placeholder="Coffee with Sam")
                ui.input(amount, label="Amount", placeholder="0.00")
                ui.select(category, list(CATEGORIES.items()), label="Category")
            with ui.when(error):
                ui.alert(error)
            with ui.row():
                ui.button("Add expense", on_click=add, disabled=cannot_add)
                ui.button("Remove last", variant="secondary", on_click=remove_last,
                          disabled=lambda: not expenses.value)
        with ui.card():
            with ui.row():
                ui.select(show, [("all", "All categories"), *CATEGORIES.items()], label="Show")
                ui.badge(lambda: f"{len(visible.value)} of {len(expenses.value)} expenses")
            ui.heading(lambda: f"Total: {money(total.value)}", level=2)
            with ui.when(lambda: not visible.value):
                ui.text("No expenses to show yet.", muted=True)
            ui.text_list(visible, formatter=lambda e: (
                f"{e['description']} ({CATEGORIES[e['category']]}): {money(e['amount'])}"))
            ui.text(lambda: " | ".join(by_category.value), muted=True)
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Expenses") as application:
        main(application)
        application.run()
