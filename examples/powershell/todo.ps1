# Task list with per-row Done/Remove buttons and an All/Open/Done filter.
#
# Teaches: the "slot pool" pattern. The UI tree is fixed once started, so the script creates
# $maxTasks rows up front and shows, hides and relabels them from state (Add-NHKUiWhen, bound
# text, bound button labels via -Bind). Each row gets its own -Data object with its index.
# Also: computed counts, a disabled Add button and "Clear done".
#
# Run:  pwsh -File ./todo.ps1   |   powershell.exe -NoProfile -File .\todo.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Tasks'

$maxTasks = 8
$s = @{
    Tasks = (New-NHKUiState -Value @())   # objects with Id, Title, Done
    Title = (New-NHKUiState -Value ''); Show = (New-NHKUiState -Value 'all'); NextId = 1; Max = $maxTasks
}
$s.Visible = New-NHKUiComputed -DependsOn @($s.Tasks, $s.Show) -Data $s -Compute {
    param($s)
    , @($s.Tasks.Value | Where-Object { $s.Show.Value -eq 'all' -or [bool]$_.Done -eq ($s.Show.Value -eq 'done') })
}
$s.Counts = New-NHKUiComputed -DependsOn @($s.Tasks) -Data $s -Compute {
    param($s)
    $all = @($s.Tasks.Value); $done = @($all | Where-Object { $_.Done }).Count
    '{0} open, {1} done' -f ($all.Count - $done), $done
}
$s.Full = New-NHKUiComputed -DependsOn @($s.Tasks) -Data $s -Compute { param($s) @($s.Tasks.Value).Count -ge $s.Max }
$s.CannotAdd = New-NHKUiComputed -DependsOn @($s.Tasks, $s.Title) -Data $s -Compute {
    param($s) (@($s.Tasks.Value).Count -ge $s.Max) -or (-not $s.Title.Value.Trim())
}
$s.NoneDone = New-NHKUiComputed -DependsOn @($s.Tasks) -Data $s -Compute { param($s) @($s.Tasks.Value | Where-Object { $_.Done }).Count -eq 0 }
$s.Empty = New-NHKUiComputed -DependsOn @($s.Visible) -Data $s -Compute { param($s) @($s.Visible.Value).Count -eq 0 }
$computeds = New-Object System.Collections.ArrayList
foreach ($c in @($s.Visible, $s.Counts, $s.Full, $s.CannotAdd, $s.NoneDone, $s.Empty)) { [void]$computeds.Add($c) }

# Per-row computed values: is the row used, its text and its toggle label.
$rows = for ($row = 0; $row -lt $maxTasks; $row++) {
    $slot = @{ S = $s; Row = $row }
    $slot.Present = New-NHKUiComputed -DependsOn @($s.Visible) -Data $slot -Compute { param($t) $t.Row -lt @($t.S.Visible.Value).Count }
    $slot.Text = New-NHKUiComputed -DependsOn @($s.Visible) -Data $slot -Compute {
        param($t)
        $items = @($t.S.Visible.Value)
        if ($t.Row -ge $items.Count) { return '' }
        $mark = if ($items[$t.Row].Done) { '[x] ' } else { '[ ] ' }
        $mark + $items[$t.Row].Title
    }
    $slot.Toggle = New-NHKUiComputed -DependsOn @($s.Visible) -Data $slot -Compute {
        param($t)
        $items = @($t.S.Visible.Value)
        if ($t.Row -lt $items.Count -and $items[$t.Row].Done) { 'Reopen' } else { 'Done' }
    }
    foreach ($c in @($slot.Present, $slot.Text, $slot.Toggle)) { [void]$computeds.Add($c) }
    $slot
}

$ui = New-NHKUi -Title 'Tasks' -Width 640 -Height 620
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Tasks' -Level 1
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $s.Title -Label 'New task' -Placeholder 'Water the plants'
        $null = Add-NHKUiButton -UI $ui -Text 'Add' -DisabledState $s.CannotAdd -Data $s -OnClick {
            param($eventObject, $s)
            $text = $s.Title.Value.Trim()
            if (-not $text -or @($s.Tasks.Value).Count -ge $s.Max) { return }
            $s.Tasks.Set(@($s.Tasks.Value) + @([pscustomobject]@{ Id = $s.NextId; Title = $text; Done = $false }))
            $s.NextId = $s.NextId + 1
            $s.Title.Set('')
        }
    }
    $null = Add-NHKUiWhen -UI $ui -Bind $s.Full -Content {
        $null = Add-NHKUiAlert -UI $ui -Text "The list is full ($maxTasks tasks). Remove or clear some first."
    }
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiSelect -UI $ui -Bind $s.Show -Label 'Show' -Options @(
            @{ Value = 'all'; Label = 'All' }, @{ Value = 'open'; Label = 'Open' }, @{ Value = 'done'; Label = 'Done' })
        $null = Add-NHKUiBadge -UI $ui -Bind $s.Counts
    }
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiWhen -UI $ui -Bind $s.Empty -Content { $null = Add-NHKUiText -UI $ui -Text 'Nothing here.' -Muted }
        foreach ($slot in $rows) {
            $null = Add-NHKUiWhen -UI $ui -Bind $slot.Present -Content {
                $null = Add-NHKUiRow -UI $ui -Content {
                    $null = Add-NHKUiText -UI $ui -Bind $slot.Text
                    $null = Add-NHKUiButton -UI $ui -Bind $slot.Toggle -Variant secondary -Data $slot -OnClick {
                        param($eventObject, $t)
                        $items = @($t.S.Visible.Value)
                        if ($t.Row -ge $items.Count) { return }
                        $id = $items[$t.Row].Id
                        $t.S.Tasks.Set(@($t.S.Tasks.Value | ForEach-Object {
                            if ($_.Id -eq $id) { [pscustomobject]@{ Id = $_.Id; Title = $_.Title; Done = -not $_.Done } } else { $_ }
                        }))
                    }
                    $null = Add-NHKUiButton -UI $ui -Text 'Remove' -Variant quiet -Data $slot -OnClick {
                        param($eventObject, $t)
                        $items = @($t.S.Visible.Value)
                        if ($t.Row -ge $items.Count) { return }
                        $id = $items[$t.Row].Id
                        $t.S.Tasks.Set(@($t.S.Tasks.Value | Where-Object { $_.Id -ne $id }))
                    }
                }
            }
        }
    }
    $null = Add-NHKUiButton -UI $ui -Text 'Clear done' -Variant danger -DisabledState $s.NoneDone -Data $s -OnClick {
        param($eventObject, $s)
        $s.Tasks.Set(@($s.Tasks.Value | Where-Object { -not $_.Done }))
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
