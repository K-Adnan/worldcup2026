#!/usr/bin/env python3
"""
Parse Transfermarkt national-team squad pages pasted as plain text (one or many
teams in a single file) and emit JSON with country and player fields.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

# Shirt number line: 1–99, or "-" when none.
_SHIRT_RE = re.compile(r"^(\d{1,2}|-)$")

# Stats row: DOB (age), club, height, foot, caps, goals, debut, market value.
_DOB_AGE_RE = re.compile(
    r"^(?P<dob>\d{2}/\d{2}/\d{4})\s*\((?P<age>\d{1,3})\)\s*$"
)
_HEIGHT_RE = re.compile(r"^(\d)([,.])(\d{2})m$")

# National squad page title line: "Squad France" — not "Squad size: 25".
_SQUAD_TITLE_RE = re.compile(
    r"^Squad\s+(?!size\b)(.+?)\s*$",
    re.IGNORECASE,
)

# Start of table: "#" then "Player" on following lines.
_TABLE_START_MARKERS = (
    "#",
    "Player",
    "Date of birth/Age",
    "Club",
    "Height",
    "Foot",
    "International matches",
    "Goals",
    "Debut",
    "Market value",
)

_FOOTER_STARTS = (
    "Quick Links",
    "Most valuable players",
    "© Transfermarkt",
    "Transfermarkt Company",
    "Legal notice",
)


def _normalize_height(raw: str) -> str:
    raw = raw.strip()
    m = _HEIGHT_RE.match(raw.replace(" ", ""))
    if not m:
        return raw
    int_part, _, dec = m.groups()
    return f"{int_part}.{dec}m"


def _parse_int_or_null(s: str) -> int | None:
    s = s.strip()
    if s in {"", "-"}:
        return None
    return int(s)


def _split_name_line(line: str) -> str:
    parts = [p.strip() for p in re.split(r"[\t]+", line) if p.strip()]
    if not parts:
        return ""
    # Transfermarkt often duplicates the name; keep the first full variant.
    return parts[0]


def _looks_like_stats_row(line: str) -> bool:
    parts = line.split("\t")
    if len(parts) < 8:
        return False
    return bool(_DOB_AGE_RE.match(parts[0].strip()))


def _parse_stats_row(line: str) -> dict[str, Any] | None:
    parts = [p.strip() for p in line.split("\t")]
    if len(parts) < 8:
        return None
    dob_age = parts[0]
    m = _DOB_AGE_RE.match(dob_age)
    if not m:
        return None
    club = parts[1]
    height = _normalize_height(parts[2])
    foot = parts[3].lower()
    caps = _parse_int_or_null(parts[4])
    goals = _parse_int_or_null(parts[5])
    debut = parts[6]
    market_value = parts[7]
    return {
        "date_of_birth": m.group("dob"),
        "age": int(m.group("age")),
        "club": club,
        "height": height,
        "preferred_foot": foot,
        "caps": caps,
        "goals": goals,
        "debut": debut,
        "market_value": market_value,
    }


def _table_header_at(lines: list[str], i: int) -> bool:
    if i + len(_TABLE_START_MARKERS) > len(lines):
        return False
    for k, marker in enumerate(_TABLE_START_MARKERS):
        if lines[i + k].strip() != marker:
            return False
    return True


def _is_footer_line(line: str) -> bool:
    s = line.strip()
    return any(s.startswith(p) for p in _FOOTER_STARTS)


def parse_squad_block(lines: list[str], country_hint: str) -> dict[str, Any]:
    players: list[dict[str, Any]] = []

    header_idx = None
    for i in range(len(lines) - len(_TABLE_START_MARKERS)):
        if _table_header_at(lines, i):
            header_idx = i + len(_TABLE_START_MARKERS)
            break

    if header_idx is None:
        return {"country": country_hint, "players": players, "_error": "no_table_header"}

    i = header_idx
    while i < len(lines):
        line_raw = lines[i]
        line = line_raw.strip()

        if _is_footer_line(line_raw):
            break

        # Skip blanks and stray nav noise.
        if not line:
            i += 1
            continue

        if line in {"Compact", "Detailed", "Gallery", "Choose year"}:
            i += 1
            continue

        if not _SHIRT_RE.match(line):
            # Not start of a row; skip (e.g. year list lines).
            i += 1
            continue

        shirt = line
        if i + 3 >= len(lines):
            break

        name_line = lines[i + 1].rstrip("\n")
        pos_line = lines[i + 2].strip()
        stats_line = lines[i + 3].rstrip("\n")

        if _is_footer_line(name_line) or _is_footer_line(pos_line):
            break

        stats = _parse_stats_row(stats_line)
        if stats is None:
            # Mis-aligned paste; skip this block.
            i += 1
            continue

        name = _split_name_line(name_line)
        players.append(
            {
                "number": shirt if shirt != "-" else None,
                "name": name,
                "position": pos_line,
                **stats,
            }
        )
        i += 4

    return {"country": country_hint.strip(), "players": players}


def split_into_squad_sections(text: str) -> list[tuple[str, list[str]]]:
    """
    Return (country_hint, lines) for each pasted squad.
    Uses 'Squad <Country>' headings from the TM UI.
    """
    lines = text.splitlines()
    sections: list[tuple[str | None, int, int]] = []

    for idx, raw in enumerate(lines):
        m = _SQUAD_TITLE_RE.match(raw.strip())
        if not m:
            continue
        country = m.group(1).strip()
        sections.append((country, idx))

    if not sections:
        return [("unknown", lines)]

    out: list[tuple[str, list[str]]] = []
    for j, (_country, start) in enumerate(sections):
        end = sections[j + 1][1] if j + 1 < len(sections) else len(lines)
        block_lines = lines[start:end]
        out.append((_country or "unknown", block_lines))
    return out


def parse_file(text: str) -> dict[str, Any]:
    teams: list[dict[str, Any]] = []
    for country, block in split_into_squad_sections(text):
        teams.append(parse_squad_block(block, country))
    return {"teams": teams}


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Parse pasted Transfermarkt squad plain text → JSON.",
    )
    ap.add_argument(
        "input",
        nargs="?",
        type=Path,
        help="Plain-text file (stdin if omitted)",
    )
    ap.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write JSON here (stdout if omitted)",
    )
    ap.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON with indentation.",
    )
    args = ap.parse_args()

    if args.input is None:
        data = sys.stdin.read()
    else:
        data = args.input.read_text(encoding="utf-8", errors="replace")

    result = parse_file(data)
    dump_kw: dict[str, Any] = {"ensure_ascii": False}
    if args.pretty:
        dump_kw["indent"] = 2
    else:
        dump_kw["separators"] = (",", ":")

    line = json.dumps(result, **dump_kw) + "\n"
    if args.output is None:
        sys.stdout.write(line)
    else:
        args.output.write_text(line, encoding="utf-8")


if __name__ == "__main__":
    main()
