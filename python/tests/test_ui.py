import threading
import time
import pytest
from nativehtmlkit_ui import UI, state, computed


def test_escaped_markup_and_themes():
    ui = UI(theme="graphite", density="regular", title="<unsafe>")
    ui.heading('<unsafe text>')
    ui.input(state('"<&'), label='Name <unsafe>')
    ui.text_list(state(['<script>alert(1)</script>', 'ok']))
    html = ui.html()
    assert '<title>&lt;unsafe&gt;</title>' in html
    assert '&lt;unsafe text&gt;' in html
    assert '&lt;script&gt;alert(1)&lt;/script&gt;' in html
    assert 'value="&quot;&lt;&amp;"' in html
    assert 'nhk-theme-graphite nhk-density-regular' in html
    assert '<script>' not in html


def test_bindings_update_native_elements(app):
    first, second = state('Hello'), state(1)
    ui = UI()
    a = ui.text(first)
    b = ui.heading(lambda: f'Count {second.value}')
    ui.mount(app)
    first.set('After')
    second.set(2)
    ui.sync()
    assert ui.document.texts[a.id] == 'After'
    assert ui.document.texts[b.id] == 'Count 2'
    assert len(ui.document.handlers) == 0
    ui.dispose()


def test_delegated_clicks_single_native_subscription(app):
    s = state(0)
    ui = UI()
    a = ui.button('A', on_click=lambda e: s.set(s.value + 1))
    b = ui.button('B', on_click=lambda e: s.set(s.value + 10))
    ui.mount(app)
    assert len(ui.document.handlers['click']) == 1
    ui.document.emit('click', a.id)
    ui.document.emit('click', b.id)
    ui.sync()
    assert s.value == 11
    ui.dispose()
    assert len(ui.document.handlers['click']) == 0


def test_input_does_not_echo_native_keystroke(app):
    name = state('old')
    ui = UI()
    el = ui.input(name)
    ui.mount(app)
    ui.document.calls.clear()
    ui.document.emit('input', el.id, value='native new')
    ui.sync()
    assert name.value == 'native new'
    assert not [c for c in ui.document.calls if c[0] == 'value']
    name.set('programmatic')
    ui.sync()
    assert ui.document.values[el.id] == 'programmatic'
    ui.dispose()


def test_checkbox_sync_and_echo_suppression(app):
    enabled = state(False)
    ui = UI()
    checkbox = ui.checkbox(enabled, label='Enabled')
    ui.mount(app)
    ui.document.calls.clear()
    ui.document.emit('change', checkbox.id, checked=True)
    ui.sync()
    assert enabled.value is True
    assert not [c for c in ui.document.calls if c[0] == 'checked']
    enabled.set(False)
    ui.sync()
    assert ui.document.checks[checkbox.id] is False
    ui.dispose()


def test_computed_bindings(app):
    a = state(1)
    twice = computed(lambda: a.value * 2)
    ui = UI()
    el = ui.text(twice)
    ui.mount(app)
    a.set(4)
    ui.sync()
    assert ui.document.texts[el.id] == '8'
    ui.dispose()
    twice.close()


def test_hidden_region_and_list_are_local_only(app):
    visible = state(False)
    items = state(['one'])
    ui = UI()
    with ui.when(visible):
        el = ui.text('Hidden')
    lst = ui.text_list(items)
    html = ui.html()
    assert 'nhk-hidden' in html
    ui.mount(app)
    visible.set(True)
    items.set(['<tag>', 'new'])
    ui.sync()
    assert any(c[0] == 'remove_class' for c in ui.document.calls)
    assert ui.document.fragments[lst.id] == '<li>&lt;tag&gt;</li><li>new</li>'
    ui.dispose()


def test_late_updates_after_dispose_ignored(app):
    s = state(0)
    ui = UI()
    ui.text(s)
    ui.mount(app)
    ui.dispose()
    ui.document.calls.clear()
    s.set(1)
    time.sleep(0.02)
    assert ui.document.calls == []
    assert ui.diagnostics['pending_updates'] == 0


