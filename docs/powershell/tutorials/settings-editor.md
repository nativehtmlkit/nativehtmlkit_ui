# Tutorial (PowerShell): build a settings editor

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
tutorial for Python: [build a settings editor](../../python/tutorials/settings-editor.md).*

You will build **Settings editor**, a small editor for a JSON settings file: bound inputs, live
validation, an "Unsaved changes" badge, Save and Revert buttons, and a theme the app itself uses
on the next start.

**Time:** about 25 minutes. **You need:** `NativeHTMLKit.UI` installed and the first window from
[getting started](../getting-started.md) working. Both steps are complete scripts, verified by
the repository's example harness against the real NativeHTMLKit host on PowerShell 7 and
Windows PowerShell 5.1:
[`examples/tutorials/powershell/settings_editor_step1.ps1`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/tutorials/powershell/settings_editor_step1.ps1)
and the final app [`examples/powershell/settings_editor.ps1`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/settings_editor.ps1).

## Step 1: a form bound to state

Create `settings_editor.ps1`:

```powershell
# Settings editor tutorial, step 1: a form whose controls are bound to UI state.
#
# Teaches: New-NHKUi, New-NHKUiState, two-way Add-NHKUiInput / Add-NHKUiSelect / Add-NHKUiCheckbox,
#          New-NHKUiComputed with explicit -DependsOn, Add-NHKUiText -Bind, Start-NHKUi / Stop-NHKUi.
# Run:     pwsh -File ./settings_editor_step1.ps1   |   powershell.exe -NoProfile -File .\settings_editor_step1.ps1
# Guide:   docs/powershell/tutorials/settings-editor.md (step 1 of 2)
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI -ErrorAction Stop
$app = Start-NativeHTMLKitScript -Name 'Settings editor'

$name = New-NHKUiState -Value 'Ada'
$email = New-NHKUiState -Value 'ada@example.org'
$theme = New-NHKUiState -Value 'cobalt'
$notify = New-NHKUiState -Value $true
$summary = New-NHKUiComputed -DependsOn @($name, $email, $theme, $notify) -Data @{ Name = $name; Email = $email; Theme = $theme; Notify = $notify } -Compute {
    param($s)
    $mail = if ($s.Notify.Value) { 'with e-mail notifications' } else { 'without notifications' }
    "$($s.Name.Value) <$($s.Email.Value)>, $($s.Theme.Value) theme, $mail"
}

$ui = New-NHKUi -Title 'Settings editor' -Theme cobalt -Density regular -Width 560 -Height 520
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Settings' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Display name'
        $null = Add-NHKUiInput -UI $ui -Bind $email -Label 'E-mail' -Type email
        $null = Add-NHKUiSelect -UI $ui -Bind $theme -Label 'Theme' -Options @(
            @{ Value = 'cobalt'; Label = 'Cobalt' }, @{ Value = 'graphite'; Label = 'Graphite' }, @{ Value = 'daylight'; Label = 'Daylight' })
        $null = Add-NHKUiCheckbox -UI $ui -Bind $notify -Label 'Send me e-mail notifications'
    }
    $null = Add-NHKUiText -UI $ui -Bind $summary -Muted
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $summary.Dispose()
    Close-NativeHTMLKit -Application $app
}
```

Run `pwsh -File ./settings_editor.ps1` (or `powershell.exe -NoProfile -File .\settings_editor.ps1`)
and edit the fields: the summary below follows every change.

- Each `New-NHKUiState` holds one setting. `Add-NHKUiInput -Bind $name` is two-way; `-Type email`
  gives an e-mail field.
- `Add-NHKUiSelect -Options` takes hashtables with `Value` and `Label`. `Add-NHKUiCheckbox` binds
  a Boolean.
- `New-NHKUiComputed -DependsOn @(...)` lists its dependencies **explicitly** (PowerShell has no
  automatic dependency tracking), and receives `-Data` as its parameter.
- The summary contains `<` and `>` around the e-mail address; `Add-NHKUiText` always encodes
  text, so this is safe.
- The inputs are inside a card, so they keep their natural height. Labelled inputs placed
  directly in a column need the B-0014 workaround from the [layouts guide](../guides/layouts.md).

## Step 2: load, validate, save and revert

Replace the script with the final version:

