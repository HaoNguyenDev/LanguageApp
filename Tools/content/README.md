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

`<SHEET_ID>` is the part of the URL between `/d/` and `/edit` (the whole sheet URL works too).

The script:

1. Validates every tab. On any error it prints the tab, row and problem, and **writes nothing**.
2. Writes `course_vi.json`, `course_en.json`, `course_zh.json`, `course_ja.json`, `course_ko.json`, `course_es.json`.
3. **Bumps `version` automatically** for each course whose content changed, so the app re-imports it on next launch while keeping learner progress.

Then build the app and commit the spreadsheet change together with the generated JSON.

## Publishing to the app without a release

Sheet changes can reach users **without building the app**. The *Publish content* GitHub workflow builds the JSON from the Google Sheet and pushes it to the public repo [`LanguageApp-content`](https://github.com/HaoNguyenDev/LanguageApp-content), served by GitHub Pages:

```
Google Sheet ──▶ Publish content (GitHub Actions) ──▶ LanguageApp-content (GitHub Pages)
                 build_courses.py (validate, bump)        v1/staging/manifest.json + course_xx.json
                 make_manifest.py (versions, sha256)       v1/production/…
                                                                   │
App, on every launch / when it comes back (at most every 30 min): manifest ─────┘ → download newer courses
→ check sha256 / id / version → import when no lesson is open (progress is kept)
```

### Every time you change the sheet

1. Edit the Google Sheet.
2. GitHub ▸ **Actions ▸ Publish content ▸ Run workflow ▸ target = `staging`**. Validation errors stop the run and nothing is published (GitHub emails you).
3. On your iPhone (Debug build, channel **Staging** by default): just reopen the app – or Settings ▸ Developer ▸ Remote content ▸ **Check for content updates now**. Look at the new lessons.
4. Run the workflow again with **target = `promote`**: production gets exactly the files you tested. Users get them the next time they open the app (GitHub Pages caches for ~10 minutes).

`target = production` publishes straight from the sheet (skips the test). Keep word / lesson / unit ids stable: the importer deletes content that disappeared, together with its review progress.

When the content needs a newer app (a new column the old app can't read), publish with **min_app_version** set to that version – older apps keep their content.

### Setup (once)

1. Create the **public** repo `HaoNguyenDev/LanguageApp-content` (with a README so `main` exists). Settings ▸ Pages ▸ *Deploy from a branch* ▸ `main` / `(root)`. Content will be at `https://haonguyendev.github.io/LanguageApp-content/v1/…`.
2. Create a **fine-grained token**: repository access *only* `LanguageApp-content`, permission **Contents: Read and write**.
3. In `LanguageApp` ▸ Settings ▸ Secrets and variables ▸ Actions:
   - Secret `CONTENT_REPO_TOKEN` = the token
   - Variable `CONTENT_SHEET_ID` = the sheet id or URL (the sheet stays shared as *Anyone with the link – Viewer*)
   - Variable `MESSAGES_SHEET_ID` = the App Messages sheet id or URL (optional, see below)
4. Run *Publish content* with `staging`, then `promote`.

The bundled JSON in `Resources/Content` is still what a fresh install starts with (and works offline): refresh it with `build_courses.py` before each App Store release.

## App messages (welcome toast, notification texts)

A second sheet, **LinguaPath – App Messages**, holds texts you can change without an app update. `build_messages.py` turns it into `messages.json`, published next to the courses by the same *Publish content* workflow (manifest entry `messages`).

| Tab | What it changes |
|---|---|
| `guide` | How to fill the sheet (not read by the tool) |
| `welcome` | The toast shown when the learner comes back (cold launch, or back after 30+ min) **and there is no new content**. Columns `id · when · min_days_away · weight · active · title_xx · message_xx`. `when`: `any`, `streak` (2+ days), `no_streak`, `away` (no study for `min_days_away`+ days), `morning` (5–12h), `evening` (18–24h), `studied_today`. Placeholders `{name} {streak} {days_away} {course}` – an empty `{name}` is removed with its comma. A higher `weight` is picked more often; the same message isn't shown twice in a row. |
| `texts` | Variants of notification / toast texts, picked at random per key: `reminder`, `review_due` `{count}`, `streak_risk` `{days}`, `word_reminder` `{course}` (title only – the body is the words), `content_updated`, `content_new_units` `{course} {units} {words}`, `content_new_words` `{course} {words}` (title = toast title, body = toast message). |

`active` empty = shown; `FALSE` / `0` / `NO` hides a row. English is required, other languages fall back to English. Without a published file the app uses its built-in strings.

```bash
python3 Tools/content/build_messages.py --sheet-id <id or URL>      # → Resources/Content/messages.json (bundled)
python3 Tools/content/build_messages.py --xlsx messages.xlsx --check  # validate only
```

**Setup (once):** share the sheet as *Anyone with the link – Viewer* and add the repo variable `MESSAGES_SHEET_ID`. Each *Publish content* run then rebuilds the messages too; the app downloads a newer `messages.json` on its next check and uses it right away (no lesson restriction – it doesn't touch progress). Developer menu ▸ Remote content shows the messages version and has **Show a welcome-back toast**.

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
