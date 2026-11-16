# Verification record - NativeHTMLKit UI 0.1.0

Qualification round of 2026-11-16 (agent session b9f5b8a6). Raw evidence (results.json per run,
screenshots, app logs) is kept locally under the ignored `evidence/` directory; this file is the
checked-in summary. Counts are PASS/FAIL/BLOCKED per check.

## Tested combination

| Item | Value |
|---|---|
| UI source | this repository (see `git log`); packages from `tools/package-local.py` (reproducible) |
| Python SDK | `nativehtmlkit` 0.1.0 published wheels (manylinux_2_39_x86_64 `3073066c…`, win_amd64 `183ba566…`) |
| PowerShell SDK | `NativeHTMLKit` 0.1.0 published module zip `8e1fe37f…` |
| Core host | 1.0.2 as bundled by the SDKs: linux-x64 `702adafc…`, windows-x64 `64d4502f…`; protocol 1 |
| Linux desktop | linuxDEV, Ubuntu 26.04, KDE Plasma 6.6 / KWin 6.6.6 native Wayland, 1280x800, Python 3.14.4, PowerShell 7.7.0 |
| Windows desktop | winDEV, Windows Server 2022 (20348), interactive RDP desktop of a dedicated user, 1280x800, Python 3.13.18, PowerShell 7.7.0, Windows PowerShell 5.1.20348 |
| Input | real OS input: ydotool/uinput through KWin (Linux), SendInput (Windows) |

## Results

| Gate | Python | PowerShell |
|---|---|---|
| Boundaries (`tools/verify_boundaries.py`) | PASS | PASS (incl. no PS7-only syntax, ASCII only) |
| Unit, fake SDK | 40/0/0 (Linux 3.13; Windows 3.13 against the installed wheel) | 21/0/0 on pwsh 7.7 Linux, pwsh 7.7 Windows, Windows PowerShell 5.1 (against the unpacked module zip) |
| Smoke with the real SDK module | - | PASS pwsh 7.7 Linux, PASS 7.7 and 5.1 Windows (installed modules) |
| Real host, headless (integration only) | 18/0/0 Linux, 18/0/0 Windows | 19/0/0 Linux pwsh 7.7, 18/0/0 Windows 5.1 and 7.7 |
| **GUI KDE Wayland 100%** | **40/0/0** | **40/0/0** (pwsh 7.7) |
| **GUI KDE Wayland 125% / 150%** | **40/0/0 / 40/0/0** | **40/0/0 / 40/0/0** |
| **GUI KDE Wayland 100% IME only (fcitx5 Pinyin, S16)** | **14/0/0** | **15/0/0** (pwsh 7.7) |
| **GUI Windows 100%** | **40/0/0** | **40/0/0** PS 5.1, **40/0/0** PS 7.7 |
| **GUI Windows 125% (DPI 120)** | **40/0/0** | **40/0/0** PS 5.1, **40/0/0** PS 7.7 |
| **GUI Windows 150% (DPI 144) + Microsoft Japanese IME** | **43/0/0** | **43/0/0** PS 5.1, **43/0/0** PS 7.7 |
| Themes Graphite/Daylight (screenshots; Windows 150%, KDE 100%) | 13/0/0 each on both | - |
| Forward check: SDK 0.1.1 trees + Core 1.0.3 dev host, headless | 18/0/0 | 18/0/0 |
| Final wheel, clean venv, headless | 18/0/0 | module zip byte-identical to the GUI-tested one |

GUI checks per run: window appears and is placed; initial render; clicks update text, computed values
and the list; typing updates state with the caret kept mid-text (no echo write); 39 characters typed at
6 ms/key without loss; checkbox click hides the `when` region (`display:none`) and the `<label for>`
click restores it; Tab/Space/Down/Enter keyboard operation with a visible focus ring; programmatic
value reaches the focused input; 1000-update burst settles with no drops/errors and the window stays
responsive; disabled binding blocks real clicks; breakpoints 1300/900/620/360 px give 3/2/1/1 grid
columns; a second window updates independently and closing it through the window manager disposes
only its UI; 100 mount/close cycles leave no listeners or errors; closing the main window while
updates are pending exits with code 0, runs the shutdown hook, leaves no uncertain DOM state, no
backend stderr errors and no host process. IME runs add: composition commits into state/value/mirror
text, caret at the end, no write errors.

## Performance and loss observations (real hosts)

| Measurement | Python | PowerShell |
|---|---|---|
| 1000 state changes from outside the UI owner, until settled | 3-7 ms (coalesced: 2 updates) | 1.7-2.4 s GUI (one write per `Set`); `Invoke-NHKUiBatch`: 66-133 ms (7.x), 280-300 ms (5.1) |
| 100 window mount/close cycles | Windows 3.5-3.9 s, KDE Wayland 28-31 s | Windows 1.8-2.7 s, KDE Wayland 27-28 s |
| Real click after a burst until state changed (includes driver input time) | Windows ~0.5 s, Linux ~1.25 s (lab-click homes the pointer first) | same |
| UI event-queue drops / SDK lost notifications / callback failures | 0 / not exposed publicly by SDK 0.1.0 / 0 errors | 0 / 0 / 0 (`Get-NativeHTMLKitDiagnosticReport`) |

## Defects found and fixed in this round (all in this repository)

1. **PowerShell (critical):** every bound state change threw "Assert-NHKUiOwner is not recognized":
   `GetNewClosure()` blocks cannot see the module's private functions. The supplied module failed 15 of
   18 behaviour tests. Fixed (module-bound callbacks with context).
2. PowerShell: a computed state that writes its own dependency crashed pwsh with a stack overflow.
3. PowerShell: `Sync-NHKUi` outside a callback could be re-entered by an SDK RPC pump and write an older
   value after a newer one.
4. PowerShell: 1000 external updates took 16.3 s (3003 RPCs); now one write per outermost `Set`, plus `Invoke-NHKUiBatch`.
5. Both: writes rejected with `-32008`/`-32004` while quit/close was already in progress (seen with a
   real host) marked the DOM uncertain and logged tracebacks; now a quiet disposal.
6. Python: `on_shutdown` has no unsubscribe, so 100 mount/dispose cycles retained 100 UIs; now weak.
7. Python: event-queue overflow raised inside the SDK event worker; now counted and logged once.
8. Python: failed mount left a half-mounted UI and an open window.
9. Both: labels were rendered after their controls (label below the input); `<select>` got an invalid
   `value` attribute; list updates were outside the atomic batch.
10. Packaging: wheel not reproducible and without the licence text; module had a non-ASCII character.

## Not covered / limits

- Screen readers (Orca/NVDA) were not run against the UI. The host accessibility tree exposes the
  label-derived names (`Your name` TextInput, `Show recent events` CheckBox, `Choice` ComboBox, buttons,
  disabled state, polite live region for alerts). The open Core defect NHK-CROSS-0009 (drop-down
  `<select>` focus with Orca/NVDA) applies to `ui.select`/`Add-NHKUiSelect` unchanged.
- Multi-monitor and suspend/resume were not exercised. macOS is not a target.
- Core 1.0.2 does not clamp oversized windows at high scale; the 125/150% runs used a smaller window.
- Python SDK 0.1.0 exposes no public notification-loss counter (0.1.1 adds `host_diagnostics`).
