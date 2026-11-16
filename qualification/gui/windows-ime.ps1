# Add / restore the Microsoft Japanese IME for the CURRENT user only (run inside the GUI user's
# session). No language pack, no reboot, no machine-wide change. Same approach as the Project's
# native-journeys lab-ime.ps1.   powershell -File windows-ime.ps1 -Mode on|off -State <dir>
param([Parameter(Mandatory)][ValidateSet('on', 'off')][string]$Mode, [Parameter(Mandatory)][string]$State)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $State | Out-Null
$snap = Join-Path $State 'languages-before.json'
function Show { ,@(foreach ($l in (Get-WinUserLanguageList)) { [pscustomobject]@{ tag = $l.LanguageTag; tips = @($l.InputMethodTips) } }) }
if ($Mode -eq 'on') {
    if (-not (Test-Path $snap)) { Show | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $snap }
    $list = Get-WinUserLanguageList
    if (-not ($list | Where-Object LanguageTag -eq 'ja')) { $list.Add((New-WinUserLanguageList 'ja-JP')[0]); Set-WinUserLanguageList $list -Force }
} else {
    $before = @(Get-Content $snap -Raw | ConvertFrom-Json)
    $list = New-WinUserLanguageList $before[0].tag
    $list[0].InputMethodTips.Clear(); foreach ($t in $before[0].tips) { $list[0].InputMethodTips.Add($t) }
    for ($i = 1; $i -lt $before.Count; $i++) {
        $l = New-WinUserLanguageList $before[$i].tag
        $l[0].InputMethodTips.Clear(); foreach ($t in $before[$i].tips) { $l[0].InputMethodTips.Add($t) }
        $list.Add($l[0])
    }
    Set-WinUserLanguageList $list -Force
}
Show | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $State "languages-after-$Mode.json")