def test_native_window_closure_disposes(app):
    ui = UI()
    ui.button('Hello', on_click=lambda e: None)
    ui.mount(app)
    for cb in list(app.window_callbacks):
        cb({'window_id': ui.window.id, 'type': 'closed'})
    assert len(ui.document.handlers['click']) == 0
    assert ui._closed


def test_post_from_background(app):
    message = state('before')
    ui = UI()
    el = ui.text(message)
    ui.mount(app)
    worker = threading.Thread(target=lambda: ui.post(message.set, 'from worker'))
    worker.start(); worker.join()
    ui.sync()
    assert message.value == 'from worker'
    assert ui.document.texts[el.id] == 'from worker'
    ui.dispose()


def test_two_windows_isolated(app):
    first, second = UI(), UI()
    a, b = state('a'), state('b')
    x, y = first.text(a), second.text(b)
    first.mount(app); second.mount(app)
    a.set('changed')
    first.sync(); second.sync()
    assert first.document.texts[x.id] == 'changed'
    assert y.id not in second.document.texts
    first.dispose(); second.dispose()


def test_reject_unsafe_attr_name_and_invalid_options():
    ui = UI()
    with pytest.raises(ValueError):
        ui.element('div', attrs={'onclick': 'malicious'})
        ui.html()
    with pytest.raises(ValueError):
        UI(theme='custom')
    with pytest.raises(ValueError):
        ui.button('X', variant='nonexistent')


def test_bindings_avoid_duplicate_dom_operations(app):
    val = state('a')
    ui = UI()
    ui.text(val)
    ui.mount(app)
    val.set('b')
    val.set('b')
    ui.sync()
    assert len([x for x in ui.document.calls if x[0] == 'set_text']) == 1
    ui.dispose()


def test_event_route_to_nearest_registered_ancestor(app):
    hits = []
    ui = UI()
    with ui.card() as card:
        nested = ui.button('Nested', on_click=lambda e: hits.append('button'))
    ui.on(card, 'click', lambda e: hits.append('card'))
    ui.mount(app)
    ui.document.emit('click', nested.id)
    ui.sync()
    assert hits == ['button']
    ui.dispose()


def test_event_callback_failure_reported_but_other_events_continue(app):
    hit = []
    ui = UI()
    bad = ui.button('Bad', on_click=lambda e: 1 / 0)
    good = ui.button('Good', on_click=lambda e: hit.append('ok'))
    ui.mount(app)
    ui.document.emit('click', bad.id)
    ui.document.emit('click', good.id)
    ui.sync()
    assert hit == ['ok']
    assert 'ZeroDivisionError' in '\n'.join(ui.diagnostics['errors'])
    ui.dispose()


def test_sdk_write_failure_halts_managed_writes(app):
    updated = state('initial')
    ui = UI()
    ui.text(updated)
    ui.mount(app)
    def broken(op, **values):
        raise RuntimeError('injected SDK fault')
    ui.document.command = broken
    updated.set('one')
    with pytest.raises(RuntimeError, match='uncertain'):
        ui.sync()
    assert ui.diagnostics['dom_uncertain']
    assert 'injected SDK fault' in '\n'.join(ui.diagnostics['errors'])
    ui.dispose()


def test_large_burst_coalesces_some_changes(app):
    signal = state(0)
    ui = UI()
    el = ui.text(signal)
    ui.mount(app)
    for n in range(1000):
        signal.set(n)
    ui.sync()
    assert ui.document.texts[el.id] == '999'
    assert ui.diagnostics['event_queue_dropped'] == 0
    ui.dispose()


def test_cannot_mutate_builder_after_mount(app):
    ui = UI()
    ui.mount(app)
    with pytest.raises(RuntimeError, match='after mount'):
        ui.text('late')
    ui.dispose()
