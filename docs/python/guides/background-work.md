# Background work

*Python (`nativehtmlkit_ui` 0.1.1). The same guide for PowerShell:
[background work](../../powershell/guides/background-work.md).*

**Goal:** run slow or periodic work without freezing the window, report progress, cancel it,
and get the results into the UI safely.

## The rule

Event handlers run on the UI owner thread. While one runs, no other event, posted function or
DOM update of that UI is processed, so handlers must return quickly. Run slow work elsewhere
(a thread or an executor) and hand every result back with `ui.post(fn, *args)`, which runs `fn`
on the UI owner.

Why `post()` and not `state.set()` directly from the worker? Setting a state from another
thread is allowed and the window write still happens on the owner, but:

- the open defect **B-0002** can corrupt a `Computed` whose dependencies are set from several
  threads at once, and
- doing all writes on the owner keeps your handlers and posted functions free of races.

## Run one job and report the result

From the [`background` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/background.py):

```python
executor = ThreadPoolExecutor(max_workers=2)
cancel = threading.Event()

def calculate(n):                    # runs on an executor thread; touches no state
    total = 0
    for start in range(0, n, 10_000):
        if cancel.is_set():
            raise InterruptedError("cancelled")
        total += sum(range(start, min(n, start + 10_000)))
    return total

def finished(text):                  # runs on the UI owner
    status.set(text)
    busy.set(False)

def run(_event):
    cancel.clear()
    busy.set(True)
    status.set("Running")
    future = executor.submit(calculate, 500_000)

    def completed(f):                # runs on an executor thread
        try:
            ui.post(finished, f"Done: {f.result()}")
        except InterruptedError:
            ui.post(finished, "Cancelled")
        except Exception as exc:
            ui.post(finished, f"Failed: {type(exc).__name__}")
    future.add_done_callback(completed)

ui.button("Calculate", on_click=run, disabled=busy)
ui.button("Cancel", variant="secondary", on_click=lambda _e: cancel.set(), disabled=lambda: not busy.value)
ui.mount(app)
app.on_shutdown(cancel.set)
app.on_shutdown(lambda: executor.shutdown(wait=False, cancel_futures=True))
```

## Report progress and cancel

A worker that reports progress posts small updates, at most a few per second. From the
[`word_counter` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/word_counter.py):

```python
def work():                                  # worker thread; touches no state
    counts, last = Counter(), 0.0
    for number, line in enumerate(lines, 1):
        if cancel.is_set():
            ui.post(finish, "Cancelled.", [])
            return
        counts.update(word.lower() for word in WORD.findall(line))
        if time.monotonic() - last > 0.2:    # at most five updates per second
            last = time.monotonic()
            ui.post(progress.set, f"{number / len(lines):.0%} - {number:,} lines")
    ui.post(finish, f"Done: {sum(counts.values()):,} words ...", top_ten(counts))
```

`ui.post(progress.set, text)` is the shortest way to set one state on the owner. Several posts
before the owner catches up are coalesced into one window update.

## Streams and timers

A producer thread that posts many items (the
[`log_viewer` example](https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/examples/python/log_viewer.py)):

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

The same structure gives a one-second clock (the `dashboard` example): a thread that waits
one second and posts the new time.

## SDK futures

SDK calls with `wait=False` return a `concurrent.futures.Future`; hand their result over the
same way: `future.add_done_callback(lambda f: ui.post(chosen, f))` (the
[SDK calls guide](mixing-ui-and-sdk-calls.md)).

## Related

[Python reference: `post()` and `sync()`](../reference.md#post-and-sync) ·
[reactive state](reactive-state.md) ·
[Python SDK](https://github.com/nativehtmlkit/nativehtmlkit-python)
