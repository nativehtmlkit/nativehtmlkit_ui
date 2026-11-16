"""Background computation safely reports results through ui.post()."""
from concurrent.futures import ThreadPoolExecutor
from nativehtmlkit_ui import UI, state


def main(app):
    status = state("Idle")
    ui = UI(title="Background example")
    executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="ui-example")

    def run(_):
        status.set("Running")
        future = executor.submit(lambda: sum(range(500_000)))
        def completed(f):
            try:
                answer = f.result()
                ui.post(status.set, f"Done: {answer}")
            except Exception as exc:
                ui.post(status.set, f"Failed: {type(exc).__name__}")
        future.add_done_callback(completed)

    with ui.column():
        ui.heading("Background work")
        ui.text(status)
        ui.button("Calculate", on_click=run)
    ui.mount(app)
    app.on_shutdown(lambda: executor.shutdown(wait=False, cancel_futures=True))


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="NativeHTMLKit Background") as application:
        main(application)
        application.run()
