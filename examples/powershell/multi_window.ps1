# Notes editor with live inspector windows that share the editor's state.
#
# Teaches: several UIs in one application, each in its own native window; binding several
# windows to the same states; starting a UI from a button callback (Start-NHKUi -NoReady);
# State.Subscribe for a side effect (an edit counter); and noticing windows the user closed via
# the SDK's window.event notification, which is where the inspector's UI is stopped.
#
# Run:  pwsh -File ./multi_window.ps1   |   powershell.exe -NoProfile -File .\multi_window.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Notes'

$s = @{
    App = $app; Note = (New-NHKUiState -Value ''); Edits = (New-NHKUiState -Value 0); Open = (New-NHKUiState -Value 0)
    Inspectors = (New-Object System.Collections.ArrayList); Max = 3
}
$null = $s.Note.Subscribe({ param($value, $ctx) $ctx.Edits.Set([int]$ctx.Edits.Value + 1) }, $s)
$s.NoteText = New-NHKUiComputed -DependsOn @($s.Note) -Data $s -Compute { param($s) 'Note: ' + $s.Note.Value }
$s.Stats = New-NHKUiComputed -DependsOn @($s.Note) -Data $s -Compute {
    param($s) '{0} words, {1} characters' -f @(([string]$s.Note.Value) -split '\s+' | Where-Object { $_ }).Count, ([string]$s.Note.Value).Length
}
$s.Words = New-NHKUiComputed -DependsOn @($s.Note) -Data $s -Compute { param($s) '{0} words' -f @(([string]$s.Note.Value) -split '\s+' | Where-Object { $_ }).Count }
$s.EditsText = New-NHKUiComputed -DependsOn @($s.Edits) -Data $s -Compute { param($s) '{0} edits' -f $s.Edits.Value }
$s.OpenText = New-NHKUiComputed -DependsOn @($s.Open) -Data $s -Compute { param($s) 'Inspectors open: {0}' -f $s.Open.Value }
$s.AtMax = New-NHKUiComputed -DependsOn @($s.Open) -Data $s -Compute { param($s) $s.Open.Value -ge $s.Max }
$computeds = @($s.NoteText, $s.Stats, $s.Words, $s.EditsText, $s.OpenText, $s.AtMax)

# The SDK calls this for every window event; stop the UI of an inspector the user closed.
Register-NativeHTMLKitNotification -Application $app -Method 'window.event' -Callback {
    param($notification)
    if ($notification.type -ne 'closed') { return }
    foreach ($entry in @($s.Inspectors)) {
        if ($entry.WindowId -eq $notification.window_id) {
            Stop-NHKUi -UI $entry.UI
            $s.Inspectors.Remove($entry)
            $s.Open.Set($s.Inspectors.Count)
        }
    }
}

# Workaround for a UI 0.1.1 stylesheet defect: a field placed directly in a column gets a
# 200px flex basis (meant for rows) and therefore 200px of height. See docs/LIMITATIONS.md.
$fieldFix = '.nhk-col > .nhk-field { flex: 0 0 auto; }'
$ui = New-NHKUi -Title 'Notes' -Width 640 -Height 480 -ExtraCss $fieldFix
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Notes' -Level 1
    $null = Add-NHKUiInput -UI $ui -Bind $s.Note -Label 'Shared note' -Placeholder 'Type here and watch the inspectors'
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Open inspector' -DisabledState $s.AtMax -Data $s -OnClick {
            param($eventObject, $s)
            if ($s.Inspectors.Count -ge $s.Max) { return }
            $number = $s.Inspectors.Count + 1
            $inspector = New-NHKUi -Title "Inspector $number" -Width 420 -Height 320 -Theme graphite
            $null = Add-NHKUiColumn -UI $inspector -Content {
                $null = Add-NHKUiHeading -UI $inspector -Text "Inspector $number" -Level 2
                $null = Add-NHKUiText -UI $inspector -Bind $s.NoteText
                $null = Add-NHKUiText -UI $inspector -Bind $s.Stats
                $null = Add-NHKUiBadge -UI $inspector -Bind $s.EditsText
                $null = Add-NHKUiButton -UI $inspector -Text 'Close inspector' -Variant secondary -Data $inspector -OnClick {
                    param($eventObject, $me) Close-NativeHTMLKitWindow -Window $me.Window
                }
            }
            $window = Start-NHKUi -UI $inspector -Application $s.App -NoReady
            [void]$s.Inspectors.Add([pscustomobject]@{ UI = $inspector; WindowId = $window.Id })
            $s.Open.Set($s.Inspectors.Count)
        }
        $null = Add-NHKUiBadge -UI $ui -Bind $s.OpenText
    }
    $null = Add-NHKUiText -UI $ui -Bind $s.Words -Muted
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    foreach ($entry in @($s.Inspectors)) { Stop-NHKUi -UI $entry.UI }
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
