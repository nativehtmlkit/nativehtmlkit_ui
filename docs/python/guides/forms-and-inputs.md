# Forms, inputs and validation

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[forms and inputs](../../powershell/guides/forms-and-inputs.md).*

**Goal:** bind inputs, checkboxes and selects to state, validate as the user types, and only
allow submitting a valid form.

## Two-way binding

| Control | Python | State holds |
|---|---|---|
| Text input | `ui.input(name, label="Name", kind="text")` | `str` |
| Checkbox | `ui.checkbox(terms, label="I accept")` | `bool` |
| Select | `ui.select(plan, [("free", "Free"), ("team", "Team")], label="Plan")` | the option value as `str` |

- Input kinds: `text`, `password`, `search`, `email`, `number`. A `number` input still gives a
  **string**; convert and validate it yourself.
- Each keystroke updates the state; there is no "on blur" mode.
- Setting the state from code updates the control (`description.set("")` clears the field
  after "Add"). Typing never triggers a write-back, so the caret and IME stay intact.
- The control must be bound to a real `State` (a `Computed` raises `TypeError`).
- `choices` accepts any iterable of `(value, text)` pairs, for example `CATEGORIES.items()`.

## Validation as derived state

Do not read values from the DOM. Compute the problems from the states (the
[`signup_form` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/signup_form.py)):

```python
def problems():
    found = []
    if email.value and not EMAIL.match(email.value.strip()):
        found.append("Enter a valid email address.")
    if confirm.value and confirm.value != password.value:
        found.append("Passwords do not match.")
    if age.value and not (age.value.isdigit() and 16 <= int(age.value) <= 120):
        found.append("Age must be a whole number from 16 to 120.")
    return found

errors = computed(problems)
complete = computed(lambda: all(s.value for s in (name, email, password, confirm, age)) and terms.value)
can_submit = computed(lambda: complete.value and not errors.value)

with ui.when(errors):
    ui.text_list(errors)
ui.button("Create account", on_click=submit, disabled=lambda: not can_submit.value)
```

A single message works the same way (the [settings editor](../tutorials/settings-editor.md)):
`problem = computed(lambda: find_problem(snapshot.value))` returns `""` when everything is
valid, and `with ui.when(problem): ui.text(problem)` shows it only when there is one.

## Patterns that make forms pleasant

- **Only complain about fields the user touched.** Each rule starts with "if the field is not
  empty"; a separate muted hint says "Fill in every field" until the form is complete.
- **Disable, then re-check.** The submit handler checks `can_submit.value` again before acting.
- **Parse at the boundary.** The expense tracker keeps the amount as text in state and converts
  it with `Decimal` only when adding; an invalid amount sets an error state shown in an `alert`
  inside `when`.
- **Reset by setting states.** "Start over" sets every state back to its initial value; the
  controls follow.
- **Show results instead of the form.** Two `when` regions (form / confirmation) switch on a
  `welcome` state.

## Loading and saving form data

Create the states from the loaded data, keep a snapshot of the last saved values and compare
(the [settings-editor tutorial](../tutorials/settings-editor.md) builds this step by step):

```python
loaded = read_settings(path)
name = state(str(loaded["DisplayName"]))
...
snapshot = computed(lambda: {"DisplayName": name.value.strip(), ...})
saved = state(snapshot.value)
changes = computed(lambda: "All changes saved" if snapshot.value == saved.value else "Unsaved changes")
```

Write files atomically (a temporary file in the same folder, then `os.replace`), so a crash
never leaves half a settings file.

## Keyboard events

`ui.on(element, kind, callback)` registers other event kinds, for example `keydown` on an input
to submit with Enter. Do not register `input` or `change` on a bound control: it would replace
the binding's own handler. Keyboard handling beyond button activation was not part of the 0.1.1
GUI qualification, so verify it in your target environment.

## Native form features

The UI does not wrap `<form>`, HTML constraint validation (`required`, `pattern`) or form data.
They are SDK document features (`Document.form_data`, `validity`) for apps that build their own
markup.

## Related

[Python reference: controls](../reference.md#controls) ·
[lists and conditional content](lists-and-conditional-content.md) ·
[expense-tracker tutorial](../tutorials/expense-tracker.md)
