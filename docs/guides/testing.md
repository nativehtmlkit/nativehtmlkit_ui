# Testing your UI

**Goal:** test application logic quickly, then prove it against the real native host.

## 1. Logic without a host

Most UI logic is plain state. Test it without any window:

```python
from nativehtmlkit_ui import computed, state

def test_total_follows_filter():
    expenses = state([{"category": "food", "amount": 3}, {"category": "home", "amount": 5}])
    show = state("all")
    visible = computed(lambda: [e for e in expenses.value if show.value in ("all", e["category"])])
    total = computed(lambda: sum(e["amount"] for e in visible.value))
    assert total.value == 8
    show.set("home")
    assert total.value == 5
```

`UI.html()` / `Get-NHKUiHtml` render the full document without a host, which is enough to
check structure, labels and escaping:

```python
ui = UI(title="t")
ui.text("<b>x</b>")
assert "&lt;b&gt;x&lt;/b&gt;" in ui.html()
```

This repository's own unit tests do the same with a fake SDK (`python/tests`,
`powershell/tests/Unit.Tests.ps1`).

## 2. The real host, headless

Set `NATIVEHTMLKIT_TEST_MODE=1` and start the app normally. The SDK launches the real Core host
with `--headless`: the whole protocol runs (documents load, commands apply, events can be
delivered) but no window is shown. Native input does not exist there, and services that need a
desktop (clipboard, file dialogs, opening URLs) fail with error -32001, so code paths for those
errors get exercised.

In a test you can then:

- read DOM state through the SDK: `ui.document.get_text(el.id)`, `get_value`, `get_checked`,
  `command("get_attribute", element=..., name="disabled")` (PowerShell
  `Get-NativeHTMLKitDocumentText`, `Get-NativeHTMLKitValue`, `Get-NativeHTMLKitChecked`,
  `Invoke-NativeHTMLKitDocumentCommand -Operation get_attribute`);
- wait for updates with `ui.sync()` (Python) - PowerShell writes synchronously;
- assert health: `ui.diagnostics` has no `errors`, `event_queue_dropped == 0`,
  `dom_uncertain is False`; `Get-NHKUiDiagnostics` has `Errors = 0`, `DomUncertain = $false`,
  and `Get-NativeHTMLKitDiagnosticReport` shows no `CallbackFailures`;
- end with `app.request_quit()` / `Request-NativeHTMLKitQuit` and check the process exits 0.

## 3. The example harness

`qualification/examples/run_examples.py` runs **every** example in `examples/` this way, each
through its own normal entry point (`python example.py`, `pwsh -File example.ps1`), unchanged.
A small probe records the mounted UIs, replays the scenario from
`qualification/examples/scenarios.json`, reads the DOM back, and quits:

```json
"expenses": {"steps": [
  {"op": "type", "label": "Description", "value": "Coffee"},
  {"op": "type", "label": "Amount", "value": "3.50"},
  {"op": "click", "label": "Add expense"},
  {"op": "expect_text", "contains": ["Coffee (Food): 3.50", "Total: 3.50"]},
  {"op": "expect_value", "label": "Description", "value": ""}
]}
```

Steps: `click`, `type`, `check`, `choose` (simulated events, see below), `expect_text` /
`wait_text` (visible text, skipping hidden regions), `expect_value`, `expect_disabled`,
`expect_uis`, `close_window`, `sleep`. Each step may target another window with `"ui": 1`
and the n-th matching control with `"nth"`.

```bash
# Python: an environment with the nativehtmlkit SDK and this UI installed
python qualification/examples/run_examples.py --lang py --python /path/to/venv/bin/python
# PowerShell: put the SDK module folder and ./powershell on PSModulePath
python qualification/examples/run_examples.py --lang ps --pwsh pwsh \
    --ps-module-path "/path/to/sdk-modules:$PWD/powershell"
# Windows PowerShell 5.1
python qualification\examples\run_examples.py --lang ps --pwsh powershell.exe --ps-module-path "C:\sdk-modules;%CD%\powershell"
```

Per example it requires: ready reached, all steps passed, clean UI diagnostics, (PowerShell)
no SDK callback failures, exit code 0, no traceback/exception on stderr, and no leftover
host/backend process.

**What this proves and what not.** Events are injected at the UI library's SDK callback entry
point after writing the control value with the public SDK, so the app's handlers, state,
computed values and document writes run against the real host exactly as after native input.
It does not prove native input, focus, IME, rendering or accessibility. Check those on a real
desktop (this repository's `qualification/gui/driver.py` drives a gallery app with real OS
input on KDE Plasma Wayland and Windows).

## 4. On a desktop

Run the example normally and use it. For repeatable GUI checks, drive real input with your
platform's tooling and read state back through the SDK, as `qualification/gui` does.
