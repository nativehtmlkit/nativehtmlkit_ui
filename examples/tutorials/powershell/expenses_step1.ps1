# Expense tracker tutorial, step 1: a window with two bound inputs and a live preview.
# Run:  pwsh -File ./expenses_step1.ps1   (docs/powershell/tutorials/expense-tracker.md)
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Expenses'

$s = @{ Description = (New-NHKUiState -Value ''); Amount = (New-NHKUiState -Value '') }
$s.Preview = New-NHKUiComputed -DependsOn @($s.Description, $s.Amount) -Data $s -Compute {
    param($s)
    $d = if ($s.Description.Value) { $s.Description.Value } else { '...' }
    $a = if ($s.Amount.Value) { $s.Amount.Value } else { '0.00' }
    "New expense: $d, $a"
}

$ui = New-NHKUi -Title 'Expenses' -Width 760 -Height 640
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Expenses' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiInput -UI $ui -Bind $s.Description -Label 'Description' -Placeholder 'Coffee with Sam'
            $null = Add-NHKUiInput -UI $ui -Bind $s.Amount -Label 'Amount' -Placeholder '0.00'
        }
        $null = Add-NHKUiText -UI $ui -Bind $s.Preview -Muted
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $s.Preview.Dispose()
    Close-NativeHTMLKit -Application $app
}
