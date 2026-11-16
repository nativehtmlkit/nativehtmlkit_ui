# CSS reference: classes, themes and tokens (UI 0.1.1)

Both libraries ship the same stylesheet (`shared/css/ui.css`, packaged as `assets/ui.css`).
It uses no JavaScript, web fonts or remote assets. The generated document is:

```html
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>...</title><style>/* ui.css */ /* your extra CSS */</style></head>
<body class="nhk-theme-cobalt nhk-density-compact"><main class="nhk-app" id="nhkui-...-1">...</main></body></html>
```

Your `extra_css` (Python) / `-ExtraCss` (PowerShell) is appended after the built-in rules in
the same `<style>` element, so a rule with equal specificity wins over the built-in one.

## Themes

The theme sets custom properties on `body.nhk-theme-<name>`:

| Token | `cobalt` | `graphite` | `daylight` | Used for |
|---|---|---|---|---|
| `--nhk-bg` | `#101824` | `#171d25` | `#f1f5fa` | Page background |
| `--nhk-panel` | `#192536` | `#222b36` | `#ffffff` | Cards |
| `--nhk-panel-2` | `#1d2b3d` | `#28333e` | `#f6f9fd` | Inputs, secondary buttons, badges, alerts |
| `--nhk-border` | `#304255` | `#3b4b5c` | `#d5deea` | Borders |
| `--nhk-text` | `#ecf3fc` | `#eff2f7` | `#203047` | Text |
| `--nhk-muted` | `#a6b9cc` | `#b1becc` | `#5a6d85` | Muted text and labels |
| `--nhk-accent` | `#69a6f3` | `#87a7ef` | `#276fca` | Primary buttons, badge text, alert edge, checkbox |
| `--nhk-accent-strong` | `#458bdf` | `#6b8ed6` | `#2365b8` | Primary button hover |
| `--nhk-accent-text` | `#0b233f` | `#121d38` | `#ffffff` | Text on accent and danger buttons |
| `--nhk-danger` | `#ed7f89` | `#eb9696` | `#bc424d` | Danger buttons |
| `--nhk-radius` | `9px` | `9px` | `9px` | Card radius |
| `--nhk-focus` | `#69a6f3` | `#87a7ef` | `#276fca` | Focus outline |
| `color-scheme` | `dark` | `dark` | `light` | Native control rendering |

## Densities

Set on `body.nhk-density-<name>`:

| Token | `compact` | `regular` | `comfortable` |
|---|---|---|---|
| `--nhk-control-h` (minimum control height) | `30px` | `36px` | `42px` |
| `--nhk-font` (base font size) | `13px` | `14px` | `15px` |
| `--nhk-gap` (row/column/grid gap) | `10px` | `13px` | `16px` |
| `--nhk-pad` (app padding) | `20px` | `25px` | `30px` |

The font stack is `Inter, "Segoe UI Variable Text", "Segoe UI", "Noto Sans", Arial, sans-serif`
(local fonts only).

## Component classes

| Class | Created by | Rules |
|---|---|---|
| `nhk-app` | root `<main>` | `padding: var(--nhk-pad)`, `max-width: 1380px`, centred. |
| `nhk-row` | `row()` / `Add-NHKUiRow` | Flex row, wrap, `align-items: center`, `gap: var(--nhk-gap)`. |
| `nhk-col` | `column()` / `Add-NHKUiColumn` | Flex column, `gap: var(--nhk-gap)`, `min-width: 0`. |
| `nhk-stack` | `stack()` (Python only) | Flex column with `gap: 6px`. |
| `nhk-grid` | `grid()` / `Add-NHKUiGrid` | `repeat(3, minmax(0, 1fr))`; 2 columns at `max-width: 1000px`; 1 column at `max-width: 620px` (also `nhk-app` padding 14 px). |
| `nhk-card` | `card()` / `Add-NHKUiCard` | `--nhk-panel` background, border, `--nhk-radius`, `padding: 16px`. |
| `nhk-heading` | headings | Weight 640; h1 24 px, h2 19 px, h3 16 px, h4 14 px. |
| `nhk-text`, `nhk-muted` | text | No margin, `overflow-wrap: anywhere`; muted uses `--nhk-muted`. |
| `nhk-badge` | badge | Pill, `--nhk-panel-2` background, accent text, 0.85 em. |
| `nhk-alert` | alert | Bordered box with a 3 px accent left border; `role="status"`. |
| `nhk-button` + `nhk-primary`/`nhk-secondary`/`nhk-danger`/`nhk-quiet` | buttons | Height `--nhk-control-h`; primary uses accent; `:disabled` has opacity 0.45. |
| `nhk-input`, `nhk-select` | input / select | `--nhk-panel-2` background; inputs are full width. |
| `nhk-field`, `nhk-label` | labelled input/select wrapper | Field is a flex column (`flex: 1 1 200px`, `min-width: 150px`); label is muted, 0.9 em. In a column the 200px basis becomes height; see [limitations](../LIMITATIONS.md) for the workaround. |
| `nhk-checkrow`, `nhk-checkbox` | checkbox | Row with 8 px gap; checkbox 16 px with `accent-color`. |
| `nhk-region`, `nhk-hidden` | `when()` / `Add-NHKUiWhen` | `nhk-hidden` is `display: none !important`. |
| `nhk-list` | text list | Left padding 20 px; items 3 px padding. |
| `nhk-custom` | `raw_html()` / `Add-NHKUiHtml` | `min-width: 0`. |
| `nhk-hr` | (style hook only) | Top border; apply it yourself, for example `ui.element("hr", css_class="nhk-hr")`. |

Focus: `.nhk-input:focus`, `.nhk-select:focus` and `.nhk-button:focus-visible` draw a 2 px
`--nhk-focus` outline with 2 px offset. `prefers-reduced-motion: reduce` disables transitions
and animations.

## Theming hooks

Override tokens for one theme, or for all, in extra CSS:

```css
body.nhk-theme-daylight { --nhk-accent: #0f7b6c; --nhk-accent-strong: #0b6458; --nhk-focus: #0f7b6c; }
/* Tokens are defined on body.nhk-theme-*; a plain `body { }` rule is less specific and loses. */
body.nhk-theme-cobalt, body.nhk-theme-graphite, body.nhk-theme-daylight { --nhk-radius: 4px; }
```

Style components by their classes (`.nhk-card { border-top: 3px solid var(--nhk-accent); }`)
or add your own classes: Python `ui.element("div", css_class="metric", text=value)` or
`ui.container("section", css_class="toolbar")`; in PowerShell, which has no generic element
function, target structure such as `.nhk-card h1.nhk-heading`. Do not rely on generated ids in
CSS; they change on every run.

The theme and density are fixed when the window is created. For a theme switch at run time,
create the UI with the chosen theme (see `examples/*/dashboard.*`) or restyle through your own
classes. The UI does not follow the desktop's light/dark preference automatically; the SDK can
read it (`Application.desktop_preferences()`, `Get-NativeHTMLKitPreferences`) before you choose
a theme.
