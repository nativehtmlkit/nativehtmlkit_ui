#!/usr/bin/env python3
"""Make offline, source-only UI artifacts (never download Core/SDK, never publish)."""
from __future__ import annotations
from pathlib import Path
import argparse
import hashlib
import shutil
import subprocess
import sys
from zipfile import ZipFile, ZIP_DEFLATED

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
    subprocess.run([sys.executable, '-m', 'pip', 'wheel', str(ROOT / 'python'),
                    '--no-deps', '--no-build-isolation', '--no-index', '--wheel-dir', str(out)],
                   cwd=ROOT, check=True)
    wheels = list(out.glob('nativehtmlkit_ui-0.1.0-*.whl'))
    if len(wheels) != 1:
        raise RuntimeError(f'Expected one UI wheel 0.1.0; found {[p.name for p in wheels]}')
    module = ROOT / 'powershell/NativeHTMLKit.UI'
    pszip = out / 'NativeHTMLKit.UI-0.1.0.zip'
    with ZipFile(pszip, 'w', ZIP_DEFLATED) as z:
        for f in sorted(module.rglob('*')):
            if f.is_file() and '__pycache__' not in f.parts:
                z.write(f, f.relative_to(module.parent).as_posix())
        z.write(ROOT / 'LICENSE', 'NativeHTMLKit.UI/LICENSE')
    artifacts = sorted(wheels + [pszip], key=lambda x: x.name)
    checksums = out / 'SHA256SUMS'
    checksums.write_text(''.join(f'{sha256(f)}  {f.name}\n' for f in artifacts), encoding='utf-8')
    for f in artifacts:
        print(f'{f.name}  {f.stat().st_size} bytes  sha256:{sha256(f)}')
    print(f'Written: {checksums}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
