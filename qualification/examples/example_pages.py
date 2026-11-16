#!/usr/bin/env python3
"""Generate docs/python/examples.md and docs/powershell/examples.md from examples/catalog.toml.

Each page lists every catalogued example of one language with its summary, what it teaches, how
to run it, its screenshot (docs/images/examples/ui-<py|ps>-<stem>.png, when one exists) and its
full source. Standard library only (Python 3.11+).

usage: example_pages.py [--check]     --check exits 1 when a page is out of date
"""
from __future__ import annotations

import sys
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BLOB = "https://github.com/nativehtmlkit/nativehtmlkit_ui/blob/main/"
LANGS = {
    "python": ("Python", "py", "python", "PowerShell", "powershell"),
    "powershell": ("PowerShell", "ps", "powershell", "Python", "python"),
}


def page(lang: str, catalog: dict) -> str:
    label, short, fence, other_label, other = LANGS[lang]
    out = [f"# Examples", "",
           f"*{label} (UI library 0.1.1). Every example also exists in {other_label} with the same window "
           f"title and behaviour: [{other_label} examples](../{other}/examples.md).*", "",
           f"{len(catalog['example'])} small applications. Each one starts with a comment that says what it "
           "teaches and how to run it, uses only the public UI and SDK APIs, and is run by the repository's "
           "example harness against the real NativeHTMLKit host (headless) on Linux and Windows. Screenshots "
           "are real captures on KDE Plasma 6.6 Wayland.", "",
           "| Example | What it is |", "|---|---|"]
    for item in catalog["example"]:
        out.append(f"| [{item['title']}](#{item['id']}) | {item['summary']} |")
    for item in catalog["example"]:
        rel = item[lang]
        source = (REPO / "examples" / rel).read_text(encoding="utf-8").rstrip()
        stem = Path(rel).stem
        shot = REPO / "docs" / "images" / "examples" / f"ui-{short}-{stem}.png"
        out += ["", f'<a id="{item["id"]}"></a>', "", f"## {item['title']}", "", item["summary"], "",
                "**Teaches:** " + ", ".join(item["teaches"]) + ".", "",
                f"**Run:** `{item['run_' + lang]}` (source: [`examples/{rel}`]({BLOB}examples/{rel}))", ""]
        if item.get("tutorial"):
            out += [f"Built step by step in the [{item['tutorial'].replace('-', ' ')} tutorial](tutorials/{item['tutorial']}.md).", ""]
        if item.get("guide"):
            out += [f"Related guide: [{item['guide'].replace('-', ' ')}](guides/{item['guide']}.md).", ""]
        if shot.is_file():
            out += [f"![{item['title']}](../images/examples/{shot.name})", ""]
        else:
            out += ["*Screenshot not captured yet.*", ""]
        out += ["<details><summary>Full source</summary>", "", f"```{fence}", source, "```", "", "</details>"]
    return "\n".join(out) + "\n"


def main() -> int:
    check = "--check" in sys.argv[1:]
    catalog = tomllib.loads((REPO / "examples" / "catalog.toml").read_text(encoding="utf-8"))
    stale = []
    for lang in LANGS:
        target = REPO / "docs" / lang / "examples.md"
        text = page(lang, catalog)
        if check:
            if not target.is_file() or target.read_text(encoding="utf-8") != text:
                stale.append(str(target.relative_to(REPO)))
        else:
            target.write_text(text, encoding="utf-8")
    if stale:
        print("out of date (run qualification/examples/example_pages.py):", ", ".join(stale))
        return 1
    print("example pages", "up to date" if check else "written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
