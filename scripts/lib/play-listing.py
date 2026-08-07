#!/usr/bin/env python3
"""Parse the Play listing copy out of docs/play_store-retain/PLAY_STORE_DESCRIPTIONS.md.

Emits JSON on stdout:

    {"en-GB": {"title": "...", "short": "...", "full": "..."},
     "da-DK": {...}}

Why this exists: the listing text is prose a person wrote and reviewed, and it
lives in the doc so it can be read and edited there. Re-typing it into an API
call is how a listing drifts from the copy that was approved.

Line wrapping. The doc is hard-wrapped at ~78 columns like every other document
in this repository — that is source formatting, not layout. Play renders the
full description's newlines *literally*, so publishing it verbatim would break
every bullet mid-sentence at whatever column the author's editor happened to
wrap. Paragraphs and bullets are therefore unwrapped back into single lines,
and only deliberate structure is kept:

  * a blank line stays a blank line (paragraph break)
  * a line starting with a bullet begins a new bullet
  * an ALL-CAPS line on its own is a section heading and stays on its own line

Pass --verbatim to skip all of that and send exactly what is in the doc.
"""

import argparse
import json
import re
import sys

DOC = "docs/play_store-retain/PLAY_STORE_DESCRIPTIONS.md"

# "### Title (en-GB) — 29"  /  "### Full description (da-DK)"
HEADING = re.compile(r"^###\s+(Title|Short description|Full description)\s+\(([a-zA-Z-]+)\)")
FIELD_KEY = {"Title": "title", "Short description": "short", "Full description": "full"}
BULLET = re.compile(r"^\s*[•\-\*]\s")
# A heading line the author wrote in caps, e.g. "THE TOOLS", "FREE AND PRIVATE".
CAPS_HEADING = re.compile(r"^[A-ZÆØÅ0-9][A-ZÆØÅ0-9 ,'&/-]*$")


def unwrap(text: str) -> str:
    """Join soft-wrapped continuation lines; keep real structure."""
    out: list[str] = []
    buffer: list[str] = []

    def flush() -> None:
        if buffer:
            out.append(" ".join(part.strip() for part in buffer))
            buffer.clear()

    for raw in text.split("\n"):
        line = raw.rstrip()
        if not line.strip():
            flush()
            out.append("")
            continue
        if BULLET.match(line) or CAPS_HEADING.match(line.strip()):
            flush()
            buffer.append(line.strip())
            continue
        buffer.append(line)
    flush()

    # Collapse any run of blank lines to exactly one.
    collapsed: list[str] = []
    for line in out:
        if line == "" and collapsed and collapsed[-1] == "":
            continue
        collapsed.append(line)
    return "\n".join(collapsed).strip()


def parse(path: str, verbatim: bool) -> dict:
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")

    listings: dict = {}
    index = 0
    # Only the "## Google Play" section — the App Store fields use the same
    # heading shapes and must not be picked up.
    in_play = False
    while index < len(lines):
        line = lines[index]
        if line.startswith("## "):
            in_play = line.strip() == "## Google Play"
        match = HEADING.match(line) if in_play else None
        if match:
            field, lang = FIELD_KEY[match.group(1)], match.group(2)
            # The next fenced block is the value.
            index += 1
            while index < len(lines) and not lines[index].startswith("```"):
                index += 1
            index += 1
            body: list[str] = []
            while index < len(lines) and not lines[index].startswith("```"):
                body.append(lines[index])
                index += 1
            value = "\n".join(body).strip()
            if not verbatim and field == "full":
                value = unwrap(value)
            elif not verbatim:
                value = " ".join(value.split())
            listings.setdefault(lang, {})[field] = value
        index += 1
    return listings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--doc", default=DOC)
    parser.add_argument("--verbatim", action="store_true")
    args = parser.parse_args()

    listings = parse(args.doc, args.verbatim)
    if not listings:
        print(f"no Play listing sections found in {args.doc}", file=sys.stderr)
        return 1

    # Play's hard limits. Failing here beats a 400 from the API, and beats a
    # silently truncated store page.
    limits = {"title": 30, "short": 80, "full": 4000}
    problems = []
    for lang, fields in sorted(listings.items()):
        for field, cap in limits.items():
            if field not in fields:
                problems.append(f"{lang}: missing {field}")
                continue
            length = len(fields[field])
            if length > cap:
                problems.append(f"{lang}: {field} is {length} chars (limit {cap})")
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1

    json.dump(listings, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
