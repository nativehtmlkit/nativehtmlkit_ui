# Tutorial (Python): build an expense tracker

In about 30 minutes you build a small native desktop app with `nativehtmlkit_ui`: enter
expenses, validate amounts, remove the last entry, filter by category and see totals that
update by themselves. Along the way you learn the library's whole model: **state, components
bound to state, event handlers that change state, and computed values**.

Every step is a complete program in [`code/python/`](code/python/) and the finished app is
[`examples/python/expenses.py`](../../examples/python/expenses.py). All of them are run by the
repository's example harness against the real NativeHTMLKit host.

The PowerShell version of this tutorial is [here](powershell-expense-tracker.md).

## Step 0: install and check

You need Python 3.10+ on Linux (KDE Plasma Wayland is the primary desktop) or Windows.

```bash
python -m venv .venv
. .venv/bin/activate            # Windows: .venv\Scripts\activate
python -m pip install nativehtmlkit_ui     # also installs the nativehtmlkit SDK with its native host
python -c "import nativehtmlkit_ui; print(nativehtmlkit_ui.__version__)"    # 0.1.1
```

## Step 1: a window with bound inputs

Create `expenses.py`:

```python
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
```

Run it with `python expenses.py` and type into both fields: the preview line follows every
keystroke.

What happened:

- `state("")` creates an observable value. `ui.input(description, ...)` binds it **two ways**:
  typing sets the state, and setting the state changes the field.
- `ui.text(lambda: ...)` is bound to an expression. The library records which states the
  lambda read (`description`, `amount`) and re-evaluates it when one of them changes.
- `with ui.column():`, `ui.card()` and `ui.row()` arrange components; the
  [layout guide](../guides/layouts.md) explains them.
- `ui.mount(app)` opens the window. You build the whole tree **before** mounting; afterwards
  you only change state.
- `Application.start()` starts the native host, which runs this same script again as its
  backend. That is why all work happens inside `main()` behind
  `if __name__ == "__main__":`; code at module level would run twice.

(Complete file: [`code/python/expenses_step1.py`](code/python/expenses_step1.py).)

## Step 2: a list of expenses

Add a list state, an **Add expense** button and a list. Replace the body of `main` with:

```python
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
```

New ideas:

- **Handlers change state, nothing else.** `add()` never touches the window. Setting
  `description` and `amount` to `""` clears the two fields because they are bound.
- **Replace, do not mutate.** `expenses.set([*expenses.value, item])` builds a new list.
  `expenses.value.append(item)` would change the list without telling anyone.
- `disabled=lambda: not expenses.value` keeps **Remove last** disabled while the list is empty.
- `ui.text_list(...)` shows one escaped line per item; `formatter` turns an item into text.
- Handlers run on the UI's own thread, one at a time; all state changes made in one handler
  reach the window as one update.

(Complete file: [`code/python/expenses_step2.py`](code/python/expenses_step2.py).)

## Step 3: categories and validation

Amounts should be numbers, and an empty form should not be addable. Add a category select, an
error state shown in an alert, and a computed value that disables the button:

```python
from decimal import Decimal, InvalidOperation

from nativehtmlkit_ui import UI, computed, state

CATEGORIES = {"food": "Food", "transport": "Transport", "home": "Home", "other": "Other"}
```

```python
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
```

and in the form card:

```python
            with ui.row():
                ui.input(description, label="Description", placeholder="Coffee with Sam")
                ui.input(amount, label="Amount", placeholder="0.00")
                ui.select(category, list(CATEGORIES.items()), label="Category")
            with ui.when(error):
                ui.alert(error)
            with ui.row():
                ui.button("Add expense", on_click=add, disabled=cannot_add)
```

with the list formatter
`lambda e: f"{e['description']} ({CATEGORIES[e['category']]}): {e['amount']:,.2f}"`.

New ideas:

- `computed(fn)` is a named derived value. Like a bound lambda it tracks what it reads; unlike a
  lambda it can be shared and read from handlers (`cannot_add.value`).
- `ui.select(state, [(value, text), ...])` binds the selected option value.
- `with ui.when(error):` shows its content only while `error` is non-empty. The region always
  exists and is only hidden, so nothing is rebuilt.
- Money uses `Decimal`, never `float`. Input fields always deliver strings; convert them where
  you use them and report problems through state.

Try it: type `three` as amount and press **Add expense**; the alert appears. Fix it and the
alert disappears. (Complete file: [`code/python/expenses_step3.py`](code/python/expenses_step3.py).)

## Step 4: filter and totals

The finished app adds a second card with a **Show** filter, a badge, a total heading and a
per-category summary, all derived from the same two states. With a module-level helper
`def money(value: Decimal) -> str: return f"{value:,.2f}"`:

```python
    show = state("all")

    visible = computed(lambda: [e for e in expenses.value if show.value in ("all", e["category"])])
    total = computed(lambda: sum((e["amount"] for e in visible.value), Decimal("0")))
    by_category = computed(lambda: [
        f"{label}: {money(sum((e['amount'] for e in expenses.value if e['category'] == key), Decimal('0')))}"
        for key, label in CATEGORIES.items() if any(e["category"] == key for e in expenses.value)])
```

```python
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
```

Computed values can depend on other computed values (`total` reads `visible`). Change the
filter and the list, badge, total and empty-state message all update together, in one window
update, without a single line of update code.

The complete program is [`examples/python/expenses.py`](../../examples/python/expenses.py).

## What you learned

| Concept | Where |
|---|---|
| State and two-way inputs | Step 1 |
| Handlers change state; replace lists instead of mutating | Step 2 |
| Computed values, select, conditional regions, validation | Step 3 |
| Computed values built on computed values | Step 4 |

Next:

- [How-to guides](../guides/README.md): background work, multiple windows, theming, SDK calls.
- [Python API reference](../reference/python.md).
- More apps in [`examples/`](../../examples/README.md): a task list with per-row buttons, a
  sign-up form, a settings panel, a live log viewer.
- [How it works](../ARCHITECTURE.md).
