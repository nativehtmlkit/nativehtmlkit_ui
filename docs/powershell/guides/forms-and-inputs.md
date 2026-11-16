# Forms, inputs and validation

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [forms and inputs](../../python/guides/forms-and-inputs.md).*

**Goal:** bind inputs, checkboxes and selects to state, validate as the user types, and only
allow submitting a valid form.

## Two-way binding

| Control | PowerShell | State holds |
|---|---|---|
| Text input | `Add-NHKUiInput -UI $ui -Bind $name -Label 'Name' -Type text` | `[string]` |
| Checkbox | `Add-NHKUiCheckbox -UI $ui -Bind $terms -Label 'I accept'` | `[bool]` |
| Select | `Add-NHKUiSelect -UI $ui -Bind $plan -Label 'Plan' -Options @(@{ Value = 'free'; Label = 'Free' }, @{ Value = 'team'; Label = 'Team' })` | the option value as `[string]` |

- Input types: `text`, `search`, `email`, `password`, `number`. A `number` input still gives a
  **string**; convert and validate it yourself.
- Each keystroke updates the state; there is no "on blur" mode.
- Setting the state from code updates the control (`$s.Description.Set('')` clears the field
  after "Add"). Typing never triggers a write-back, so the caret and IME stay intact.
- `-Options` is fixed at build time; build it from an ordered dictionary with
  `@($categories.Keys | ForEach-Object { @{ Value = $_; Label = $categories[$_] } })`.

## Validation as derived state

Do not read values from the DOM. Compute the problems from the states (the
[`signup_form` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/signup_form.ps1)):

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
$null = Add-NHKUiButton -UI $ui -Text 'Create account' -DisabledState $s.CannotSubmit -Data $s -OnClick { <# ... #> }
```

A single message works the same way (the [settings editor](../tutorials/settings-editor.md)):
`$problem` is a computed string that is `''` when everything is valid, `$hasProblem` a computed
boolean, and `Add-NHKUiWhen -Bind $hasProblem` shows the message only when there is one. Bind
`Add-NHKUiWhen` to a boolean: the string `'False'` is true in PowerShell.

## Patterns that make forms pleasant

- **Only complain about fields the user touched.** Each rule starts with "if the field is not
  empty"; a separate muted hint says "Fill in every field" until the form is complete.
- **Disable, then re-check.** The submit callback checks the condition again before acting.
- **Parse at the boundary.** The expense tracker keeps the amount as text in state and converts
  it with `[decimal]::TryParse(..., InvariantCulture, ...)` only when adding; an invalid amount
  sets an error state shown in an alert inside `Add-NHKUiWhen`.
- **Reset by setting states.** "Start over" sets every state back to its initial value; the
  controls follow.
- **Show results instead of the form.** Two `Add-NHKUiWhen` regions (form / confirmation) switch
  on a `Welcome` state.

## Loading and saving form data

Create the states from the loaded data, keep a text snapshot of the last saved values and
compare (the [settings-editor tutorial](../tutorials/settings-editor.md) builds this step by
step):

```powershell
$loaded = Read-Settings
$name = New-NHKUiState -Value ([string]$loaded.DisplayName)
...
$saved = New-NHKUiState -Value (ConvertTo-Json -InputObject (Get-Snapshot) -Compress)
$changes = New-NHKUiComputed -DependsOn $all -Compute {
    if ((ConvertTo-Json -InputObject (Get-Snapshot) -Compress) -eq $saved.Value) { 'All changes saved' } else { 'Unsaved changes' }
}
```

Write files atomically (a temporary file in the same folder, then `[IO.File]::Replace` or
`[IO.File]::Move`), so a crash never leaves half a settings file.
Build paths with `[IO.Path]::Combine` rather than `Join-Path`: on Windows the backend runs with
an extended-length working directory (`\\?\C:\...`), relative paths resolve to such paths, and
Windows PowerShell 5.1's `Join-Path` rejects them.

## Keyboard events

The module only has `-OnClick` for buttons; there is no keydown or submit parameter. Use
buttons, or register SDK document events on `$ui.Document` yourself
(`Register-NativeHTMLKitDocumentEvent`) for other event kinds, and do not register `input` or
`change` events for bound controls.

## Native form features

The UI does not wrap `<form>`, HTML constraint validation (`required`, `pattern`) or form data.
They are SDK document features (`Get-NativeHTMLKitFormData`, `Submit-NativeHTMLKitForm`) for apps
that build their own markup.

## Related

[PowerShell reference: controls](../reference.md#controls) ·
[lists and conditional content](lists-and-conditional-content.md) ·
[expense-tracker tutorial](../tutorials/expense-tracker.md)
