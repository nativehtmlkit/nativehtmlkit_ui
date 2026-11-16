# UI validation and distribution

## Unit tests (no host)

Python (fake SDK, no native host):

```bash
cd python
PYTHONPATH=src python -m pytest -q tests
python -m build
```

PowerShell (fake SDK module in `powershell/tests/FakeSdk`; exit code = number of failures):

```powershell
pwsh -NoProfile -File ./powershell/tests/Unit.Tests.ps1
powershell.exe -NoProfile -File .\powershell\tests\Unit.Tests.ps1   # Windows PowerShell 5.1
```

## Examples against the real host (headless)

`qualification/examples/run_examples.py` runs every example in `examples/` and every tutorial
step in `docs/tutorials/code/` against the real Core host in headless test mode
(`NATIVEHTMLKIT_TEST_MODE=1`) and checks the scenario in `qualification/examples/scenarios.json`.
Use the **released** SDK packages:

```bash
python -m venv /tmp/nhkui-venv
/tmp/nhkui-venv/bin/python -m pip install nativehtmlkit==0.1.2 ./python      # SDK wheel + this UI from source
mkdir -p /tmp/nhk-modules && unzip NativeHTMLKit-0.1.2-linux-x64+win-x64.zip -d /tmp/nhk-modules
python qualification/examples/run_examples.py --python /tmp/nhkui-venv/bin/python \
    --ps-module-path "/tmp/nhk-modules:$PWD/powershell" --out /tmp/nhkui-examples
```

On Windows pass `--pwsh powershell.exe` for Windows PowerShell 5.1 (or `pwsh.exe`) and use
`;` in `--ps-module-path`. `--lang py|ps` and `--only name1,name2` narrow the run. A JSON
report and per-example logs are written to `--out`. See the
[testing guide](guides/testing.md) for what the harness proves.

## GUI qualification

Run real GUI tests on Linux KDE Wayland and Windows with the **current, released** SDKs/host,
including event delivery, IME and accessibility. `qualification/gui/driver.py` drives the
gallery apps in `qualification/gui/apps` with real OS input inside an interactive desktop
session (`--headless` runs only its input-free checks).

## Packaging

Packaging metadata resides in `python/pyproject.toml` and
`powershell/NativeHTMLKit.UI/NativeHTMLKit.UI.psd1`. UI Python and PowerShell share the GitHub
UI repository's release tag; update both to the same new tag only after qualification.
