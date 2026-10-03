#!/usr/bin/env python3
"""
Build LinguaPath course JSON files from the course-content spreadsheet.

The spreadsheet (Google Sheets or .xlsx) has four tabs: courses, units, lessons, words, plus an
optional `tips` tab (a rule explained on a card before a lesson, per course).
One row in `words` = one concept, with the word / reading / meaning / example in all six
languages. Every course (vi, en, zh, ja, ko, es) is generated from the same rows.

Usage
    python3 build_courses.py --sheet-id <GOOGLE_SHEET_ID>     # sheet shared as "Anyone with the link"
    python3 build_courses.py --xlsx LinguaPath_Course_Content.xlsx
    python3 build_courses.py --xlsx file.xlsx --check          # validate only, write nothing

Only the Python standard library is needed.
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

LANGS = ["vi", "en", "zh", "ja", "ko", "es"]          # UI languages == course languages
JSON_LANG_ORDER = ["en", "vi", "zh", "ja", "ko", "es"]  # key order inside LocalizedText
READING_REQUIRED = {"zh", "ja", "ko"}
# Languages written without spaces: their example sentences need `tokens_xx` (chunks separated
# by " / ") for the sentence-builder exercise. Other languages are split on spaces.
TOKENS_REQUIRED = {"zh", "ja"}
# Space-separated languages without `tokens_xx` are split on spaces, but multi-word phrases stay
# together: every multi-word term of the course (e.g. "sân bay", "phone number", "fin de semana")
# plus these common phrases. Vietnamese needs this most – it puts spaces between syllables.
EXTRA_PHRASES = {
    "vi": ["chúng ta", "chúng tôi", "anh ấy", "cô ấy", "em gái", "cái này", "cái nào", "hẹn gặp lại",
           "đi học", "đi làm", "mỗi sáng", "mỗi tháng", "một lần", "đánh răng", "rửa tay", "rửa mặt",
           "lớp học", "trường học", "bạn bè", "bông hoa", "ngọn núi", "con sông", "bộ phim", "cuốn sách",
           "quyển sách", "trò chơi", "nhà ga", "nhà hàng", "nhật bản", "hà nội", "con số", "đất nước",
           "bị ốm", "bị sốt", "bị ho", "bị lạc", "gần đây", "đến đây", "cứu với", "mỗi ngày", "mở cửa",
           "mười một", "vui lòng", "đứa trẻ", "mát mẻ", "ấm áp"],
    "en": ["thank you", "good morning", "see you", "a lot of", "every day", "every morning"],
    "es": ["por favor", "todos los días", "cada mañana", "de compras", "lo siento"],
}
READING_RECOMMENDED = {"en"}
TABS = ["courses", "units", "lessons", "words"]

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
DEFAULT_OUT = REPO_ROOT / "LanguageApp" / "LanguageApp" / "Resources" / "Content"
IMPORTER_SWIFT = REPO_ROOT / "LanguageApp" / "LanguageApp" / "Data" / "Content" / "ContentImporter.swift"

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
WORD_ID_RE = re.compile(r"^\d{4}$")
SF_SYMBOL_RE = re.compile(r"^[a-z0-9]+(?:\.[a-z0-9]+)*$")


# --------------------------------------------------------------------------- report

class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"{where}: {msg}")

    def print(self) -> None:
        for w in self.warnings:
            print(f"  ⚠️  {w}")
        for e in self.errors:
            print(f"  ❌ {e}")


# --------------------------------------------------------------------------- xlsx reader (stdlib)

NS_MAIN = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
NS_REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
NS_PKG_REL = "{http://schemas.openxmlformats.org/package/2006/relationships}"


def _col_index(ref: str) -> int:
    letters = "".join(ch for ch in ref if ch.isalpha())
    index = 0
    for ch in letters:
        index = index * 26 + (ord(ch.upper()) - 64)
    return index - 1


def _cell_text(cell: ET.Element, shared: list[str]) -> str:
    kind = cell.get("t")
    if kind == "inlineStr":
        return "".join(t.text or "" for t in cell.iter(f"{NS_MAIN}t"))
    value = cell.find(f"{NS_MAIN}v")
    if value is None or value.text is None:
        return ""
    raw = value.text
    if kind == "s":
        return shared[int(raw)]
    if kind == "b":
        return "TRUE" if raw == "1" else "FALSE"
    if kind in ("str", "e"):
        return raw
    # Number: 25.0 -> "25"
    try:
        number = float(raw)
        return str(int(number)) if number.is_integer() else raw
    except ValueError:
        return raw


def read_xlsx(data: bytes) -> dict[str, list[list[str]]]:
    """Returns {sheet name: rows (list of cell strings)}."""
    archive = zipfile.ZipFile(io.BytesIO(data))
    names = set(archive.namelist())

    shared: list[str] = []
    if "xl/sharedStrings.xml" in names:
        root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
        for si in root.findall(f"{NS_MAIN}si"):
            shared.append("".join(t.text or "" for t in si.iter(f"{NS_MAIN}t")))

    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {r.get("Id"): r.get("Target") for r in rels.findall(f"{NS_PKG_REL}Relationship")}

    sheets: dict[str, list[list[str]]] = {}
    for sheet in workbook.find(f"{NS_MAIN}sheets"):
        target = targets[sheet.get(f"{NS_REL}id")]
        path = target.lstrip("/") if target.startswith("/") else f"xl/{target}"
        root = ET.fromstring(archive.read(path))
        rows: list[list[str]] = []
        for row in root.iter(f"{NS_MAIN}row"):
            values: dict[int, str] = {}
            for position, cell in enumerate(row.findall(f"{NS_MAIN}c")):
                ref = cell.get("r")
                values[_col_index(ref) if ref else position] = _cell_text(cell, shared)
            row_number = int(row.get("r", len(rows) + 1))
            while len(rows) < row_number - 1:
                rows.append([])           # keep sheet row numbers aligned
            width = max(values) + 1 if values else 0
            rows.append([values.get(i, "") for i in range(width)])
        sheets[sheet.get("name")] = rows
    return sheets


def sheet_id_from(value: str) -> str:
    """Accepts the sheet id or the whole sheet URL (…/spreadsheets/d/<id>/edit?…)."""
    value = value.strip()
    match = re.search(r"/spreadsheets/d/([A-Za-z0-9_-]+)", value)
    return match.group(1) if match else value


def download_google_sheet(sheet_id: str) -> bytes:
    sheet_id = sheet_id_from(sheet_id)
    url = f"https://docs.google.com/spreadsheets/d/{sheet_id}/export?format=xlsx"
    request = urllib.request.Request(url, headers={"User-Agent": "LinguaPath-content-builder"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"Could not download the Google Sheet ({exc}).\n"
                 "Share it as 'Anyone with the link – Viewer', or use File ▸ Download ▸ .xlsx and --xlsx.")
    if not data.startswith(b"PK"):
        sys.exit("Google returned a web page instead of a spreadsheet – the sheet is probably private.\n"
                 "Share it as 'Anyone with the link – Viewer', or download it as .xlsx and use --xlsx.")
    return data


# --------------------------------------------------------------------------- tab parsing

def tab_records(sheets: dict[str, list[list[str]]], tab: str, report: Report) -> list[tuple[int, dict[str, str]]]:
    """[(sheet row number, {header: value})] – skips empty rows and 'note' columns."""
    rows = sheets.get(tab)
    if rows is None:
        report.error(tab, f"tab '{tab}' not found (found: {', '.join(sheets)})")
        return []
    header_index = next((i for i, r in enumerate(rows) if any(c.strip() for c in r)), None)
    if header_index is None:
        report.error(tab, "tab is empty")
        return []
    headers = [h.strip().lower() for h in rows[header_index]]
    records = []
    for i, row in enumerate(rows[header_index + 1:], start=header_index + 2):
        record = {}
        for col, header in enumerate(headers):
            if not header or header == "note" or header.startswith("#"):
                continue
            value = row[col] if col < len(row) else ""
            record[header] = value.strip()
            if value != value.strip() and value.strip():
                report.warn(f"{tab}!row {i}", f"'{header}' has leading/trailing spaces (trimmed)")
        if any(record.values()):
            records.append((i, record))
    return records


def require_columns(tab: str, records, columns: list[str], report: Report) -> bool:
    if not records:
        return False
    missing = [c for c in columns if c not in records[0][1]]
    if missing:
        report.error(tab, f"missing column(s): {', '.join(missing)}")
        return False
    return True


def localized(record: dict[str, str], prefix: str, where: str, report: Report, required: bool = True) -> dict[str, str]:
    values = {}
    for lang in LANGS:
        value = record.get(f"{prefix}_{lang}", "")
        if not value and required:
            report.error(where, f"'{prefix}_{lang}' is empty")
        values[lang] = value
    return {lang: values[lang] for lang in JSON_LANG_ORDER}


def normalize_word_id(raw: str) -> str:
    """Google Sheets may turn 0007 into 7 – pad it back to 4 digits."""
    return f"{int(raw):04d}" if raw.isdigit() and len(raw) <= 4 else raw


# --------------------------------------------------------------------------- build

def build(sheets: dict[str, list[list[str]]], report: Report) -> dict[str, dict]:
    records = {tab: tab_records(sheets, tab, report) for tab in TABS}

    course_cols = ["course_id", "version", "speech_locale", "reading_label", "native_name", "flag"] + [f"name_{l}" for l in LANGS]
    unit_cols = ["unit_id"] + [f"title_{l}" for l in LANGS]
    lesson_cols = ["lesson_id", "unit_id", "icon", "xp"] + [f"title_{l}" for l in LANGS]
    word_cols = ["id", "lesson_id"] + [f"{p}_{l}" for l in LANGS for p in ("term", "reading", "meaning", "example")]
    ok = all([
        require_columns("courses", records["courses"], course_cols, report),
        require_columns("units", records["units"], unit_cols, report),
        require_columns("lessons", records["lessons"], lesson_cols, report),
        require_columns("words", records["words"], word_cols, report),
    ])
    if not ok:
        return {}

    # Courses
    courses = {}
    for row, r in records["courses"]:
        where = f"courses!row {row}"
        cid = r["course_id"]
        if cid not in LANGS:
            report.error(where, f"course_id '{cid}' must be one of {', '.join(LANGS)}")
            continue
        if cid in courses:
            report.error(where, f"duplicate course_id '{cid}'")
            continue
        version = r["version"] or "1"
        if not version.isdigit():
            report.error(where, f"version '{version}' must be a whole number")
            version = "1"
        if not r["speech_locale"]:
            report.error(where, "speech_locale is empty (e.g. ja-JP)")
        if not r["native_name"]:
            report.error(where, "native_name is empty")
        courses[cid] = {
            "id": cid,
            "version": int(version),
            "name": localized(r, "name", where, report),
            "nativeName": r["native_name"],
            "flag": r["flag"],
            "speechLocale": r["speech_locale"],
            "readingLabel": r["reading_label"] or None,
        }
    for lang in LANGS:
        if lang not in courses:
            report.error("courses", f"no row for course '{lang}' (UI languages and courses must match)")

    # Units
    units: dict[str, dict] = {}
    for row, r in records["units"]:
        where = f"units!row {row}"
        uid = r["unit_id"]
        if not SLUG_RE.match(uid):
            report.error(where, f"unit_id '{uid}' must be lowercase letters/digits/dashes (e.g. u1)")
            continue
        if uid in units:
            report.error(where, f"duplicate unit_id '{uid}'")
            continue
        units[uid] = {"id": uid, "title": localized(r, "title", where, report), "lessons": []}

    # Lessons
    lessons: dict[str, dict] = {}
    for row, r in records["lessons"]:
        where = f"lessons!row {row}"
        lid = r["lesson_id"]
        if not SLUG_RE.match(lid):
            report.error(where, f"lesson_id '{lid}' must be lowercase letters/digits/dashes (e.g. u1-l1)")
            continue
        if lid in lessons:
            report.error(where, f"duplicate lesson_id '{lid}'")
            continue
        if r["unit_id"] not in units:
            report.error(where, f"unit_id '{r['unit_id']}' does not exist in the units tab")
            continue
        icon = r["icon"] or "star.fill"
        if not r["icon"]:
            report.warn(where, "icon is empty – using 'star.fill'")
        elif not SF_SYMBOL_RE.match(icon):
            report.error(where, f"icon '{icon}' doesn't look like an SF Symbol name (e.g. fork.knife)")
        xp = r["xp"] or "10"
        if not xp.isdigit() or int(xp) <= 0:
            report.error(where, f"xp '{xp}' must be a positive whole number")
            xp = "10"
        lesson = {"id": lid, "title": localized(r, "title", where, report), "icon": icon, "xp": int(xp), "words": []}
        lessons[lid] = lesson
        units[r["unit_id"]]["lessons"].append(lesson)

    tips = build_tips(sheets, lessons, set(courses), report)

    # Words
    seen_ids: dict[str, int] = {}
    examples_without_term: dict[str, list[str]] = defaultdict(list)
    for row, r in records["words"]:
        where = f"words!row {row}"
        wid = normalize_word_id(r["id"])
        if not WORD_ID_RE.match(wid):
            report.error(where, f"id '{r['id']}' must be a 4-digit number (e.g. 0025)")
            continue
        if wid in seen_ids:
            report.error(where, f"duplicate id {wid} (also on row {seen_ids[wid]})")
            continue
        seen_ids[wid] = row
        where = f"words!row {row} (id {wid}{', ' + r['key'] if r.get('key') else ''})"
        if r["lesson_id"] not in lessons:
            report.error(where, f"lesson_id '{r['lesson_id']}' does not exist in the lessons tab")
            continue

        word = {"id": wid, "term": {}, "reading": {}, "meaning": {}, "example": {}, "tokens": {}}
        for lang in LANGS:
            term = r[f"term_{lang}"]
            reading = r[f"reading_{lang}"]
            meaning = r[f"meaning_{lang}"] or term
            if not term:
                report.error(where, f"term_{lang} is empty")
            if lang in READING_REQUIRED and not reading:
                report.error(where, f"reading_{lang} is empty (required for {lang})")
            elif lang in READING_RECOMMENDED and not reading:
                report.warn(where, f"reading_{lang} is empty (IPA recommended)")
            word["term"][lang] = term
            word["reading"][lang] = reading
            word["meaning"][lang] = meaning
            word["example"][lang] = r[f"example_{lang}"]
            word["tokens"][lang] = check_tokens(where, lang, r[f"example_{lang}"],
                                                (r.get(f"tokens_{lang}") or "").strip(), report)
        filled = [l for l in LANGS if word["example"][l]]
        if filled and len(filled) != len(LANGS):
            missing = [l for l in LANGS if l not in filled]
            report.error(where, f"example is filled for {', '.join(filled)} but missing for {', '.join(missing)}")
        for lang in LANGS:
            example, term = word["example"][lang], word["term"][lang]
            if example and term and term.casefold() not in example.casefold():
                examples_without_term[lang].append(wid)
        lessons[r["lesson_id"]]["words"].append(word)

    # Auto-chunk examples without tokens_xx, keeping multi-word terms / phrases together.
    for lang in LANGS:
        phrases = {p.casefold() for p in EXTRA_PHRASES.get(lang, [])}
        for lesson in lessons.values():
            for w in lesson["words"]:
                if " " in w["term"][lang]:
                    phrases.add(w["term"][lang].casefold())
        for lesson in lessons.values():
            for w in lesson["words"]:
                if w["tokens"][lang] is None:
                    w["tokens"][lang] = group_words(w["example"][lang], phrases)

    for lang, ids in examples_without_term.items():
        report.warn(f"words (example_{lang})",
                    f"{len(ids)} example(s) don't contain term_{lang} as written – fill-in-the-blank skips them: "
                    + ", ".join(ids[:12]) + (" …" if len(ids) > 12 else ""))

    # Structure checks
    for uid, unit in units.items():
        if not unit["lessons"]:
            report.error(f"units ({uid})", "unit has no lessons")
    for lid, lesson in lessons.items():
        count = len(lesson["words"])
        if count == 0:
            report.error(f"lessons ({lid})", "lesson has no words")
        elif count < 4:
            report.warn(f"lessons ({lid})", f"only {count} words – lessons work best with 4–8 (answer options & match pairs)")
        elif count > 10:
            report.warn(f"lessons ({lid})", f"{count} words – consider splitting (lessons work best with 4–8)")

    # Duplicates inside one language (confusing answer options)
    for lang in LANGS:
        for field, label in (("term", "term"), ("meaning", "meaning")):
            where_by_value = defaultdict(list)
            for lesson in lessons.values():
                for w in lesson["words"]:
                    if w[field][lang]:
                        where_by_value[w[field][lang].casefold()].append(w["id"])
            for value, ids in where_by_value.items():
                if len(ids) > 1:
                    report.warn(f"words ({', '.join(ids)})", f"same {label}_{lang} '{value}' – options may look identical")

    if report.errors:
        return {}

    # Assemble one JSON per course
    output = {}
    for cid, course in courses.items():
        data = dict(course)
        data["units"] = []
        for uid, unit in units.items():
            unit_json = {"id": f"{cid}-{uid}", "title": unit["title"], "lessons": []}
            for lesson in unit["lessons"]:
                lesson_json = {"id": f"{cid}-{lesson['id']}", "title": lesson["title"],
                               "icon": lesson["icon"], "xp": lesson["xp"]}
                if (lesson["id"], cid) in tips:
                    lesson_json["tip"] = tips[(lesson["id"], cid)]
                lesson_json["items"] = []
                for w in lesson["words"]:
                    item = {"id": f"{cid}-{w['id']}", "term": w["term"][cid],
                            "meaning": {l: w["meaning"][l] for l in JSON_LANG_ORDER}}
                    if w["reading"][cid]:
                        item["reading"] = w["reading"][cid]
                    if w["example"][cid]:
                        item["example"] = w["example"][cid]
                        item["exampleTokens"] = w["tokens"][cid]
                        item["exampleMeaning"] = {l: w["example"][l] for l in JSON_LANG_ORDER}
                    lesson_json["items"].append(item)
                unit_json["lessons"].append(lesson_json)
            data["units"].append(unit_json)
        output[cid] = data
    return output


def build_tips(sheets: dict[str, list[list[str]]], lessons: dict[str, dict], course_ids: set[str],
               report: Report) -> dict[tuple[str, str], dict[str, str]]:
    """Optional `tips` tab → {(lesson_id, course_id): {ui_lang: text}}.
    A tip explains a rule of the language being learned (e.g. how numbers are built), written in
    every UI language. It is shown on a card before the lesson's first question."""
    tips: dict[tuple[str, str], dict[str, str]] = {}
    if "tips" not in sheets:
        return tips
    records = tab_records(sheets, "tips", report)
    columns = ["lesson_id", "course_id"] + [f"text_{l}" for l in LANGS]
    if not records or not require_columns("tips", records, columns, report):
        return tips
    for row, r in records:
        where = f"tips!row {row}"
        lid, cid = r["lesson_id"], r["course_id"]
        if lid not in lessons:
            report.error(where, f"lesson_id '{lid}' does not exist in the lessons tab")
            continue
        if cid not in course_ids:
            report.error(where, f"course_id '{cid}' does not exist in the courses tab")
            continue
        if (lid, cid) in tips:
            report.error(where, f"duplicate tip for lesson '{lid}' in course '{cid}'")
            continue
        if not r["text_en"]:
            report.error(where, "text_en is empty (required – it is the fallback for other languages)")
            continue
        missing = [l for l in LANGS if not r[f"text_{l}"]]
        if missing:
            report.warn(where, f"text_{', text_'.join(missing)} empty – English is shown instead")
        tips[(lid, cid)] = {l: r[f"text_{l}"] for l in JSON_LANG_ORDER if r[f"text_{l}"]}
    return tips


