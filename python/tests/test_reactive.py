import pytest
from nativehtmlkit_ui import state, computed
from nativehtmlkit_ui.reactive import Binding


def test_state_reads_and_notifications():
    s = state(1)
    hits = []
    close = s.subscribe(lambda: hits.append(s.value))
    assert not s.set(1)
    assert s.set(2)
    assert hits == [2]
    close()
    s.value = 3
    assert hits == [2]


def test_computed_dynamic_dependencies():
    which, left, right = state(True), state(5), state(9)
    choice = computed(lambda: left.value if which.value else right.value)
    seen = []
    choice.subscribe(lambda: seen.append(choice.value))
    assert choice.value == 5
    left.set(6)
    which.set(False)
    left.set(8)  # discarded dependency
    right.set(10)
    assert seen == [6, 9, 10]
    choice.close()
    right.set(20)
    assert seen == [6, 9, 10]


def test_binding_tracks_dependencies_and_disposes():
    enabled = state(True)
    first, second = state("a"), state("b")
    changes = []
    b = Binding(lambda: first.value if enabled.value else second.value,
                lambda _b: changes.append("changed"))
    assert b.evaluate() == 'a'
    first.set('x')
    assert changes == ['changed']
    enabled.set(False)
    assert b.evaluate() == 'b'
    before = len(changes)
    first.set('z')
    assert len(changes) == before
    b.close()
    second.set('y')
    assert len(changes) == before


def test_computed_error_propagates():
    s = state(0)
    c = computed(lambda: 100 // (1 - s.value))
    with pytest.raises(ZeroDivisionError):
        s.set(1)
    c.close()
