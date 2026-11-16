#!/usr/bin/env python3
"""Non-GUI local qualification. Interactive GUI gates are separate."""
from __future__ import annotations
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
checks = [
    ('boundaries', [sys.executable, str(root / 'tools/verify_boundaries.py')], {}),
    ('python_unit', [sys.executable, '-m', 'pytest', '-q', str(root / 'python/tests')],
     {'PYTHONPATH': str(root / 'python/src')}),
]
pwsh = shutil.which('pwsh')
if pwsh:
    checks.append(('powershell_unit_fake_sdk', [pwsh, '-NoProfile', '-File', str(root / 'powershell/tests/Unit.Tests.ps1')], {}))
    # Smoke.ps1 imports the manifest, which requires the REAL NativeHTMLKit SDK module on PSModulePath.
    checks.append(('powershell_smoke', [pwsh, '-NoProfile', '-File', str(root / 'powershell/tests/Smoke.ps1')], {}))
results = []
for name, command, env_add in checks:
    env = os.environ.copy()
    env.update(env_add)
    print(f'RUN {name}: {command}', flush=True)
    result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True)
    print(result.stdout[-2500:])
    if result.returncode:
        print(result.stderr[-2500:], file=sys.stderr)
    results.append({'gate': name, 'status': 'PASS' if result.returncode == 0 else 'FAIL',
                    'returncode': result.returncode, 'command': command})
if not pwsh:
    results.append({'gate': 'powershell_smoke', 'status': 'BLOCKED',
                    'reason': 'pwsh executable unavailable; must run in local lab with NativeHTMLKit SDK'})
for name in ('linux_wayland_gui','windows_interactive_gui','ps_5_1_gui'):
    results.append({'gate': name, 'status':'BLOCKED', 'reason':'Must be run in native interactive target environment'})
out = root / 'evidence'
out.mkdir(exist_ok=True)
report = {'generated_at': datetime.now(timezone.utc).isoformat(), 'results': results}
(out/'qualification-local.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print(f'Report: {out/"qualification-local.json"}')
print('NOTE: headless/fake results only; native GUI gates are recorded separately (docs/QUALIFICATION.md).')
if any(x['status']=='FAIL' for x in results):
    sys.exit(1)
