# File inspector: pick files with the native open dialog and list their sizes and a total.
#
# Teaches: calling an SDK dialog (Show-NativeHTMLKitFileDialog) from a UI button callback with
# the UI's own window ($ui.Window) as the owner, handling cancel and errors (dialogs are
# unavailable in headless test mode, error -32001), and turning the result into list state.
# The call waits until the user closes the dialog; UI changes made in the callback are written
# once it returns.
#
# Run:  pwsh -File ./file_picker.ps1   |   powershell.exe -NoProfile -File .\file_picker.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'File inspector'

$s = @{
    Files = (New-NHKUiState -Value @())   # objects with Name and Size (bytes)
    Status = (New-NHKUiState -Value 'Choose one or more files to see their sizes.'); UI = $null
}
$s.HasFiles = New-NHKUiComputed -DependsOn @($s.Files) -Data $s -Compute { param($s) @($s.Files.Value).Count -gt 0 }
$s.NoFiles = New-NHKUiComputed -DependsOn @($s.HasFiles) -Data $s -Compute { param($s) -not $s.HasFiles.Value }
$s.Lines = New-NHKUiComputed -DependsOn @($s.Files) -Data $s -Compute {
    param($s) , @($s.Files.Value | ForEach-Object { '{0}: {1:N1} KB' -f $_.Name, ($_.Size / 1KB) })
}
$s.Summary = New-NHKUiComputed -DependsOn @($s.Files) -Data $s -Compute {
    param($s)
    $total = [long]0; foreach ($f in @($s.Files.Value)) { $total += $f.Size }
    '{0} files, {1:N1} KB in total' -f @($s.Files.Value).Count, ($total / 1KB)
}
$computeds = @($s.HasFiles, $s.NoFiles, $s.Lines, $s.Summary)

$ui = New-NHKUi -Title 'File inspector' -Width 720 -Height 560
$s.UI = $ui
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'File inspector' -Level 1
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Choose files...' -Data $s -OnClick {
            param($eventObject, $s)
            try {
                $result = Show-NativeHTMLKitFileDialog -Window $s.UI.Window -Kind OpenFiles -Multiple $true -Title 'Choose files to inspect'
            } catch {
                $s.Status.Set('File dialogs are unavailable here: ' + $_.Exception.Message)
                return
            }
            $paths = @($result.paths)
            if ($result.cancelled -or $paths.Count -eq 0) { $s.Status.Set('No files chosen.'); return }
            $rows = foreach ($path in $paths) {
                try { $item = Get-Item -LiteralPath $path; [pscustomobject]@{ Name = $item.Name; Size = [long]$item.Length } }
                catch { [pscustomobject]@{ Name = ([IO.Path]::GetFileName($path) + ' (unreadable)'); Size = [long]0 } }
            }
            $s.Files.Set(@($rows))
            $s.Status.Set(('{0} file(s) chosen.' -f @($rows).Count))
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Clear' -Variant secondary -DisabledState $s.NoFiles -Data $s -OnClick {
            param($eventObject, $s) $s.Files.Set(@())
        }
    }
    $null = Add-NHKUiText -UI $ui -Bind $s.Status -Muted
    $null = Add-NHKUiWhen -UI $ui -Bind $s.HasFiles -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Bind $s.Summary -Level 3
            $null = Add-NHKUiTextList -UI $ui -Bind $s.Lines
        }
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
