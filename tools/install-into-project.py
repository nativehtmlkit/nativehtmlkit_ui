#!/usr/bin/env python3
"""Non-destructive local copy into existing NativeHTMLKit Project repositories.

No remote operations, no overwrite; opt-in --init-git creates an independent local Git repo.
"""
from __future__ import annotations
from pathlib import Path
import argparse
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

p = argparse.ArgumentParser()
p.add_argument('--project', required=True, type=Path, help='path to existing nativehtmlkit-project checkout')
p.add_argument('--init-git', action='store_true')
a = p.parse_args()
project = a.project.expanduser().resolve()
if not (project/'AGENTS.md').is_file() or not (project/'repositories').is_dir():
    raise SystemExit('Refusing: project must contain AGENTS.md and repositories/ directory')
destination = project/'repositories/nativehtmlkit_ui'
if destination.exists():
    raise SystemExit(f'Refusing to overwrite existing destination: {destination}')
if destination == ROOT:
    raise SystemExit('Source already at destination; nothing copied')
shutil.copytree(ROOT, destination, ignore=shutil.ignore_patterns('.git','.venv','dist','build',
                                  '__pycache__','.pytest_cache','*.egg-info','evidence'))
if a.init_git:
    subprocess.run(['git','init'],cwd=destination,check=True)
print(f'Created separate repository worktree at {destination}')
print('Next: read AGENTS.md, run local tests, initialize remote only if you choose.')
