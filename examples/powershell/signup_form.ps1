# Sign-up form with live validation, a guarded submit button and a success screen.
#
# Teaches: validation as a computed array of messages (no DOM reads), messages only for fields
# the user has typed in, a submit button disabled until the form is valid, swapping the form
# and a confirmation with Add-NHKUiWhen, and resetting every control by setting its state.
#
# Run:  pwsh -File ./signup_form.ps1   |   powershell.exe -NoProfile -File .\signup_form.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Create account'

$plans = @(@{ Value = 'free'; Label = 'Free' }, @{ Value = 'team'; Label = 'Team' }, @{ Value = 'enterprise'; Label = 'Enterprise' })
$s = @{ Plans = $plans }
foreach ($name in @('Name', 'Email', 'Password', 'Confirm', 'Age', 'Welcome')) { $s[$name] = New-NHKUiState -Value '' }
$s.Plan = New-NHKUiState -Value 'free'
$s.Terms = New-NHKUiState -Value $false
$fields = @($s.Name, $s.Email, $s.Password, $s.Confirm, $s.Age)

$s.Errors = New-NHKUiComputed -DependsOn $fields -Data $s -Compute {
    param($s)
    $found = New-Object System.Collections.ArrayList
    if ($s.Name.Value -and $s.Name.Value.Trim().Length -lt 2) { [void]$found.Add('Name needs at least 2 characters.') }
    if ($s.Email.Value -and $s.Email.Value.Trim() -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { [void]$found.Add('Enter a valid email address.') }
    if ($s.Password.Value -and $s.Password.Value.Length -lt 8) { [void]$found.Add('Password needs at least 8 characters.') }
    if ($s.Confirm.Value -and $s.Confirm.Value -cne $s.Password.Value) { [void]$found.Add('Passwords do not match.') }
    if ($s.Age.Value -and -not ($s.Age.Value -match '^\d{1,3}$' -and [int]$s.Age.Value -ge 16 -and [int]$s.Age.Value -le 120)) {
        [void]$found.Add('Age must be a whole number from 16 to 120.')
    }
    , @($found)
}
$s.HasErrors = New-NHKUiComputed -DependsOn @($s.Errors) -Data $s -Compute { param($s) @($s.Errors.Value).Count -gt 0 }
$s.Complete = New-NHKUiComputed -DependsOn ($fields + @($s.Terms)) -Data $s -Compute {
    param($s) (@($s.Name, $s.Email, $s.Password, $s.Confirm, $s.Age | Where-Object { -not $_.Value }).Count -eq 0) -and [bool]$s.Terms.Value
}
$s.CannotSubmit = New-NHKUiComputed -DependsOn @($s.Complete, $s.HasErrors) -Data $s -Compute {
    param($s) (-not $s.Complete.Value) -or $s.HasErrors.Value
}
$s.Hint = New-NHKUiComputed -DependsOn @($s.Complete) -Data $s -Compute {
    param($s) if ($s.Complete.Value) { '' } else { 'Fill in every field and accept the terms.' }
}
$s.FormVisible = New-NHKUiComputed -DependsOn @($s.Welcome) -Data $s -Compute { param($s) -not $s.Welcome.Value }
$computeds = @($s.Errors, $s.HasErrors, $s.Complete, $s.CannotSubmit, $s.Hint, $s.FormVisible)

# Workaround for a UI 0.1.1 stylesheet defect: a field placed directly in a column gets a
# 200px flex basis (meant for rows) and therefore 200px of height. See docs/LIMITATIONS.md.
$fieldFix = '.nhk-col > .nhk-field { flex: 0 0 auto; }'
$ui = New-NHKUi -Title 'Create account' -Width 620 -Height 700 -Theme daylight -Density regular -ExtraCss $fieldFix
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Create your account' -Level 1
    $null = Add-NHKUiWhen -UI $ui -Bind $s.FormVisible -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiColumn -UI $ui -Content {
                $null = Add-NHKUiInput -UI $ui -Bind $s.Name -Label 'Name' -Placeholder 'Ada Lovelace'
                $null = Add-NHKUiInput -UI $ui -Bind $s.Email -Label 'Email' -Type email -Placeholder 'ada@example.org'
                $null = Add-NHKUiRow -UI $ui -Content {
                    $null = Add-NHKUiInput -UI $ui -Bind $s.Password -Label 'Password' -Type password
                    $null = Add-NHKUiInput -UI $ui -Bind $s.Confirm -Label 'Confirm password' -Type password
                }
                $null = Add-NHKUiRow -UI $ui -Content {
                    $null = Add-NHKUiInput -UI $ui -Bind $s.Age -Label 'Age' -Type number
                    $null = Add-NHKUiSelect -UI $ui -Bind $s.Plan -Label 'Plan' -Options $s.Plans
                }
                $null = Add-NHKUiCheckbox -UI $ui -Bind $s.Terms -Label 'I accept the terms of service'
                $null = Add-NHKUiWhen -UI $ui -Bind $s.HasErrors -Content { $null = Add-NHKUiTextList -UI $ui -Bind $s.Errors }
                $null = Add-NHKUiText -UI $ui -Bind $s.Hint -Muted
                $null = Add-NHKUiButton -UI $ui -Text 'Create account' -DisabledState $s.CannotSubmit -Data $s -OnClick {
                    param($eventObject, $s)
                    if ($s.CannotSubmit.Value) { return }   # never trust that a disabled button cannot be activated
                    $plan = ($s.Plans | Where-Object { $_.Value -eq $s.Plan.Value }).Label
                    $s.Welcome.Set("Welcome, $($s.Name.Value.Trim())! Your $plan account is ready.")
                }
            }
        }
    }
    $null = Add-NHKUiWhen -UI $ui -Bind $s.Welcome -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiAlert -UI $ui -Bind $s.Welcome
            $null = Add-NHKUiButton -UI $ui -Text 'Start over' -Variant secondary -Data $s -OnClick {
                param($eventObject, $s)
                foreach ($name in @('Name', 'Email', 'Password', 'Confirm', 'Age', 'Welcome')) { $s[$name].Set('') }
                $s.Plan.Set('free')
                $s.Terms.Set($false)
            }
        }
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
