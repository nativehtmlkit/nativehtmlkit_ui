"""Background calculation: run slow work on a thread pool and report the result with ui.post().

Teaches: never block a UI event handler with slow work; submit it to an executor, then hand the
result (or the error) back to the UI owner with ui.post(); a busy flag that disables the button;
shutting the executor down from app.on_shutdown().

Run:  python background.py      (pip install nativehtmlkit_ui)
"""
from concurrent.futures import ThreadPoolExecutor

from nativehtmlkit_ui import UI, state


def main(app):
    status = state("Idle")
    busy = state(False)
    ui = UI(title="Background example")
    executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="ui-example")

    def finished(text: str) -> None:            # runs on the UI owner
        status.set(text)
        busy.set(False)

    def run(_event):
        busy.set(True)
        status.set("Running")
        future = executor.submit(lambda: sum(range(500_000)))

        def completed(f):                       # runs on an executor thread
            try:
                ui.post(finished, f"Done: {f.result()}")
            except Exception as exc:
                ui.post(finished, f"Failed: {type(exc).__name__}")
        future.add_done_callback(completed)

    with ui.column():
        ui.heading("Background work")
        ui.text(status)
        ui.button("Calculate", on_click=run, disabled=busy)
    ui.mount(app)
    app.on_shutdown(lambda: executor.shutdown(wait=False, cancel_futures=True))


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="NativeHTMLKit Background") as application:
        main(application)
        application.run()
