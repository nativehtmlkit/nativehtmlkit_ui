# Supplied source snapshots used for architecture and implementation

Prepared from the user-provided ZIPs. These are reference snapshots; agent must check current local repos before qualification.

| Archive | SHA-256 |
|---|---|
| `nativehtmlkit-python.zip` | `3b49bf9fbc91f33d7b639a16bcfb029738cee064d3e363e76904705b54e58590` |
| `nativehtmlkit-powershell.zip` | `1fef5f1614f494905caf05fa4c81b2cfdcd8c62d4b32d2d76f0e1f1e4cacaa1d` |
| `nativehtmlkit-core(1).zip` | `074d51ad5b919f9f4f5cb01213701f1951b3029120b6b677fe60c88574621824` |
| `nativehtmlkit-cli(1).zip` | `34ce5e7d193ae556357ee0d14d4616b5df05fd2a88d17c0e948f40ad85af5682` |
| `nativehtmlkit-project(2).zip` | `e71cf334b18d23f009de2189669d4c6305e347e8959788533229560767bcd8ab` |
| `ui4me-main(20261115-231733).zip` | `2c6ecfe55daec4b36d46cc61ecfe1f36ce966d42078b132ac4eeebb3634fcb04` |
| `ui4me-design-reference-v0.1(1).zip` | `092099262a4b10d4600f5c56f1a0544751b5507f1241db6d82a5aa7de8bb1b21` |
| `NativeHTMLKit-Discussion-Reviews-2026-11-15(1).zip` | `d9f8b9aa9aac4358bd50c0f9cdad8caab34195772ffef48be2f981e1b505fbc8` |

Key inspected APIs:

- Python SDK: `src/nativehtmlkit/application.py` for Application, Window, Document event and mutation methods; `asyncio_api.py`; README and tests.
- PowerShell SDK: `NativeHTMLKit/NativeHTMLKit.psm1`, `NativeHTMLKit.psd1`, README and integration tests.
- Core: `protocol/v1/schemas/document-command.schema.json` and `docs/reference/legacy-css-profile.md` for batch operations and CSS capabilities.
- Project: `agents/shared.md`, `agents/environment.md`, `AGENTS.md` for repo boundaries and local release policy.
- UI4ME design reference: `ui4me-tokens.css` (visual inspiration only); UI4ME runtime is not imported or built upon.

The new UI source does not include or alter any of these repositories. SHA-256 checksums refer to the original attachments, not installed SDK/host versions.
