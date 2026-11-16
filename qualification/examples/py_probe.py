"""Example probe (Python). Test tooling for run_examples.py, not part of the package.

usage: python py_probe.py MARKER EXAMPLE.py [ARGS...]

Runs EXAMPLE.py unchanged as ``__main__`` with ``sys.argv == [EXAMPLE.py, *ARGS]`` (so its own
``Application.start()`` launcher/backend logic runs exactly as with ``python EXAMPLE.py ARGS``;
the marker stays on the real command line, where the SDK re-runs it and the harness finds it). In the backend process it records every
``UI.mount``, and once the application is ready it executes the scenario steps from the JSON
file named by NHKUI_EXAMPLE_SPEC, writes results to NHKUI_EXAMPLE_OUT and requests an orderly quit.

Events are injected at the UI library's SDK-callback entry point (the same call the SDK event
worker makes); this proves application logic and DOM writes against the real host, not native
input. Control values are first written with the public SDK so the DOM matches the event.
"""
from __future__ import annotations

import json
import os
import runpy
import sys
import threading
import time
import traceback
from pathlib import Path

import nativehtmlkit_ui
from nativehtmlkit import Application

UIS: list = []
RESULTS: dict = {"steps": [], "ready": False, "finished": False, "shutdown": None}
_lock = threading.Lock()


def _write() -> None:
    out = os.environ.get("NHKUI_EXAMPLE_OUT")
    if not out:
        return
    with _lock:
        tmp = Path(out + ".tmp")
        tmp.write_text(json.dumps(RESULTS, indent=1, default=repr), encoding="utf-8")
        tmp.replace(out)


# ------------------------------------------------------------------------------------ tree helpers
def _walk(el, ancestors=()):
    yield el, ancestors
    for child in el.children:
        if not isinstance(child, str):
            yield from _walk(child, ancestors + (el,))


def _own_text(el) -> str:
    return "".join(c for c in el.children if isinstance(c, str)).strip()


def _control(ui, label: str, nth: int = 0) -> str:
    hits = [el.attrs["for"] for el, _ in _walk(ui.root) if el.tag == "label" and _own_text(el) == label]
    hits += [el.id for el, _ in _walk(ui.root) if el.tag == "input" and el.attrs.get("placeholder") == label]
    if len(hits) <= nth:
        raise LookupError(f"no control labelled {label!r} (#{nth})")
    return hits[nth]


def _button(ui, label: str, nth: int = 0) -> str:
    hits = [el.id for el, _ in _walk(ui.root) if el.tag == "button" and _own_text(el) == label]
    if len(hits) <= nth:
        raise LookupError(f"no button {label!r} (#{nth})")
    return hits[nth]


def _visible_text(ui) -> str:
    doc = ui.document
    parts: list[str] = []

    def visit(el):
        if "nhk-region" in str(el.attrs.get("class", "")):
            cls = doc.command("get_attribute", element=el.id, name="class").get("value") or ""
            if "nhk-hidden" in cls.split():
                return
        kids = [c for c in el.children if not isinstance(c, str)]
        if not kids or el.tag in ("select", "ul") or hasattr(el, "_trusted_html"):
            if el.tag not in ("input", "select"):
                parts.append(doc.get_text(el.id))
            return
        for child in kids:
            visit(child)
    visit(ui.root)
    return " | ".join(p for p in parts if p)


# ------------------------------------------------------------------------------------ step runner
def _event(ui, kind: str, element: str, **fields) -> None:
    ui._forward_event(kind, {"type": kind, "element": element, "path": [], **fields})
    ui.sync()


