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
]
forbid_ps = [r"\bInvoke-NativeHTMLKitRpc\b", r"\bStart-NativeHTMLKitHost\b", r"\bAdd-Type\b"]
failures = []
for f in python_files:
    content = f.read_text(encoding="utf8")
    for pattern in forbid_python:
        if re.search(pattern, content):
            failures.append(f"{f.relative_to(ROOT)}: forbidden pattern {pattern}")
for f in ps_files:
    content = f.read_text(encoding="utf8")
    for pattern in forbid_ps:
        if re.search(pattern, content, re.IGNORECASE):
            failures.append(f"{f.relative_to(ROOT)}: forbidden pattern {pattern}")
a = (ROOT / "shared/css/ui.css").read_bytes()
b = (ROOT / "python/src/nativehtmlkit_ui/assets/ui.css").read_bytes()
c = (ROOT / "powershell/NativeHTMLKit.UI/assets/ui.css").read_bytes()
if a != b or a != c:
    failures.append("CSS assets differ across shared/Python/PowerShell distributions")
if failures:
    print("FAIL: UI boundaries\n" + "\n".join(failures), file=sys.stderr)
    sys.exit(1)
print(f"PASS: {len(python_files)} Python sources, {len(ps_files)} PowerShell sources, identical shared CSS; no forbidden dependency patterns")
