#!/usr/bin/env python3
"""Make offline, source-only UI artifacts (never download Core/SDK, never publish)."""
from __future__ import annotations
from pathlib import Path
import argparse
import os
import re
import hashlib
import shutil
import subprocess
import sys
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--out', default='dist', help='output folder relative to repository unless absolute')
    args = p.parse_args()
    out = Path(args.out)
    if not out.is_absolute():
        out = ROOT / out
    out.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, str(ROOT / 'tools/verify_boundaries.py')], check=True)
    version = re.search(r'^version = "([^"]+)"', (ROOT / 'python/pyproject.toml').read_text(), re.M).group(1)
    ps_version = re.search(r"ModuleVersion = '([^']+)'",
                           (ROOT / 'powershell/NativeHTMLKit.UI/NativeHTMLKit.UI.psd1').read_text()).group(1)
    init_version = re.search(r'__version__ = "([^"]+)"',
                             (ROOT / 'python/src/nativehtmlkit_ui/__init__.py').read_text()).group(1)
    if not version == ps_version == init_version:
        raise RuntimeError(f'Version mismatch: pyproject {version}, __init__ {init_version}, psd1 {ps_version}')
    for stale in out.glob('nativehtmlkit_ui-*.whl'):
        stale.unlink()
    # Reproducible wheel: fixed timestamps (SOURCE_DATE_EPOCH = last commit, else a constant).
    env = dict(os.environ)
    if 'SOURCE_DATE_EPOCH' not in env:
        try:
            env['SOURCE_DATE_EPOCH'] = subprocess.run(['git', 'log', '-1', '--format=%ct', '--', 'python'], cwd=ROOT,
                                                      capture_output=True, text=True, check=True).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            env['SOURCE_DATE_EPOCH'] = '1700000000'
    shutil.rmtree(ROOT / 'python/build', ignore_errors=True)
    subprocess.run([sys.executable, '-m', 'pip', 'wheel', str(ROOT / 'python'),
                    '--no-deps', '--no-build-isolation', '--no-index', '--wheel-dir', str(out)],
                   cwd=ROOT, check=True, env=env)
    shutil.rmtree(ROOT / 'python/build', ignore_errors=True)
    wheels = list(out.glob(f'nativehtmlkit_ui-{version}-*.whl'))
    if len(wheels) != 1:
        raise RuntimeError(f'Expected one UI wheel {version}; found {[p.name for p in wheels]}')
    module = ROOT / 'powershell/NativeHTMLKit.UI'
    pszip = out / f'NativeHTMLKit.UI-{version}.zip'
    stamp = (2020, 1, 1, 0, 0, 0)
    with ZipFile(pszip, 'w', ZIP_DEFLATED) as z:
        members = [(f, f.relative_to(module.parent).as_posix()) for f in sorted(module.rglob('*'))
                   if f.is_file() and '__pycache__' not in f.parts]
        members.append((ROOT / 'LICENSE', 'NativeHTMLKit.UI/LICENSE'))
        for f, name in members:
            info = ZipInfo(name, stamp)
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, f.read_bytes())
    artifacts = sorted(wheels + [pszip], key=lambda x: x.name)
    checksums = out / 'SHA256SUMS'
    checksums.write_text(''.join(f'{sha256(f)}  {f.name}\n' for f in artifacts), encoding='utf-8')
    for f in artifacts:
        print(f'{f.name}  {f.stat().st_size} bytes  sha256:{sha256(f)}')
    print(f'Written: {checksums}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
