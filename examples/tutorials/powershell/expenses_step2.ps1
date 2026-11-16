# Expense tracker tutorial, step 2: add expenses to a list state and remove the last one.
# Run:  pwsh -File ./expenses_step2.ps1   (docs/powershell/tutorials/expense-tracker.md)
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Expenses'

$s = @{ Expenses = (New-NHKUiState -Value @()); Description = (New-NHKUiState -Value ''); Amount = (New-NHKUiState -Value '') }
$s.Lines = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute {
    param($s) , @($s.Expenses.Value | ForEach-Object { '{0}: {1}' -f $_.Description, $_.Amount })
}
$s.NoExpenses = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute { param($s) @($s.Expenses.Value).Count -eq 0 }
$computeds = @($s.Lines, $s.NoExpenses)

$ui = New-NHKUi -Title 'Expenses' -Width 760 -Height 640
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Expenses' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiInput -UI $ui -Bind $s.Description -Label 'Description' -Placeholder 'Coffee with Sam'
            $null = Add-NHKUiInput -UI $ui -Bind $s.Amount -Label 'Amount' -Placeholder '0.00'
        }
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiButton -UI $ui -Text 'Add expense' -Data $s -OnClick {
                param($eventObject, $s)
                $new = [pscustomobject]@{ Description = $s.Description.Value.Trim(); Amount = $s.Amount.Value.Trim() }
                $s.Expenses.Set(@($s.Expenses.Value) + @($new))
                $s.Description.Set('')
                $s.Amount.Set('')
            }
            $null = Add-NHKUiButton -UI $ui -Text 'Remove last' -Variant secondary -DisabledState $s.NoExpenses -Data $s -OnClick {
                param($eventObject, $s)
                $items = @($s.Expenses.Value)
                $s.Expenses.Set(@($items | Select-Object -First ([Math]::Max(0, $items.Count - 1))))
            }
        }
    }
    $null = Add-NHKUiCard -UI $ui -Content { $null = Add-NHKUiTextList -UI $ui -Bind $s.Lines }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
