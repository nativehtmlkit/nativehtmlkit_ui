#!/usr/bin/env python3
"""NativeHTMLKit UI native qualification driver (test tooling, stdlib only).

Runs INSIDE the interactive desktop session (KDE Plasma Wayland: real ydotool/uinput input via KWin;
Windows: the logged-in RDP/console desktop with SendInput). Launches the Python or PowerShell
gallery app through the public SDK runner, drives it with REAL OS input, reads DOM/state snapshots
through the app's private command channel, and writes results.json (PASS/FAIL/BLOCKED per check),
screenshots and logs. --headless runs only the input-free checks in the host's headless test mode
(that is integration evidence, NOT GUI evidence).

usage: driver.py --lang py|ps --out DIR [--headless] [--python EXE] [--pwsh EXE] [--theme T]
                 [--only S1,S2,...] [--scale-label 100]
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
WINDOWS = os.name == "nt"


# ------------------------------------------------------------------------------------- desktops
class LinuxDesktop:
    KEYS = {"Enter": 28, "Escape": 1, "Tab": 15, "Alt": 56, "F4": 62, "Left": 105, "Right": 106, "Down": 108,
            "Up": 103, "Home": 102, "End": 107, "Ctrl": 29, "A": 30, "Space": 57, "Shift": 42, "Backspace": 14}

    def __init__(self):
        self.lab = Path.home() / "lab/bin"
        subprocess.run([str(self.lab / "lab-input-init")], capture_output=True, timeout=20)

    def kwin(self, js: str, wait: float = 0.4) -> list[str]:
        tag = "NHKUI" + uuid.uuid4().hex[:8]
        path = Path(tempfile.gettempdir()) / f"kwin-{tag}.js"
        path.write_text(js.replace("OUT(", f"print('{tag} ' + "))
        since = time.strftime("%Y-%m-%d %H:%M:%S")
        number = subprocess.check_output(["qdbus6", "org.kde.KWin", "/Scripting",
                                          "org.kde.kwin.Scripting.loadScript", str(path), tag], text=True).strip()
        subprocess.run(["qdbus6", "org.kde.KWin", f"/Scripting/Script{number}", "org.kde.kwin.Script.run"],
                       capture_output=True, check=True)
        time.sleep(wait)
        subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", tag],
                       capture_output=True)
        path.unlink(missing_ok=True)
        out = subprocess.run(["journalctl", "--user", "-q", "--since", since, "-o", "cat", "--no-pager"],
                             capture_output=True, text=True).stdout
        return [line.split(tag + " ", 1)[1] for line in out.splitlines() if tag + " " in line]

    def windows(self) -> list[dict]:
        lines = self.kwin(r"""var ws = workspace.windowList(); var r = [];
for (var i = 0; i < ws.length; i++) { var w = ws[i]; if (!w.normalWindow && !w.dialog) continue;
 r.push({caption: w.caption, pid: w.pid, x: w.frameGeometry.x, y: w.frameGeometry.y, w: w.frameGeometry.width,
 h: w.frameGeometry.height, cx: w.clientGeometry.x, cy: w.clientGeometry.y, cw: w.clientGeometry.width,
 ch: w.clientGeometry.height, active: w.active}); }
