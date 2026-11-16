import pytest
from nativehtmlkit_ui import UI


class FakeDocument:
    def __init__(self):
        self.handlers = {}
        self.calls = []
        self.values = {}
        self.checks = {}
        self.attrs = {}
        self.texts = {}
        self.fragments = {}

    def on(self, kind, callback, *, element=None):
        self.handlers.setdefault(kind, []).append(callback)
        def unsubscribe():
            self.handlers[kind].remove(callback)
        return unsubscribe

    def emit(self, kind, id_, **other):
        event = {"type": kind, "element": id_, "path": [id_], **other}
        for callback in tuple(self.handlers.get(kind, [])):
            callback(event)

    def batch(self, operations):
        self.calls.append(("batch", operations))
        for op in operations:
            self.command(op["op"], **{k:v for k,v in op.items() if k != "op"})

    def command(self, op, **fields):
        self.calls.append((op, fields))
        if op == 'set_text':
            self.texts[fields['element']] = fields['text']
        if op == 'set_attribute':
            self.attrs[(fields['element'], fields['name'])] = fields['value']
        if op == 'remove_attribute':
            self.attrs.pop((fields['element'], fields['name']), None)

    def set_value(self, ident, value):
        self.calls.append(('value', ident, value))
        self.values[ident] = value

    def get_value(self, ident):
        return self.values.get(ident, "")

    def set_checked(self, ident, value):
        self.calls.append(('checked', ident, value))
        self.checks[ident] = value

    def get_checked(self, ident):
        return self.checks.get(ident, False)

    def replace_html(self, ident, html):
        self.calls.append(('html', ident, html))
        self.fragments[ident] = html


class FakeWindow:
    id = "window-1"
    def __init__(self, html):
        self.html = html
        self.document = FakeDocument()


class FakeApp:
    def __init__(self):
        self.windows = []
        self.shutdown_callbacks = []
        self.window_callbacks = []

    def open_html(self, html, **opts):
        win = FakeWindow(html)
        self.windows.append(win)
        return win

    def on_shutdown(self, callback):
        self.shutdown_callbacks.append(callback)

    def on_window_event(self, callback):
        self.window_callbacks.append(callback)
        return lambda: self.window_callbacks.remove(callback)

    def shutdown(self):
        for callback in self.shutdown_callbacks:
            callback()


@pytest.fixture
def app():
    return FakeApp()
