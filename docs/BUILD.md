# UI validation and distribution

Python:

```bash
cd python
python -m pytest tests
python -m build
```

PowerShell:

```powershell
Import-Module ./powershell/NativeHTMLKit.UI/NativeHTMLKit.UI.psd1 -Force
Invoke-Pester ./powershell/tests
```

Run real GUI smoke tests on Linux KDE Wayland and Windows with the **current, released** SDKs/host, including event delivery, IME and accessibility. Packaging metadata resides in `python/pyproject.toml` and `powershell/NativeHTMLKit.UI/NativeHTMLKit.UI.psd1`. UI Python and PowerShell share the GitHub UI repository's release tag; update both to the same new tag only after qualification.
