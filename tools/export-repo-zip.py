#!/usr/bin/env python3
"""Export the repository as a clean independent checkout ZIP with local dist artifacts.

Excludes Git history, caches and work products; does not use network or GitHub.
"""
from pathlib import Path
import argparse
import hashlib
import json
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
EXCLUDE_DIRS = {'.git','.venv','venv','build','__pycache__','.pytest_cache',
                '.mypy_cache','.ruff_cache','evidence'}

def selected():
    for path in ROOT.rglob('*'):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(p in EXCLUDE_DIRS or p.endswith('.egg-info') for p in rel.parts):
            continue
        if rel.name.endswith(('.pyc','.pyo','.log','.tmp')):
            continue
        yield path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default=str(ROOT.parent/'nativehtmlkit_ui-repo-0.1.0.zip'))
    args = parser.parse_args()
    out = Path(args.out).expanduser().resolve()
    if out.is_relative_to(ROOT):
        raise SystemExit('Output must be outside source repo')
    entries = sorted(selected(),key=lambda f:f.relative_to(ROOT).as_posix())
    manifest = {
        'project':'nativehtmlkit_ui', 'version':'0.1.0', 'archive_type':'independent-source-checkout',
        'includes_offline_ui_package_artifacts':True,
        'excludes':['.git','build','caches','evidence'],
        'files':{f.relative_to(ROOT).as_posix():hashlib.sha256(f.read_bytes()).hexdigest()
                 for f in entries if f.name != 'BUNDLE-MANIFEST.json'}
    }
    (ROOT/'BUNDLE-MANIFEST.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n',encoding='utf8')
    entries=sorted(selected(),key=lambda f:f.relative_to(ROOT).as_posix())
    out.parent.mkdir(parents=True,exist_ok=True)
    with ZipFile(out,'w',compression=ZIP_DEFLATED,compresslevel=9) as z:
        for f in entries:
            z.write(f,'nativehtmlkit_ui/'+f.relative_to(ROOT).as_posix())
    with ZipFile(out) as z:
        failure=z.testzip()
        if failure:
            raise RuntimeError(f'ZIP failed CRC check: {failure}')
    print(f'{out}: {len(entries)} files, {out.stat().st_size} bytes')
    print('SHA-256:',hashlib.sha256(out.read_bytes()).hexdigest())

if __name__=='__main__':
    main()