OUT(JSON.stringify(r));""")
        return json.loads(lines[-1]) if lines else []

    def scale(self) -> float:
        lines = self.kwin("var o = workspace.screens; var r=[]; for (var i=0;i<o.length;i++) r.push(o[i].devicePixelRatio);"
                          " OUT(JSON.stringify(r));")
        try:
            return float(json.loads(lines[-1])[0])
        except (ValueError, IndexError):
            return 1.0

    def activate(self, title: str) -> None:
        self.kwin("var ws = workspace.windowList(); for (var i=0;i<ws.length;i++){ if (ws[i].caption.indexOf(%s)>=0)"
                  "{ workspace.activeWindow = ws[i]; OUT('ok'); break; } }" % json.dumps(title), wait=0.3)

    def place(self, title: str, x: int, y: int) -> None:
        self.kwin("var ws = workspace.windowList(); for (var i=0;i<ws.length;i++){ if (ws[i].caption.indexOf(%s)>=0)"
                  "{ var g = ws[i].frameGeometry; ws[i].frameGeometry = {x:%d, y:%d, width:g.width, height:g.height};"
                  " OUT('ok'); break; } }" % (json.dumps(title), x, y), wait=0.4)

    def click(self, x: float, y: float) -> None:
        subprocess.run([str(self.lab / "lab-click"), str(int(round(x))), str(int(round(y)))], check=True, timeout=20)
        time.sleep(0.35)

    def type(self, text: str, delay_ms: int = 40) -> None:
        subprocess.run(["ydotool", "type", "-d", str(delay_ms), "--", text], check=True, capture_output=True, timeout=60)
        time.sleep(0.4)

    def key(self, *names: str) -> None:
        codes = [self.KEYS[n] for n in names]
        subprocess.run(["ydotool", "key", *[f"{c}:1" for c in codes], *[f"{c}:0" for c in reversed(codes)]],
                       check=True, capture_output=True, timeout=20)
        time.sleep(0.25)

    def close(self, title: str) -> None:
        self.kwin("var ws = workspace.windowList(); for (var i=0;i<ws.length;i++){ if (ws[i].caption.indexOf(%s)>=0)"
                  "{ ws[i].closeWindow(); OUT('ok'); break; } }" % json.dumps(title), wait=0.3)

    # IME (fcitx5 must already be KWin's Wayland input method; the runner enables and restores it)
    IME = {"engine": "fcitx5 pinyin", "keys": "nihao", "commit_keys": ["Space"], "committed": "\u4f60\u597d"}

    def ime_available(self) -> bool:
        return subprocess.run(["fcitx5-remote"], capture_output=True).returncode == 0

    def ime_on(self) -> None:
        subprocess.run(["fcitx5-remote", "-o"], capture_output=True, timeout=10)
        time.sleep(0.4)

    def ime_off(self) -> None:
        subprocess.run(["fcitx5-remote", "-c"], capture_output=True, timeout=10)
        time.sleep(0.4)

    def type_composed(self, text: str) -> None:
        self.type(text, delay_ms=90)

    def screenshot(self, path: Path) -> bool:
        subprocess.run(["spectacle", "-b", "-n", "-f", "-o", str(path)], capture_output=True, timeout=30)
        return path.exists() and path.stat().st_size > 0

    def client_point(self, window: dict, x: float, y: float, scale: float) -> tuple[float, float]:
        return window["cx"] + x, window["cy"] + y  # KWin logical coordinates == CSS px

    def host_processes(self) -> list[str]:
        out = subprocess.run(["pgrep", "-af", "nativehtmlkit-host"], capture_output=True, text=True).stdout
        return [line for line in out.splitlines() if line.strip()]


class WindowsDesktop:
    VK = {"Enter": 0x0D, "Escape": 0x1B, "Tab": 0x09, "Alt": 0x12, "F4": 0x73, "Left": 0x25, "Right": 0x27,
          "Down": 0x28, "Up": 0x26, "Home": 0x24, "End": 0x23, "Ctrl": 0x11, "A": 0x41, "Space": 0x20,
          "Shift": 0x10, "Backspace": 0x08, "IME_ON": 0x16, "IME_OFF": 0x1A}
    EXTENDED = {0x25, 0x26, 0x27, 0x28, 0x24, 0x23}
    IME = {"engine": "Microsoft IME (Japanese)", "keys": "nihonn", "commit_keys": ["Space", "Enter"],
           "committed": "\u65e5\u672c"}

    def ime_available(self) -> bool:
        return True  # the runner adds ja-JP to this user's input languages (lab-ime.ps1)

    def _lang(self, klid: str) -> None:
        u, wt = self.user32, self.wt
        u.LoadKeyboardLayoutW.restype = wt.HKL
        u.LoadKeyboardLayoutW.argtypes = [wt.LPCWSTR, wt.UINT]
        hkl = u.LoadKeyboardLayoutW(klid, 0)
        u.GetForegroundWindow.restype = wt.HWND
        u.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, self.ctypes.c_void_p]
        u.PostMessageW(u.GetForegroundWindow(), 0x0050, 0, hkl)  # WM_INPUTLANGCHANGEREQUEST
        time.sleep(0.6)

    def ime_on(self) -> None:
        self._lang("00000411")
        self.key("IME_ON")
        time.sleep(0.5)

    def ime_off(self) -> None:
        self.key("IME_OFF")
        time.sleep(0.3)
        self._lang("00000409")

    def type_composed(self, text: str) -> None:
        """Real virtual keys for ASCII letters, so the IME composes them (KEYEVENTF_UNICODE bypasses it)."""
        for char in text:
            vk = ord(char.upper())
            self._send(self._key(vk=vk), self._key(vk=vk, flags=0x0002))
            time.sleep(0.09)
        time.sleep(0.5)

    def __init__(self):
        import ctypes
        from ctypes import wintypes
        self.ctypes, self.wt = ctypes, wintypes
        self.user32 = ctypes.WinDLL("user32", use_last_error=True)
        try:
            self.user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))  # per-monitor v2: physical pixels
        except AttributeError:
            pass
        u = self.user32
        u.GetWindowTextLengthW.argtypes = [wintypes.HWND]
        u.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
        u.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
        u.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
        u.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
        u.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
        u.IsWindowVisible.argtypes = [wintypes.HWND]
        u.GetDpiForWindow.argtypes = [wintypes.HWND]
        u.SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                   ctypes.c_int, wintypes.UINT]

        class MOUSEINPUT(ctypes.Structure):
            _fields_ = [("dx", ctypes.c_long), ("dy", ctypes.c_long), ("mouseData", wintypes.DWORD),
                        ("dwFlags", wintypes.DWORD), ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]

        class KEYBDINPUT(ctypes.Structure):
            _fields_ = [("wVk", wintypes.WORD), ("wScan", wintypes.WORD), ("dwFlags", wintypes.DWORD),
                        ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]

        class UNION(ctypes.Union):
            _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("pad", ctypes.c_byte * 32)]

        class INPUT(ctypes.Structure):
            _fields_ = [("type", wintypes.DWORD), ("u", UNION)]
        self.INPUT = INPUT
        u.SendInput.argtypes = [wintypes.UINT, ctypes.POINTER(INPUT), ctypes.c_int]

    def _send(self, *inputs) -> None:
        array = (self.INPUT * len(inputs))(*inputs)
        sent = self.user32.SendInput(len(inputs), array, self.ctypes.sizeof(self.INPUT))
        if sent != len(inputs):
            raise OSError(f"SendInput delivered {sent}/{len(inputs)} (error {self.ctypes.get_last_error()})")

    def _mouse(self, flags, x=0, y=0):
        item = self.INPUT(type=0)
        if flags & 0x8000:
            vx, vy = self.user32.GetSystemMetrics(76), self.user32.GetSystemMetrics(77)
            vw, vh = self.user32.GetSystemMetrics(78), self.user32.GetSystemMetrics(79)
            item.u.mi.dx = int(round((x - vx) * 65535 / max(vw - 1, 1)))
            item.u.mi.dy = int(round((y - vy) * 65535 / max(vh - 1, 1)))
            flags |= 0x4000
        item.u.mi.dwFlags = flags
        return item

    def click(self, x, y):
        self._send(self._mouse(0x0001 | 0x8000, x, y))
        time.sleep(0.05)
        self._send(self._mouse(0x0002), self._mouse(0x0004))
        time.sleep(0.35)

    def _key(self, vk=0, scan=0, flags=0):
        item = self.INPUT(type=1)
        item.u.ki.wVk, item.u.ki.wScan, item.u.ki.dwFlags = vk, scan, flags
        return item

    def type(self, text, delay_ms: int = 40):
        for char in text:
            code = ord(char)
            self._send(self._key(scan=code, flags=0x0004), self._key(scan=code, flags=0x0004 | 0x0002))
            time.sleep(delay_ms / 1000.0)
        time.sleep(0.4)

    def key(self, *names):
        codes = [self.VK[n] for n in names]
        ext = lambda c: 0x0001 if c in self.EXTENDED else 0  # noqa: E731
        self._send(*[self._key(vk=c, flags=ext(c)) for c in codes],
                   *[self._key(vk=c, flags=ext(c) | 0x0002) for c in reversed(codes)])
        time.sleep(0.25)

    def windows(self):
        ctypes, wt = self.ctypes, self.wt
        found = []

        @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
        def callback(hwnd, _):
            if not self.user32.IsWindowVisible(hwnd):
                return True
            length = self.user32.GetWindowTextLengthW(hwnd)
            title = ctypes.create_unicode_buffer(length + 1)
            self.user32.GetWindowTextW(hwnd, title, length + 1)
            rect, client, origin, pid = wt.RECT(), wt.RECT(), wt.POINT(0, 0), wt.DWORD()
            self.user32.GetWindowRect(hwnd, ctypes.byref(rect))
            self.user32.GetClientRect(hwnd, ctypes.byref(client))
            self.user32.ClientToScreen(hwnd, ctypes.byref(origin))
            self.user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if title.value:
                found.append({"caption": title.value, "pid": pid.value, "hwnd": int(hwnd or 0),
                              "x": rect.left, "y": rect.top, "w": rect.right - rect.left, "h": rect.bottom - rect.top,
                              "cx": origin.x, "cy": origin.y, "cw": client.right, "ch": client.bottom,
                              "dpi": self.user32.GetDpiForWindow(hwnd)})
            return True
        self.user32.EnumWindows(callback, 0)
        return found

    def scale(self) -> float:
        return 1.0  # per window: see client_point

    def activate(self, title):
        window = next((w for w in self.windows() if title in w["caption"]), None)
        if window:  # a real click on the caption (SetForegroundWindow is refused for background processes)
            self.click(window["x"] + window["w"] // 2, window["y"] + max(8, (window["cy"] - window["y"]) // 2))

    def place(self, title, x, y):
        window = next((w for w in self.windows() if title in w["caption"]), None)
        if window:
            self.user32.SetWindowPos(window["hwnd"], None, x, y, 0, 0, 0x0001 | 0x0004 | 0x0010)
            time.sleep(0.4)

    def close(self, title):
        self.activate(title)
        time.sleep(0.3)
        self.key("Alt", "F4")

    def screenshot(self, path: Path) -> bool:
        script = ("Add-Type -AssemblyName System.Windows.Forms,System.Drawing; "
                  "$b=[System.Windows.Forms.SystemInformation]::VirtualScreen; "
                  "$i=New-Object System.Drawing.Bitmap $b.Width,$b.Height; $g=[System.Drawing.Graphics]::FromImage($i); "
                  "$g.CopyFromScreen($b.Left,$b.Top,0,0,$i.Size); $i.Save('%s'); $g.Dispose(); $i.Dispose()") % str(path)
        subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True, timeout=60)
        return path.exists() and path.stat().st_size > 0

    def client_point(self, window, x, y, scale):
        factor = (window.get("dpi") or 96) / 96.0
        return window["cx"] + x * factor, window["cy"] + y * factor

    def host_processes(self) -> list[str]:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq nativehtmlkit-host.exe", "/FO", "CSV", "/NH"],
                             capture_output=True, text=True).stdout
        return [line for line in out.splitlines() if "nativehtmlkit-host" in line]


class Headless:
    """No desktop: input checks are BLOCKED, everything else runs against the headless host."""
    def windows(self):
        return []

    def host_processes(self):
        return LinuxDesktop.host_processes(self) if not WINDOWS else WindowsDesktop.host_processes(self)

    def screenshot(self, path):
        return False


# ------------------------------------------------------------------------------------- harness
class Run:
    def __init__(self, args):
        self.args = args
        self.out = Path(args.out).resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        self.results: list[dict] = []
        self.channel = Path(tempfile.mkdtemp(prefix="nhkui-ch-"))
        self.title = f"NHKUI-{args.lang}-{uuid.uuid4().hex[:6]}"
        self.n = 0
        self.proc = None
        self.desktop = Headless() if args.headless else (WindowsDesktop() if WINDOWS else LinuxDesktop())
        self.ids: dict = {}

    # results
    def check(self, name: str, ok, **detail) -> bool:
        status = "PASS" if ok else "FAIL"
        self.results.append({"check": name, "status": status, **detail})
        print(f"{status} {name} {json.dumps(detail, default=repr)[:400]}", flush=True)
        return bool(ok)

    def blocked(self, name: str, reason: str) -> None:
        self.results.append({"check": name, "status": "BLOCKED", "reason": reason})
        print(f"BLOCKED {name} {reason}", flush=True)

    # app control
    def launch(self) -> None:
        env = dict(os.environ)
        env.update({"NHKUI_CHANNEL": str(self.channel), "NHKUI_TITLE": self.title, "NHKUI_THEME": self.args.theme,
                    "NHKUI_SIZE": self.args.size})
        if self.args.headless:
            env["NATIVEHTMLKIT_TEST_MODE"] = "1"
            env["UI4ME_TEST_MODE"] = "1"
        apps = HERE / "apps"
        if self.args.lang == "py":
            env["PYTHONPATH"] = os.pathsep.join(p for p in [str(apps), self.args.ui_src or "", env.get("PYTHONPATH", "")] if p)
            argv = [self.args.python, "-m", "nativehtmlkit", "run", "py_gallery:main", "--name", "NHKUI"]
        else:
            argv = [self.args.pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(apps / "ps_gallery.ps1")] \
                if WINDOWS else [self.args.pwsh, "-NoProfile", "-File", str(apps / "ps_gallery.ps1")]
        self.stdout = open(self.out / "app-stdout.log", "w")
        self.stderr = open(self.out / "app-stderr.log", "w")
        flags = 0x08000000 if WINDOWS else 0  # CREATE_NO_WINDOW: no console window over the app
        self.started = time.monotonic()
        self.proc = subprocess.Popen(argv, cwd=str(apps), env=env, stdout=self.stdout, stderr=self.stderr,
                                     stdin=subprocess.DEVNULL, creationflags=flags, start_new_session=not WINDOWS)
        (self.out / "command.json").write_text(json.dumps({"argv": argv, "title": self.title}, indent=1))

    def call(self, op: str, timeout: float = 60, **args) -> dict:
        self.n += 1
        tmp = self.channel / f"cmd-{self.n}.tmp"
        tmp.write_text(json.dumps({"op": op, "args": args}), encoding="utf-8")
        tmp.replace(self.channel / f"cmd-{self.n}.json")
        resp = self.channel / f"resp-{self.n}.json"
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if resp.exists():
                try:
                    return json.loads(resp.read_text(encoding="utf-8"))
                except ValueError:
                    pass
            if self.proc.poll() is not None:
                return {"ok": False, "error": "app exited", "code": self.proc.returncode}
            time.sleep(0.03)
        return {"ok": False, "error": "timeout", "op": op}

    def wait_ready(self) -> bool:
        deadline = time.monotonic() + 60
        log = self.channel / "app.jsonl"
        while time.monotonic() < deadline:
            if log.exists() and '"ready"' in log.read_text(encoding="utf-8"):
                return True
            if self.proc.poll() is not None:
                return False
            time.sleep(0.1)
        return False

    def window(self, title=None) -> dict | None:
        title = title or self.title
        for _ in range(40):
            hits = [w for w in self.desktop.windows() if w["caption"] == title or w["caption"].startswith(title + " ")
                    or w["caption"] == title]
            if hits:
                return hits[0]
            time.sleep(0.25)
        return None

    def point(self, name: str, dx: float = 0.5, dy: float = 0.5, rects=None, title=None) -> tuple[float, float]:
        rects = rects or self.call("rects")["rects"]
        r = rects[name]
        r = r.get("rect", r)
        win = self.window(title)
        x = r["x"] + r["width"] * dx if dx <= 1 else r["x"] + dx
        y = r["y"] + r["height"] * dy
        return self.desktop.client_point(win, x, y, 1.0)

    def click(self, name: str, **kw) -> None:
        x, y = self.point(name, **kw)
        self.desktop.click(x, y)

    def snap(self) -> dict:
        s = self.call("snapshot")
        return s

    def shot(self, label: str) -> None:
        if not self.args.headless:
            path = self.out / f"{label}.png"
            ok = self.desktop.screenshot(path)
            if ok:
                self.results.append({"check": f"screenshot.{label}", "status": "INFO", "path": path.name})

    def wait_for(self, predicate, timeout=5.0, interval=0.15):
        deadline = time.monotonic() + timeout
        last = None
        while time.monotonic() < deadline:
            last = self.snap()
            try:
                if last.get("ok") and predicate(last):
                    return True, last
            except (KeyError, TypeError, IndexError):
                pass
            time.sleep(interval)
        return False, last

    # ------------------------------------------------------------------------------- scenarios
    def run(self) -> int:
        only = set(self.args.only.split(",")) if self.args.only else None
        want = lambda s: only is None or s in only  # noqa: E731
        if not self.args.headless:
            foreign = [w["caption"] for w in self.desktop.windows() if w["caption"].startswith("NHKUI-")]
            if foreign:
                self.blocked("preflight.no_foreign_test_windows", f"foreign test windows on this desktop: {foreign}")
                return self.finish()
        self.launch()
        if not self.check("app.ready", self.wait_ready(), seconds=round(time.monotonic() - self.started, 2)):
            return self.finish()
        ids = self.call("ids")
        self.ids = ids.get("ids", {})
        self.check("ids.unique_prefixed", len(set(self.ids.values()) - {None}) == len([v for v in self.ids.values() if v])
                   and all(v.startswith(ids.get("prefix", "?")) for v in self.ids.values() if v), prefix=ids.get("prefix"))
        gui = not self.args.headless
        if gui:
            win = self.window()
            if not self.check("gui.window_appears", win is not None, title=self.title):
                return self.finish()
            self.desktop.place(self.title, 40, 30)
            self.desktop.activate(self.title)
            win = self.window()
            self.check("gui.window_geometry", win is not None, window=win, scale=self.desktop.scale())
            time.sleep(0.6)
            self.shot("01-initial")
        s0 = self.snap()
        self.check("dom.initial_render", s0.get("ok") and s0["texts"]["message"] == "Nobody: 0 clicks"
                   and s0["value"]["choice"] == "b" and s0["checked"]["show"] is True, snapshot=s0)
        self.check("dom.no_errors_after_mount", s0.get("ok") and not _diag(s0, "errors")
                   and not _diag(s0, "dom_uncertain"), diagnostics=s0.get("diagnostics"))

        try:
            self.scenarios(gui, want)
        except Exception as error:  # noqa: BLE001 - a driver/app failure is a FAIL with evidence
            import traceback
            self.check("driver.scenario_exception", False, error=type(error).__name__, message=str(error)[:300],
                       trace=traceback.format_exc()[-1500:])
        # S15: close the main window while updates are pending -> orderly exit, no orphans
        if want("S15"):
            self.call("storm_async", n=5000)
            time.sleep(0.3)
            if gui:
                self.desktop.close(self.title)
            else:
                self.call("quit")
        else:
            self.call("quit")
        try:
            code = self.proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            code = "killed"
        self.check("lifecycle.orderly_exit_code_0", code == 0, code=code)
        time.sleep(1.5)
        log = (self.channel / "app.jsonl").read_text(encoding="utf-8") if (self.channel / "app.jsonl").exists() else ""
        shutdown = [json.loads(line) for line in log.splitlines() if '"shutdown"' in line]
        diag = shutdown[-1]["diagnostics"] if shutdown else {}
        self.check("lifecycle.shutdown_hook_ran", bool(shutdown), diagnostics=diag)
        sdk = shutdown[-1].get("sdk") if shutdown else None
        if sdk:  # PowerShell SDK public counters (Get-NativeHTMLKitDiagnosticReport)
            self.check("sdk.no_lost_notifications_or_callback_failures",
                       not sdk.get("DroppedNotifications") and not sdk.get("DeferredDropped")
                       and not sdk.get("CallbackFailures"), sdk=sdk)
        self.check("lifecycle.no_dom_uncertain_after_close_with_pending_updates",
                   bool(shutdown) and not _get(diag, "dom_uncertain", "DomUncertain"),
                   diagnostics=diag)
        stderr = (self.out / "app-stderr.log").read_text(errors="replace")
        bad = [line for line in stderr.splitlines() if any(k in line for k in ("Traceback", "Exception", "FAILED", "failed"))]
        self.check("lifecycle.no_errors_in_backend_stderr", not bad, lines=bad[:8])
        leftovers = [p for p in self.desktop.host_processes() if self.title in p or str(self.proc.pid) in p]
        self.check("lifecycle.no_orphan_host_process", not leftovers, leftovers=leftovers)
        return self.finish()

    def scenarios(self, gui: bool, want) -> None:
        if gui and want("S3"):
            for _ in range(3):
                self.click("increment")
            ok, s = self.wait_for(lambda s: s["texts"]["message"].endswith("3 clicks"))
            self.check("gui.click_updates_text", ok, texts=s and s.get("texts"), clicks=s and s.get("clicks"))
            self.check("gui.click_updates_list_and_computed",
                       ok and s["texts"]["alert"].endswith(": 3") and "Count became 3" in (s["list_html"] or "")
                       and s["texts"]["badge"] == "3", list_html=s and s.get("list_html"))
            self.shot("03-after-clicks")
        if gui and want("S4"):
            self.click("name", dx=0.5)
            self.desktop.key("Ctrl", "A")
            self.desktop.type("hello world")
            for _ in range(5):
                self.desktop.key("Left")
            self.desktop.type("X")
            ok, s = self.wait_for(lambda s: s["state"]["name"] == "hello Xworld")
            sel = (s or {}).get("name_selection") or {}
            self.check("gui.typing_updates_state", ok and s["value"]["name"] == "hello Xworld"
                       and s["texts"]["mirror"] == "Mirror: hello Xworld", value=s and s.get("value"),
                       state=s and s["state"]["name"])
            self.check("gui.caret_stable_mid_text_edit", ok and isinstance(sel, dict) and sel.get("start") == 7
                       and sel.get("end") == 7, selection=sel)
            self.check("gui.no_echo_write_while_typing", ok and not _diag(s, "errors"),
                       diagnostics=s and s.get("diagnostics"))
            self.shot("04-typed")
        if gui and want("S5"):
            self.click("name", dx=0.5)
            self.desktop.key("Ctrl", "A")
            fast = "Quick brown fox jumps over 13 lazy dogs"
            self.desktop.type(fast, delay_ms=6)
            ok, s = self.wait_for(lambda s: s["state"]["name"] == fast, timeout=8)
            self.check("gui.rapid_typing_no_loss", ok and s["value"]["name"] == fast,
                       state=s and s["state"]["name"], value=s and s["value"]["name"])
        if gui and want("S6"):
            self.click("show", dx=0.5)
            ok, s = self.wait_for(lambda s: s["state"]["show"] is False)
            self.check("gui.checkbox_click_hides_region", ok and "nhk-hidden" in (s["region_class"] or "")
                       and s["region_display"]["properties"]["display"]["value"] == "none",
                       region_class=s and s.get("region_class"))
            self.shot("06-hidden")
            # The <label for> follows the checkbox; click its text.
            self.click("show", dx=40)
            ok, s = self.wait_for(lambda s: s["state"]["show"] is True)
            self.check("gui.label_click_toggles_checkbox", ok and s["checked"]["show"] is True
                       and "nhk-hidden" not in (s["region_class"] or ""), region_class=s and s.get("region_class"))
        if gui and want("S7"):
            self.click("name", dx=0.5)
            self.desktop.key("Tab")
            ok, s = self.wait_for(lambda s: (s["focused"] or {}).get("element") == self.ids["show"], timeout=3)
            self.check("gui.tab_moves_focus_to_checkbox", ok, focused=s and s.get("focused"))
            self.desktop.key("Space")
            ok, s = self.wait_for(lambda s: s["state"]["show"] is False, timeout=3)
            self.check("gui.space_toggles_checkbox", ok, show=s and s["state"]["show"])
            self.desktop.key("Space")
            self.desktop.key("Tab")
            ok, s = self.wait_for(lambda s: (s["focused"] or {}).get("element") == self.ids["choice"], timeout=3)
            self.check("gui.tab_reaches_select", ok, focused=s and s.get("focused"))
            self.check("gui.focus_ring_visible", ok and (s.get("focused_outline") or {}).get("properties", {})
                       .get("outline-style", {}).get("value") == "solid", outline=s and s.get("focused_outline"))
            self.desktop.key("Down")
            ok, s = self.wait_for(lambda s: s["state"]["choice"] == "c", timeout=3)
            self.check("gui.keyboard_select_change", ok and s["texts"]["choice_mirror"] == "Choice: c",
                       choice=s and s["state"]["choice"], value=s and s["value"]["choice"])
            # Keyboard activation of a button: focus Increment programmatically, press Enter.
            before = (s or {}).get("state", {}).get("count", 0)
            self.call("focus", name="increment")
            self.desktop.key("Enter")
            ok, s = self.wait_for(lambda s: s["state"]["count"] == before + 1, timeout=3)
            self.check("gui.enter_activates_button", ok, count=s and s["state"]["count"], before=before)
            self.shot("07-keyboard")
        if gui and want("S16") and self.args.ime:
            ime = self.desktop.IME
            self.click("name", dx=0.5)
            self.desktop.key("Ctrl", "A")
            self.desktop.type("abc ")
            self.desktop.ime_on()
            self.desktop.type_composed(ime["keys"])
            self.shot("16-ime-preedit")
            mid = self.snap()
            for k in ime["commit_keys"]:
                self.desktop.key(k)
                time.sleep(0.4)
            self.desktop.ime_off()
            self.desktop.type(" xyz")
            want_value = "abc " + ime["committed"] + " xyz"
            ok, s = self.wait_for(lambda s: s["state"]["name"] == want_value, timeout=6)
            sel = (s or {}).get("name_selection") or {}
            self.check("gui.ime_composition_commits_into_state", ok and s["value"]["name"] == want_value
                       and s["texts"]["mirror"] == "Mirror: " + want_value, engine=ime["engine"],
                       expected=want_value, value=s and s["value"]["name"], state=s and s["state"]["name"],
                       mid_composition_value=mid.get("value", {}).get("name"))
            self.check("gui.ime_caret_at_end_after_commit", ok and isinstance(sel, dict)
                       and sel.get("start") == len(want_value.encode("utf-16-le")) // 2, selection=sel)
            self.check("gui.ime_no_write_errors", ok and not _diag(s, "errors") and not _diag(s, "dom_uncertain"),
                       diagnostics=s and s.get("diagnostics"))
            self.shot("16-ime-committed")
        # programmatic updates while the control has focus (echo path)
        if want("S9"):
            if gui:
                self.click("name", dx=0.5)
            r = self.call("set", name="name", value="programmatic")
            ok, s = self.wait_for(lambda s: s["value"]["name"] == "programmatic")
            self.check("dom.programmatic_value_reaches_control", r.get("ok") and ok
                       and s["texts"]["mirror"] == "Mirror: programmatic", value=s and s["value"])
        if want("S10"):
            r = self.call("storm", n=1000, timeout=120)
            ok, s = self.wait_for(lambda s: s["texts"]["badge"] == str(r.get("final")), timeout=20)
            self.check("load.1000_updates_settle", r.get("ok") and ok and s["texts"]["alert"].endswith(str(r["final"])),
                       set_ms=r.get("set_ms"), settled_ms=r.get("settled_ms"), batched_ms=r.get("batched_ms"),
                       final=r.get("final"),
                       diagnostics=r.get("diagnostics"))
            self.check("load.no_drops_no_errors", ok and _diag(s, "event_queue_dropped", 0) == 0
                       and not _diag(s, "errors"), diagnostics=s and s.get("diagnostics"))
            if gui:
                before = s["state"]["count"]
                t0 = time.monotonic()
                self.click("increment")
                ok, s = self.wait_for(lambda s: s["state"]["count"] == before + 1, timeout=5, interval=0.05)
                self.check("load.responsive_after_burst", ok, click_to_state_s=round(time.monotonic() - t0, 3))
        if want("S14"):
            self.call("set", name="busy", value=True)
            ok, s = self.wait_for(lambda s: s["disabled_attr"] is not None)
            self.check("dom.disabled_binding_sets_attribute", ok, disabled_attr=s and s.get("disabled_attr"))
            if gui:
                self.click("disabled")
                time.sleep(0.5)
                s = self.snap()
                self.check("gui.disabled_button_ignores_click", s["disabled_clicks"] == 0, disabled_clicks=s["disabled_clicks"])
            self.call("set", name="busy", value=False)
            ok, s = self.wait_for(lambda s: s["disabled_attr"] is None)
            self.check("dom.disabled_binding_removes_attribute", ok)
            if gui:
                self.click("disabled")
                ok, s = self.wait_for(lambda s: s["disabled_clicks"] == 1)
                self.check("gui.enabled_button_clicks", ok)
        if want("S11"):
            widths = {}
            for w in (1300, 900, 620, 360):
                r = self.call("resize", width=w, height=700 if w > 400 else 640)
                time.sleep(0.5)
                s = self.snap()
                widths[w] = s.get("grid_columns", {}).get("properties", {}).get("grid-template-columns", {}).get("value")
                if gui:
                    self.shot(f"11-width-{w}")
            expect = {1300: "repeat(3", 900: "repeat(2", 620: "1fr", 360: "1fr"}
            self.check("layout.responsive_breakpoints", all(str(widths.get(w) or "").startswith(v) for w, v in expect.items()),
                       columns=widths)
            w, h = (int(v) for v in self.args.size.split("x"))
            self.call("resize", width=w, height=h)
        if want("S12"):
            r = self.call("open_second")
            ok = r.get("ok")
            if gui and ok:
                second = self.title + "-second"
                win2 = self.window(second)
                self.check("gui.second_window_appears", win2 is not None)
                if win2:
                    self.desktop.place(second, 300, 200)
                    self.desktop.activate(second)
                    st = self.call("second_state")
                    rect = st["rects"]["button"]
                    rect = rect.get("rect", rect)
                    x, y = self.desktop.client_point(self.window(second), rect["x"] + rect["width"] / 2,
                                                     rect["y"] + rect["height"] / 2, 1.0)
                    self.desktop.click(x, y)
                    self.desktop.click(x, y)
                    time.sleep(0.4)
                    st = self.call("second_state")
                    self.check("gui.second_window_isolated_updates", st.get("text") == "second: 2", text=st.get("text"))
                    self.shot("12-two-windows")
                    self.desktop.close(second)
                    time.sleep(1.0)
                    st = self.call("second_state")
                    self.check("gui.closing_second_window_disposes_its_ui",
                               st.get("ok") and st["diagnostics"].get("disposed"), state=st)
                    self.desktop.activate(self.title)
                    before = self.snap()["state"]["count"]
                    self.click("increment")
                    ok2, s = self.wait_for(lambda s: s["state"]["count"] == before + 1)
                    self.check("gui.main_window_still_works_after_second_closed", ok2)
            elif ok:
                st = self.call("second_state")
                self.check("dom.second_window_mounts", st.get("ok") and st.get("text") == "second: 0", state=st)
            else:
                self.check("dom.second_window_mounts", False, response=r)
        if want("S13"):
            r = self.call("cycle", n=100, timeout=600)
            self.check("lifecycle.mount_close_100_cycles", r.get("ok") and not r.get("errors"),
                       ms=r.get("ms"), errors=r.get("errors"), threads=(r.get("threads_before"), r.get("threads_after")))
            s = self.snap()
            self.check("lifecycle.main_ui_healthy_after_cycles", s.get("ok") and not _diag(s, "dom_uncertain"),
                       diagnostics=s.get("diagnostics"))

    def kill_app(self) -> None:
        """Last-resort cleanup of the launched app tree (launcher, host, backend) after a driver failure."""
        if not self.proc or self.proc.poll() is not None:
            return
        self.results.append({"check": "driver.app_killed_by_driver", "status": "INFO"})
        if WINDOWS:
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(self.proc.pid)], capture_output=True)
        else:
            import signal
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except OSError:
                pass
        try:
            self.proc.wait(10)
        except subprocess.TimeoutExpired:
            pass

    def finish(self) -> int:
        self.kill_app()
        shutil.copy2(self.channel / "app.jsonl", self.out / "app.jsonl") if (self.channel / "app.jsonl").exists() else None
        summary = {s: sum(1 for r in self.results if r["status"] == s) for s in ("PASS", "FAIL", "BLOCKED")}
        (self.out / "results.json").write_text(json.dumps({"lang": self.args.lang, "headless": self.args.headless,
                                                           "theme": self.args.theme, "summary": summary,
                                                           "results": self.results}, indent=1, default=repr))
        print("SUMMARY", json.dumps(summary), flush=True)
        shutil.rmtree(self.channel, ignore_errors=True)
        return 0 if summary["FAIL"] == 0 else 1


def _get(d, *names, default=None):
    for n in names:
        if isinstance(d, dict) and n in d:
            return d[n]
    return default


def _diag(snapshot, key, default=None):
    d = (snapshot or {}).get("diagnostics") or {}
    alt = {"dom_uncertain": "DomUncertain", "event_queue_dropped": "EventQueueDropped", "errors": "Errors"}
    return _get(d, key, alt.get(key, key), default=default)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--lang", choices=("py", "ps"), required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--headless", action="store_true")
    p.add_argument("--python", default=sys.executable)
    p.add_argument("--pwsh", default="pwsh")
    p.add_argument("--ui-src", default="", help="nativehtmlkit_ui source dir (omit to use the installed wheel)")
    p.add_argument("--theme", default="cobalt")
    p.add_argument("--only", default="")
    p.add_argument("--ime", action="store_true", help="run S16 (the runner must enable the input method)")
    p.add_argument("--size", default="1000x700", help="main window size in CSS px (smaller for 125/150%% scaling)")
    run = Run(p.parse_args())
    try:
        return run.run()
    except BaseException:
        run.kill_app()
        raise


if __name__ == "__main__":
    sys.exit(main())