```powershell
# Settings editor: edit, validate and save a JSON settings file (settings-editor tutorial, final code).
#
# Teaches: loading initial state from a file, computed validation and "unsaved changes" states,
#          saving JSON atomically, Revert, an Add-NHKUiAlert status line, and starting the UI in
#          the theme the user saved.
# Run:     pwsh -File ./settings_editor.ps1 [PATH]   |   powershell.exe -NoProfile -File .\settings_editor.ps1 [PATH]
#          (default file: nativehtmlkit-settings.json in your application-data folder:
#          %APPDATA% on Windows, $XDG_CONFIG_HOME or ~/.config on Linux)
# Guide:   docs/powershell/tutorials/settings-editor.md (step 2 of 2)
param([string]$Path)
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI -ErrorAction Stop
$app = Start-NativeHTMLKitScript -Name 'Settings editor'

# .NET path methods instead of Join-Path/Test-Path: on Windows the backend's working directory is an
# extended-length path (\\?\C:\...), which Windows PowerShell 5.1's Join-Path rejects.
if (-not $Path) { $Path = [IO.Path]::Combine([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData, [Environment+SpecialFolderOption]::Create), 'nativehtmlkit-settings.json') }
$Path = [IO.Path]::GetFullPath($Path)
$defaults = [ordered]@{ DisplayName = ''; Email = ''; Theme = 'cobalt'; RefreshSeconds = 60; Notifications = $false }
$themes = @('cobalt', 'graphite', 'daylight')

function Read-Settings {
    $result = [ordered]@{}
    foreach ($key in $defaults.Keys) { $result[$key] = $defaults[$key] }
    if ([IO.File]::Exists($Path)) {
        $data = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
        foreach ($key in $defaults.Keys) {
            if ($null -ne $data.PSObject.Properties[$key]) { $result[$key] = $data.$key }
        }
    }
    if ($themes -notcontains $result.Theme) { $result.Theme = 'cobalt' }
    return $result
}

function Get-Snapshot {
    # The values as they would be saved; also used to detect unsaved changes.
    return [ordered]@{ DisplayName = $name.Value.Trim(); Email = $email.Value.Trim(); Theme = $theme.Value
        RefreshSeconds = $interval.Value.Trim(); Notifications = [bool]$notify.Value }
}

function Save-Settings {
    $snapshot = Get-Snapshot
    $snapshot.RefreshSeconds = [int]$snapshot.RefreshSeconds
    $json = ConvertTo-Json -InputObject $snapshot
    $folder = [IO.Path]::GetDirectoryName($Path)
    $null = [IO.Directory]::CreateDirectory($folder)
    $temporary = [IO.Path]::Combine($folder, '.settings-' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($temporary, $json, (New-Object Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) } else { [IO.File]::Move($temporary, $Path) }
}

$loaded = Read-Settings
$name = New-NHKUiState -Value ([string]$loaded.DisplayName)
$email = New-NHKUiState -Value ([string]$loaded.Email)
$theme = New-NHKUiState -Value ([string]$loaded.Theme)
$interval = New-NHKUiState -Value ([string]$loaded.RefreshSeconds)
$notify = New-NHKUiState -Value ([bool]$loaded.Notifications)
$saved = New-NHKUiState -Value (ConvertTo-Json -InputObject (Get-Snapshot) -Compress)
$status = New-NHKUiState -Value "Editing $Path"
$all = @($name, $email, $theme, $interval, $notify, $saved)

$problem = New-NHKUiComputed -DependsOn $all -Compute {
    $s = Get-Snapshot
    $seconds = 0
    if ($s.DisplayName -eq '') { 'Enter a display name.' }
    elseif ($s.Email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { 'The e-mail address looks invalid.' }
    elseif (-not [int]::TryParse($s.RefreshSeconds, [ref]$seconds) -or $seconds -lt 5 -or $seconds -gt 3600) { 'Refresh interval must be a whole number from 5 to 3600.' }
    else { '' }
}
$changes = New-NHKUiComputed -DependsOn $all -Compute {
    if ((ConvertTo-Json -InputObject (Get-Snapshot) -Compress) -eq $saved.Value) { 'All changes saved' } else { 'Unsaved changes' }
}
$hasProblem = New-NHKUiComputed -DependsOn @($problem) -Compute { $problem.Value -ne '' }

$ui = New-NHKUi -Title 'Settings editor' -Theme $loaded.Theme -Density regular -Width 600 -Height 640
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Settings' -Level 1
        $null = Add-NHKUiBadge -UI $ui -Bind $changes
    }
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Display name'
        $null = Add-NHKUiInput -UI $ui -Bind $email -Label 'E-mail' -Type email
        $null = Add-NHKUiInput -UI $ui -Bind $interval -Label 'Refresh interval (seconds)' -Type number
        $null = Add-NHKUiSelect -UI $ui -Bind $theme -Label 'Theme (applies on next start)' -Options @(
            @{ Value = 'cobalt'; Label = 'Cobalt' }, @{ Value = 'graphite'; Label = 'Graphite' }, @{ Value = 'daylight'; Label = 'Daylight' })
        $null = Add-NHKUiCheckbox -UI $ui -Bind $notify -Label 'Send me e-mail notifications'
    }
    $null = Add-NHKUiWhen -UI $ui -Bind $hasProblem -Content {
        $null = Add-NHKUiText -UI $ui -Bind $problem
    }
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Save' -OnClick {
            param($eventObject, $data)
            if ($problem.Value -ne '') { $status.Set('Fix the problem above before saving.'); return }
            try {
                Save-Settings
                $saved.Set((ConvertTo-Json -InputObject (Get-Snapshot) -Compress))
                $status.Set("Saved $(Get-Date -Format 'HH:mm:ss')")
            } catch {
                $status.Set('Could not save: ' + $_.Exception.Message)
            }
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Revert' -Variant secondary -OnClick {
            param($eventObject, $data)
            $fresh = Read-Settings
            $name.Set([string]$fresh.DisplayName); $email.Set([string]$fresh.Email); $theme.Set([string]$fresh.Theme)
            $interval.Set([string]$fresh.RefreshSeconds); $notify.Set([bool]$fresh.Notifications)
            $status.Set('Reverted to the saved file')
        }
    }
    $null = Add-NHKUiAlert -UI $ui -Bind $status
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in @($problem, $changes, $hasProblem)) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
```

