# Theming and custom CSS

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [theming and custom CSS](../../python/guides/theming-and-custom-css.md).*

**Goal:** pick a theme and density, adjust colours, and style your own elements.

## Themes and densities

```powershell
$ui = New-NHKUi -Title 'Dashboard' -Theme graphite -Density regular -ExtraCss $css
```

- Themes: `cobalt` (dark blue, default), `graphite` (dark grey), `daylight` (light).
- Densities: `compact` (default), `regular`, `comfortable`.
- The [CSS reference](../../css.md) lists every token and class.

To see them all, run the
[`theme_preview` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/theme_preview.ps1)
with different arguments. It uses `Start-NativeHTMLKitScript -Instance multiple`, so several
previews can run side by side:

```powershell
pwsh -File ./theme_preview.ps1 cobalt compact
pwsh -File ./theme_preview.ps1 daylight comfortable '#0f7b6c'
```

## Override design tokens

`-ExtraCss` is appended after the built-in stylesheet, so the same selector wins. Override
**tokens** on `body.nhk-theme-<name>`; every component follows. From `theme_preview.ps1`:

```powershell
$css = ''
if ($Accent) { $css = "body.nhk-theme-$Theme { --nhk-accent: $Accent; --nhk-accent-strong: $Accent; --nhk-focus: $Accent; }" }
$ui = New-NHKUi -Title "Theme preview: $Theme/$Density" -Theme $Theme -Density $Density -ExtraCss $css
```

Change `--nhk-accent`, `--nhk-accent-strong` and `--nhk-focus` together and check contrast
against `--nhk-accent-text`.

## Style your own elements

The module has no generic element function, so style the structure it creates. From the
[`dashboard` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/dashboard.ps1):

```powershell
$css = @'
.nhk-card h1.nhk-heading { font-size: 30px; margin: 4px 0; }
.nhk-card { border-top: 3px solid var(--nhk-accent); }
body.nhk-theme-daylight { --nhk-accent: #0f7b6c; --nhk-accent-strong: #0b6458; --nhk-focus: #0f7b6c; }
'@
```

For your own classes, put static markup you wrote into `Add-NHKUiHtml` and style it (see
[trusted and untrusted content](trusted-and-untrusted-content.md)).

Guidelines:

- Use `var(--nhk-*)` in your own rules so they work in every theme.
- Target classes, never generated ids (they are random per run).
- Extra CSS is trusted developer input. Do not build it from user input (the preview only
  accepts an accent that matches `#RRGGBB`).
- Core renders a defined CSS subset natively (no browser engine); test layouts on your target
  desktops. See Core's [HTML/CSS support](https://github.com/nativehtmlkit/nativehtmlkit-core/blob/main/docs/guides/html-css-support.md).

## Choose the theme at start

Theme and density are fixed when the window opens. Take them from the command line (the
dashboard and theme preview), from a saved setting (the
[settings-editor tutorial](../tutorials/settings-editor.md) starts in the saved theme), or from
the desktop: read `Get-NativeHTMLKitPreferences -Application $app` before building the UI and
pick `daylight` or a dark theme. Inspect the returned object on your systems first; the UI
module does not interpret it.

## Related

[CSS reference](../../css.md) · [layouts](layouts.md) ·
[PowerShell reference: `New-NHKUi`](../reference.md#new-nhkui)
