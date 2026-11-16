# Testing your UI

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[testing](../../powershell/guides/testing.md).*

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

`UI.html()` renders the full document without a host, which is enough to check structure,
labels and escaping:

```python
from nativehtmlkit_ui import UI

def test_text_is_escaped():
    ui = UI(title="t")
    ui.text("<b>x</b>")
    assert "&lt;b&gt;x&lt;/b&gt;" in ui.html()
```

The library's own unit tests do the same with a fake SDK
([`python/tests`](https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/python/tests)).

## 2. The real host, headless

Set `NATIVEHTMLKIT_TEST_MODE=1` and start the app normally. The SDK launches the real Core host
in headless mode: the whole protocol runs (documents load, commands apply, events can be
delivered) but no window is shown. Native input does not exist there, and services that need a
desktop (clipboard, file dialogs, opening URLs) fail with error -32001, so code paths for those
errors get exercised.

In a test you can then:

- read DOM state through the SDK: `ui.document.get_text(el.id)`, `get_value`, `get_checked`,
  `command("get_attribute", element=..., name="disabled")`;
- wait for pending window updates with `ui.sync()`;
- assert health: `ui.diagnostics` has no `errors`, `event_queue_dropped == 0` and
  `dom_uncertain is False`;
- end with `app.request_quit()` and check the process exits 0.

## 3. The example harness

`qualification/examples/run_examples.py` runs **every** example and tutorial step listed in
[`examples/catalog.toml`](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/catalog.toml)
this way, in Python and PowerShell, each through its own normal entry point
(`python example.py [args]`), unchanged. A small probe records the mounted UIs, replays the
scenario from `qualification/examples/scenarios.json`, reads the DOM back, and quits:

```json
"expenses": {"steps": [
  {"op": "type", "label": "Description", "value": "Coffee"},
  {"op": "type", "label": "Amount", "value": "3.50"},
  {"op": "click", "label": "Add expense"},
  {"op": "expect_text", "contains": ["Coffee (Food): 3.50", "Total: 3.50"]},
  {"op": "expect_value", "label": "Description", "value": ""}
]}
```

Steps: `click`, `type`, `check`, `choose` (simulated events), `expect_text` / `wait_text`
(visible text, skipping hidden regions), `expect_value`, `expect_disabled`, `expect_uis`,
`close_window`, `sleep`. Each step may target another window with `"ui": 1` and the n-th
matching control with `"nth"`. A scenario may give `"args"` for the command line (the settings
editor gets a file name in a fresh temporary folder) and separate `"py"`/`"ps"` step lists.

```bash
# an environment with the nativehtmlkit SDK and nativehtmlkit_ui installed
python qualification/examples/run_examples.py --lang py --python /path/to/venv/bin/python
```

Per example it requires: ready reached, all steps passed, clean UI diagnostics, exit code 0, no
traceback on stderr, and no leftover host/backend process. It also fails when a catalogue entry
lacks a file in either language, a file has no scenario, or a script under `examples/` is not in
the catalogue.

**What this proves and what not.** Events are injected at the UI library's SDK callback entry
point after writing the control value with the public SDK, so the app's handlers, state,
computed values and document writes run against the real host exactly as after native input.
It does not prove native input, focus, IME, rendering or accessibility.

## 4. On a desktop

Run the example normally and use it. For repeatable GUI checks, drive real input with your
platform's tooling and read state back through the SDK, as the repository's
[`qualification/gui`](https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/qualification/gui)
driver does on KDE Plasma Wayland and Windows.

## Related

[Python reference: diagnostics](../reference.md#diagnostics) ·
[build and qualification](../../BUILD.md)