def group_words(example: str, phrases: set[str], max_words: int = 5) -> list[str]:
    """Splits on spaces but keeps known phrases together (longest match first, punctuation and case
    ignored for matching): "Tôi đi taxi đến sân bay." → ["Tôi", "đi", "taxi", "đến", "sân bay."]."""
    words = example.split()
    def key(chunk: list[str]) -> str:
        return " ".join(w.strip(".,!?¡¿;:…\"'“”«»") for w in chunk).casefold()
    chunks, i = [], 0
    while i < len(words):
        for size in range(min(max_words, len(words) - i), 0, -1):
            if size == 1 or key(words[i:i + size]) in phrases:
                chunks.append(" ".join(words[i:i + size]))
                i += size
                break
    return chunks


def check_tokens(where: str, lang: str, example: str, tokens: str, report: "Report") -> list[str] | None:
    """Validates `tokens_xx` ("私 / は / 学生 / です。") against the example and returns the chunks.
    Without tokens, space-separated languages are split on spaces."""
    if not example:
        if tokens:
            report.error(where, f"tokens_{lang} is filled but example_{lang} is empty")
        return []
    if not tokens:
        if lang in TOKENS_REQUIRED:
            report.error(where, f"tokens_{lang} is empty (required for {lang} examples, e.g. 私 / は / 学生 / です。)")
            return []
        return None  # split on spaces later, keeping known phrases together (see group_words)
    parts = [p.strip() for p in tokens.split("/")]
    if any(not p for p in parts):
        report.error(where, f"tokens_{lang} has an empty chunk: '{tokens}'")
        return []
    if lang in TOKENS_REQUIRED:
        same = "".join(parts) == "".join(example.split())
    else:
        same = " ".join(" ".join(parts).split()) == " ".join(example.split())
    if not same:
        report.error(where, f"tokens_{lang} '{tokens}' don't rebuild example_{lang} '{example}'")
        return []
    if len(parts) < 2:
        report.warn(where, f"tokens_{lang} has a single chunk – the sentence builder needs at least 2")
    return parts


