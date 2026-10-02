# Course content tool

Course content lives in one spreadsheet (Google Sheets). `build_courses.py` validates it and generates the six `course_xx.json` files that the app bundles in `LanguageApp/LanguageApp/Resources/Content/`.

```
Google Sheet ──(export .xlsx)──▶ build_courses.py ──▶ validate ──▶ course_vi.json … course_es.json
```

Only the Python 3 standard library is needed (macOS already ships `python3` with the Xcode command line tools).

## Usage

Run from the repository root.

```bash
# Option A – read the Google Sheet directly (sheet shared as "Anyone with the link – Viewer")
python3 Tools/content/build_courses.py --sheet-id <SHEET_ID>

# Option B – File ▸ Download ▸ Microsoft Excel (.xlsx) in Google Sheets, then:
python3 Tools/content/build_courses.py --xlsx ~/Downloads/LinguaPath_Course_Content.xlsx

# Validate only, write nothing
python3 Tools/content/build_courses.py --sheet-id <SHEET_ID> --check
```

`<SHEET_ID>` is the part of the URL between `/d/` and `/edit`.

The script:

1. Validates every tab. On any error it prints the tab, row and problem, and **writes nothing**.
2. Writes `course_vi.json`, `course_en.json`, `course_zh.json`, `course_ja.json`, `course_ko.json`, `course_es.json`.
3. **Bumps `version` automatically** for each course whose content changed, so the app re-imports it on next launch while keeping learner progress.

Then build the app and commit the spreadsheet change together with the generated JSON.

## Spreadsheet format

Four tabs (names must match), plus an optional `tips` tab. Columns ending in `_vi`, `_en`, `_zh`, `_ja`, `_ko`, `_es` exist once per language. Row order defines display order. A column named `note` is ignored everywhere.

### `courses`

| Column | Example | Notes |
|---|---|---|
| `course_id` | `ja` | One row per language: vi, en, zh, ja, ko, es |
| `version` | `3` | Minimum version; the script raises it when content changes |
| `speech_locale` | `ja-JP` | Text-to-speech voice |
| `reading_label` | `Romaji` | Optional |
| `native_name` | `日本語` | |
| `flag` | 🇯🇵 | Kept in the JSON, not shown in the UI |
| `name_xx` | `Japanese`, `Tiếng Nhật`… | Course name in each UI language |

### `units`

| Column | Example |
|---|---|
| `unit_id` | `u1` |
| `title_xx` | `Basics 1`, `Cơ bản 1`… |

### `lessons`

| Column | Example | Notes |
|---|---|---|
| `lesson_id` | `u1-l1` | Unique |
| `unit_id` | `u1` | Must exist in `units` |
| `icon` | `hand.wave.fill` | SF Symbol name |
| `xp` | `10` | XP reward |
| `title_xx` | `Greetings`, `Chào hỏi`… | |

### `words` – one row per concept

| Column | Example | Notes |
|---|---|---|
| `id` | `0025` | 4 digits, unique. **Never change or reuse an id** – learner progress is stored per id. New word → next free number |
| `key` | `hello` | Optional readable name, only used in messages |
| `lesson_id` | `u1-l1` | Must exist in `lessons` |
| `term_xx` | `こんにちは` | The word in language xx – the term of course xx. Required for all 6 |
| `reading_xx` | `konnichiwa` | Required for zh (Pinyin), ja (kana · Romaji), ko (Romanization); recommended for en (IPA) |
| `meaning_xx` | `xin chào` | Meaning shown when the **app language** is xx. Empty → uses `term_xx` |
| `example_xx` | `こんにちは、お元気ですか？` | Optional. The same sentence in every language: fill all 6 or none. Use the term as written when possible – fill-in-the-blank skips examples that don't contain it |
| `tokens_xx` | `こんにちは、 / お元気ですか？` | Chunks of `example_xx` for the sentence builder, separated by ` / ` (punctuation stays on the chunk before it). **Required for zh and ja**. Optional for the others: they are split on spaces, but multi-word terms of the course (`sân bay`, `phone number`, `fin de semana`) and the phrases in `EXTRA_PHRASES` in the script stay together. Fill it to override the automatic split. The chunks must rebuild the example exactly |

Example: for the Japanese course with the app in Vietnamese, the word shows `term_ja` + `reading_ja`, its meaning is `meaning_vi` (or `term_vi`), the example is `example_ja` and its translation is `example_vi`.

### `tips` – optional, one row per lesson + course

A rule of the language being learned (e.g. how numbers are built), shown on a card before the lesson's first question. Written in every UI language, because the learner reads it in the app language.

| Column | Example | Notes |
|---|---|---|
| `lesson_id` | `u2-l3` | Must exist in `lessons` |
| `course_id` | `en` | The course (language being learned) the tip is for |
| `text_xx` | `13–19 = number + -teen …` | Tip in UI language xx. `text_en` is required (fallback); one point per line (Alt+Enter) |

A lesson without a row for a course has no tip in that course.

## Checks

**Errors** (nothing is written):

- Missing tab or column, empty required value
- Duplicate `course_id`, `unit_id`, `lesson_id` or word `id`; word id not 4 digits
- Lesson → unknown unit, word → unknown lesson; unit without lessons; lesson without words
- Missing `term_xx` in any language, missing `reading_zh` / `reading_ja` / `reading_ko`
- Example filled for some languages but not all
- `tokens_zh` / `tokens_ja` missing for an example, chunks that don't rebuild the example, empty chunks
- `icon` that doesn't look like an SF Symbol name, `xp` not a positive number
- A UI language without a course row
- `tips`: unknown lesson or course, duplicate lesson + course, empty `text_en`

**Warnings** (files are still written):

- Leading/trailing spaces (trimmed automatically)
- Missing English IPA, empty icon (defaults to `star.fill`)
- Lessons with fewer than 4 or more than 10 words
- Two words with the same term or meaning in one language (answer options would look identical)
- A course that isn't listed in `ContentImporter.bundledCourseFiles`
- Examples that don't contain the term as written (normal for conjugated verbs / adjectives; fill-in-the-blank skips them)
- `tokens_xx` with a single chunk
- `tips` row with some `text_xx` empty (English is shown instead)

## Tips

- Google Sheets turns `0025` into `25`; the script pads it back, but formatting the `id` column as **Plain text** avoids confusion.
- Removing a word, lesson or unit from the sheet also removes it from the app on the next import (learner progress for that word is lost).
- Keep lessons at 4–8 words: the multiple-choice questions need 3 distractors and the match-pairs exercise uses up to 5 words.
