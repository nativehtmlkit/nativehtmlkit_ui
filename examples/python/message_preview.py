"""Message composer: untrusted user text is always escaped; only static help uses raw_html().

Teaches: the trust boundary. Everything a user types reaches the window through text bindings
(ui.text, ui.text_list), which escape it, so typing <b>hi</b> shows those characters literally.
ui.raw_html() is used only for a fixed, developer-written snippet. Also: a length limit with a
computed counter and a sent-messages list.

Run:  python message_preview.py      (pip install nativehtmlkit_ui)
"""
from nativehtmlkit_ui import UI, computed, state

LIMIT = 140
HELP = """
<table class="help">
  <tr><th>Tip</th><th>Why</th></tr>
  <tr><td>Type <code>&lt;b&gt;</code> in the message</td><td>It is shown as text, never as markup.</td></tr>
  <tr><td>Keep it under <strong>140</strong> characters</td><td>Longer messages cannot be sent.</td></tr>
</table>
"""
CSS = ".help { border-collapse: collapse; width: 100%; } .help td, .help th { text-align: left; padding: 4px 8px;" \
      " border-bottom: 1px solid var(--nhk-border); }"


def main(app):
    recipient = state("")
    message = state("")
    sent = state([])
    remaining = computed(lambda: LIMIT - len(message.value))

    def send(_event):
        if message.value.strip() and remaining.value >= 0:
            sent.set([f"To {recipient.value.strip() or 'everyone'}: {message.value.strip()}", *sent.value][:10])
            message.set("")

    ui = UI(title="Message composer", width=700, height=640, extra_css=CSS)
    with ui.column():
        ui.heading("Compose a message", level=1)
        with ui.card():
            ui.input(recipient, label="To", placeholder="Team channel")
            ui.input(message, label="Message", placeholder="Say something")
            with ui.row():
                ui.button("Send", on_click=send, disabled=lambda: not message.value.strip() or remaining.value < 0)
                ui.badge(lambda: f"{remaining.value} characters left")
            with ui.when(lambda: remaining.value < 0):
                ui.alert(lambda: f"Too long by {-remaining.value} characters.")
        with ui.card():
            ui.heading("Preview (escaped text)", level=3)
            ui.text(lambda: message.value or "Nothing typed yet.")
        with ui.card():
            ui.heading("Sent", level=3)
            with ui.when(lambda: not sent.value):
                ui.text("No messages sent yet.", muted=True)
            ui.text_list(sent)
        ui.raw_html(HELP)                       # trusted, static, written by the developer
    ui.mount(app)


if __name__ == "__main__":
    from nativehtmlkit import Application
    with Application.start(name="Message composer") as application:
        main(application)
        application.run()
