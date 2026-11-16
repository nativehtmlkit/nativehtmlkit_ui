# Background work

*PowerShell (`NativeHTMLKit.UI` 0.1.1; PowerShell 7.2+ and Windows PowerShell 5.1). The same
guide for Python: [background work](../../python/guides/background-work.md).*

**Goal:** run slow or periodic work without freezing the window, report progress, cancel it,
and get the results into the UI safely.

## The rule

The UI may only be changed on the runspace that started it (the *owner runspace*). Work in
another runspace (`Start-NativeHTMLKitTask`) cannot touch UI states; it receives plain data and
returns plain data. The SDK runs `-OnCompleted` / `-OnFailed` later **on the owner runspace**,
while `Wait-NativeHTMLKit` pumps, and those callbacks may set states.

Never call `.Set()` on a UI state from `ForEach-Object -Parallel`, thread jobs, raw runspaces or
.NET event handlers: the module throws `UI updates must run on the SDK owning runspace`.

## Run one job and report the result

From the [`background` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/background.ps1):

```powershell
$s.Task = Start-NativeHTMLKitTask -Application $s.App -ArgumentList @(500000) -TimeoutMilliseconds 60000 -ScriptBlock {
    param([int]$n)                   # runs in another runspace; sees only its arguments
    $sum = [long]0
    for ($i = 0; $i -lt $n; $i++) { $sum += $i }
    $sum
} -OnCompleted {
    param($result)                   # the worker's output as an array; runs on the owner
    $s.Status.Set('Done: ' + $result[0])
    $s.Busy.Set($false)
} -OnFailed {
    param($failure)                  # an exception; OperationCanceledException after Stop-NativeHTMLKitTask
    if ($failure -is [OperationCanceledException]) { $s.Status.Set('Cancelled') }
    else { $s.Status.Set('Failed: ' + $failure.GetType().Name) }
    $s.Busy.Set($false)
}
```

- `Stop-NativeHTMLKitTask -Task $s.Task` requests cancellation; `-OnFailed` then receives an
  `OperationCanceledException` (verified by the example harness).
- The SDK allows 8 running tasks per application; `Close-NativeHTMLKit` stops tasks that are
  still running.
- Several `.Set()` calls in a task callback are separate window writes; wrap them in
  `Invoke-NHKUiBatch -UI $ui -ScriptBlock { ... }` to write once.

## Report progress and cancel

A task cannot report progress while it runs. Split the work into chunks instead: each chunk is
one task, its `-OnCompleted` merges the partial result, updates the progress state and starts
the next chunk. Cancel sets a flag that the next chunk checks and stops the running task. From
the [`word_counter` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/word_counter.ps1):

```powershell
function Start-Chunk {
    if ($s.Cancel) { Complete-Count 'Cancelled.' @(); return }
    if ($s.Next -ge $s.Lines.Count) { <# all chunks done: report the totals #> return }
    $count = [Math]::Min($chunkSize, $s.Lines.Count - $s.Next)
    $chunk = [string[]]$s.Lines[$s.Next..($s.Next + $count - 1)]
    $s.Next += $count
    $s.Task = Start-NativeHTMLKitTask -Application $s.App -ArgumentList (, $chunk) -ScriptBlock {
        param([string[]]$lines)
        $counts = @{}
        # ... count the words of this chunk ...
        $counts                              # a plain hashtable goes back to the owner
    } -OnCompleted {
        param($result)
        foreach ($entry in $result[0].GetEnumerator()) { <# merge into $s.Counts #> }
        $s.Progress.Set(('{0}% - {1} lines' -f [Math]::Round(100.0 * $s.Next / $s.Lines.Count), $s.Next))
        Start-Chunk
    } -OnFailed {
        param($failure)
        if ($s.Cancel) { Complete-Count 'Cancelled.' @() } else { Complete-Count ('Failed: ' + $failure.Message) @() }
    }
}
```

`, $chunk` passes the array as **one** argument; without the comma every line would become a
separate argument. `Complete-Count` sets three states inside `Invoke-NHKUiBatch`.

## Streams and timers

There is no timer cmdlet. A task that only sleeps, whose completion callback does the work and
starts the next task, gives a periodic tick on the owner runspace (the
[`log_viewer` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/powershell/log_viewer.ps1)
and the `dashboard` example):

```powershell
function Start-Tick {
    $null = Start-NativeHTMLKitTask -Application $app -ScriptBlock { Start-Sleep -Milliseconds 200 } -OnCompleted {
        param($result)
        Add-LogLine $s
        Start-Tick
    }
}
$null = Start-NHKUi -UI $ui -Application $app
Start-Tick
Wait-NativeHTMLKit -Application $app -UntilShutdown
```

Each tick creates a runspace, which is fine for a few ticks per second, not for animation.

## SDK calls that wait

Calls such as `Show-NativeHTMLKitFileDialog` wait inside the button callback while the SDK keeps
processing host messages; their result is available when they return (the
[SDK calls guide](mixing-ui-and-sdk-calls.md)).

## Related

[PowerShell reference: the owner runspace](../reference.md#the-owner-runspace) ·
[reactive state](reactive-state.md) ·
[PowerShell SDK](https://github.com/nativehtmlkit/nativehtmlkit-powershell)
