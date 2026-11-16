"""Sign-up form with live validation, a guarded submit button and a success screen.

Teaches: validation as a computed list of messages (no DOM reads), showing errors only for
fields the user has typed in, a submit button disabled until the form is valid, swapping the
form and a confirmation with ui.when(), and resetting every control by setting its state.

Run:  python signup_form.py      (pip install nativehtmlkit_ui)
"""
import re

from nativehtmlkit_ui import UI, computed, state

EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PLANS = [("free", "Free"), ("team", "Team"), ("enterprise", "Enterprise")]


def main(app):
    name, email, password, confirm, age = (state("") for _ in range(5))
    plan = state("free")
    terms = state(False)
    welcome = state("")                 # non-empty once the account was "created"

    def problems() -> list[str]:
        found = []
        if name.value and len(name.value.strip()) < 2:
            found.append("Name needs at least 2 characters.")
        if email.value and not EMAIL.match(email.value.strip()):
            found.append("Enter a valid email address.")
        if password.value and len(password.value) < 8:
            found.append("Password needs at least 8 characters.")
        if confirm.value and confirm.value != password.value:
            found.append("Passwords do not match.")
        if age.value and not (age.value.isdigit() and 16 <= int(age.value) <= 120):
            found.append("Age must be a whole number from 16 to 120.")
        return found

    errors = computed(problems)
    complete = computed(lambda: all(s.value for s in (name, email, password, confirm, age)) and terms.value)
    can_submit = computed(lambda: complete.value and not errors.value)

    def submit(_event):
        if can_submit.value:  # re-check: never trust that a disabled button cannot be activated
            welcome.set(f"Welcome, {name.value.strip()}! Your {dict(PLANS)[plan.value]} account is ready.")

    def start_over(_event):
        for field in (name, email, password, confirm, age, welcome):
            field.set("")
        plan.set("free")
        terms.set(False)

    ui = UI(title="Create account", width=620, height=700, theme="daylight", density="regular")
    with ui.column():
        ui.heading("Create your account", level=1)
        with ui.when(lambda: not welcome.value):
            with ui.card():
                with ui.column():
                    ui.input(name, label="Name", placeholder="Ada Lovelace")
                    ui.input(email, label="Email", kind="email", placeholder="ada@example.org")
                    with ui.row():
                        ui.input(password, label="Password", kind="password")
                        ui.input(confirm, label="Confirm password", kind="password")
                    with ui.row():
                        ui.input(age, label="Age", kind="number")
                        ui.select(plan, PLANS, label="Plan")
                    ui.checkbox(terms, label="I accept the terms of service")
                    with ui.when(errors):
                        ui.text_list(errors)
                    ui.text(lambda: "" if complete.value else "Fill in every field and accept the terms.",
                            muted=True)
                    ui.button("Create account", on_click=submit, disabled=lambda: not can_submit.value)
        with ui.when(welcome):
            with ui.card():
                ui.alert(welcome)
                ui.button("Start over", variant="secondary", on_click=start_over)
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Create account") as application:
        main(application)
        application.run()
