#!/usr/bin/env python3
"""Parse assets/3rd_place_combinations.txt and emit lib/data/third_place_matrix_data.dart.

Skips lines starting with '#' and a single optional header row whose first cell is
'scenario_id'. Data rows must have 21 tab-separated fields:
  id, A..L advance markers (letter or empty), eight third-slot letters (3X or X).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "3rd_place_combinations.txt"
DST = ROOT / "lib" / "data" / "third_place_matrix_data.dart"


def parse_third_cell(cell: str) -> str:
    t = cell.strip().upper()
    if not t:
        raise ValueError(f"empty third-slot cell")
    if t.startswith("3") and len(t) == 2:
        return t[1]
    if len(t) == 1 and t in "ABCDEFGHIJKL":
        return t
    raise ValueError(f"bad third-slot token: {cell!r}")


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    rows: list[tuple[int, int, str]] = []
    for line in text.splitlines():
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if parts[0].strip().lower() == "scenario_id":
            continue
        if len(parts) < 21:
            print(f"skip short line ({len(parts)} cols): {line[:80]!r}", file=sys.stderr)
            continue
        sid = int(parts[0].strip())
        mask = 0
        for i in range(12):
            cell = parts[i + 1].strip().upper()
            if cell:
                expect = "ABCDEFGHIJKL"[i]
                if cell != expect:
                    raise SystemExit(f"row {sid}: col {expect!r} has {cell!r}")
                mask |= 1 << i
        thirds = "".join(parse_third_cell(parts[j]) for j in range(13, 21))
        rows.append((sid, mask, thirds))

    if len(rows) != 495:
        print(f"expected 495 rows, got {len(rows)}", file=sys.stderr)
        return 1
    masks = [m for _, m, _ in rows]
    if len(set(masks)) != len(masks):
        print("duplicate advMask", file=sys.stderr)
        return 1

    out: list[str] = []
    out.append("// GENERATED FILE — do not edit by hand.")
    out.append("// Regenerate:  python3 scripts/gen_third_place_matrix_data.py")
    out.append("abstract final class ThirdPlaceMatrixData {")
    out.append("  ThirdPlaceMatrixData._();")
    out.append("  /// Bit i = group `A`+i has a third-placed team among the eight qualifiers.")
    out.append(
        "  /// String: eight letters — which group's 3rd plays `1A`, `1B`, `1D`, `1E`, `1G`, `1I`, `1K`, `1L`."
    )
    out.append("  static const List<(int advMask, String thirdVsWinnerSlots)> rows = [")
    for _, m, s in rows:
        out.append(f"    ({m}, {json.dumps(s)}),")
    out.append("  ];")
    out.append("  static final Map<int, String> _byMask = {")
    out.append("    for (final (m, s) in rows) m: s,")
    out.append("  };")
    out.append("  /// Third-slot letters for the eight fixed winner columns, or null if mask unknown.")
    out.append("  static String? thirdSlotsForAdvancingMask(int advMask) => _byMask[advMask];")
    out.append("}")
    DST.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Wrote {DST.relative_to(ROOT)} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
