"""Small, synchronous, dependency-tracked reactive primitives.

No SDK imports. State changes may originate on any Python thread. A subscriber
that touches the UI must marshal back to UI.post (Binding does this).
"""
from __future__ import annotations

from contextvars import ContextVar
from threading import RLock
from typing import Any, Callable, Generic, TypeVar

T = TypeVar("T")
_COLLECT: ContextVar[Callable[["Observable"], None] | None] = ContextVar("nhk_ui_collect", default=None)


class Observable:
    def __init__(self) -> None:
        self._listeners: set[Callable[[], None]] = set()
        self._lock = RLock()

    def _read(self) -> None:
        collector = _COLLECT.get()
        if collector is not None:
            collector(self)

    def subscribe(self, callback: Callable[[], None]) -> Callable[[], None]:
        with self._lock:
            self._listeners.add(callback)

        def remove() -> None:
            with self._lock:
                self._listeners.discard(callback)
        return remove

    def _notify(self) -> None:
        with self._lock:
            listeners = tuple(self._listeners)
        for callback in listeners:
            callback()


class State(Observable, Generic[T]):
    """Observable value; use .set(...) or assign .value; does not deeply proxy collections."""
    def __init__(self, value: T):
        super().__init__()
        self._value = value

    @property
    def value(self) -> T:
        self._read()
        with self._lock:
            return self._value

    @value.setter
    def value(self, value: T) -> None:
        self.set(value)

    def set(self, value: T) -> bool:
        with self._lock:
            if self._value is value or self._value == value:
                return False
            self._value = value
        self._notify()
        return True


class Computed(Observable, Generic[T]):
    """Eager dependency-tracked computed value, with self-cycle detection."""
    def __init__(self, fn: Callable[[], T]):
        super().__init__()
        self._fn = fn
        self._unsub: dict[Observable, Callable[[], None]] = {}
        self._calculating = False
        self._closed = False
        self._value: T = self._calculate(initial=True)

    def _calculate(self, initial: bool = False) -> T:
        if self._calculating:
            raise RuntimeError("Circular computed-state dependency")
        self._calculating = True
        deps: set[Observable] = set()
        token = _COLLECT.set(deps.add)
        try:
            value = self._fn()
        finally:
            _COLLECT.reset(token)
            self._calculating = False
        if self in deps:
            raise RuntimeError("Computed value depends on itself")
        for dep, remove in tuple(self._unsub.items()):
            if dep not in deps:
                remove()
                del self._unsub[dep]
        for dep in deps - self._unsub.keys():
            self._unsub[dep] = dep.subscribe(self._changed)
        return value

    def _changed(self) -> None:
        if self._closed:
            return
        new = self._calculate()
        with self._lock:
            if new is self._value or new == self._value:
                return
            self._value = new
        self._notify()

    @property
    def value(self) -> T:
        self._read()
        return self._value

    def close(self) -> None:
        self._closed = True
        for remove in self._unsub.values():
            remove()
        self._unsub.clear()
        with self._lock:
            self._listeners.clear()


def state(value: T) -> State[T]:
    return State(value)


def computed(fn: Callable[[], T]) -> Computed[T]:
    return Computed(fn)


class Binding:
    """Tracks observable reads in an expression and notifies a scheduler."""
    def __init__(self, expression: Callable[[], Any], changed: Callable[["Binding"], None]):
        self.expression = expression
        self.changed = changed
        self.last: Any = _MISSING
        self.unsub: dict[Observable, Callable[[], None]] = {}
        self.closed = False

    def evaluate(self) -> Any:
        if self.closed:
            return self.last
        deps: set[Observable] = set()
        token = _COLLECT.set(deps.add)
        try:
            val = self.expression()
        finally:
            _COLLECT.reset(token)
        for dep, remove in tuple(self.unsub.items()):
            if dep not in deps:
                remove()
                del self.unsub[dep]
        for dep in deps - self.unsub.keys():
            self.unsub[dep] = dep.subscribe(self._change)
        return val

    def _change(self) -> None:
        if not self.closed:
            self.changed(self)

    def close(self) -> None:
        self.closed = True
        for remove in self.unsub.values():
            remove()
        self.unsub.clear()


_MISSING = object()
