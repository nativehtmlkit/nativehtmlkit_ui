# Sub-repository integration and deployment

This project is an **independent repository checkout** in the existing NativeHTMLKit project workspace, **not a Git submodule**. That matches `nativehtmlkit-project/agents/shared.md` and the parent repo's excludes for child projects.

## Recommended workspace layout

```text
nativehtmlkit-project/                  # workspace coordinator, independent Git repository
├── repositories/
│   ├── nativehtmlkit-core/             # existing
│   ├── nativehtmlkit-cli/              # existing
│   ├── nativehtmlkit-python/           # existing
│   ├── nativehtmlkit-powershell/        # existing
│   └── nativehtmlkit_ui/               # THIS repository, independent Git history
└── docs/
```

1. Extract `nativehtmlkit_ui-repo.zip` so its root `nativehtmlkit_ui/` directory is under `repositories/` (or use a separate checkout and copy the files).
2. Inspect the code, `AGENTS.md`, and the local Project conventions. If there is no `.git`, run `git init` **inside** `repositories/nativehtmlkit_ui` before an initial local commit. No remote is created or configured for you.
3. Confirm that the parent Project does not stage nested repository source. Update the parent workspace inventory manually when appropriate, without changing the SDK or Core repositories.
4. For development, install the existing SDK **first**. Install the UI module from the local source tree or locally packaged artifact.
5. Qualify on both the Linux Wayland development desktop and interactive Windows development VM, recording results under ignored `evidence/`.
6. Only after local acceptance, request a separate publication step if desired. `nativehtmlkit_ui` release artifacts are **not** Core or SDK host artifacts.

## Python development

```bash
cd nativehtmlkit_ui
uv venv .venv && . .venv/bin/activate   # or Python venv on Windows
# Install your already-qualified nativehtmlkit SDK platform wheel first:
python -m pip install /path/to/nativehtmlkit-0.1.0-*.whl
python -m pip install --no-build-isolation --no-deps -e ./python
python -m pip install pytest
python -m pytest -q python/tests

# SDK module runner (recommended; no duplicate top-level effects):
PYTHONPATH=examples/python python -m nativehtmlkit run counter:main --name NativeHTMLKitUIDemo
```

The SDK prerelease currently bundles the native host itself. The UI wheel is `py3-none-any`, includes CSS assets, and contains no host binary. For an application using `Application.start()` directly, follow the SDK's documented two-process script startup rules.

## PowerShell development

```powershell
# SDK module must already be installed/available.
$env:PSModulePath = "$(Join-Path $PWD 'powershell');$env:PSModulePath"
Import-Module NativeHTMLKit.UI -Force
& ./powershell/tests/Smoke.ps1
& ./examples/powershell/counter.ps1
```

PowerShell 7 Linux separates paths using `:` rather than `;`. The command above is a **Windows** example. Linux:

```powershell
$env:PSModulePath = "$(Join-Path $PWD 'powershell'):$env:PSModulePath"
```

`New-NHKUi` is pure PowerShell. `Start-NHKUi` calls public SDK commands and requires a connected `$app` returned by `Start-NativeHTMLKitScript`. The SDK remains responsible for its two-process startup, `Wait-NativeHTMLKit` and shutdown. Do not package the SDK host into the UI module.

## Packaging, offline and release

```bash
python tools/package-local.py --out dist
cat dist/SHA256SUMS
```

Outputs:

- `dist/nativehtmlkit_ui-0.1.0-py3-none-any.whl`: pure-Python wheel; depends on an SDK wheel compatible with the target operating system.
- `dist/NativeHTMLKit.UI-0.1.0.zip`: source-only PowerShell module archive; requires a compatible, separately installed SDK module.
- `dist/SHA256SUMS`: output integrity hashes.

The script builds locally/offline using local setuptools/wheel. It does not download dependencies, compile the Core host, create tags or publish. A clean-install check must be performed on each target platform before release.

## Open packaging issues

- PowerShell Gallery publishing is **not** preconfigured for this new UI module. Do not copy SDK's publish-only GitHub workflow without a new authorization and threat review.
- GitHub repository name and remote are not created by this ZIP. The intended name is `nativehtmlkit_ui`, consistent with the Python distribution/import. A future remote URL, if created, should reflect the current namespace chosen by the owner.
- The parent workspace's repository inventory script may have a hard-coded known-repo list; adding an optional UI repository is a **Project-scoped** change, not a UI code dependency.
