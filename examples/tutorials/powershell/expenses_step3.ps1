# Expense tracker tutorial, step 3: categories, validated decimal amounts and a guarded button.
# Run:  pwsh -File ./expenses_step3.ps1   (docs/powershell/tutorials/expense-tracker.md)
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Expenses'

$categories = [ordered]@{ food = 'Food'; transport = 'Transport'; home = 'Home'; other = 'Other' }
$categoryOptions = @($categories.Keys | ForEach-Object { @{ Value = $_; Label = $categories[$_] } })
$s = @{
    Expenses = (New-NHKUiState -Value @()); Description = (New-NHKUiState -Value ''); Amount = (New-NHKUiState -Value '')
    Category = (New-NHKUiState -Value 'food'); Error = (New-NHKUiState -Value '')
    Categories = $categories; Culture = [Globalization.CultureInfo]::InvariantCulture
}
$s.Lines = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute {
    param($s)
    , @($s.Expenses.Value | ForEach-Object {
        '{0} ({1}): {2}' -f $_.Description, $s.Categories[$_.Category], $_.Amount.ToString('#,##0.00', $s.Culture) })
}
$s.NoExpenses = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute { param($s) @($s.Expenses.Value).Count -eq 0 }
$s.CannotAdd = New-NHKUiComputed -DependsOn @($s.Description, $s.Amount) -Data $s -Compute {
    param($s) (-not $s.Description.Value.Trim()) -or (-not $s.Amount.Value.Trim())
}
$computeds = @($s.Lines, $s.NoExpenses, $s.CannotAdd)

$ui = New-NHKUi -Title 'Expenses' -Width 760 -Height 640
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Expenses' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiInput -UI $ui -Bind $s.Description -Label 'Description' -Placeholder 'Coffee with Sam'
            $null = Add-NHKUiInput -UI $ui -Bind $s.Amount -Label 'Amount' -Placeholder '0.00'
            $null = Add-NHKUiSelect -UI $ui -Bind $s.Category -Label 'Category' -Options $categoryOptions
        }
        $null = Add-NHKUiWhen -UI $ui -Bind $s.Error -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.Error }
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiButton -UI $ui -Text 'Add expense' -DisabledState $s.CannotAdd -Data $s -OnClick {
                param($eventObject, $s)
                $value = [decimal]0
                $text = $s.Amount.Value.Trim().Replace(',', '.')
                if (-not [decimal]::TryParse($text, [Globalization.NumberStyles]::Number, $s.Culture, [ref]$value)) {
                    $s.Error.Set('Amount must be a number, for example 12.50'); return
                }
                if ($value -le 0) { $s.Error.Set('Amount must be greater than zero'); return }
                $new = [pscustomobject]@{ Description = $s.Description.Value.Trim(); Amount = [Math]::Round($value, 2); Category = $s.Category.Value }
                $s.Expenses.Set(@($s.Expenses.Value) + @($new))
                $s.Description.Set('')
                $s.Amount.Set('')
                $s.Error.Set('')
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
