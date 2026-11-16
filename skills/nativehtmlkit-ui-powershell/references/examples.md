# PowerShell UI example notes

`Add-NHKUiSelect -UI $ui -Bind $choice -Options @(@{Value='a';Label='A'})` uses a state. When changing many bindings at once, prefer `Invoke-NHKUiBatch`. Keep reactive updates on the owner runspace and use SDK task-completion callbacks for background worker results.

Full gallery: https://github.com/nativehtmlkit/nativehtmlkit/blob/main/examples/powershell-ui/gallery.ps1
