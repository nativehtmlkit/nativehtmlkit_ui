# Run in pwsh 7.2+ on KDE Wayland, or powershell.exe 5.1 / pwsh on Windows.
# Install the NativeHTMLKit SDK and add NativeHTMLKit.UI to PSModulePath.
Import-Module NativeHTMLKit.UI -ErrorAction Stop
$app = Start-NativeHTMLKitScript -Name 'NativeHTMLKit UI Counter'
$ui = New-NHKUi -Title 'NativeHTMLKit UI' -Theme cobalt -Density compact
$count = New-NHKUiState -Value 0
$name = New-NHKUiState -Value 'NativeHTMLKit'
$show = New-NHKUiState -Value $true
$history = New-NHKUiState -Value @('Ready')
$message = New-NHKUiComputed -DependsOn @($count,$name) -Data @{Count=$count;Name=$name} -Compute {
    param($s)
    return "$($s.Name.Value): $($s.Count.Value) clicks"
}
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'NativeHTMLKit UI' -Level 1
    $null = Add-NHKUiText -UI $ui -Text 'Browserless native desktop UI with PowerShell'
    $null = Add-NHKUiGrid -UI $ui -Content {
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Reactive state'
            $null = Add-NHKUiText -UI $ui -Bind $message
            $null = Add-NHKUiButton -UI $ui -Text 'Increment' -Data @{Count=$count;History=$history} -OnClick {
                param($eventObject,$data)
                $data.Count.Set([int]$data.Count.Value + 1)
                $data.History.Set(@("Count became $($data.Count.Value)") + @($data.History.Value))
            }
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'Input'
            $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Your name'
            $null = Add-NHKUiCheckbox -UI $ui -Bind $show -Label 'Show events'
        }
        $null = Add-NHKUiCard -UI $ui -Content {
            $null = Add-NHKUiHeading -UI $ui -Text 'List'
            $null = Add-NHKUiWhen -UI $ui -Bind $show -Content {
                $null = Add-NHKUiTextList -UI $ui -Bind $history
            }
        }
    }
}
try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $message.Dispose()
    Close-NativeHTMLKit -Application $app
}
