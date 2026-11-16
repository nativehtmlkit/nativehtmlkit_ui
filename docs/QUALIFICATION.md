# Qualification matrix (local agent acceptance gates)

## G0 — Source and dependency baseline

- Verify the exact local `nativehtmlkit-python` and `nativehtmlkit-powershell` checkout/API signatures against `docs/SDK_CONTRACT.md`. Uploaded ZIP snapshots may be older than live repos.
- Record SDK releases, wheel/module hashes, host Core binary SHA256, protocol version (`1.0-rc` in supplied snapshots), OS, DPI and toolchain versions.
- Verify local Project repository boundaries, per-repo versioning and **no build/test on GitHub Actions**.

## G1 — Pure logic and fake SDK

| Gate | Python | PowerShell |
|---|---|---|
| Escaping and attribute safety | `python -m pytest -q python/tests` | `powershell/tests/Smoke.ps1` |
| State and computed dependencies | same | same |
| One subscription per event kind | fake document | mocked SDK / introspect `Document.Handlers` |
| Input echo/caret prevention | fake value events | fake and native input events |
| UI changes after dispose | fake document | runspace smoke |
| Error/unknown DOM states | injected SDK faults | injected SDK faults |
| One window per UI instance | fake app | real SDK |

## G2 — Real SDK integration (Linux KDE Wayland)

Use a **real logged-in KDE Wayland session**, not Xvfb/headless/SSH-only.

1. Install the qualified native host and both SDKs; verify `doctor`/diagnostics and hashes.
2. Run `examples/python/counter.py` through the SDK module runner; assert window/title, colors, density, buttons, text and keyboard.
3. Type rapidly into the bound input, use an IME if available, move caret to center, type; verify text remains correct and caret/selection stable.
4. Toggle checkbox/visibility; verify list remains localized, no redraw of text input.
5. Run `examples/python/background.py`; confirm UI responsiveness, completion, shutdown and no late callback writes.
6. Run `examples/powershell/counter.ps1` through `pwsh` with both modules; verify same semantics.
7. Resize through 360/620/900/1300 pixel widths; verify responsive grid and overflow; capture screenshots.
8. Test 100% and 150% scaling (and 125% if supported); verify keyboard tab order, labels, focus rings and disabled/keyboard activation.
9. Exercise >1k rapid state changes and 100 UI open/dispose cycles; record elapsed time, callbacks, event loss counters, stale handles, memory trends.
10. Check graceful window close, app quit, unexpected Core disconnect, and SDK `app.shutdown`. Errors must be reported correctly without misleading success.

## G3 — Windows Server 2022 interactive desktop

- Test **Python**, **PowerShell 7**, **Windows PowerShell 5.1**, with the SDK's own bundled qualified host.
- Repeat critical G2 interactive scenarios. RDP GUI session or console is required; SSH PowerShell runs alone are not sufficient.
- Check DPI and input/focus/IME; test window resizing, two simultaneous windows, clean close and no orphan host processes.
- Note Windows PowerShell 5.1 behaviors separately; do not silently relax assertions for that edition.

## G4 — Fresh install and source-only packaging

- From a clean Python venv install the pinned `nativehtmlkit` platform wheel, then the locally built `nativehtmlkit_ui` wheel; import and run a native sample.
- From a clean PowerShell session install/point to the pinned `NativeHTMLKit` SDK module, then unpack and import the UI module; run `Smoke.ps1` and a native sample.
- Verify package contains CSS, examples and metadata as expected, but **no** Rust host executable, SDK secret, CLI, auth token, binary bridge or separate service.
- Check `dist/SHA256SUMS` and record dependency versions and source commit.

## G5 — Release eligibility

Passing tests does not authorize publication. Record exact commands, versions, hashes, screenshots and PASS/FAIL/BLOCKED outcomes. No green release status until all required Windows/Linux interactive gates are independently verified. A Core/SDK bug goes into the Project bug register with reproduction, observed/expected, impact and temporary workaround; no cross-repo opportunistic fixes.

For an agent starting from this handoff, `agent/AUTONOMOUS_FINISH_PROMPT.md` is the operational prompt.

## Harness (qualification/gui)

`qualification/gui/driver.py` runs **inside** the interactive desktop session and drives the gallery
apps (`apps/py_gallery.py`, `apps/ps_gallery.ps1`, identical controls) with real OS input. It reads
DOM/state snapshots through a private file channel and writes `results.json` (PASS/FAIL/BLOCKED per
check), screenshots and app logs. Scenarios: S3 clicks, S4 typing + mid-text caret, S5 rapid typing,
S6 checkbox and `<label for>`, S7 keyboard (Tab/Space/Down/Enter, focus ring), S9 programmatic value,
S10 1000-update burst + responsiveness, S11 breakpoints 1300/900/620/360, S12 second window + compositor
close, S13 100 mount/close cycles, S14 disabled binding, S15 close with pending updates (exit code,
backend stderr, orphan hosts), S16 IME composition (`--ime`).

```bash
# headless integration (NOT GUI evidence)
python qualification/gui/driver.py --lang py --headless --ui-src python/src --out evidence/headless-py
PSModulePath=powershell:<sdk-modules>:... python qualification/gui/driver.py --lang ps --headless --out evidence/headless-ps
# inside KDE Wayland (source ~/lab/bin/gui-env) or an interactive Windows desktop:
python qualification/gui/driver.py --lang py --python <venv-python> --out DIR [--size 760x440] [--ime]
python qualification/gui/driver.py --lang ps --pwsh pwsh|powershell.exe --out DIR
```

Input methods are enabled only around `--ime` runs and restored afterwards: `linux-ime.sh on|off STATE`
(fcitx5 Pinyin as KWin's input method) and `windows-ime.ps1 -Mode on|off -State DIR` (Microsoft Japanese
IME for the current user only). Shared lab desktops: hold the Project's per-desktop `flock` for the whole
run; the driver refuses to start when another `NHKUI-` window is on the desktop and always kills the app
tree it launched.
