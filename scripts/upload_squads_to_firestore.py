#!/usr/bin/env python3
"""
Transform scripts/squads.json (Transfermarkt parser output) into Firestore team
documents matching TeamInfo / TeamPlayer in lib/data/world_cup_data.dart, then
merge-update the `squad` field on each matching `teams` document (by `name`).
New documents are created only when you pass --create-if-missing.

Germany (and other teams) in your project should already follow this schema:
  number?, name, position, dateOfBirth, club, height, preferredFoot,
  caps, goals, debut?, marketValue

Requires a service account JSON with Firestore access (recommended role:
"Firebase Admin" / "Cloud Datastore User"):
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

# Map Transfermarkt / parser `country` string → Firestore `name` field if they differ.
# Extend if your schedule uses names that don't match pasted squad titles.
_firestore_team_name_overrides: dict[str, str] = {
    # "United States": "USA",
}


def height_to_cm(height: str | None) -> int:
    if not height:
        return 0
    s = height.strip().replace(" ", "")
    try:
        if s.lower().endswith("m"):
            metres = float(s[:-1].replace(",", "."))
            return int(round(metres * 100))
    except ValueError:
        pass
    digits = "".join(c for c in s if c.isdigit())
    return int(digits) if digits else 0


def market_value_to_eur(raw: str | None) -> int:
    """
    App displays marketValue as euros (integer); see TeamPlayer._parseInt and
    _formatMarketValue in team_detail_screen.dart.
    Transfermarkt strings: €35.00m → 35_000_000.
    """
    if not raw or not str(raw).strip():
        return 0
    s = (
        str(raw)
        .strip()
        .replace("€", "")
        .replace(" ", "")
        .lower()
        .replace(",", ".")
    )
    mult = 1
    if s.endswith("bn") or s.endswith("b"):
        mult = 1_000_000_000
        s = re.sub(r"b[n]?$", "", s)
    elif s.endswith("m"):
        mult = 1_000_000
        s = s[:-1]
    elif s.endswith("k"):
        mult = 1_000
        s = s[:-1]
    s = s.strip()
    if not s:
        return 0
    try:
        return int(round(float(s) * mult))
    except ValueError:
        return 0


def _parse_optional_int(val) -> int | None:
    if val is None:
        return None
    if isinstance(val, int):
        return val
    if isinstance(val, str) and val.strip() in {"", "-"}:
        return None
    try:
        return int(val)
    except (TypeError, ValueError):
        return None


def player_to_firestore(p: dict) -> dict:
    """Shape matches TeamPlayer.fromJson field names (camelCase)."""
    num = _parse_optional_int(p.get("number"))
    caps = p.get("caps")
    goals = p.get("goals")
    out: dict = {
        "name": (p.get("name") or "").strip(),
        "position": (p.get("position") or "").strip(),
        "dateOfBirth": (p.get("date_of_birth") or "").strip(),
        "club": (p.get("club") or "").strip(),
        "height": height_to_cm(p.get("height")),
        "preferredFoot": (p.get("preferred_foot") or "").strip().lower(),
        "caps": int(caps) if caps is not None else 0,
        "goals": int(goals) if goals is not None else 0,
        "debut": (p.get("debut") or "").strip(),
        "marketValue": market_value_to_eur(p.get("market_value")),
    }
    if num is not None:
        out["number"] = num
    else:
        out["number"] = None
    return out


def resolve_team_name(parsed_country: str) -> str:
    return _firestore_team_name_overrides.get(parsed_country, parsed_country)


def load_teams(path: Path) -> list[dict]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    teams = raw.get("teams") or []
    return [t for t in teams if isinstance(t, dict)]


def write_payload(teams_source: Path, output: Path, pretty: bool) -> None:
    teams = load_teams(teams_source)
    payload = []
    for t in teams:
        country = (t.get("country") or "").strip()
        if not country:
            continue
        name = resolve_team_name(country)
        players = [
            player_to_firestore(p)
            for p in (t.get("players") or [])
            if isinstance(p, dict)
        ]
        payload.append({"name": name, "source_country": country, "squad": players})
    dump_kw = {"ensure_ascii": False}
    if pretty:
        dump_kw["indent"] = 2
    else:
        dump_kw["separators"] = (",", ":")
    output.write_text(json.dumps({"teams": payload}, **dump_kw) + "\n", encoding="utf-8")


def upload(
    project_id: str,
    teams_source: Path,
    *,
    dry_run: bool,
    create_if_missing: bool,
) -> None:
    squads_js = load_teams(teams_source)

    if dry_run:
        for t in squads_js:
            country = (t.get("country") or "").strip()
            fs_name = resolve_team_name(country)
            squad = [
                player_to_firestore(p)
                for p in (t.get("players") or [])
                if isinstance(p, dict)
            ]
            sample = squad[0] if squad else {}
            print(f"[dry-run] {fs_name}: {len(squad)} players, sample keys={list(sample.keys())}")
        return

    try:
        import firebase_admin  # noqa: PLC0415
        from firebase_admin import credentials  # noqa: PLC0415
        from firebase_admin import firestore  # noqa: PLC0415
    except ImportError as e:
        raise SystemExit(
            "Install firebase-admin: pip install -r scripts/requirements-firestore.txt"
        ) from e

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.ApplicationDefault(),
            {"projectId": project_id},
        )

    db = firestore.client()

    updated = 0
    created = 0

    try:
        for t in squads_js:
            country = (t.get("country") or "").strip()
            fs_name = resolve_team_name(country)
            squad = [
                player_to_firestore(p)
                for p in (t.get("players") or [])
                if isinstance(p, dict)
            ]

            q = db.collection("teams").where(
                filter=firestore.FieldFilter("name", "==", fs_name)
            ).limit(1)
            docs = list(q.stream())

            if not docs:
                if create_if_missing:
                    db.collection("teams").add(
                        {
                            "name": fs_name,
                            "squad": squad,
                        }
                    )
                    created += 1
                    print(f"created team document: {fs_name} ({len(squad)} players)")
                else:
                    print(
                        f"skip (no team doc with name={fs_name!r}). "
                        f"Fix _firestore_team_name_overrides or pass --create-if-missing."
                    )
                continue

            ref = docs[0].reference
            ref.update({"squad": squad})
            updated += 1
            print(f"updated squad: {fs_name} ({len(squad)} players) doc={ref.id}")
    except Exception as e:
        from google.api_core import exceptions as gexc

        if isinstance(e, gexc.PermissionDenied):
            raise SystemExit(
                "Firestore PermissionDenied. Use a service account JSON with Firestore access:\n"
                "  Firebase console → Project settings → Service accounts → "
                "Generate new private key\n"
                "  export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/key.json\n"
                "Then re-run this script."
            ) from e
        raise

    print(f"Done. updated={updated} created={created}")


def main() -> None:
    root = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(
        description="Upload squads.json to Firestore (TeamPlayer schema).",
    )
    ap.add_argument(
        "--squads",
        type=Path,
        default=root / "squads.json",
        help="Path to squads.json from parse_transfermarkt_squads.py",
    )
    ap.add_argument(
        "--project",
        default="worldcup2026-1",
        help="Firebase / GCP project id",
    )
    ap.add_argument(
        "--write-payload",
        type=Path,
        metavar="OUT.json",
        help="Write Firestore-shaped JSON only (no upload).",
    )
    ap.add_argument(
        "--pretty-payload",
        action="store_true",
        help="Pretty-print when using --write-payload.",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="With upload: print summary only, do not write.",
    )
    ap.add_argument(
        "--create-if-missing",
        action="store_true",
        help="Create a new teams/ document if no row matches name (default is update-only).",
    )
    args = ap.parse_args()

    if args.write_payload:
        write_payload(args.squads, args.write_payload, args.pretty_payload)
        print(f"Wrote {args.write_payload}")
        return

    upload(
        args.project,
        args.squads,
        dry_run=args.dry_run,
        create_if_missing=args.create_if_missing,
    )


if __name__ == "__main__":
    main()
