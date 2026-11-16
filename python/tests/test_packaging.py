from importlib.resources import files
from nativehtmlkit_ui import UI


def test_package_css_present():
    css = files('nativehtmlkit_ui.assets').joinpath('ui.css').read_text()
    assert '.nhk-grid' in css
    assert 'nhk-theme-cobalt' in css
    assert '@media' in css


def test_html_has_no_http_dependencies():
    markup = UI(title='Offline').html()
    assert 'https://' not in markup
    assert '<script' not in markup
