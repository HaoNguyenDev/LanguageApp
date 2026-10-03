#!/usr/bin/env python3
"""
Build messages.json (welcome-back toasts + notification / toast texts) from the app messages
spreadsheet "LinguaPath – App Messages".

    python3 Tools/content/build_messages.py --sheet-id <MESSAGES_SHEET_ID>          # → Resources/Content/messages.json
    python3 Tools/content/build_messages.py --sheet-id <ID> --out <folder>          # publish workflow
    python3 Tools/content/build_messages.py --xlsx messages.xlsx --check            # validate only

Tabs (see the sheet's `guide` tab):
  welcome  id · when · min_days_away · weight · active · title_xx · message_xx
  texts    id · key · active · title_xx · body_xx

Only the Python 3 standard library is needed (the xlsx reader is shared with build_courses.py).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_courses import (  # noqa: E402
    JSON_LANG_ORDER, LANGS, Report, download_google_sheet, read_xlsx, require_columns, tab_records,
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_OUT = SCRIPT_DIR.parent.parent / "LanguageApp" / "LanguageApp" / "Resources" / "Content"
FILE_NAME = "messages.json"

# Must match AppMessages in the app (MessageCatalog.swift).
WHEN = {"any", "streak", "no_streak", "away", "morning", "evening", "studied_today"}
KEYS = {
    "reminder": set(),
    "review_due": {"count"},
    "streak_risk": {"days"},
    "word_reminder": {"course"},
    "content_updated": set(),
    "content_new_units": {"course", "units", "words"},
    "content_new_words": {"course", "words"},
}
WELCOME_PLACEHOLDERS = {"name", "streak", "days_away", "course"}
PLACEHOLDER_RE = re.compile(r"\{([a-z_]+)\}")


def is_active(value: str) -> bool:
    """Empty counts as active; FALSE / 0 / NO hides the row."""
    return value.strip().upper() not in {"FALSE", "0", "NO"}


def texts(record: dict[str, str], prefix: str, where: str, report: Report, required: bool) -> dict[str, str] | None:
    values = {lang: record.get(f"{prefix}_{lang}", "") for lang in LANGS}
    if not values["en"]:
        if required:
            report.error(where, f"'{prefix}_en' is empty (English is the fallback)")
        return None
    missing = [lang for lang in LANGS if not values[lang]]
    if missing:
        report.warn(where, f"{prefix} missing in {', '.join(missing)} – English is shown")
    return {lang: values[lang] for lang in JSON_LANG_ORDER if values[lang]}


def check_placeholders(text: dict[str, str] | None, allowed: set[str], where: str, report: Report) -> None:
    for lang, value in (text or {}).items():
        unknown = set(PLACEHOLDER_RE.findall(value)) - allowed
        if unknown:
            report.warn(where, f"{lang}: unknown placeholder(s) {', '.join('{' + u + '}' for u in sorted(unknown))}"
                               f" – allowed: {', '.join('{' + a + '}' for a in sorted(allowed)) or 'none'}")


def build(sheets: dict[str, list[list[str]]], report: Report) -> dict:
    ids: set[str] = set()

    def unique(row_id: str, where: str) -> None:
        if not row_id:
            report.error(where, "id is empty")
        elif row_id in ids:
            report.error(where, f"duplicate id '{row_id}'")
        ids.add(row_id)

    welcome = []
    records = tab_records(sheets, "welcome", report)
    if require_columns("welcome", records, ["id", "when", "title_en", "message_en"], report):
        for row, r in records:
            where = f"welcome!row {row}"
            unique(r.get("id", ""), where)
            if not is_active(r.get("active", "")):
                continue
            when = r.get("when", "any") or "any"
            if when not in WHEN:
                report.error(where, f"when '{when}' must be one of: {', '.join(sorted(WHEN))}")
            days = r.get("min_days_away", "") or "0"
            weight = r.get("weight", "") or "1"
            if not days.isdigit():
                report.error(where, f"min_days_away '{days}' must be a whole number")
                days = "0"
            if not weight.isdigit() or int(weight) < 1:
                report.error(where, f"weight '{weight}' must be a whole number ≥ 1")
                weight = "1"
            title = texts(r, "title", where, report, required=True)
            message = texts(r, "message", where, report, required=True)
            check_placeholders(title, WELCOME_PLACEHOLDERS, where, report)
            check_placeholders(message, WELCOME_PLACEHOLDERS, where, report)
            if title and message:
                welcome.append({"id": r["id"], "when": when, "minDaysAway": int(days), "weight": int(weight),
                                "title": title, "message": message})
    if not welcome:
        report.warn("welcome", "no active message – the app uses its built-in welcome texts")

    texts_out = []
    records = tab_records(sheets, "texts", report)
    if require_columns("texts", records, ["id", "key", "title_en"], report):
        for row, r in records:
            where = f"texts!row {row}"
            unique(r.get("id", ""), where)
            if not is_active(r.get("active", "")):
                continue
            key = r.get("key", "")
            if key not in KEYS:
                report.error(where, f"key '{key}' must be one of: {', '.join(sorted(KEYS))}")
                continue
            title = texts(r, "title", where, report, required=True)
            body = texts(r, "body", where, report, required=key != "word_reminder")
            check_placeholders(title, KEYS[key], where, report)
            check_placeholders(body, KEYS[key], where, report)
            if title:
                entry = {"id": r["id"], "key": key, "title": title}
                if body:
                    entry["body"] = body
                texts_out.append(entry)

    return {"version": 1, "welcome": welcome, "texts": texts_out}


def resolve_version(data: dict, path: Path) -> str:
    """Bumps the version when the messages changed (same rule as the course files)."""
    if not path.exists():
        return "new file, version 1"
    existing = json.loads(path.read_text(encoding="utf-8"))
    old = int(existing.get("version", 0))
    if {**existing, "version": 0} == {**data, "version": 0}:
        data["version"] = max(old, 1)
        return f"unchanged, version {data['version']}"
    data["version"] = old + 1
    return f"CHANGED, version {old} → {data['version']}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build messages.json from the app messages spreadsheet.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--sheet-id", help="Google Sheet id or URL (shared as 'Anyone with the link – Viewer')")
    source.add_argument("--xlsx", type=Path, help="path to a downloaded .xlsx file")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"output folder (default: {DEFAULT_OUT})")
    parser.add_argument("--check", action="store_true", help="validate only, don't write files")
    args = parser.parse_args()

    data = download_google_sheet(args.sheet_id) if args.sheet_id else args.xlsx.read_bytes()
    report = Report()
    messages = build(read_xlsx(data), report)

    print("Validation:")
    report.print()
    if report.errors:
        print(f"\n❌ {len(report.errors)} error(s), {len(report.warnings)} warning(s) – nothing was written.")
        return 1
    if not report.warnings:
        print("  ✅ no problems found")

    path = args.out / FILE_NAME
    note = resolve_version(messages, path)
    keys = sorted({t["key"] for t in messages["texts"]})
    print(f"\n{FILE_NAME}: {len(messages['welcome'])} welcome messages · {len(messages['texts'])} texts "
          f"({', '.join(keys)})  ({note})")
    if args.check:
        print("\n--check: no files written.")
        return 0
    args.out.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(messages, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ Wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
