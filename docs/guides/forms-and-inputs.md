# Forms, inputs and validation

**Goal:** bind inputs, checkboxes and selects to state, validate as the user types, and only
allow submitting a valid form.

## Two-way binding

| Control | Python | PowerShell | State holds |
|---|---|---|---|
| Text input | `ui.input(name, label="Name", kind="text")` | `Add-NHKUiInput -UI $ui -Bind $name -Label 'Name' -Type text` | `str` / `[string]` |
| Checkbox | `ui.checkbox(terms, label="I accept")` | `Add-NHKUiCheckbox -UI $ui -Bind $terms -Label 'I accept'` | `bool` |
| Select | `ui.select(plan, [("free", "Free"), ("team", "Team")], label="Plan")` | `Add-NHKUiSelect -UI $ui -Bind $plan -Label 'Plan' -Options @(@{Value='free';Label='Free'})` | option value string |

- Input kinds: `text`, `password`, `search`, `email`, `number`. A `number` input still gives a
  **string**; convert and validate it yourself.
- Each keystroke updates the state; there is no "on blur" mode.
- Setting the state from code updates the control (`description.set("")` clears the field
  after "Add"). Typing never triggers a write-back, so the caret and IME stay intact.
- The control must be bound to a real state (Python raises `TypeError` for a computed).

## Validation as derived state

Do not read values from the DOM. Compute the list of problems from the states
(`examples/*/signup_form.*`):

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

```powershell
$s.Errors = New-NHKUiComputed -DependsOn $fields -Data $s -Compute {
    param($s)
    $found = New-Object System.Collections.ArrayList
    if ($s.Email.Value -and $s.Email.Value.Trim() -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { [void]$found.Add('Enter a valid email address.') }
    if ($s.Confirm.Value -and $s.Confirm.Value -cne $s.Password.Value) { [void]$found.Add('Passwords do not match.') }
    , @($found)
}
$s.HasErrors = New-NHKUiComputed -DependsOn @($s.Errors) -Data $s -Compute { param($s) @($s.Errors.Value).Count -gt 0 }
$null = Add-NHKUiWhen -UI $ui -Bind $s.HasErrors -Content { $null = Add-NHKUiTextList -UI $ui -Bind $s.Errors }
$null = Add-NHKUiButton -UI $ui -Text 'Create account' -DisabledState $s.CannotSubmit -Data $s -OnClick { ... }
```

Patterns that make forms pleasant:

- **Only complain about fields the user touched.** Each rule starts with "if the field is not
  empty"; a separate muted hint says "Fill in every field" until the form is complete.
- **Disable, then re-check.** The submit handler checks `can_submit` again before acting.
- **Parse at the boundary.** The expense tracker keeps the amount as text in state and converts
  it with `Decimal` / `[decimal]::TryParse(..., InvariantCulture)` only when adding; an invalid
  amount sets an error state shown in an `alert` inside `when`.
- **Reset by setting states.** "Start over" sets every state back to its initial value; the
  controls follow.
- **Show results instead of the form.** Two `when` regions (form / confirmation) switch on a
  `welcome` state.

## Submitting with Enter (Python)

Python can register other event kinds with `ui.on(element, kind, callback)`, for example
`keydown` on an input. Do not register `input` or `change` on a bound control: it would
replace the binding's own handler. Keyboard handling beyond button activation was not part of
the 0.1.1 GUI qualification, so verify it in your target environment. PowerShell's UI module
has no keydown parameter; use buttons, or SDK events on `$ui.Document`.

## Native form features

The UI does not wrap `<form>`, HTML constraint validation (`required`, `pattern`) or
`form_data`. They are SDK document features (`Document.form_data`, `validity`,
`Get-NativeHTMLKitFormData`, `Submit-NativeHTMLKitForm`) for apps that build their own markup.