Run it with `pwsh -File ./settings_editor.ps1` or with a file of your choice:
`pwsh -File ./settings_editor.ps1 ./my-settings.json`.

- `param([string]$Path)` takes the file as the first argument. Without it, the file is
  `nativehtmlkit-settings.json` in your application-data folder
  (`[Environment]::GetFolderPath(...ApplicationData, Create)`, which creates the folder if it is
  missing: `%APPDATA%` on Windows, `$XDG_CONFIG_HOME` or `~/.config` on Linux). The Python version
  of this tutorial uses the same folder and the same JSON keys, so both apps edit the same file.
- The script uses .NET methods (`[IO.Path]::Combine`, `[IO.File]::Exists`,
  `[IO.Directory]::CreateDirectory`) instead of `Join-Path`, `Test-Path` and `New-Item`. On
  Windows the backend's working directory is an extended-length path (`\\?\C:\...`), so a
  relative path argument becomes such a path, and Windows PowerShell 5.1's `Join-Path` rejects it
  ("the value of argument "drive" is null"). The .NET methods work in every PowerShell version.
- `Read-Settings` starts from defaults and copies known keys from the file, so a partial or older
  file still works.
- `Get-Snapshot` returns the values as they would be saved. Two computed states use it:
  `$problem` (a validation message or `''`) and `$changes`, which compares the snapshot with
  `$saved`, the compressed JSON of the last save (hashtables compare by reference, text by value).
- These computed states call script functions instead of receiving `-Data`; that works because
  the scriptblocks run on the owner runspace in the script's scope. They still list every state
  they read in `-DependsOn` (`$all`).
- `$hasProblem` is computed from `$problem` and drives `Add-NHKUiWhen`, which shows the message
  only when there is one.
- **Save** refuses to write while there is a problem, writes a temporary file and replaces the
  real one (`[IO.File]::Replace`, with `[NullString]::Value` for "no backup", since a plain
  `$null` would be passed as an empty string), then updates `$saved`, so the badge returns to
  "All changes saved". Errors become a status message.
- **Revert** reads the file again and sets every state; the bound inputs update themselves. All
  `.Set()` calls in one callback reach the window as one update.
- `New-NHKUi -Theme $loaded.Theme`: the theme is chosen when the UI is built, so a changed theme
  applies on the next start.

Try it: clear **Display name** (the message appears and Save refuses), type an e-mail without a
dot after the `@`, set the refresh interval to `2`. Fix everything, press **Save**, change a
field and press **Revert**.

## What you learned

| Concept | Where |
|---|---|
| Bind inputs, selects and checkboxes; derive a summary with `New-NHKUiComputed` | Step 1 |
| Initial state from a file, computed validation and unsaved-changes tracking | Step 2 |
| Atomic save, revert from disk, theme chosen at start | Step 2 |

## Where next

- [Theming and custom CSS](../guides/theming-and-custom-css.md): what the saved theme changes.
- [Forms, inputs and validation](../guides/forms-and-inputs.md).
- Add "Save as..." with `Show-NativeHTMLKitFileDialog -Kind SaveFile`: [mixing the UI with SDK calls](../guides/mixing-ui-and-sdk-calls.md).
- [PowerShell API reference](../reference.md).
