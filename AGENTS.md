# NativeHTMLKit UI — autonomous development rules

This is a **separate repository** designed to live under `nativehtmlkit-project/repositories/nativehtmlkit_ui`. Read the parent Project's current `AGENTS.md`, `agents/shared.md`, `agents/environment.md`, `docs/architecture/local-releases.md`, `docs/bugs/bug_list.md` when present, then these instructions. Do not blindly apply superseded migration advice.

## Architecture, hard boundaries

- UI depends **only on public** `nativehtmlkit` Python SDK and `NativeHTMLKit` PowerShell module APIs. Do not import Core private modules, use Core protocol/IPC, link Rust crates, call the CLI, or manage host processes independently.
- Do not add a plugin system, ViewSpec, contributions/registries, routing engine, JS, browser, web server, Node, or additional mandatory services.
- Keep Python and PowerShell independently implemented with matching essential component semantics; they must never require the other language at runtime.
- UI owns lightweight reactive state, managed nodes, event subscriptions, DOM scheduling, CSS and component lifecycle. Core owns HTML rendering; the SDK owns native window/process transport.
- Raw HTML/CSS is **trusted source only**. Escape all runtime values. No credentials, personal data, form inputs, or tokens in tracing/logs.
- Native input is authoritative. Do not write back every keystroke; preserve selection, caret and IME.
- No arbitrary dependency upgrades or feature expansion beyond scoped release gates. If an SDK bug blocks work, record a standalone reproducible issue and fix in that SDK only under a separately authorized task.

## Engineering and release rules

- Read actual SDK source/contracts before changing integrations. Source from supplied ZIPs is a snapshot and may not match the user's current local checkouts.
- Test pure logic first; fake SDK integration second; then real interactive KDE Wayland and Windows Server GUI, Python and PowerShell 7 and Windows PowerShell 5.1. SSH-only sessions do **not** prove interactive GUI behavior.
- Keep a local evidence directory (ignored) with commands, exact versions, hashes, screenshots and failures. Do not claim native qualification from headless or mocked tests.
- Local builds and tests only. No build/test GitHub Actions. Do not push, publish, tag, create GitHub repo, change VM snapshots or modify other repositories without explicit authorization.
- Respect parent Project's independently versioned release and source provenance policy.
- On completion: summarize commits, actual tests, failures, remaining issues, and copy-ready release steps; no "all passed" claims without evidence.

## Build/test sequence

1. Python: `PYTHONPATH=python/src python -m pytest -q python/tests`.
2. Build offline: `python tools/package-local.py --out dist` and verify packaged wheel and module zip.
3. PowerShell: ensure SDK module discoverable; `pwsh -NoProfile -File powershell/tests/Smoke.ps1`, then Windows PowerShell 5.1 equivalent.
4. Interactive SDK-host-backed gallery: `examples/python/counter.py` and `examples/powershell/counter.ps1`, with click, edit, checkbox, dynamic list and close cycles.
5. Run the matrix in `docs/QUALIFICATION.md`; record evidence and defects instead of hiding them.
