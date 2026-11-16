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
