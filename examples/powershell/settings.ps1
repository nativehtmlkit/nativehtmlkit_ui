# Settings panel with Save, Revert and Restore defaults, plus an "unsaved changes" indicator.
#
# Teaches: one computed snapshot key over many controls, dirty tracking by comparing it with
# the last saved key, writing state back into inputs/selects/checkboxes (Revert, Defaults),
# and buttons enabled only when they would do something. Replace the Save body with your own
# persistence (for example ConvertTo-Json to a file).
#
# Run:  pwsh -File ./settings.ps1   |   powershell.exe -NoProfile -File .\settings.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Settings'

$defaults = [ordered]@{ DisplayName = ''; Language = 'en'; FontSize = '14'; Autosave = $true; Interval = '5'; Telemetry = $false }
$s = @{ Defaults = $defaults; Fields = [ordered]@{}; Saved = @{} }
foreach ($key in $defaults.Keys) { $s.Fields[$key] = New-NHKUiState -Value $defaults[$key]; $s.Saved[$key] = $defaults[$key] }
$s.Status = New-NHKUiState -Value 'Loaded defaults.'
# A text key of all current values; comparing keys detects unsaved changes.
$s.Key = New-NHKUiComputed -DependsOn @($s.Fields.Values) -Data $s -Compute {
    param($s) (@($s.Fields.Keys | ForEach-Object { $_ + '=' + [string]$s.Fields[$_].Value }) -join ';')
}
$s.SavedKey = New-NHKUiState -Value $s.Key.Value
$s.Dirty = New-NHKUiComputed -DependsOn @($s.Key, $s.SavedKey) -Data $s -Compute { param($s) $s.Key.Value -ne $s.SavedKey.Value }
$s.Badge = New-NHKUiComputed -DependsOn @($s.Dirty) -Data $s -Compute { param($s) if ($s.Dirty.Value) { 'Unsaved changes' } else { 'All changes saved' } }
$s.IntervalOk = New-NHKUiComputed -DependsOn @($s.Fields.Interval) -Data $s -Compute {
    param($s) $v = [string]$s.Fields.Interval.Value; ($v -match '^\d{1,2}$') -and [int]$v -ge 1 -and [int]$v -le 60
}
$s.IntervalBad = New-NHKUiComputed -DependsOn @($s.IntervalOk) -Data $s -Compute { param($s) -not $s.IntervalOk.Value }
$s.CannotSave = New-NHKUiComputed -DependsOn @($s.Dirty, $s.IntervalOk) -Data $s -Compute { param($s) (-not $s.Dirty.Value) -or (-not $s.IntervalOk.Value) }
$s.Clean = New-NHKUiComputed -DependsOn @($s.Dirty) -Data $s -Compute { param($s) -not $s.Dirty.Value }
$computeds = @($s.Key, $s.Dirty, $s.Badge, $s.IntervalOk, $s.IntervalBad, $s.CannotSave, $s.Clean)
$f = $s.Fields

$ui = New-NHKUi -Title 'Settings' -Width 700 -Height 640 -Density regular
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Settings' -Level 1
        $null = Add-NHKUiBadge -UI $ui -Bind $s.Badge
    }
    $null = Add-NHKUiGrid -UI $ui -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Profile' -Level 3
            $null = Add-NHKUiInput -UI $ui -Bind $f.DisplayName -Label 'Display name' -Placeholder 'Shown in the title bar'
            $null = Add-NHKUiSelect -UI $ui -Bind $f.Language -Label 'Language' -Options @(
                @{ Value = 'en'; Label = 'English' }, @{ Value = 'de'; Label = 'German' },
                @{ Value = 'fr'; Label = 'French' }, @{ Value = 'ja'; Label = 'Japanese' })
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Editor' -Level 3
            $null = Add-NHKUiSelect -UI $ui -Bind $f.FontSize -Label 'Font size' -Options @(
                @{ Value = '12'; Label = 'Small (12 px)' }, @{ Value = '14'; Label = 'Normal (14 px)' }, @{ Value = '16'; Label = 'Large (16 px)' })
            $null = Add-NHKUiCheckbox -UI $ui -Bind $f.Autosave -Label 'Save documents automatically'
            $null = Add-NHKUiWhen -UI $ui -Bind $f.Autosave -Content {
                $null = Add-NHKUiInput -UI $ui -Bind $f.Interval -Label 'Autosave every (minutes)' -Type number
                $null = Add-NHKUiWhen -UI $ui -Bind $s.IntervalBad -Content {
                    $null = Add-NHKUiAlert -UI $ui -Text 'Use a whole number of minutes from 1 to 60.'
                }
            }
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Privacy' -Level 3
            $null = Add-NHKUiCheckbox -UI $ui -Bind $f.Telemetry -Label 'Send anonymous usage statistics'
            $null = Add-NHKUiText -UI $ui -Text 'Off by default. Nothing is sent by this example.' -Muted
        }
    }
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Save' -DisabledState $s.CannotSave -Data $s -OnClick {
            param($eventObject, $s)
            if ($s.CannotSave.Value) { return }
            foreach ($key in $s.Fields.Keys) { $s.Saved[$key] = $s.Fields[$key].Value }
            $s.SavedKey.Set($s.Key.Value)
            $s.Status.Set('Saved at ' + (Get-Date).ToString('HH:mm:ss') + '.')
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Revert' -Variant secondary -DisabledState $s.Clean -Data $s -OnClick {
            param($eventObject, $s)
            foreach ($key in $s.Fields.Keys) { $s.Fields[$key].Set($s.Saved[$key]) }
            $s.Status.Set('Reverted to the last saved settings.')
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Restore defaults' -Variant quiet -Data $s -OnClick {
            param($eventObject, $s)
            foreach ($key in $s.Fields.Keys) { $s.Fields[$key].Set($s.Defaults[$key]) }
            $s.Status.Set('Defaults restored (not saved yet).')
        }
    }
    $null = Add-NHKUiText -UI $ui -Bind $s.Status -Muted
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
