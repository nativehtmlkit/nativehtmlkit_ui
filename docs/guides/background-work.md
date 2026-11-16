# Background work

**Goal:** run slow or periodic work without freezing the window, and get the results into the
UI safely.

## Python: worker threads + `ui.post()`

Event handlers run on the UI owner thread. While one runs, no other event, posted function or
DOM update of that UI is processed, so handlers must return quickly. Submit slow work to a
thread or executor, and hand the result back with `ui.post(fn, *args)`, which runs `fn` on the
owner (`examples/python/background.py`):

```python
executor = ThreadPoolExecutor(max_workers=2)

def finished(text):                  # runs on the UI owner
    status.set(text)
    busy.set(False)

def run(_event):
    busy.set(True)
    status.set("Running")
    future = executor.submit(lambda: sum(range(500_000)))

    def completed(f):                # runs on an executor thread
        try:
            ui.post(finished, f"Done: {f.result()}")
        except Exception as exc:
            ui.post(finished, f"Failed: {type(exc).__name__}")
    future.add_done_callback(completed)

ui.button("Calculate", on_click=run, disabled=busy)
ui.mount(app)
app.on_shutdown(lambda: executor.shutdown(wait=False, cancel_futures=True))
```

Why `post()` and not `status.set()` directly from the worker? Setting a state from another
thread is allowed and the UI write still happens on the owner, but:

- the open defect **B-0002** can corrupt a `Computed` whose dependencies are set from several
  threads at once, and
- doing all writes on the owner keeps your handlers and posted functions free of races
  (`receive()` in the log viewer reads `paused.value` and writes one of two lists).

### Streams and timers

A producer thread that posts many items (`examples/python/log_viewer.py`):

```python
stop = threading.Event()

def produce():
    n = 0
    while not stop.wait(0.2):
        n += 1
        try:
            ui.post(receive, make_line(n))
        except RuntimeError:            # owner queue full (4096): drop instead of blocking
            pass

threading.Thread(target=produce, daemon=True).start()
app.on_shutdown(stop.set)
```

The same structure gives a one-second clock (`examples/python/dashboard.py`). Several posts
before the owner catches up are coalesced into one window update.

### SDK futures

SDK calls with `wait=False` return a `concurrent.futures.Future`; the file picker hands its
result over the same way: `future.add_done_callback(lambda f: ui.post(chosen, f))`.

## PowerShell: owner runspace + SDK tasks

The UI may only be changed on the runspace that started it. PowerShell work in another
runspace (`Start-NativeHTMLKitTask`) cannot touch UI states; it receives plain data and returns
plain data. The SDK runs `-OnCompleted` / `-OnFailed` later **on the owner runspace**, while
`Wait-NativeHTMLKit` pumps, and those callbacks may set states
(`examples/powershell/background.ps1`):

```powershell
$s.Task = Start-NativeHTMLKitTask -Application $s.App -ArgumentList @(500000) -TimeoutMilliseconds 60000 -ScriptBlock {
    param([int]$n)
    $sum = [long]0
    for ($i = 0; $i -lt $n; $i++) { $sum += $i }
    $sum
} -OnCompleted {
    param($result)                  # the worker's output as an array
    $s.Status.Set('Done: ' + $result[0])
    $s.Busy.Set($false)
} -OnFailed {
    param($failure)                 # an exception; OperationCanceledException after Stop-NativeHTMLKitTask
    $s.Status.Set('Failed: ' + $failure.GetType().Name)
    $s.Busy.Set($false)
}
```

- `Stop-NativeHTMLKitTask -Task $s.Task` requests cancellation; `-OnFailed` then receives an
  `OperationCanceledException` (verified by the example harness).
- The SDK allows 8 running tasks per application; `Close-NativeHTMLKit` stops tasks that are
  still running.
- Several `.Set()` calls in a task callback are separate writes; wrap them in
  `Invoke-NHKUiBatch -UI $ui -ScriptBlock { ... }` to write once (`Update-Dashboard` in the
  dashboard example does this).

### Timers

There is no timer cmdlet. A task that only sleeps, whose completion callback does the work and
starts the next task, gives a periodic tick on the owner runspace
(`examples/powershell/log_viewer.ps1`, `dashboard.ps1`):

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

Never call `.Set()` on a UI state from `ForEach-Object -Parallel`, thread jobs, raw runspaces
or .NET event handlers: the module throws
`UI updates must run on the SDK owning runspace`.
