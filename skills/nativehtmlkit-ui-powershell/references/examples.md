# PowerShell UI example notes

`Add-NHKUiSelect -UI $ui -Bind $choice -Options @(@{Value='a';Label='A'})` uses a state. Always `.Set()` a NEW array (`$s.Items.Set(@($s.Items.Value) + @($x))`); assigning `.Value` does not notify. Return arrays from `-Compute` with a leading comma: `, @(...)`. When changing many bindings at once outside a callback, prefer `Invoke-NHKUiBatch`. Keep reactive updates on the owner runspace and use SDK task-completion callbacks for background worker results.

Verified example scripts (PowerShell 7 and 5.1; each also exists in Python): https://github.com/nativehtmlkit/nativehtmlkit_ui/tree/main/examples — expenses (tutorial app), todo (slot pool), signup_form, settings, log_viewer and dashboard (task-based timer), background (task with cancel), clipboard_tool and file_picker (SDK calls), multi_window (window.event), message_preview (encoding vs `Add-NHKUiHtml`).

Reference: https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/docs/reference/powershell.md
Full gallery: https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/powershell-ui/gallery.ps1
