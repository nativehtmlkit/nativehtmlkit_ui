#!/usr/bin/env python3
"""Run every example (examples/, docs/tutorials/code/) against the real NativeHTMLKit host, headless.

Test tooling (stdlib only). Each example is started UNCHANGED through its normal entry point
(``python EXAMPLE.py`` / ``pwsh -File EXAMPLE.ps1``, wrapped by py_probe.py / ps_probe.ps1) with
NATIVEHTMLKIT_TEST_MODE=1, so the real native host runs the whole protocol without a window.
The probe executes the scenario from scenarios.json (simulated events at the UI library's SDK
callback entry point plus DOM read-back through the public SDK), then requests an orderly quit.

Per example the driver checks: a scenario exists; the app reached ready; every scenario step
passed; UI diagnostics show no errors, no dropped events and no uncertain DOM; (PowerShell) the
SDK counted no callback failures or dropped notifications; the process exited 0 within the
timeout; stderr has no traceback/exception; no host/backend process carrying this run's marker
is left (Linux: /proc environ; Windows: backend command line).

usage: run_examples.py [--lang py|ps|all] [--python EXE] [--pwsh EXE] [--ps-module-path DIRS]
                       [--only NAME,...] [--out DIR] [--timeout SECONDS]
The Python interpreter must have the nativehtmlkit SDK and nativehtmlkit_ui installed; for
PowerShell, --ps-module-path is prepended to PSModulePath (SDK module dir and ./powershell).
Not GUI evidence: there is no native input and no rendering check.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
WINDOWS = os.name == "nt"
BAD_STDERR = ("Traceback", "Exception", "callback/update failed", "event handler failed")


def _marker_processes(marker: str) -> list[str]:
    found = []
    if WINDOWS:
        cmd = ["powershell.exe", "-NoProfile", "-Command",
               "Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*%s*' } | "
               "ForEach-Object { \"$($_.ProcessId) $($_.Name)\" }" % marker]
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
        return [line for line in out.splitlines() if line.strip()]
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            environ = (proc / "environ").read_bytes()
        except OSError:
            continue
        if f"NHKUI_EXAMPLE_MARKER={marker}".encode() in environ:
            try:
                found.append(proc.name + " " + (proc / "cmdline").read_bytes().replace(b"\0", b" ").decode()[:160])
            except OSError:
                found.append(proc.name)
    return found


def run_one(lang: str, example: Path, steps: list, args, out: Path) -> dict:
    marker = uuid.uuid4().hex[:16]
    work = Path(tempfile.mkdtemp(prefix="nhkui-ex-"))
    spec, result_file = work / "spec.json", work / "result.json"
    spec.write_text(json.dumps(steps), encoding="utf-8")
    env = {k: v for k, v in os.environ.items() if not k.startswith("UI4ME_")}
    env.update(NATIVEHTMLKIT_TEST_MODE="1", NHKUI_EXAMPLE_SPEC=str(spec), NHKUI_EXAMPLE_OUT=str(result_file),
               NHKUI_EXAMPLE_MARKER=marker, PYTHONUNBUFFERED="1")
    if lang == "py":
        argv = [args.python, str(HERE / "py_probe.py"), str(example), marker]
    else:
        if args.ps_module_path:
            env["PSModulePath"] = args.ps_module_path + os.pathsep + env.get("PSModulePath", "")
        argv = [args.pwsh, "-NoProfile", "-NonInteractive"] + (["-ExecutionPolicy", "Bypass"] if WINDOWS else []) \
            + ["-File", str(HERE / "ps_probe.ps1"), str(example), marker]
    started = time.monotonic()
    proc = subprocess.Popen(argv, cwd=str(work), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            stdin=subprocess.DEVNULL, **({} if WINDOWS else {"start_new_session": True}))
    try:
        stdout, stderr = proc.communicate(timeout=args.timeout)
        code = proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate(timeout=30)
        code = "timeout"
    seconds = round(time.monotonic() - started, 2)
    stdout, stderr = stdout.decode(errors="replace"), stderr.decode(errors="replace")
    name = f"{lang}-{example.stem}"
    (out / f"{name}.stdout.log").write_text(stdout, encoding="utf-8")
    (out / f"{name}.stderr.log").write_text(stderr, encoding="utf-8")
    result = json.loads(result_file.read_text(encoding="utf-8")) if result_file.exists() else {}
    (out / f"{name}.result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    leftovers = []
    for _ in range(50):
        leftovers = _marker_processes(marker)
        if not leftovers:
            break
        time.sleep(0.1)

    checks: dict[str, tuple[bool, object]] = {}
    steps_done = result.get("steps", [])
    checks["ready"] = (bool(result.get("ready")), None)
    failed = [s for s in steps_done if not s.get("ok")]
    checks["scenario"] = (result.get("finished", False) and not failed and len(steps_done) == len(steps),
                          failed[:1] or f"{len(steps_done)}/{len(steps)} steps")
    diags = result.get("diagnostics") or []

    def field(d, py, ps):
        return d.get(py, d.get(ps))
    dirty = [d for d in diags if field(d, "errors", "Errors") or field(d, "dom_uncertain", "DomUncertain")
             or d.get("event_queue_dropped")]
    checks["ui_diagnostics_clean"] = (bool(diags) and not dirty, dirty[:2] or len(diags))
    sdk = result.get("sdk")
    if lang == "ps":
        checks["sdk_no_callback_failures"] = (bool(sdk) and not sdk.get("CallbackFailures") and not sdk.get(
            "DroppedNotifications") and not sdk.get("DeferredDropped") and "unavailable" not in sdk, sdk)
    checks["exit_code_0"] = (code == 0, code)
    bad = [line for line in stderr.splitlines() if any(k in line for k in BAD_STDERR)]
    checks["stderr_clean"] = (not bad, bad[:5])
    checks["no_orphan_processes"] = (not leftovers, leftovers[:5])
    status = "PASS" if all(ok for ok, _ in checks.values()) else "FAIL"
    return {"example": f"{lang}/{example.name}", "status": status, "seconds": seconds, "steps": len(steps_done),
            "checks": {k: {"ok": ok, "detail": detail} for k, (ok, detail) in checks.items()}}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--lang", choices=("py", "ps", "all"), default="all")
    p.add_argument("--python", default=sys.executable)
    p.add_argument("--pwsh", default="powershell.exe" if WINDOWS else "pwsh")
    p.add_argument("--ps-module-path", default="")
    p.add_argument("--only", default="", help="comma-separated example stems")
    p.add_argument("--out", default=str(Path(tempfile.gettempdir()) / "nhkui-examples"))
    p.add_argument("--timeout", type=float, default=120)
    args = p.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    scenarios = json.loads((HERE / "scenarios.json").read_text(encoding="utf-8"))
    only = set(filter(None, args.only.split(",")))
    plan = []
    # The examples and the runnable tutorial steps (docs/tutorials/code) are verified alike.
    if args.lang in ("py", "all"):
        for folder in ("examples/python", "docs/tutorials/code/python"):
            plan += [("py", e) for e in sorted((REPO / folder).glob("*.py"))]
    if args.lang in ("ps", "all"):
        for folder in ("examples/powershell", "docs/tutorials/code/powershell"):
            plan += [("ps", e) for e in sorted((REPO / folder).glob("*.ps1"))]
    report = []
    for lang, example in plan:
        if only and example.stem not in only:
            continue
        entry = scenarios.get(example.stem)
        if entry is None:
            report.append({"example": f"{lang}/{example.name}", "status": "FAIL",
                           "checks": {"scenario_defined": {"ok": False, "detail": "add it to scenarios.json"}}})
        else:
            steps = entry.get(lang, entry.get("steps", []))
            report.append(run_one(lang, example, steps, args, out))
        r = report[-1]
        failed = [k for k, v in r["checks"].items() if not v["ok"]]
        print(f"{r['status']} {r['example']} ({r.get('seconds', 0)} s, {r.get('steps', 0)} steps)"
              + (f" failed: {failed} {json.dumps({k: r['checks'][k]['detail'] for k in failed}, default=repr)[:600]}"
                 if failed else ""), flush=True)
    summary = {s: sum(1 for r in report if r["status"] == s) for s in ("PASS", "FAIL")}
    (out / "report.json").write_text(json.dumps({"summary": summary, "python": args.python, "pwsh": args.pwsh,
                                                 "results": report}, indent=1, default=repr), encoding="utf-8")
    print("SUMMARY", json.dumps(summary), "report:", out / "report.json", flush=True)
    return 0 if summary["FAIL"] == 0 and report else 1


if __name__ == "__main__":
    sys.exit(main())
