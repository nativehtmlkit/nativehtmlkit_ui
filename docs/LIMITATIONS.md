# UI limitations and qualification

The UI v0.1.0 GitHub release is a prerelease. The detailed visual qualification was performed with earlier SDK/Core combinations; it does not independently prove every capability under Core 1.0.3, Python/PowerShell SDK 0.1.1. Screen-reader validation is incomplete and Core's select/Orca announcement issue remains open.

**Known UI bugs recorded in the Project register:** Python `Computed` can falsely raise a circular dependency error and retain a stale value during concurrent updates; disposing many UI windows can accumulate SDK shutdown callbacks. Until fixed, serialize writes affecting the same computed state, use background worker handoff via `ui.post`, and avoid rapidly creating/discarding many UIs in long-lived applications.

There is no UI modal wrapper, router, plugin system, arbitrary widget gallery, virtualized data grid, video/audio player, JS runtime, or HTTP server. The SDK may expose underlying HTML dialogs and bitmap surfaces; do not claim them as UI components.
