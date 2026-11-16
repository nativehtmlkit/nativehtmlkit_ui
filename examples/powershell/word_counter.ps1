# Word counter: count words in a text file with SDK background tasks, with progress and Cancel.
#
# Teaches: splitting work into chunks that each run in Start-NativeHTMLKitTask (a separate
#          runspace that receives plain data only), merging each chunk's result and reporting
#          progress in -OnCompleted on the owner runspace, starting the next chunk from there,
#          Cancel via a flag plus Stop-NativeHTMLKitTask, Invoke-NHKUiBatch for several .Set()
#          calls in one write, and a busy state that disables Count while work runs.
# Run:     pwsh -File ./word_counter.ps1 [FILE]   |   powershell.exe -NoProfile -File .\word_counter.ps1 [FILE]
#          (without FILE it counts 20,000 lines of generated text)
# Guide:   docs/powershell/guides/background-work.md
param([string]$Path)
$ErrorActionPreference = 'Stop'
Import-Module NativeHTMLKit.UI
$app = Start-NativeHTMLKitScript -Name 'Word counter'

$culture = [Globalization.CultureInfo]::InvariantCulture
$s = @{ App = $app; Path = $Path; Lines = @(); Next = 0; Counts = @{}; Task = $null; Cancel = $false
        Progress = (New-NHKUiState -Value 'Press Count to start.'); TopWords = (New-NHKUiState -Value @())
        Running = (New-NHKUiState -Value $false) }
$s.Idle = New-NHKUiComputed -DependsOn @($s.Running) -Data $s -Compute { param($s) -not $s.Running.Value }
$chunkSize = 2000

function Format-Number([long]$Value) { return [string]::Format($culture, '{0:N0}', $Value) }

function Read-Lines {
    if ($s.Path) { return , [IO.File]::ReadAllLines([IO.Path]::GetFullPath($s.Path)) }
    # Generated sample: line i is nine consecutive words of a fixed list, starting at word i.
    $words = 'the quick brown fox jumps over the lazy dog while native windows render html'.Split(' ')
    $distinct = @(for ($i = 0; $i -lt $words.Count; $i++) { (@(for ($j = 0; $j -lt 9; $j++) { $words[($i + $j) % $words.Count] })) -join ' ' })
    return , [string[]]@(for ($i = 0; $i -lt 20000; $i++) { $distinct[$i % $words.Count] })
}

function Complete-Count([string]$Message, [object[]]$Words) {
    Invoke-NHKUiBatch -UI $ui -ScriptBlock {
        $s.Progress.Set($Message)
        $s.TopWords.Set($Words)
        $s.Running.Set($false)
    }
}

function Start-Chunk {
    if ($s.Cancel) { Complete-Count 'Cancelled.' @(); return }
    $total = $s.Lines.Count
    if ($s.Next -ge $total) {
        $sum = [long]0
        foreach ($value in $s.Counts.Values) { $sum += $value }
        $top = @($s.Counts.GetEnumerator() | Sort-Object @{ Expression = 'Value'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            Select-Object -First 10 | ForEach-Object { '{0}: {1}' -f $_.Name, (Format-Number $_.Value) })
        Complete-Count ('Done: {0} words, {1} different, {2} lines.' -f (Format-Number $sum), (Format-Number $s.Counts.Count), (Format-Number $total)) $top
        return
    }
    $count = [Math]::Min($chunkSize, $total - $s.Next)
    $chunk = [string[]]$s.Lines[$s.Next..($s.Next + $count - 1)]
    $s.Next += $count
    # The worker sees only its argument (an array of strings) and returns a plain hashtable.
    $s.Task = Start-NativeHTMLKitTask -Application $s.App -ArgumentList (, $chunk) -TimeoutMilliseconds 60000 -ScriptBlock {
        param([string[]]$lines)
        $pattern = New-Object Text.RegularExpressions.Regex("[^\W\d_]+(?:'[^\W\d_]+)?")
        $counts = @{}
        foreach ($line in $lines) {
            foreach ($match in $pattern.Matches($line)) {
                $word = $match.Value.ToLowerInvariant()
                if ($counts.ContainsKey($word)) { $counts[$word]++ } else { $counts[$word] = 1 }
            }
        }
        $counts
    } -OnCompleted {
        param($result)
        foreach ($entry in $result[0].GetEnumerator()) {
            if ($s.Counts.ContainsKey($entry.Key)) { $s.Counts[$entry.Key] += $entry.Value } else { $s.Counts[$entry.Key] = $entry.Value }
        }
        $s.Progress.Set(('{0}% - {1} lines' -f [Math]::Round(100.0 * $s.Next / [Math]::Max(1, $s.Lines.Count)), (Format-Number $s.Next)))
        Start-Chunk
    } -OnFailed {
        param($failure)
        if ($s.Cancel) { Complete-Count 'Cancelled.' @() } else { Complete-Count ('Failed: ' + $failure.Message) @() }
    }
}

$ui = New-NHKUi -Title 'Word counter' -Theme daylight -Density regular -Width 560 -Height 560
$source = if ($Path) { [IO.Path]::GetFileName($Path) } else { 'generated sample text' }
$null = Add-NHKUiColumn -UI $ui -Content {
    $null = Add-NHKUiHeading -UI $ui -Text 'Word counter' -Level 1
    $null = Add-NHKUiText -UI $ui -Text "Source: $source" -Muted
    $null = Add-NHKUiRow -UI $ui -Content {
        $null = Add-NHKUiButton -UI $ui -Text 'Count' -DisabledState $s.Running -Data $s -OnClick {
            param($eventObject, $s)
            if ($s.Running.Value) { return }
            try { $s.Lines = Read-Lines }
            catch { $s.Progress.Set('Cannot read the file: ' + $_.Exception.Message); return }
            $s.Next = 0; $s.Counts = @{}; $s.Cancel = $false
            $s.Running.Set($true)
            $s.TopWords.Set(@())
            $s.Progress.Set('Starting...')
            Start-Chunk
        }
        $null = Add-NHKUiButton -UI $ui -Text 'Cancel' -Variant secondary -DisabledState $s.Idle -Data $s -OnClick {
            param($eventObject, $s)
            $s.Cancel = $true
            if ($null -ne $s.Task) { Stop-NativeHTMLKitTask -Task $s.Task }
        }
    }
    $null = Add-NHKUiAlert -UI $ui -Bind $s.Progress
    $null = Add-NHKUiCard -UI $ui -Content {
        $null = Add-NHKUiHeading -UI $ui -Text 'Most frequent words' -Level 2
        $null = Add-NHKUiTextList -UI $ui -Bind $s.TopWords
    }
}

try {
    $null = Start-NHKUi -UI $ui -Application $app
    Wait-NativeHTMLKit -Application $app -UntilShutdown
} finally {
    Stop-NHKUi -UI $ui
    $s.Idle.Dispose()
    Close-NativeHTMLKit -Application $app      # also stops a task that is still running
}
