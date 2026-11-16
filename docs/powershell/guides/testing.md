# Testing your UI

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [testing](../../python/guides/testing.md).*

**Goal:** test application logic quickly, then prove it against the real native host.

## 1. Logic without a host

States and computed states work without any window, so plain Pester tests cover the logic:

```powershell
Describe 'expense totals' {
    It 'follows the filter' {
        $s = @{ Expenses = (New-NHKUiState -Value @(
                    [pscustomobject]@{ Category = 'food'; Amount = 3 }, [pscustomobject]@{ Category = 'home'; Amount = 5 }))
                Show = (New-NHKUiState -Value 'all') }
        $total = New-NHKUiComputed -DependsOn @($s.Expenses, $s.Show) -Data $s -Compute {
            param($s) ($s.Expenses.Value | Where-Object { $s.Show.Value -eq 'all' -or $_.Category -eq $s.Show.Value } |
                Measure-Object Amount -Sum).Sum
        }
        $total.Value | Should -Be 8
        $s.Show.Set('home')
        $total.Value | Should -Be 5
        $total.Dispose()
    }
}
```

`Get-NHKUiHtml` renders the full document without a host, which is enough to check structure,
labels and escaping:

```powershell
$ui = New-NHKUi -Title 't'
$null = Add-NHKUiText -UI $ui -Text '<b>x</b>'
(Get-NHKUiHtml -UI $ui) | Should -Match '&lt;b&gt;x&lt;/b&gt;'
```

The module's own unit tests do the same with a fake SDK
([`powershell/tests/Unit.Tests.ps1`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/powershell/tests/Unit.Tests.ps1)).

## 2. The real host, headless

Set `NATIVEHTMLKIT_TEST_MODE=1` and start the script normally. The SDK launches the real Core
host in headless mode: the whole protocol runs (documents load, commands apply, events can be
delivered) but no window is shown. Native input does not exist there, and services that need a
desktop (clipboard, file dialogs, opening URLs) fail with error -32001, so code paths for those
errors get exercised.

In a test you can then:

- read DOM state through the SDK: `Get-NativeHTMLKitDocumentText`, `Get-NativeHTMLKitValue`,
  `Get-NativeHTMLKitChecked`, `Invoke-NativeHTMLKitDocumentCommand -Operation get_attribute`
  with `$node.Id` and `$ui.Document`;
- rely on synchronous writes: outside callbacks the window is written when the outermost
  `.Set()` returns (`Sync-NHKUi` writes anything pending);
- assert health: `Get-NHKUiDiagnostics` has `Errors = 0` and `DomUncertain = $false`, and
  `Get-NativeHTMLKitDiagnosticReport` shows no `CallbackFailures`;
- end with `Request-NativeHTMLKitQuit` and check the process exits 0.

## 3. The example harness

`qualification/examples/run_examples.py` (Python 3.11+, standard library only) runs **every**
example and tutorial step listed in
[`examples/catalog.toml`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/catalog.toml)
this way, in PowerShell and Python, each through its own normal entry point
(`pwsh -File example.ps1 [args]`), unchanged. A small probe records the started UIs, replays the
scenario from `qualification/examples/scenarios.json` on the owner runspace, reads the DOM back,
and quits:

```json
"expenses": {"steps": [
  {"op": "type", "label": "Description", "value": "Coffee"},
  {"op": "type", "label": "Amount", "value": "3.50"},
  {"op": "click", "label": "Add expense"},
  {"op": "expect_text", "contains": ["Coffee (Food): 3.50", "Total: 3.50"]},
  {"op": "expect_value", "label": "Description", "value": ""}
]}
```

Steps: `click`, `type`, `check`, `choose` (simulated events), `expect_text` / `wait_text`
(visible text, skipping hidden regions), `expect_value`, `expect_disabled`, `expect_uis`,
`close_window`, `sleep`. Each step may target another window with `"ui": 1` and the n-th
matching control with `"nth"`. A scenario may give `"args"` (positional script arguments) and
separate `"py"`/`"ps"` step lists.

```bash
# PowerShell 7: put the NativeHTMLKit SDK module folder and ./powershell on PSModulePath
python qualification/examples/run_examples.py --lang ps --pwsh pwsh \
    --ps-module-path "/path/to/sdk-modules:$PWD/powershell"
```

```powershell
# Windows PowerShell 5.1
python qualification\examples\run_examples.py --lang ps --pwsh powershell.exe --ps-module-path "C:\sdk-modules;$PWD\powershell"
```

Per example it requires: ready reached, all steps passed, clean UI diagnostics, no SDK callback
failures or dropped notifications, exit code 0, no exception on stderr, and no leftover
host/backend process. It also fails when a catalogue entry lacks a file in either language, a
file has no scenario, or a script under `examples/` is not in the catalogue.

**What this proves and what not.** Events are injected at the UI module's SDK callback entry
point after writing the control value with the public SDK, so the app's callbacks, states,
computed states and document writes run against the real host exactly as after native input.
It does not prove native input, focus, IME, rendering or accessibility.

## 4. On a desktop

Run the script normally and use it. For repeatable GUI checks, drive real input with your
platform's tooling and read state back through the SDK, as the repository's
[`qualification/gui`](https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/qualification/gui)
driver does on KDE Plasma Wayland and Windows.

## Related

[PowerShell reference: `Get-NHKUiDiagnostics`](../reference.md#get-nhkuidiagnostics) ·
[build and qualification](../../BUILD.md)
