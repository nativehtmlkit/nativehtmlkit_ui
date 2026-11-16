"""NativeHTMLKit UI qualification gallery (Python). Test tooling, not part of the package.

Run through the SDK runner:  python -m nativehtmlkit run py_gallery:main --name NHKUI
Environment:
  NHKUI_CHANNEL  directory for the driver command channel (cmd-N.json -> resp-N.json) and app.jsonl
  NHKUI_TITLE    unique window title for this run
  NHKUI_THEME    cobalt|graphite|daylight (default cobalt)
The app never logs typed values; snapshots are written only into the private channel directory.
"""
from __future__ import annotations

import json
import os
import sys
import threading
import time
import traceback
from pathlib import Path

from nativehtmlkit_ui import UI, computed, state

CHANNEL = Path(os.environ["NHKUI_CHANNEL"])
TITLE = os.environ.get("NHKUI_TITLE", "NHKUI-py")
THEME = os.environ.get("NHKUI_THEME", "cobalt")
_lock = threading.Lock()


def log(kind: str, **fields) -> None:
    with _lock, open(CHANNEL / "app.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"t": round(time.time(), 3), "kind": kind, **fields}, default=repr) + "\n")


class Gallery:
    def __init__(self, app):
        self.app = app
        self.count = state(0)
        self.name = state("")
        self.show = state(True)
        self.busy = state(False)
        self.choice = state("b")
        self.history = state(["Ready"])
        self.clicks = 0
        self.disabled_clicks = 0
        self.message = computed(lambda: f"{self.name.value or 'Nobody'}: {self.count.value} clicks")
        ui = self.ui = UI(title=TITLE, theme=THEME, density="compact", width=1000, height=700)
        ids = self.ids = {}
        with ui.column():
            ids["heading"] = ui.heading("NativeHTMLKit UI gallery", level=1).id
            ui.text("Python SDK - qualification build", muted=True)
            with ui.grid() as grid:
                ids["grid"] = grid.id
                with ui.card():
                    ui.heading("State")
                    ids["message"] = ui.text(self.message).id
                    with ui.row():
                        ids["increment"] = ui.button("Increment", on_click=self.increment).id
                        ids["reset"] = ui.button("Reset", variant="secondary",
                                                 on_click=lambda e: self.count.set(0)).id
                        ids["disabled"] = ui.button("Busy action", variant="quiet", disabled=self.busy,
                                                    on_click=self.disabled_click).id
                    ids["badge"] = ui.badge(lambda: f"{self.count.value}").id
                with ui.card():
                    ui.heading("Input")
                    ids["name"] = ui.input(self.name, label="Your name", placeholder="Type here").id
                    ids["mirror"] = ui.text(lambda: f"Mirror: {self.name.value}").id
                    ids["show"] = ui.checkbox(self.show, label="Show recent events").id
                    ids["choice"] = ui.select(self.choice, [("a", "Alpha"), ("b", "Bravo"), ("c", "Charlie")],
                                              label="Choice").id
                    ids["choice_mirror"] = ui.text(lambda: f"Choice: {self.choice.value}").id
                with ui.card():
                    ui.heading("Lists")
                    with ui.when(self.show) as region:
                        ids["region"] = region.id
                        ids["list"] = ui.text_list(self.history).id
            ids["alert"] = ui.alert(lambda: f"Native reactive updates: {self.count.value}").id
        # The label "for" target of the checkbox: the <label> right after it (click target for S6).
        ids["show_label"] = None

    def increment(self, _event) -> None:
        self.clicks += 1
        self.count.set(self.count.value + 1)
        self.history.set([f"Count became {self.count.value}", *self.history.value][:8])

    def disabled_click(self, _event) -> None:
        self.disabled_clicks += 1


def element_info(doc, ident: str) -> dict:
    info: dict = {"id": ident}
    try:
        info["rect"] = doc.command("get_rect", element=ident)
    except Exception as e:  # noqa: BLE001 - recorded
        info["rect_error"] = type(e).__name__
    return info


class Channel:
    def __init__(self, gallery: Gallery):
        self.g = gallery
        self.extra: dict[str, tuple[UI, dict]] = {}
        self.stop = threading.Event()

    def run(self) -> None:
        n = 1
        while not self.stop.is_set():
            path = CHANNEL / f"cmd-{n}.json"
            if not path.exists():
                time.sleep(0.03)
                continue
            try:
                cmd = json.loads(path.read_text(encoding="utf-8"))
            except ValueError:
                time.sleep(0.03)
                continue
            started = time.perf_counter()
            try:
                result = {"ok": True, **(getattr(self, "cmd_" + cmd["op"])(**cmd.get("args", {})) or {})}
            except Exception as e:  # noqa: BLE001 - returned to the driver
                result = {"ok": False, "error": type(e).__name__, "message": str(e)[:300],
                          "trace": traceback.format_exc()[-1500:]}
            result["ms"] = round((time.perf_counter() - started) * 1000, 1)
            tmp = CHANNEL / f"resp-{n}.tmp"
            tmp.write_text(json.dumps(result, default=repr), encoding="utf-8")
            tmp.replace(CHANNEL / f"resp-{n}.json")
            n += 1

    # -- commands -------------------------------------------------------------------------------
    def cmd_ids(self):
        return {"ids": self.g.ids, "prefix": self.g.ui.prefix}

    def cmd_rects(self, names=None):
        doc = self.g.ui.document
        ids = self.g.ids
        return {"rects": {k: element_info(doc, v).get("rect") for k, v in ids.items()
                          if v and (names is None or k in names)}}

    def cmd_snapshot(self):
        g, doc = self.g, self.g.ui.document
        ids = g.ids
        snap = {"state": {"count": g.count.value, "name": g.name.value, "show": g.show.value,
                          "busy": g.busy.value, "choice": g.choice.value, "history": g.history.value,
                          "message": g.message.value},
                "clicks": g.clicks, "disabled_clicks": g.disabled_clicks,
                "diagnostics": g.ui.diagnostics, "threads": threading.active_count()}
        texts = {}
        for key in ("message", "mirror", "choice_mirror", "alert", "badge"):
            texts[key] = doc.get_text(ids[key])
        snap["texts"] = texts
        snap["list_html"] = doc.command("get_html", element=ids["list"]).get("html")
        snap["region_class"] = doc.command("get_attribute", element=ids["region"], name="class").get("value")
        snap["disabled_attr"] = doc.command("get_attribute", element=ids["disabled"], name="disabled").get("value")
        snap["value"] = {"name": doc.get_value(ids["name"]), "choice": doc.get_value(ids["choice"])}
        snap["checked"] = {"show": doc.get_checked(ids["show"])}
        snap["focused"] = doc.focused_element()
        try:
            snap["name_selection"] = doc.control_selection(ids["name"])
        except Exception as e:  # noqa: BLE001
            snap["name_selection"] = repr(e)
        snap["grid_columns"] = doc.computed_style(["grid-template-columns"], ids["grid"])
        focused = (snap["focused"] or {}).get("element")
        if focused:
            snap["focused_outline"] = doc.computed_style(["outline-style", "outline-color"], focused)
        snap["region_display"] = doc.computed_style(["display"], ids["region"])
        snap["window"] = g.ui.window.state()
        return snap

    def cmd_set(self, name, value):
        # Deliberately from this (non-owner) thread: State marshals DOM writes to the UI owner.
        getattr(self.g, name).set(value)
        self.g.ui.sync()
        return {}

    def cmd_storm(self, n=1000, threads=1):
        g = self.g
        start = time.perf_counter()

        def work(offset):
            for i in range(n):
                g.count.set(offset + i + 1)
        workers = [threading.Thread(target=work, args=(k * n,)) for k in range(threads)]
        for w in workers:
            w.start()
        for w in workers:
            w.join()
        set_ms = (time.perf_counter() - start) * 1000
        g.ui.sync(timeout=30)
        return {"set_ms": round(set_ms, 1), "settled_ms": round((time.perf_counter() - start) * 1000, 1),
                "final": g.count.value, "diagnostics": g.ui.diagnostics}

    def cmd_storm_async(self, n=5000):
        # Start updates and return at once (used to close the window while updates are pending).
        def work():
            for i in range(n):
                try:
                    self.g.count.set(i + 1)
                except Exception as e:  # noqa: BLE001
                    log("storm_async_error", error=type(e).__name__)
                    return
                time.sleep(0.001)
        threading.Thread(target=work, daemon=True).start()
        return {}

    def cmd_resize(self, width, height=700):
        self.g.ui.window.set(width=width, height=height)
        time.sleep(0.6)
        return {"window": self.g.ui.window.state()}

    def cmd_focus(self, name):
        self.g.ui.document.focus(self.g.ids[name])
        return {}

    def cmd_open_second(self):
        text = state("second: 0")
        n = {"v": 0}
        ui = UI(title=TITLE + "-second", theme=THEME, width=520, height=360)
        with ui.column():
            ui.heading("Second window")
            t = ui.text(text)

            def bump(_e):
                n["v"] += 1
                text.set(f"second: {n['v']}")
            b = ui.button("Second +", on_click=bump)
        ui.mount(self.g.app)
        self.extra["second"] = (ui, {"button": b.id, "text": t.id})
        return {"ids": {"button": b.id, "text": t.id}}

    def cmd_second_state(self):
        ui, ids = self.extra["second"]
        out = {"diagnostics": ui.diagnostics}
        if not ui.diagnostics["disposed"]:
            out["text"] = ui.document.get_text(ids["text"])
            out["rects"] = {k: ui.document.command("get_rect", element=v) for k, v in ids.items()}
            out["window"] = ui.window.state()
        return out

    def cmd_cycle(self, n=100):
        start = time.perf_counter()
        closed = threading.Event()
        errors = []
        threads_before = threading.active_count()
        for i in range(n):
            s = state(i)
            ui = UI(title=f"{TITLE}-cycle", theme=THEME, width=400, height=260)
            ui.text(s)
            ui.button("x", on_click=lambda e: None)
            ui.mount(self.g.app)
            s.set(i + 1)
            ui.sync()
            closed.clear()
            unsub = self.g.app.on_window_event(
                lambda ev, wid=ui.window.id: closed.set() if ev.get("window_id") == wid and ev.get("type") == "closed" else None)
            ui.window.request_close()
            if not closed.wait(10):
                errors.append(f"cycle {i}: no closed event")
            unsub()
            time.sleep(0.02)
            if not ui.diagnostics["disposed"]:
                errors.append(f"cycle {i}: UI not disposed after window close")
        import gc
        gc.collect()
        return {"n": n, "ms": round((time.perf_counter() - start) * 1000, 1), "errors": errors[:10],
                "threads_before": threads_before, "threads_after": threading.active_count()}

    def cmd_quit(self):
        threading.Timer(0.2, self.g.app.request_quit).start()
        return {}


def main(app):
    CHANNEL.mkdir(parents=True, exist_ok=True)
    gallery = Gallery(app)
    gallery.ui.mount(app)
    channel = Channel(gallery)
    threading.Thread(target=channel.run, name="nhkui-channel", daemon=True).start()

    def shutdown():
        channel.stop.set()
        log("shutdown", diagnostics=gallery.ui.diagnostics, extra={k: v[0].diagnostics for k, v in channel.extra.items()})
    app.on_shutdown(shutdown)
    log("ready", title=TITLE, ids=gallery.ids, python=sys.version.split()[0])


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="NHKUI") as application:
        main(application)
        application.run()
