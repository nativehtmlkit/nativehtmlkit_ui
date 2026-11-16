"""Regression tests for defects found while qualifying 0.1.0 (fake SDK only)."""
import gc
import threading
import time
import weakref

import pytest
from nativehtmlkit_ui import UI, state, computed


def test_labels_precede_their_controls_and_select_marks_option():
    ui = UI()
    name = ui.input(state('x'), label='Name')
    pick = ui.select(state('b'), [('a', 'A'), ('b', 'B')], label='Pick')
    html = ui.html()
    assert html.index('>Name</label>') < html.index(f'id="{name.id}"')
    assert html.index('>Pick</label>') < html.index(f'id="{pick.id}"')
    assert f'<select class="nhk-select" id="{pick.id}">' in html  # no invalid value attribute
    assert '<option value="b" selected' in html or 'selected' in html.split('value="b"')[1][:30]
    assert '__NHK_RAW' not in html


def test_text_list_update_is_part_of_the_atomic_batch(app):
    items, label = state(['a']), state('x')
    ui = UI()
    lst = ui.text_list(items)
    ui.text(label)
    ui.mount(app)
    ui.document.calls.clear()
    items.set(['<b>', 'c']); label.set('y')
    ui.sync()
    batches = [c for c in ui.document.calls if c[0] == 'batch']
    assert len(batches) == 1 and {op['op'] for op in batches[0][1]} == {'set_text', 'replace_children_html'}
    assert ui.document.fragments[lst.id] == '<li>&lt;b&gt;</li><li>c</li>'
    ui.dispose()


def test_repeated_mount_dispose_does_not_retain_uis(app):
    shared = state(0)
    refs = []
    for n in range(100):
        ui = UI()
        ui.text(shared)
        ui.button('b', on_click=lambda e: None)
        ui.mount(app)
        shared.set(n + 1)
        ui.sync()
        ui.dispose()
        refs.append(weakref.ref(ui))
        del ui
    gc.collect()
    assert sum(r() is not None for r in refs) == 0
    assert len(shared._listeners) == 0
    assert app.window_callbacks == []
    app.shutdown()  # dead weak shutdown hooks are harmless


def test_updates_after_window_closed_or_shutdown_dispose_quietly(app):
    s = state(0)
    ui = UI()
    ui.text(s)
    ui.mount(app)
    ui.window.closed = True  # SDK retired the handles (last-window close sends no "closed" event)
    s.set(1)
    time.sleep(0.05)
    d = ui.diagnostics
    assert d['disposed'] and not d['dom_uncertain'] and d['errors'] == ()


def test_stale_document_error_during_write_is_disposal_not_uncertainty(app):
    s = state(0)
    ui = UI()
    ui.text(s)
    ui.mount(app)

    class StaleDocumentError(RuntimeError):
        pass

    def stale(op, **fields):
        ui.window.closed = True
        raise StaleDocumentError('This document was replaced, unloaded, or closed')
    ui.document.command = stale
    s.set(1)
    time.sleep(0.05)
    assert ui.diagnostics['disposed'] and not ui.diagnostics['dom_uncertain']


def test_timeout_is_not_converted_into_success(app):
    s = state(0)
    ui = UI()
    ui.text(s)
    ui.mount(app)

    def timeout(op, **fields):
        raise TimeoutError('outcome unknown')
    ui.document.command = timeout
    s.set(1)
    with pytest.raises(RuntimeError, match='uncertain'):
        ui.sync()
    assert ui.diagnostics['dom_uncertain'] and not ui.diagnostics['disposed']
    s.set(2)
    with pytest.raises(RuntimeError, match='uncertain'):
        ui.sync()
    ui.dispose()


def test_event_queue_overflow_is_counted_not_raised_into_the_sdk(app):
    gate = threading.Event()
    ui = UI()
    btn = ui.button('x', on_click=lambda e: gate.wait(5))
    ui.mount(app)
    ui.document.emit('click', btn.id)  # blocks the owner
    time.sleep(0.05)
    for _ in range(ui._work.maxsize + 10):
        ui.document.emit('click', btn.id)  # must never raise in the SDK event worker
    assert ui.diagnostics['event_queue_dropped'] >= 10
    gate.set()
    ui.dispose()


def test_failed_mount_disposes_and_closes_its_window(app):
    ui = UI()
    ui.button('x', on_click=lambda e: None)
    original = app.open_html

    def open_html(html, **opts):
        win = original(html, **opts)
        def refuse(*a, **k):
            raise RuntimeError('Document callback limit reached')
        win.document.on = refuse
        return win
    app.open_html = open_html
    with pytest.raises(RuntimeError, match='callback limit'):
        ui.mount(app)
    assert ui.diagnostics['disposed']
    assert app.windows[0].close_requests == 1


def test_dispose_while_background_updates_are_pending(app):
    s = state(0)
    ui = UI()
    ui.text(s)
    ui.mount(app)
    stop = threading.Event()

    def storm():
        n = 0
        while not stop.is_set():
            n += 1
            s.set(n)
    workers = [threading.Thread(target=storm) for _ in range(4)]
    for w in workers:
        w.start()
    time.sleep(0.1)
    ui.dispose()
    writes = len(ui.document.calls)
    time.sleep(0.1)
    stop.set()
    for w in workers:
        w.join()
    assert len(ui.document.calls) - writes <= 1  # at most the write that was in flight
    assert not ui._thread.is_alive()
    assert len(s._listeners) == 0


def test_shutdown_disposes_ui(app):
    s = state(0)
    ui = UI()
    ui.text(s)
    ui.mount(app)
    app.shutdown()
    assert ui.diagnostics['disposed']


def test_computed_that_writes_its_dependency_reports_a_cycle():
    s = state(0)
    c = computed(lambda: s.set(s.value + 1) or s.value)  # writes what it reads
    with pytest.raises(RuntimeError, match='Circular'):
        s.set(100)
    c.close()
