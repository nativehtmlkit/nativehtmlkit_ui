# How-to guides

Task-oriented recipes for NativeHTMLKit UI 0.1.1. Each guide shows Python and PowerShell side by
side and points to a complete, harness-verified example.

| Guide | You will learn | Examples |
|---|---|---|
| [Reactive state and computed values](reactive-state.md) | Model data as state, derive the rest, replace instead of mutate, subscribe for side effects | `expenses`, `settings`, `multi_window` |
| [Layouts and the responsive grid](layouts.md) | Rows, columns, cards, grid breakpoints, density | `settings`, `dashboard` |
| [Forms, inputs and validation](forms-and-inputs.md) | Two-way binding, validation as computed state, guarded submit, reset | `signup_form`, `expenses` |
| [Lists and conditional content](lists-and-conditional-content.md) | `when`, text lists, the slot pool for rows with buttons | `todo`, `log_viewer` |
| [Theming and custom CSS](theming-and-custom-css.md) | Themes, density, token overrides, your own classes | `dashboard`, `message_preview` |
| [Background work](background-work.md) | Python threads + `ui.post()`, PowerShell tasks on the owner runspace, timers, cancel | `background`, `log_viewer`, `dashboard` |
| [Multiple windows](multiple-windows.md) | Several UIs, shared state, close handling | `multi_window` |
| [Mixing the UI with SDK calls](mixing-ui-and-sdk-calls.md) | Clipboard, file dialogs, DOM reads, error handling | `clipboard_tool`, `file_picker` |
| [Trusted and untrusted content](trusted-and-untrusted-content.md) | Escaping, when `raw_html` is acceptable | `message_preview` |
| [Testing your UI](testing.md) | Unit tests, headless real-host tests, the example harness | all |

New to the library? Start with a [tutorial](../tutorials/README.md). Looking for exact
signatures? See the [API reference](../API.md).
