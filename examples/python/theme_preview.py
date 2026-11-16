"""Theme preview: try the UI library's themes, densities and a custom accent colour.

Teaches: UI(theme=..., density=..., extra_css=...), overriding the library's CSS custom properties
(--nhk-accent and friends) for one theme, and the main components side by side.
instance="multiple" lets you start several previews at once and compare them.
Run:     python theme_preview.py [cobalt|graphite|daylight] [compact|regular|comfortable] [#RRGGBB]
Guide:   docs/python/guides/theming-and-custom-css.md
"""
import re
import sys

from nativehtmlkit import Application
from nativehtmlkit_ui import UI, state

THEMES = ("cobalt", "graphite", "daylight")
DENSITIES = ("compact", "regular", "comfortable")


def main():
    with Application.start(name="Theme preview", instance="multiple") as app:
        args = sys.argv[1:]
        theme = args[0] if len(args) > 0 and args[0] in THEMES else "cobalt"
        density = args[1] if len(args) > 1 and args[1] in DENSITIES else "compact"
        accent = args[2] if len(args) > 2 and re.fullmatch(r"#[0-9A-Fa-f]{6}", args[2]) else None
        # extra_css is appended after the library stylesheet, so the same selector wins.
        extra = (f"body.nhk-theme-{theme} {{ --nhk-accent: {accent}; --nhk-accent-strong: {accent}; "
                 f"--nhk-focus: {accent}; }}") if accent else ""

        name = state("Ada")
        enabled = state(True)
        size = state("m")
        ui = UI(title=f"Theme preview: {theme}/{density}", theme=theme, density=density, extra_css=extra,
                width=720, height=560)
        with ui.column():
            ui.heading(f"{theme.title()} theme, {density} density", level=1)
            with ui.row():
                ui.badge("Badge")
                ui.badge(lambda: f"Hello {name.value}")
                ui.badge(f"accent {accent or 'default'}")
            with ui.grid():
                with ui.card():
                    ui.heading("Controls", level=2)
                    ui.input(name, label="Name")
                    ui.select(size, [("s", "Small"), ("m", "Medium"), ("l", "Large")], label="Size")
                    ui.checkbox(enabled, label="Enabled")
                with ui.card():
                    ui.heading("Buttons", level=2)
                    with ui.row():
                        ui.button("Primary")
                        ui.button("Secondary", variant="secondary")
                        ui.button("Danger", variant="danger")
                        ui.button("Quiet", variant="quiet")
                        ui.button("Disabled", disabled=True)
            ui.alert("Alerts use role=status, so screen readers announce changes.")
            ui.text("Muted text for secondary information.", muted=True)
        try:
            ui.mount(app)
            app.run()
        finally:
            ui.dispose()


if __name__ == "__main__":
    main()
