# Message composer: untrusted user text is always encoded; only static help uses Add-NHKUiHtml.
#
# Teaches: the trust boundary. Everything a user types reaches the window through text
# bindings (Add-NHKUiText, Add-NHKUiTextList), which HTML-encode it, so typing <b>hi</b> shows
# those characters literally. Add-NHKUiHtml is used only for a fixed, developer-written
# snippet. Also: a length limit with a computed counter and a sent-messages list.
#
# Run:  pwsh -File ./message_preview.ps1   |   powershell.exe -NoProfile -File .\message_preview.ps1
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Message composer'

$help = @'
<table class="help">
  <tr><th>Tip</th><th>Why</th></tr>
  <tr><td>Type <code>&lt;b&gt;</code> in the message</td><td>It is shown as text, never as markup.</td></tr>
  <tr><td>Keep it under <strong>140</strong> characters</td><td>Longer messages cannot be sent.</td></tr>
</table>
'@
$css = '.help { border-collapse: collapse; width: 100%; } .help td, .help th { text-align: left; padding: 4px 8px; border-bottom: 1px solid var(--nhk-border); }'

$s = @{ Recipient = (New-NHKUiState -Value ''); Message = (New-NHKUiState -Value ''); Sent = (New-NHKUiState -Value @()); Limit = 140 }
$s.Remaining = New-NHKUiComputed -DependsOn @($s.Message) -Data $s -Compute { param($s) $s.Limit - ([string]$s.Message.Value).Length }
$s.RemainingText = New-NHKUiComputed -DependsOn @($s.Remaining) -Data $s -Compute { param($s) '{0} characters left' -f $s.Remaining.Value }
$s.TooLong = New-NHKUiComputed -DependsOn @($s.Remaining) -Data $s -Compute { param($s) $s.Remaining.Value -lt 0 }
$s.TooLongText = New-NHKUiComputed -DependsOn @($s.Remaining) -Data $s -Compute { param($s) 'Too long by {0} characters.' -f (-$s.Remaining.Value) }
$s.CannotSend = New-NHKUiComputed -DependsOn @($s.Message, $s.Remaining) -Data $s -Compute {
    param($s) (-not ([string]$s.Message.Value).Trim()) -or $s.Remaining.Value -lt 0
}
$s.Preview = New-NHKUiComputed -DependsOn @($s.Message) -Data $s -Compute {
    param($s) if ($s.Message.Value) { $s.Message.Value } else { 'Nothing typed yet.' }
}
$s.NothingSent = New-NHKUiComputed -DependsOn @($s.Sent) -Data $s -Compute { param($s) @($s.Sent.Value).Count -eq 0 }
$computeds = @($s.Remaining, $s.RemainingText, $s.TooLong, $s.TooLongText, $s.CannotSend, $s.Preview, $s.NothingSent)

$ui = New-NHKUi -Title 'Message composer' -Width 700 -Height 640 -ExtraCss $css
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Compose a message' -Level 1
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $s.Recipient -Label 'To' -Placeholder 'Team channel'
        $null = Add-NHKUiInput -UI $ui -Bind $s.Message -Label 'Message' -Placeholder 'Say something'
        $null = Add-NHKUiRow -UI $ui -Content {
            $null = Add-NHKUiButton -UI $ui -Text 'Send' -DisabledState $s.CannotSend -Data $s -OnClick {
                param($eventObject, $s)
                if ($s.CannotSend.Value) { return }
                $to = ([string]$s.Recipient.Value).Trim(); if (-not $to) { $to = 'everyone' }
                $line = 'To {0}: {1}' -f $to, ([string]$s.Message.Value).Trim()
                $s.Sent.Set(@(@($line) + @($s.Sent.Value) | Select-Object -First 10))
                $s.Message.Set('')
            }
            $null = Add-NHKUiBadge -UI $ui -Bind $s.RemainingText
        }
        $null = Add-NHKUiWhen -UI $ui -Bind $s.TooLong -Content { $null = Add-NHKUiAlert -UI $ui -Bind $s.TooLongText }
    }
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Preview (escaped text)' -Level 3
        $null = Add-NHKUiText -UI $ui -Bind $s.Preview
    }
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Sent' -Level 3
        $null = Add-NHKUiWhen -UI $ui -Bind $s.NothingSent -Content { $null = Add-NHKUiText -UI $ui -Text 'No messages sent yet.' -Muted }
        $null = Add-NHKUiTextList -UI $ui -Bind $s.Sent
    }
    $null = Add-NHKUiHtml -UI $ui -Markup $help    # trusted, static, written by the developer
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    foreach ($c in $computeds) { $c.Dispose() }
    Close-NativeHTMLKit -Application $app
}
