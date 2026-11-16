# Tutorial (PowerShell): build an expense tracker

In about 30 minutes you build a small native desktop app with `NativeHTMLKit.UI`: enter
expenses, validate amounts, remove the last entry, filter by category and see totals that
update by themselves. You learn the module's whole model: **states, components bound to
states, button callbacks that change states, and computed states**.

Every step is a complete script in [`code/powershell/`](code/powershell/) and the finished app
is [`examples/powershell/expenses.ps1`](../../examples/powershell/expenses.ps1). All of them run
in the repository's example harness against the real NativeHTMLKit host, on PowerShell 7 and
Windows PowerShell 5.1. The code avoids PowerShell 7-only syntax.

The Python version of this tutorial is [here](python-expense-tracker.md).

## Step 0: install and check

PowerShell 7.2+ (Linux or Windows) or Windows PowerShell 5.1:

```powershell
Install-Module NativeHTMLKit.UI -Scope CurrentUser      # also installs the NativeHTMLKit SDK
Import-Module NativeHTMLKit.UI
(Get-Module NativeHTMLKit.UI).Version                    # 0.1.1
```

## Step 1: a window with bound inputs

Create `expenses.ps1`:

```powershell
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
```

Run it with `pwsh -File ./expenses.ps1` (or `powershell.exe -NoProfile -File .\expenses.ps1`)
and type into both fields: the preview follows every keystroke.

What happened:

- `Start-NativeHTMLKitScript` starts the native host, which runs this script again as its
  backend and returns the connected application there. Everything above that line runs twice;
  keep side effects below it.
- `New-NHKUiState` creates an observable value; `Add-NHKUiInput -Bind` binds it **two ways**.
- `New-NHKUiComputed` derives a value. Unlike Python, PowerShell lists the dependencies
  explicitly in `-DependsOn`, and the scriptblock gets its inputs through `-Data` (here the
  hashtable `$s` that holds all states).
- Containers take a `-Content` scriptblock; components created inside it become children.
  Assign results to `$null` so the nodes do not end up in the script's output.
- `Start-NHKUi` opens the window and announces readiness; `Wait-NativeHTMLKit -UntilShutdown`
  pumps events until the window closes. `finally` stops the UI, disposes computed states and
  closes the connection.

(Complete file: [`code/powershell/expenses_step1.ps1`](code/powershell/expenses_step1.ps1).)

## Step 2: a list of expenses

Add a list state, a computed list of lines and two buttons:

```powershell
$s = @{ Expenses = (New-NHKUiState -Value @()); Description = (New-NHKUiState -Value ''); Amount = (New-NHKUiState -Value '') }
$s.Lines = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute {
    param($s) , @($s.Expenses.Value | ForEach-Object { '{0}: {1}' -f $_.Description, $_.Amount })
}
$s.NoExpenses = New-NHKUiComputed -DependsOn @($s.Expenses) -Data $s -Compute { param($s) @($s.Expenses.Value).Count -eq 0 }
$computeds = @($s.Lines, $s.NoExpenses)
```

```powershell
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
```

and dispose every computed state in `finally`: `foreach ($c in $computeds) { $c.Dispose() }`.

New ideas:

- **Callbacks change states, nothing else.** Setting `Description` and `Amount` to `''` clears
  the fields. A button callback receives `param($eventObject, $data)`, where `$data` is the
  `-Data` argument.
- **Always `.Set()` a new array.** States compare with `[object]::Equals`, which for arrays
  means "same array object". `$s.Expenses.Value += $new` would not notify anybody.
- **The leading comma** in `, @(...)` returns the array itself; without it an empty list
  becomes `$null` and a one-item list a single string.
- `-DisabledState` takes a state (here a computed boolean).
- All changes made in one callback reach the window in one update.

(Complete file: [`code/powershell/expenses_step2.ps1`](code/powershell/expenses_step2.ps1).)

## Step 3: categories and validation

Add a category select, an error state and a computed state that disables **Add expense** while
a field is empty. Parse the amount culture-independently:

```powershell
$categories = [ordered]@{ food = 'Food'; transport = 'Transport'; home = 'Home'; other = 'Other' }
$categoryOptions = @($categories.Keys | ForEach-Object { @{ Value = $_; Label = $categories[$_] } })
# in $s: Category = (New-NHKUiState -Value 'food'); Error = (New-NHKUiState -Value '')
#        Categories = $categories; Culture = [Globalization.CultureInfo]::InvariantCulture
$s.CannotAdd = New-NHKUiComputed -DependsOn @($s.Description, $s.Amount) -Data $s -Compute {
    param($s) (-not $s.Description.Value.Trim()) -or (-not $s.Amount.Value.Trim())
}
```

```powershell
            $null = Add-NHKUiSelect -UI $ui -Bind $s.Category -Label 'Category' -Options $categoryOptions
        ...
        $null = Add-NHKUiWhen -UI $ui -Bind $s.Error -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.Error }
        ...
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
                $s.Description.Set(''); $s.Amount.Set(''); $s.Error.Set('')
            }
```

New ideas:

- `Add-NHKUiSelect -Options` takes `@{ Value = ...; Label = ... }` entries; the state holds the
  selected value.
- `Add-NHKUiWhen -Bind $s.Error` shows its content while the error text is non-empty; the
  region is only hidden, never rebuilt.
- `[decimal]` with `InvariantCulture` parses `12.50` the same way on every system locale.

(Complete file: [`code/powershell/expenses_step3.ps1`](code/powershell/expenses_step3.ps1).)

## Step 4: filter and totals

The finished app adds a **Show** filter and derives everything else from `Expenses` and `Show`:

```powershell
$s.Visible = New-NHKUiComputed -DependsOn @($s.Expenses, $s.Show) -Data $s -Compute {
    param($s)
    , @($s.Expenses.Value | Where-Object { $s.Show.Value -eq 'all' -or $_.Category -eq $s.Show.Value })
}
$s.Total = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute {
    param($s)
    $sum = [decimal]0
    foreach ($e in $s.Visible.Value) { $sum += $e.Amount }
    'Total: ' + $sum.ToString('#,##0.00', $s.Culture)
}
$s.Count = New-NHKUiComputed -DependsOn @($s.Visible, $s.Expenses) -Data $s -Compute {
    param($s) '{0} of {1} expenses' -f @($s.Visible.Value).Count, @($s.Expenses.Value).Count
}
```

```powershell
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
```

Computed states can depend on computed states (`Total` depends on `Visible`). One change to the
filter recomputes the chain and updates the list, badge and total in one window update.

The complete script, including `Lines`, `ByCategory`, `NothingVisible` and `NoExpenses`, is
[`examples/powershell/expenses.ps1`](../../examples/powershell/expenses.ps1).

## What you learned

| Concept | Where |
|---|---|
| States, two-way inputs, computed states with `-DependsOn` and `-Data` | Step 1 |
| Callbacks change states; `.Set()` new arrays; return arrays with `, @()` | Step 2 |
| Select, conditional regions, validation, culture-independent parsing | Step 3 |
| Chains of computed states | Step 4 |

Next:

- [How-to guides](../guides/README.md): background tasks, timers, multiple windows, theming.
- [PowerShell API reference](../reference/powershell.md).
- More apps in [`examples/`](../../examples/README.md).
- [How it works](../ARCHITECTURE.md).
