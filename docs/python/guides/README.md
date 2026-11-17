# How-to guides

Task-oriented recipes for the Python UI library (`nativehtmlkit_ui` 0.1.1). Each guide
points to complete, harness-verified examples. The same guides exist for PowerShell:
[PowerShell how-to guides](../../powershell/guides/README.md).

| Guide | You will learn |
|---|---|
| [Reactive state and computed values](reactive-state.md) | Model data as state, derive the rest, replace instead of mutate, subscribe for side effects |
| [Layouts and the responsive grid](layouts.md) | Rows, columns, cards, grid breakpoints, density, the column field-height workaround |
| [Forms, inputs and validation](forms-and-inputs.md) | Two-way binding, validation as computed state, guarded submit, loading and saving form data |
| [Lists and conditional content](lists-and-conditional-content.md) | Conditional regions, text lists, the slot pool for rows with buttons |
| [Theming and custom CSS](theming-and-custom-css.md) | Themes, density, design-token overrides, your own styles |
| [Background work](background-work.md) | Worker threads and `ui.post()`, progress, cancel, streams and timers |
| [Multiple windows and multiple UIs](multiple-windows.md) | Several windows, shared state, noticing closed windows |
| [Mixing the UI with direct SDK calls](mixing-ui-and-sdk-calls.md) | Clipboard, file dialogs, DOM reads, error handling |
| [Trusted and untrusted content](trusted-and-untrusted-content.md) | Escaping, when raw markup is acceptable |
| [Testing your UI](testing.md) | Logic tests without a host, headless real-host tests, the example harness |

New to the library? Start with [getting started](../getting-started.md) and a
[tutorial](../tutorials/README.md). Exact signatures: the [API reference](../reference.md).
