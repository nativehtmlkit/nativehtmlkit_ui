"""Word counter: count words in a text file in a worker thread, with progress and Cancel.

Teaches: starting background work from a button, handing progress and results back to the UI
owner with ui.post(), throttled progress (at most five updates per second), a Cancel button
driven by a threading.Event, and a busy state that disables Count while the worker runs.
Run:     uv run word_counter.py [FILE]   (without FILE it counts 20,000 lines of generated text)
Guide:   docs/python/guides/background-work.md
"""
import re
import sys
import threading
import time
from collections import Counter
from pathlib import Path

from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state

WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)?")
SAMPLE_WORDS = "the quick brown fox jumps over the lazy dog while native windows render html".split()
SAMPLE_LINES = 20_000


def sample_lines():
    return [" ".join(SAMPLE_WORDS[(i + j) % len(SAMPLE_WORDS)] for j in range(9)) for i in range(SAMPLE_LINES)]


def main():
    with Application.start(name="Word counter") as app:
        source = Path(sys.argv[1]) if len(sys.argv) > 1 else None
        progress = state("Press Count to start.")
        top_words = state([])
        running = state(False)
        cancel = threading.Event()

        def finish(message, words):          # runs on the UI owner thread
            progress.set(message)
            top_words.set(words)
            running.set(False)

        def work():                          # runs on the worker thread; touches no state
            try:
                lines = source.read_text(encoding="utf-8", errors="replace").splitlines() if source else sample_lines()
            except OSError as error:
                ui.post(finish, f"Cannot read the file: {error.strerror or error}", [])
                return
            counts, last = Counter(), 0.0
            for number, line in enumerate(lines, 1):
                if cancel.is_set():
                    ui.post(finish, "Cancelled.", [])
                    return
                counts.update(word.lower() for word in WORD.findall(line))
                if time.monotonic() - last > 0.2:
                    last = time.monotonic()
                    ui.post(progress.set, f"{number / max(1, len(lines)):.0%} - {number:,} lines")
            ui.post(finish, f"Done: {sum(counts.values()):,} words, {len(counts):,} different, {len(lines):,} lines.",
                    [f"{word}: {count:,}" for word, count in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:10]])

        def start(_event):
            if running.value:
                return
            cancel.clear()
            running.set(True)
            top_words.set([])
            progress.set("Starting...")
            threading.Thread(target=work, name="word-count", daemon=True).start()

        ui = UI(title="Word counter", theme="daylight", density="regular", width=560, height=560)
        with ui.column():
            ui.heading("Word counter", level=1)
            ui.text(f"Source: {source.name if source else 'generated sample text'}", muted=True)
            with ui.row():
                ui.button("Count", on_click=start, disabled=running)
                ui.button("Cancel", variant="secondary", on_click=lambda _e: cancel.set(),
                          disabled=lambda: not running.value)
            ui.alert(progress)
            with ui.card():
                ui.heading("Most frequent words", level=2)
                ui.text_list(top_words)
        try:
            ui.mount(app)
            app.on_shutdown(cancel.set)
            app.run()
        finally:
            cancel.set()
            ui.dispose()


if __name__ == "__main__":
    main()
