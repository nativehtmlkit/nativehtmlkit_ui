# nativehtmlkit_ui — development-agent instructions

**Ownership:** Python and PowerShell UI component libraries.

This is an independent Git repository in the NativeHTMLKit ecosystem. Central issue tracking, approval and cross-repository coordination are in the private workspace `nativehtmlkit-project` under `work/bugs/` and `work/features/` (normally at `../../work/`). When cloning this repository alone, locate that private workspace using `NHK_PROJECT_ROOT`; do not create a duplicate issue register in this repository.

## Mandatory behavior

1. Read the root Project `AGENTS.md`, `governance/SCOPE.md`, `governance/ARCHITECTURE.md`, `governance/WORKFLOW.md`, and generated `STATUS.md` if the workspace is available. Read this repository's README, `docs/ARCHITECTURE.md` and `docs/BUILD.md` as relevant.
2. Only implement an expressly approved `B-####` or `F-####` task. Scope repository changes to the assigned issue; unrelated defects must be recorded and deferred, unless blocking or security-critical.
3. UI libraries call ONLY public language SDK APIs. Do not call Core internals, host protocol or CLI directly. Keep components deliberately minimal; no plugin systems. Verify Python/PowerShell separately. The current UI version is prerelease and known Python reactive concurrency/shutdown callback issues remain open.
4. Never silently modify another repository, publish packages, create release tags, bump versions, erase test evidence or change native host binaries. Those actions need separate task authorization and qualification.
5. Verify against the actual public API and released binary versions. Report exact commands, pass/fail/skip, runtime/OS and outstanding issues. Keep issue records current and regenerate central `STATUS.md` after work.
6. Public README/API/tutorials contain **only** verified user-facing information and never private workspace logs, credential details or release plans. Repo-local architecture is owned here, not duplicated in landing docs.

For this repository's public user documentation, start at its `README.md` and `docs/`. For public onboarding across all entrypoints, see https://github.com/nativehtmlkit/nativehtmlkit .
