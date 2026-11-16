# Multiple windows and multiple UIs

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [multiple windows](../../python/guides/multiple-windows.md).*

**Goal:** open more than one window, share state between them, and handle closing.

## One UI per window

Each `New-NHKUi` object is one window. Create as many as you need from one SDK application;
they may bind the same states, and every window updates when a shared state changes (the
[`multi_window` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/multi_window.ps1)).
All UIs live on the same owner runspace.

## Open a window from a callback

```powershell
$inspector = New-NHKUi -Title 'Inspector 1' -Width 420 -Height 320 -Theme graphite
$null = Add-NHKUiColumn -UI $inspector -Content {
    $null = Add-NHKUiText -UI $inspector -Bind $s.NoteText        # same state as the main window
}
$window = Start-NHKUi -UI $inspector -Application $s.App -NoReady
[void]$s.Inspectors.Add([pscustomobject]@{ UI = $inspector; WindowId = $window.Id })
```

Start later UIs with `-NoReady` (readiness was announced by the first one; the SDK would ignore
a second call anyway). `Close-NativeHTMLKitWindow -Window $inspector.Window` asks the host to
close a window from code.

## Notice closed windows

The UI module does not watch window events itself: without a handler, a closed window's UI is
stopped on its next write (`DiscardedAfterClose`). To react immediately, handle the SDK's
`window.event` notification:

```powershell
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
```

- `Register-NativeHTMLKitNotification` holds one callback per method; combine all window-event
  handling in that one callback.
- Closing the **last** window ends the application (Core asks for quit with reason
  `last_window`).

## Limits

The Python shutdown-callback defect B-0003 does not apply: `Start-NHKUi` registers no
application shutdown callback. Still keep the number of windows bounded; the example allows
three inspectors at a time.

## Clean up

In `finally`, call `Stop-NHKUi` for every UI you started (it is idempotent) and dispose shared
computed states once, then `Close-NativeHTMLKit`.

## Related

[PowerShell reference: `Start-NHKUi`](../reference.md#start-nhkui) ·
[SDK calls](mixing-ui-and-sdk-calls.md)