def _step(app, step: dict) -> dict:
    op = step["op"]
    ui = UIS[step.get("ui", 0)] if UIS else None
    nth = step.get("nth", 0)
    if op == "click":
        _event(ui, "click", _button(ui, step["label"], nth))
    elif op == "type":
        ident = _control(ui, step["label"], nth)
        ui.document.set_value(ident, step["value"])
        _event(ui, "input", ident, value=step["value"])
    elif op == "check":
        ident = _control(ui, step["label"], nth)
        ui.document.set_checked(ident, bool(step["value"]))
        _event(ui, "change", ident, checked=bool(step["value"]))
    elif op == "choose":
        ident = _control(ui, step["label"], nth)
        ui.document.set_value(ident, step["value"])
        _event(ui, "change", ident, value=step["value"])
    elif op in ("expect_text", "wait_text"):
        deadline = time.monotonic() + (step.get("timeout", 15) if op == "wait_text" else 0)
        while True:
            ui.sync()
            text = _visible_text(ui)
            missing = [s for s in step.get("contains", []) if s not in text]
            present = [s for s in step.get("absent", []) if s in text]
            if (not missing and not present) or time.monotonic() >= deadline:
                break
            time.sleep(0.1)
        return {"ok": not missing and not present, "missing": missing, "unexpected": present, "text": text[:1500]}
    elif op == "expect_value":
        ui.sync()
        ident = _control(ui, step["label"], nth)
        if "checked" in step:
            got = ui.document.get_checked(ident)
            return {"ok": got == step["checked"], "checked": got}
        got = ui.document.get_value(ident)
        return {"ok": got == step["value"], "value": got}
    elif op == "expect_disabled":
        ui.sync()
        got = ui.document.command("get_attribute", element=_button(ui, step["label"], nth), name="disabled").get("value")
        return {"ok": (got is not None) == step["value"], "attribute": got}
    elif op == "expect_uis":
        live = [u for u in UIS if not u.diagnostics["disposed"]]
        return {"ok": len(live) == step["count"], "live": len(live), "mounted": len(UIS)}
    elif op == "close_window":
        ui.window.request_close()
        deadline = time.monotonic() + 10
        while not ui.diagnostics["disposed"] and time.monotonic() < deadline:
            time.sleep(0.05)
        return {"ok": ui.diagnostics["disposed"], "diagnostics": ui.diagnostics}
    elif op == "sleep":
        time.sleep(step.get("seconds", 0.5))
    else:
        raise ValueError(f"unknown step {op!r}")
    return {"ok": True}


def _drive(app) -> None:
    steps = json.loads(Path(os.environ["NHKUI_EXAMPLE_SPEC"]).read_text(encoding="utf-8")) \
        if os.environ.get("NHKUI_EXAMPLE_SPEC") else []
    try:
        deadline = time.monotonic() + 10
        while not UIS and time.monotonic() < deadline:
            time.sleep(0.05)
        time.sleep(0.3)  # let mount-time writes and producers settle
        for ui in UIS:
            ui.sync()
        RESULTS["ready"] = bool(UIS)
        for step in steps:
            try:
                outcome = _step(app, step)
            except Exception as error:  # noqa: BLE001 - recorded as a failed step
                outcome = {"ok": False, "error": f"{type(error).__name__}: {error}",
                           "trace": traceback.format_exc()[-1200:]}
            RESULTS["steps"].append({"step": step, **outcome})
            if not outcome.get("ok"):
                break
        RESULTS["diagnostics"] = [u.diagnostics for u in UIS]
    except Exception as error:  # noqa: BLE001
        RESULTS["driver_error"] = f"{type(error).__name__}: {error}"
    finally:
        RESULTS["finished"] = True
        _write()
        try:
            app.request_quit()
        except Exception as error:  # noqa: BLE001
            RESULTS["quit_error"] = repr(error)
            _write()


def _install() -> None:
    original_mount = nativehtmlkit_ui.UI.mount
    original_run = Application.run

    def mount(self, app):
        result = original_mount(self, app)
        UIS.append(self)
        return result

    def run(self):
        self.ready()  # public and idempotent; the original run() calls it again

        def on_shutdown():
            RESULTS["shutdown"] = {"diagnostics": [u.diagnostics for u in UIS],
                                   "threads": sorted(t.name for t in threading.enumerate())}
            _write()
        self.on_shutdown(on_shutdown)
        threading.Thread(target=_drive, args=(self,), name="example-probe", daemon=True).start()
        return original_run(self)

    nativehtmlkit_ui.UI.mount = mount
    Application.run = run


if __name__ == "__main__":
    target = os.path.abspath(sys.argv[2])
    _install()
    # The example sees only its own arguments. The SDK rebuilds the backend command line from
    # sys.orig_argv, so the backend runs exactly "py_probe.py MARKER EXAMPLE ARGS..." again.
    sys.argv = [target, *sys.argv[3:]]
    runpy.run_path(target, run_name="__main__")
