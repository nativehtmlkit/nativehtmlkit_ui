"""NativeHTMLKit UI: small, SDK-only responsive/reactive desktop toolkit.

No Core, CLI, browser, JavaScript, or third-party runtime dependency.
"""
from .engine import UI
from .reactive import Computed, State, computed, state

__version__ = "0.1.0"
__all__ = ["UI", "State", "Computed", "state", "computed"]
