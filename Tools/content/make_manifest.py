#!/usr/bin/env python3
"""
Write manifest.json for a folder of course files (used by the "Publish content" workflow).

    python3 Tools/content/make_manifest.py --dir <channel folder> --min-app-version 1.0

The app downloads manifest.json, compares each course's `version` with the installed one and
downloads the newer files; `sha256` lets it reject a broken or partial download.
Only the Python 3 standard library is needed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = 1  # must match RemoteContentService.supportedSchema in the app
# Display order of the courses (same as ContentImporter.bundledCourseFiles).
ORDER = ["en", "zh", "ja", "ko", "es", "vi"]


def build_manifest(folder: Path, min_app_version: str) -> dict:
    entries = []
    for path in sorted(folder.glob("course_*.json")):
        data = path.read_bytes()
        course = json.loads(data)
        entries.append({
            "id": course["id"],
            "version": int(course["version"]),
            "file": path.name,
            "sha256": hashlib.sha256(data).hexdigest(),
        })
    entries.sort(key=lambda e: (ORDER.index(e["id"]) if e["id"] in ORDER else len(ORDER), e["id"]))
    manifest = {
        "schema": SCHEMA,
        "minAppVersion": min_app_version,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "courses": entries,
    }
    # Welcome toasts + notification texts (build_messages.py) – optional.
    messages = folder / "messages.json"
    if messages.exists():
        data = messages.read_bytes()
        manifest["messages"] = {
            "version": int(json.loads(data)["version"]),
            "file": messages.name,
            "sha256": hashlib.sha256(data).hexdigest(),
        }
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Write manifest.json for published course files.")
    parser.add_argument("--dir", type=Path, required=True, help="folder with course_xx.json files")
    parser.add_argument("--min-app-version", default="1.0", help="oldest app version that reads this content")
    args = parser.parse_args()

    manifest = build_manifest(args.dir, args.min_app_version)
    if not manifest["courses"]:
        print(f"❌ no course_*.json in {args.dir}")
        return 1
    (args.dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for entry in manifest["courses"] + ([manifest["messages"]] if "messages" in manifest else []):
        print(f"  {entry['file']}  v{entry['version']}  {entry['sha256'][:12]}…")
    print(f"✅ manifest.json written to {args.dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
