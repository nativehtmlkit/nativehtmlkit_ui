# Expense tracker: add expenses, remove the last one, filter by category, see totals.
#
# Teaches: states and computed values with explicit -DependsOn, two-way input/select binding,
# a button disabled by a computed value, a filtered text list, an empty-state region with
# Add-NHKUiWhen, and culture-independent decimal parsing. This is the finished app of
# docs/tutorials/powershell-expense-tracker.md.
#
# Run:  pwsh -File ./expenses.ps1                      (PowerShell 7.2+, Linux or Windows)
#       powershell.exe -NoProfile -File .\expenses.ps1  (Windows PowerShell 5.1)
# Needs: Install-Module NativeHTMLKit.UI -Scope CurrentUser
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Expenses'

$categories = [ordered]@{ food = 'Food'; transport = 'Transport'; home = 'Home'; other = 'Other' }
$categoryOptions = @($categories.Keys | ForEach-Object { @{ Value = $_; Label = $categories[$_] } })

# One hashtable holds every state; it is passed to callbacks and computed values as -Data.
$s = @{
    Expenses = (New-NHKUiState -Value @())    # array of objects; always replaced, never changed in place
    Description = (New-NHKUiState -Value ''); Amount = (New-NHKUiState -Value '')
    Category = (New-NHKUiState -Value 'food'); Show = (New-NHKUiState -Value 'all')
    Error = (New-NHKUiState -Value ''); Categories = $categories
    Culture = [Globalization.CultureInfo]::InvariantCulture
}
$s.Visible = New-NHKUiComputed -DependsOn @($s.Expenses, $s.Show) -Data $s -Compute {
    param($s)
    # The leading comma returns the array itself, even when it has zero or one element.
    , @($s.Expenses.Value | Where-Object { $s.Show.Value -eq 'all' -or $_.Category -eq $s.Show.Value })
}
$s.Total = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute {
    param($s)
    $sum = [decimal]0
    foreach ($e in $s.Visible.Value) { $sum += $e.Amount }
    'Total: ' + $sum.ToString('#,##0.00', $s.Culture)
}
$s.Lines = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute {
    param($s)
    , @($s.Visible.Value | ForEach-Object {
        '{0} ({1}): {2}' -f $_.Description, $s.Categories[$_.Category], $_.Amount.ToString('#,##0.00', $s.Culture) })
}
$s.Count = New-NHKUiComputed -DependsOn @($s.Visible, $s.Expenses) -Data $s -Compute {
    param($s) '{0} of {1} expenses' -f @($s.Visible.Value).Count, @($s.Expenses.Value).Count
}
$s.ByCategory = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute {
    param($s)
    $parts = foreach ($key in $s.Categories.Keys) {
        $items = @($s.Expenses.Value | Where-Object { $_.Category -eq $key })
        if ($items.Count -gt 0) {
            $sum = [decimal]0; foreach ($e in $items) { $sum += $e.Amount }
            $s.Categories[$key] + ': ' + $sum.ToString('#,##0.00', $s.Culture)
        }
    }
    @($parts) -join ' | '
}
$s.NothingVisible = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute { param($s) @($s.Visible.Value).Count -eq 0 }
$s.NoExpenses = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute { param($s) @($s.Expenses.Value).Count -eq 0 }
$s.CannotAdd = New-NHKUiComputed -DependsOn @($s.Description, $s.Amount) -Data $s -Compute {
    param($s) (-not $s.Description.Value.Trim()) -or (-not $s.Amount.Value.Trim())
}
$computeds = @($s.Visible, $s.Total, $s.Lines, $s.Count, $s.ByCategory, $s.NothingVisible, $s.NoExpenses, $s.CannotAdd)

$ui = New-NHKUi -Title 'Expenses' -Width 760 -Height 640
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Expenses' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'New expense' -Level 3
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
                $s.Description.Set('')      # writes back into the native inputs
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
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiSelect -UI $ui -Bind $s.Show -Label 'Show' -Options (@(@{ Value = 'all'; Label = 'All categories' }) + $categoryOptions)
            $null = Add-NHKUiBadge -UI $ui -Bind $s.Count
        }
        $null = Add-NHKUiHeading -UI $ui -Bind $s.Total -Level 2
        $null = Add-NHKUiWhen -UI $ui -Bind $s.NothingVisible -Content {
            $null = Add-NHKUiText -UI $ui -Text 'No expenses to show yet.' -Muted
        }
        $null = Add-NHKUiTextList -UI $ui -Bind $s.Lines
        $null = Add-NHKUiText -UI $ui -Bind $s.ByCategory -Muted
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