# --------------------------------------------------------------------------- write

def resolve_versions(output: dict[str, dict], out_dir: Path) -> dict[str, str]:
    """Bump a course's version automatically when its content changed."""
    notes = {}
    for cid, data in output.items():
        path = out_dir / f"course_{cid}.json"
        sheet_version = data["version"]
        if not path.exists():
            notes[cid] = f"new file, version {sheet_version}"
            continue
        existing = json.loads(path.read_text(encoding="utf-8"))
        old_version = int(existing.get("version", 0))
        same = {**existing, "version": 0} == {**data, "version": 0}
        if same:
            data["version"] = max(sheet_version, old_version)
            notes[cid] = f"unchanged, version {data['version']}"
        else:
            data["version"] = max(sheet_version, old_version + 1)
            notes[cid] = f"CHANGED, version {old_version} → {data['version']}"
    return notes


def check_importer_list(course_ids: list[str], report: Report) -> None:
    if not IMPORTER_SWIFT.exists():
        return
    source = IMPORTER_SWIFT.read_text(encoding="utf-8")
    for cid in course_ids:
        if f'"course_{cid}"' not in source:
            report.warn("ContentImporter.swift", f'"course_{cid}" is not listed in bundledCourseFiles – the app won\'t import it')


def main() -> int:
    parser = argparse.ArgumentParser(description="Build LinguaPath course JSON from the content spreadsheet.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--sheet-id", help="Google Sheet id (the part between /d/ and /edit in the URL) or the whole URL")
    source.add_argument("--xlsx", type=Path, help="path to a downloaded .xlsx file")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"output folder (default: {DEFAULT_OUT})")
    parser.add_argument("--check", action="store_true", help="validate only, don't write files")
    args = parser.parse_args()

    data = download_google_sheet(args.sheet_id) if args.sheet_id else args.xlsx.read_bytes()
    report = Report()
    output = build(read_xlsx(data), report)

    print("Validation:")
    report.print()
    if report.errors:
        print(f"\n❌ {len(report.errors)} error(s), {len(report.warnings)} warning(s) – nothing was written.")
        return 1
    if not report.warnings:
        print("  ✅ no problems found")

    check_importer_list(list(output), report)
    args.out.mkdir(parents=True, exist_ok=True)
    notes = resolve_versions(output, args.out)

    print("\nCourses:")
    for cid, data in output.items():
        lessons = sum(len(u["lessons"]) for u in data["units"])
        words = sum(len(l["items"]) for u in data["units"] for l in u["lessons"])
        tips = sum(1 for u in data["units"] for l in u["lessons"] if "tip" in l)
        print(f"  course_{cid}.json  {len(data['units'])} units · {lessons} lessons · {words} words · {tips} tips  ({notes[cid]})")

    if args.check:
        print("\n--check: no files written.")
        return 0
    for cid, data in output.items():
        path = args.out / f"course_{cid}.json"
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n✅ Wrote {len(output)} files to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
