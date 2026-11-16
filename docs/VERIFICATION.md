# Preparation-time verification and open gates

Assembled 2026-11-16 using supplied SDK source archives. See `tools/package-local.py` and `dist/SHA256SUMS` for local build outputs after packaging.

| Gate | Result | Evidence |
|---|---|---|
| Static inspection of supplied Python/PowerShell SDK public APIs | DONE | Compared `application.py`, SDK README and PowerShell module exported command signatures |
| Python state, computed, UI markup, fake native callbacks | PASS (24 tests) | `PYTHONPATH=python/src python -m pytest -q python/tests` |
| Python wheel packaging | PASS | Locally built `nativehtmlkit_ui-0.1.0-py3-none-any.whl`; isolated target import and CSS resource smoke passed |
| PowerShell module source | IMPLEMENTED, UNVERIFIED | `pwsh`/`powershell.exe` unavailable in the preparation environment |
| Linux real KDE Wayland native GUI | NOT RUN | No user's interactive SDK host/lab attached here |
| Windows PowerShell 5.1 and 7 native GUI | NOT RUN | No interactive Windows VM available here |
| Fresh install against current user's SDK builds | NOT RUN | Requires current local SDK packages and pinned Core host |
| UI4ME compatibility | NOT APPLICABLE | Deliberate clean-sheet API |
| GitHub commit/push/release | NOT RUN | Separate explicit authorization required |

**Do not interpret the implemented source or Python fake-SDK passes as proof that native GUI qualification succeeded.** The local AI-agent handoff explicitly requires it to inspect current SDKs, fix UI-layer defects, run PowerShell and both native GUI targets, and report evidence.

Known implementation boundaries and non-goals are documented in README/ARCHITECTURE. If qualification finds missing SDK behavior, record a cross-repo defect rather than importing private SDK APIs.
