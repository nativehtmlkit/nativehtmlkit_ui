# Small, evidence-driven development roadmap

This repository intentionally does **not** contain a speculative widget/extension backlog. Scope stays small until actual applications establish a need.

## Current version candidate 0.1

- Runtime/component implementations for Python/PowerShell.
- Small shared responsive CSS theme.
- Offline build and packaging scripts.
- Python fake-SDK unit/integration tests and explicit local-agent handoff.

Status 2026-11-16: verified and corrected against the published SDK 0.1.0, PowerShell on both editions and real GUI qualification completed (`docs/VERIFICATION.md`). Next: re-run the harness against the SDK 0.1.1 / Core 1.0.3 releases once published, and add a screen-reader pass.

## After qualification

- Improve core input/focus, accessibility, diagnostics and performance based on observed native GUI evidence.
- Add **only** repeated, demonstrably useful components, likely one small semantic table and basic loading/error-status helpers, but do not commit to their API until needed.
- Keep distribution assets small, local and reproducible. UI versions remain independent of host/SDK versions.

## Explicit permanent non-goals of this package

Plugin/extension discovery and contributions, ViewSpec, browser/WebKit/JavaScript, runtime HTTP/daemon, universal routing/state-persistence framework, heavy virtual DOM, automatic deep mutable-object proxying and a hundred-component catalogue. Application-level code or separately developed packages may provide those if needed later; no such infrastructure belongs in `nativehtmlkit_ui` now.
