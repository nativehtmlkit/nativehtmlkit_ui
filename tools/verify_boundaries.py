#!/usr/bin/env python3
"""Check non-negotiable source boundaries without network or external tools."""
from __future__ import annotations
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
python_files = list((ROOT / "python/src/nativehtmlkit_ui").rglob("*.py"))
ps_files = list((ROOT / "powershell/NativeHTMLKit.UI").rglob("*.ps1")) + [ROOT / "powershell/NativeHTMLKit.UI/NativeHTMLKit.UI.psm1"]
forbid_python = [
    r"\bimport\s+nativehtmlkit\.(?:client|_bootstrap|_contract|launcher)",
    r"\bfrom\s+nativehtmlkit\.(?:client|_bootstrap|_contract|launcher)\b",
    r"\b(?:app|document|window)\.rpc\b",
    r"\b(?:subprocess|Popen)\b",
    r"\b(?:requests|websockets|pywebview|cefpython)\b",
    # SDK private state (public attributes such as Window.closed/.document are allowed).
    r"\.(?:_handlers|_windows|_retire|_dispatch|_check|_shutdown_listeners|_window_listeners)\b",
]
forbid_ps = [r"\bInvoke-NativeHTMLKitRpc\b", r"\bStart-NativeHTMLKitHost\b", r"\bAdd-Type\b",
             r"\bStart-NativeHTMLKitRpc\b", r"\bSend-NativeHTMLKitNotification\b",
             # SDK private state/transport/pump (only documented commands and exception types)
             r"\.Transport\b", r"\bInvoke-NativeHTMLKitPump\b", r"\.(?:Retired|ShutdownRequested|Dispatching|Deferred)\b",
             r"\bRegister-NativeHTMLKitNotification\b"]
# PS 5.1 parser safety: no PS7-only operators in the module.
ps7_only = [r"\?\?=?", r"\?\.", r"\s\|\|\s", r"\s&&\s", r"\bclean\s*\{"]
failures = []
for f in python_files:
    content = f.read_text(encoding="utf8")
    for pattern in forbid_python:
        if re.search(pattern, content):
            failures.append(f"{f.relative_to(ROOT)}: forbidden pattern {pattern}")
for f in ps_files:
    content = f.read_text(encoding="utf8")
    code = "\n".join(line.split("#", 1)[0] for line in content.splitlines())
    for pattern in forbid_ps:
        if re.search(pattern, code, re.IGNORECASE):
            failures.append(f"{f.relative_to(ROOT)}: forbidden pattern {pattern}")
    for pattern in ps7_only:
        if re.search(pattern, code):
            failures.append(f"{f.relative_to(ROOT)}: PowerShell 7-only syntax {pattern} (module must parse on 5.1)")
    if any(ord(ch) > 127 for ch in content):
        failures.append(f"{f.relative_to(ROOT)}: non-ASCII character (Windows PowerShell 5.1 reads BOM-less files as ANSI)")
a = (ROOT / "shared/css/ui.css").read_bytes()
b = (ROOT / "python/src/nativehtmlkit_ui/assets/ui.css").read_bytes()
c = (ROOT / "powershell/NativeHTMLKit.UI/assets/ui.css").read_bytes()
if a != b or a != c:
    failures.append("CSS assets differ across shared/Python/PowerShell distributions")
if failures:
    print("FAIL: UI boundaries\n" + "\n".join(failures), file=sys.stderr)
    sys.exit(1)
print(f"PASS: {len(python_files)} Python sources, {len(ps_files)} PowerShell sources, identical shared CSS; no forbidden dependency patterns")
