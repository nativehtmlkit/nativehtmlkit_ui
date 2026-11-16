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
