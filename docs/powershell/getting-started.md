# Getting started with the PowerShell UI module

`NativeHTMLKit.UI` builds native desktop windows from PowerShell with components (headings,
inputs, buttons, lists, cards, a grid) bound to reactive state. It runs on the NativeHTMLKit
native host, without a browser engine or JavaScript, and uses only the public cmdlets of the
[PowerShell SDK](https://github.com/nativehtmlkit/nativehtmlkit-powershell). This page covers
version 0.1.1. The same page for Python: [getting started](../python/getting-started.md).

## Install

You need PowerShell 7.2 or later on Linux x64 (KDE Plasma Wayland is the primary desktop) or
Windows x64, or Windows PowerShell 5.1 on Windows.

```powershell
Install-Module NativeHTMLKit.UI -Scope CurrentUser      # also installs the NativeHTMLKit SDK
Import-Module NativeHTMLKit.UI
(Get-Module NativeHTMLKit.UI).Version                    # 0.1.1
```

## Your first window

Save this as `hello.ps1` (it is the
[`hello` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/hello.ps1)):

```powershell
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Hello UI'

$name = New-NHKUiState -Value 'world'
$greeting = New-NHKUiComputed -DependsOn @($name) -Data $name -Compute { param($n) "Hello, $($n.Value)!" }

$ui = New-NHKUi -Title 'Hello UI' -Width 480 -Height 320
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Bind $greeting -Level 1
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiInput -UI $ui -Bind $name -Label 'Your name'
        $null = Add-NHKUiButton -UI $ui -Text 'Reset' -Variant secondary -Data $name -OnClick {
            param($eventObject, $n)
            $n.Set('world')
        }
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $greeting.Dispose()
    Close-NativeHTMLKit -Application $app
}
```

Run it:

```powershell
pwsh -File ./hello.ps1                        # PowerShell 7
powershell.exe -NoProfile -File .\hello.ps1    # Windows PowerShell 5.1
```

Type a name: the heading follows every keystroke. **Reset** sets the state back, and the input
follows too.

## How it works

- `New-NHKUiState` is an observable value. `Add-NHKUiInput -Bind $name` binds it both ways:
  typing sets the state, `.Set()` changes the field.
- `New-NHKUiComputed` derives a value. List the states it reads in `-DependsOn`; it receives
  `-Data` as its parameter. Dispose computed states in `finally`.
- Containers such as `Add-NHKUiColumn` take a `-Content` scriptblock; components added inside it
  become children. Assign every result to `$null`. You build the whole tree first;
  `Start-NHKUi` opens the window. After that you only change state.
- Button callbacks receive `param($eventObject, $data)`, where `$data` is the `-Data` argument,
  and change state, never the window.
- `Start-NativeHTMLKitScript` starts the native host, which runs **this same script again** as
  its backend. Everything above that line runs twice; keep side effects below it.
- `Wait-NativeHTMLKit -UntilShutdown` processes events until the window is closed; `finally`
  stops the UI and closes the connection.

## Where to go next

- Tutorials: [build an expense tracker](tutorials/expense-tracker.md), then
  [build a settings editor](tutorials/settings-editor.md).
- [How-to guides](guides/README.md): state, layouts, forms, lists, theming, background work,
  multiple windows, SDK calls, trusted content, testing.
- [Examples](examples.md): sixteen small applications, each also available in Python.
- [API reference](reference.md) and [CSS reference](../css.md).
- [Known limitations](../LIMITATIONS.md) of 0.1.1.
