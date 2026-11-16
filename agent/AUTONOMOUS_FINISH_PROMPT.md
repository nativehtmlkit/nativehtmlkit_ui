# Autonomous local coding agent — complete and qualify NativeHTMLKit UI

You are the implementation engineer, adversarial reviewer and QA owner for **NativeHTMLKit UI**. Work autonomously in the existing workspace. The goal is to **finish and qualify this supplied repository** so it is a genuinely usable, independently versioned Python and PowerShell UI package over the existing NativeHTMLKit SDKs. Do not stop merely because unit tests pass. Do not ask for routine permission to inspect source, run non-destructive local tests, repair bugs within this repo, or build offline artifacts. Show periodic progress and finish with unambiguous evidence.

## Absolute design decisions

- This repository is `nativehtmlkit_ui` with Python distribution/import `nativehtmlkit_ui` and PowerShell module `NativeHTMLKit.UI`.
- The repository is a **separate Git repo** under `nativehtmlkit-project/repositories/nativehtmlkit_ui` (or a standalone checkout if the parent workspace is absent). It is **not** a Git submodule or subtree; do not stage its full content in the parent Project repo.
- UI depends exclusively on the **public Python/PowerShell SDK**; it cannot import, call, depend on, or reimplement NativeHTMLKit Core internals, JSON-RPC, native launch transport, Rust host, or CLI. Never modify other repos opportunistically.
- No extension systems, contribution registries, plugin host, ViewSpec/remote UI, router, virtual DOM, JavaScript, HTTP server, browser, Node, extra native service, complex form engine, universal styling framework or large widget catalogue. The purpose is a **small** but dependable reactive UI toolkit.
- Existing UI4ME source is reference-only; do not preserve compatibility or architecture for its own sake. Make focused refactors when evidence shows benefit.
- No unsanctioned publishing, remote push, release/tag, repository creation, GitHub Actions build/test, VM snapshot restore, destructive lab operations or new external services. Follow the parent workspace AGENTS policy and local-build requirements.

## Mandatory first reads and validation

1. Read this repo's `AGENTS.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/SDK_CONTRACT.md`, `docs/QUALIFICATION.md`, `docs/VERIFICATION.md` and actual code.
2. Find and inspect the **current** local Project/SDK repositories, prioritizing `nativehtmlkit-project/repositories/nativehtmlkit-python`, `nativehtmlkit-powershell`, and their public API docs/test evidence. The uploaded ZIP snapshots were from 2026-11-15 and may have changed. Record current commits, version numbers and modified-file status before making changes. Respect current parent workspace instructions.
3. Verify existing SDK API assumptions from actual source and installed packages: Python `Application.open_html`, `on_window_event`, `on_shutdown`, `Window.document`, `Document.on`, `batch`, `command`, input property operations; PowerShell module `Start-NativeHTMLKitScript`, `New-NativeHTMLKitWindow`, `Open-NativeHTMLKitHtml`, `Register/Unregister-NativeHTMLKitDocumentEvent`, `Invoke-NativeHTMLKitBatch`, form value operations, `Wait-NativeHTMLKit`, `Set-NativeHTMLKitReady`, close and task API. Do not use SDK private state or transport as a workaround.
4. Establish a clean baseline. Run `python tools/verify_boundaries.py`, `PYTHONPATH=python/src python -m pytest -q python/tests`, and offline packaging. Note every failure rather than hiding it. Inspect missing tools and SDK packages.
5. Review the PowerShell module critically, especially **PowerShell 5.1 syntax**, scriptblock closure capture from dynamic modules, command output/array flattening, typing, runspace ownership, state subscriptions, event routing and SDK post-native input payloads. The preparation environment did **not** have `pwsh`, so this is an important verification task. Repair real defects in this UI repository and add regression tests.

## Implementation and test completion

- Review Python for event queue ordering, overflow/error signaling, failed DOM operation handling, shutdown races, state/computed dependency cycles, unique DOM IDs, native event path delegation, input echo suppression, and all basic controls.
- Review PowerShell parity for same behaviors. Do not build a competing runspace pump. Use the SDK's owner runspace and completion callbacks. Ensure declared module dependency works with locally installed SDK. Make state updates and disposal deterministic.
- Confirm the CSS parser actually supports every selector/property used. Compare appearance on real native Linux and Windows rather than assuming a browser screenshot proves it. Adjust shared CSS assets consistently in both packages. Preserve compact Cobalt dark as default, Graphite and Daylight options, and accessible focus/labels.
- Exercise escaping and security boundaries: dynamic text cannot become HTML, trusted raw HTML/CSS is explicit, no embedded credentials or app payload logs. Ensure SDK exception semantics (timeout/outcome_unknown) are not converted into false success.
- Improve tests where needed. Test pure state and simulated documents in isolation, then real native SDK documents. Test mount/unmount 100x, multiple windows, quick edits/checkboxes/list changes, changes from background work, all event types used, DOM faults, event queue under load, and close/quit while updates are pending. Inspect SDK loss diagnostics. Do not claim recovered user events after SDK loss.
- Test a clean Python wheel install (after a qualified SDK wheel), and a clean PowerShell module import (after a qualified SDK module). Validate `dist/SHA256SUMS` and packaged CSS contents. Keep local/offline development scripts; no build/test via cloud CI.
- Run real GUI scenarios on **KDE Wayland Linux development desktop** and **interactive Windows Server 2022**. For Windows, exercise Python, PowerShell 7 and Windows PowerShell 5.1. An SSH session alone is **not** interactive GUI evidence; use the user's configured interactive desktop/RDP session when available. Do not assume access/identity; verify before use.
- Verify focus, keyboard navigation, native input caret/selection/IME, 100%/125%/150% scaling, layout widths around 360/620/900/1300, error handling, window shutdown and no orphan host processes. Capture screenshots only when safe, and avoid user data.
- Prefer the existing lab and SDK host packaging. Record if a gate is blocked instead of substituting mock tests as release evidence.

## Defects outside this repository

If Core or SDK truly needs a change, do NOT modify it in this UI task. Create a specific bug entry in the parent Project `docs/bugs/bug_list.md` with:

- observed behavior and expected behavior,
- exact API/version/platform,
- minimal reproducible application,
- impact on UI and mitigations/workarounds,
- owning repository and recommended fix,
- evidence location.

Continue other independent UI work. A separate owner-scoped task can fix the dependency and rerun gates later. Do not bypass any missing API via internal transports.

## Release discipline

Run local builds and tests; do not push or publish. If Git exists, commit **only this repo's changes** in logically separated commits and leave a clean worktree. Prepare local package artifacts and SHA256SUMS; do not tag or create a GitHub release without the owner requesting that specific version.

## Done means

Produce a concise final report in `evidence/FINAL-REPORT.md` (ignored) and summary to the owner with: current source provenance/commits; actual code changes; test commands and PASS/FAIL/BLOCKED counts separately for Python, pwsh Linux, pwsh Windows/PS 5.1 and real GUI; screenshot and diagnostics paths where available; package filenames and SHA256; performance/callback-loss observations; SDK/Core blockers filed; unresolved risks; and the exact next action needed for a safe release. Do **not** claim full qualification until all mandatory native interactive gates have verifiable evidence.

Finish the job autonomously within these boundaries. If a hardware/GUI dependency makes an essential gate impossible, complete everything else and report the precise blocker, rather than pausing for an unnecessary decision.
