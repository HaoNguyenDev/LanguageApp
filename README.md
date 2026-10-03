# LinguaPath (LanguageApp)

An iOS language-learning app for **Vietnamese, English, Chinese, Japanese, Korean and Spanish**. It combines **Duolingo-style gamified lessons** with **Anki-style spaced-repetition (SRS) flashcard reviews**.

- SwiftUI + SwiftData, **iOS 17+** (the first iOS version with SwiftData), iPhone only
- Architecture based on `SwiftUI-BaseApp`: Coordinator + `NavRouter`, `@Observable` managers injected via `.environment`, Theme, `LanguageManager` (JSON strings), toast/alert/inform messages
- No backend required yet. The data model is CloudKit-compatible, so iCloud sync can be enabled in phase 2
- **The same 6 languages are offered for the UI and for learning**

> "LinguaPath" is a placeholder name. Change it in `INFOPLIST_KEY_CFBundleDisplayName` and the `app_name` key in `lang_*.json`.

## Getting started

1. Open `LanguageApp/LanguageApp.xcodeproj` in Xcode 26.
2. Xcode resolves the **Lottie** package (`lottie-spm`) automatically.
3. Select an iPhone simulator and run.

CI (`.github/workflows/ci.yml`) builds the app and runs the unit tests on every PR into `develop` / `main`.

Unit tests (`⌘U`) cover the SRS scheduler, exercise generator, typed-answer matching, lesson state machine, streaks and streak freezes, daily quests, content import/upsert (word counts are read from the bundled JSON), and localization (UI languages match courses, every UI language has a strings file with the same keys as English, English fallback).

## MVP features

| Screen | What it does |
|---|---|
| Onboarding | Asks for the **app language** (the UI switches immediately) → the **language to learn** (the course in the app language is hidden) → daily XP goal → daily reminder |
| Learn | Unit → lesson path in a zig-zag layout; lessons unlock in order; header shows the course badge, streak 🔥, XP ⚡ and hearts ❤️; tap the streak for the last 7 days and **streak freezes**; **daily quests** card at the top of the path; floating buttons above the tab bar: **back to top** (from Unit 2 on – never in Unit 1) and **Unit N ↑/↓** – scrolls to the unit of the furthest completed lesson; hidden while that unit's header is on screen (pinned because you're in the unit, or scrolling by), otherwise ↓ when above it (e.g. after back to top) or ↑ when past it. Header visibility uses `onScrollVisibilityChange` on iOS 18 (lazy appear/disappear on iOS 17). Unit headers are **sticky** (pinned section headers) |
| Lesson | New-word card → choose the meaning → choose the word / listen & choose / type the word / type what you hear → **example sentences**: build the sentence (tap the chunks in order, plus 2 distractor chunks) and **fill in the blank** (pick the missing word; only examples that contain the word as written) → match pairs. **Difficulty:** the first time through a lesson uses more multiple choice and 1 + 1 sentence questions; replaying a finished lesson (and *Practice weak words*) uses more typing / listening and 2 + 2. Typed answers are graded leniently (`AnswerMatcher`: case, punctuation and spaces ignored; kana or kanji; Pinyin / Romaji / Korean romanization without tones; a missing accent or one typo is accepted and the correct spelling is shown). A wrong answer costs a heart and the question comes back at the end of the lesson |
| Lesson result | XP (+5 bonus for a perfect lesson), accuracy, streak, daily goal |
| Review | Flashcards with a 3D flip, graded Again/Hard/Good/Easy; SM-2 schedules the next review (Easy is always at least 2 days later than Good, e.g. a new word: Again 10m · Hard 1d · Good 3d · Easy 5d; labels keep one decimal for months / years); a **How reviews work** guide (spaced repetition, the steps for each card, what each button means) opens before the first review session and from the ⓘ button on the Review tab and in the session; **Practice weak words** (a lesson of up to 8 words ranked by mistakes, SRS lapses, low ease and short interval – no hearts lost); word list with memory strength and search |
| Profile | Daily goal ring, stats, 7-day XP chart (Swift Charts), achievements, editable display name |
| Achievements | 15 achievements (lessons, perfect lessons, best streak 3 / 7 / 30, words 50 / 200, XP 500 / 2,000, checkpoints 1 / 5, quest days 1 / 7, 100 reviews). Unlocked once and kept (`achievements.unlocked` in UserDefaults, with the date) – streak ones use the **best** streak ever. Checked after lessons, practice, checkpoints, reviews and when the app becomes active; shown on the lesson result with confetti (or as a toast). The profile lists unlocked ones first, the rest with a progress bar |
| Unit complete | Passing a unit's checkpoint for the first time shows *Unit N complete!* with confetti (`ConfettiView`, off with Reduce Motion) |
| Settings | Course, daily goal, sound effects, auto-play pronunciation, reminder (at my usual time, or a time picked), word reminders; turning on or changing a reminder option checks the notification permission – asks the first time, otherwise an alert opens iOS Settings, and a warning row stays while reminders are on but notifications are off; app language, theme, reset course progress, restore purchases |
| Streak | Current streak, last 7 days (studied 🔥 / frozen ❄️ / missed). **Streak freeze:** covers a missed day so the streak survives (frozen days keep the streak but don't add to it); applied automatically when the app becomes active. Free users buy them for 50 XP each from the spendable XP balance (lifetime XP − XP spent; total XP shown in the header doesn't drop) and hold up to 2; Plus is always fully equipped. A gap longer than 2 days, or one bigger than the freezes owned, loses the streak – freezes bought later can't revive it |
| Unit checkpoint | A 🏆 node at the end of each unit, unlocked when every lesson of the unit is completed. 10 words of the unit (half the learner's weakest, half random), one harder question each (choose / listen / type, as when replaying a lesson) + example sentences, no intro cards or match pairs; costs hearts like a lesson. **≥ 80 % correct passes**: +20 XP (+5 perfect), counts as a lesson for quests, and the next unit opens (the first lesson of a unit needs the previous unit's checkpoint; lessons already completed stay unlocked). A failed attempt gives no XP but records mistakes for *Practice weak words* |
| Daily quests | 3 quests a day: always *Earn {daily goal} XP* (+10 XP) plus two of *Complete 2 lessons* (+15), *Review 15 cards* (+10, only offered once words are learned) and *Finish a lesson with no mistakes* (+15, practice counts too), picked from the day (stable FNV-1a hash of the day key) and fixed once chosen (`DailyActivity.questKinds`). Progress comes from the day's counters; rewards are given automatically when a quest completes and shown on the lesson result (or as a toast after a review session). Reward XP counts toward *Earn XP* and the streak-freeze balance |
| Notifications | Local notifications planned 7 days ahead (`NotificationPlanner`) and re-planned whenever the app becomes active or goes to the background: a **daily reminder** at the learner's usual study time (median time of the day's first activity over the last 14 days, ≥ 3 days of history, 07:00–21:00, rounded to 15 min; otherwise the time picked) – saying how many words are due when there are 5 or more; a **streak at risk** warning at 21:00 when the streak would end at midnight (today, or tomorrow after studying today). No reminder on a day already studied; a reminder less than an hour before the streak warning is dropped |
| Remote content | Course content is updated **without an App Store release**: the *Publish content* workflow builds the Google Sheet into JSON and publishes it to `LanguageApp-content` (GitHub Pages). The app checks `manifest.json` on every launch and when it comes back to the foreground (every 30 min at most), downloads newer courses, verifies sha256 / id / version and imports them when no lesson is open – progress is kept – then shows a toast with what's new in the course being learned (*Japanese just got 1 new unit and 10 new words*). Staging channel for Debug builds (Developer ▸ Remote content). See `Tools/content/README.md` |
| Welcome back & remote texts | When the learner comes back (cold launch, or back after 30+ min) and there's no new content, a welcome / encouragement toast is shown, picked by streak, days away and time of day (weighted, never the same twice in a row). Its texts and the notification / content-update texts come from a second Google Sheet (*App Messages*) published as `messages.json` with the content – editable without an app update; built-in strings are the fallback. See `Tools/content/README.md` |
| Word reminders | Optional (Settings ▸ Word reminders, off by default): every 15–120 min (picked) a quiet, grouped notification shows 1–5 words (picked) of the course being learned – the words of the latest completed lesson plus up to 20 words last graded Again / Hard in reviews (🔁), rotating through them. Only 08:00–22:00. Planned ahead as one-shot notifications in the slots the smart reminders leave (at most 56 planned in total – iOS keeps 64 and may drop requests added beyond that, so a few slots stay free) and re-planned when the app opens / closes, so they stop by themselves if the app isn't opened for a while |
| Plus (paywall) | StoreKit 2: unlimited hearts, unlimited reviews (free tier: 20 cards per session) and streak freezes that never run out |

Pronunciation uses `AVSpeechSynthesizer`: offline, free, with built-in voices for all 6 languages.

## Build configurations & developer menu

| | Debug | Release |
|---|---|---|
| Home-screen name | **LinguaPath Dev** | LinguaPath |
| `DEBUG` flag (`#if DEBUG`) | ✅ | – |
| `DEVELOPER_MENU` flag | ✅ | – |
| Settings ▸ **Developer** | ✅ | hidden |
| Developer switches | editable, saved in `UserDefaults` (`debug.*`) | always off |

Run from Xcode (`⌘R`) uses **Debug**. To try a Release build locally: Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Build Configuration ▸ Release. Archives / TestFlight use Release.

**Settings ▸ Developer** (no code changes needed):

- **Access:** unlock all lessons, unlimited hearts, force Free / Plus (overrides StoreKit)
- **Lessons:** a 🏁 button in the lesson top bar finishes the lesson at once (perfect / with a mistake), force one question type (choose, listen, type, type what you hear, build the sentence, fill in the blank), skip new-word cards, skip match pairs, short lessons (3 words), show the correct answer above each exercise
- **Hearts:** refill / empty
- **Progress:** complete the current unit or all lessons, pass the checkpoints of completed units, reset course progress
- **Review & practice:** make all learned words due now, mark 8 random words weak
- **Stats:** +100 XP today (also completes quests), build a 7-day streak
- **Daily quests:** start today over (today's XP, lessons, reviews, quests and rewards back to 0), next quest set (switch today's quests without paying rewards twice)
- **Streak freeze:** give 2 / remove freezes, 7-day streak with yesterday missed, apply freezes now
- **Remote content:** channel (staging by default in developer builds, remembered across launches; Release always reads production), check for updates now (also when the channel changes), installed content versions, messages version, welcome-back toast preview
- **Notifications:** send one of each notification in 10 s, send a word reminder in 10 s, re-plan now and list the planned ones
- **Reset** (with confirmation): reset all courses (lessons + review progress of all 6 courses), reset everything (also XP, streak, daily activity, quests, achievements, streak freezes and hearts – like a fresh install, settings kept)
- **App:** show the review guide again, show onboarding on next launch, reset all switches; build info

The developer menu is gated by the `DEVELOPER_MENU` compilation condition (set for Debug in *Active Compilation Conditions*), not by `DEBUG`, so a future **Beta** configuration for TestFlight can enable it in an optimized build. App code only reads the *effective* values (`DebugSettings.shared.unlocksAllLessons`, `forcedPremium`, …), which are `false`/`nil` in Release builds and while unit tests run.

## Languages

| Language | `LanguageCode` (UI) | Course id | UI strings | Speech locale | Badge |
|---|---|---|---|---|---|
| Vietnamese | `vi` | `vi` | `lang_vi.json` | `vi-VN` | VI |
| English | `eng` | `en` | `lang_en.json` | `en-US` | EN |
| Chinese | `chs` | `zh` | `lang_cn.json` | `zh-CN` | 中 |
| Japanese | `ja` | `ja` | `lang_ja.json` | `ja-JP` | あ |
| Korean | `ko` | `ko` | `lang_ko.json` | `ko-KR` | 한 |
| Spanish | `es` | `es` | `lang_es.json` | `es-ES` | ES |

- UI languages (`LanguageCode`) and courses must stay the **same set**; a unit test enforces this.
- The default UI language comes from the device's preferred language (falls back to English).
- A course in the same language as the UI is hidden during onboarding (e.g. a Japanese UI doesn't offer the Japanese course).
- In Settings, picking a course in the UI language (or switching the UI to the language being learned) shows a confirmation alert, because meanings and hints would then be in the language being learned. The course list marks such a course with "Same as app language".
- Missing UI keys fall back to English; missing `LocalizedText` translations also fall back to English.
- The Japanese, Korean and Spanish UI strings are first drafts and should be reviewed by native speakers before release.

### Adding a language

1. Add a case to `LanguageCode` (title, `courseId`, strings file name, device-locale detection).
2. Add `lang_xx.json` with every UI key.
3. Add the language to the `LocalizedText` struct and to every `LocalizedText` in the course JSON files (`meaning`, `exampleMeaning`, unit/lesson titles, course names).
4. Add `course_xx.json` and list it in `ContentImporter.bundledCourseFiles`.
5. Add a badge style in `LanguageBadge.style(for:)`.

## Project structure

```
Tools/content/              build_courses.py – Google Sheet → course JSON (see its README)
LanguageApp/
├── App/                    LanguageAppApp (entry point, DI, ModelContainer)
├── AppCoordinator/         Root NavigationStack + sheet/full-screen routing (Router.Study)
├── Router/                 NavRouter, Routable, ScreenCoordinator   (from BaseApp)
├── Managers/               UserSettings, AppState, AppSettings, LanguageManager, LanguageCode
├── Theme/                  Light/Dark themes + gamification color tokens
├── Data/
│   ├── Models/             Course, CourseUnit, Lesson, VocabItem (+SRS state), DailyActivity, LocalizedText
│   ├── Content/            CourseDTO + ContentImporter (upsert by remoteId)
│   └── PersistenceController.swift
├── Services/               SRSScheduler, ExerciseGenerator, ProgressService,
│                           GamificationManager (hearts), SpeechService, PremiumManager,
│                           NotificationManager, FeedbackService
├── Scenes/                 Splash, Onboarding, MainTab, Learn, Lesson, Review, Profile,
│                           Settings, CourseSelection, WordList, Paywall, ThemeChange
├── CustomUI/               BaseApp components + FilledButtonStyle, OptionButtonStyle,
│                           LanguageBadge, LessonProgressBar, StatPill, SpeakerButton…
└── Resources/
    ├── Content/            course_{vi,en,zh,ja,ko,es}.json (generated – see Tools/content)
    ├── Languages/          lang_{vi,en,cn,ja,ko,es}.json (UI strings)
    ├── Animation/          Lottie
    └── Font/               Nunito
```

## Course content

Each course currently has 10 units, 38 lessons and 283 words (1,698 in total), content `version` 8 (zh / ja: 7):

| Unit | Lessons |
|---|---|
| 1 Basics 1 | Greetings · Essentials · Questions |
| 2 Everyday life | Numbers (0–10, then tens, hundreds, thousands) · Food & drink · Meals |
| 3 People & family | Family · People · Describing people · About me |
| 4 Time | Today & tomorrow · Days of the week · Hours, days, months · Daily routine |
| 5 Shopping | At the shop · Clothes · Colors · Paying |
| 6 Travel | Places · Directions · Transport · At the hotel |
| 7 Work & school | Jobs · At the office · At school · Learning |
| 8 Hobbies | Free time · Sports · Activities · Likes & dislikes |
| 9 Weather & nature | Weather · Seasons · Nature · Animals |
| 10 Health | Body · Face · Feeling sick · Emergencies |

Lessons have 7–8 words (Numbers: 21), 24–35 words per unit. **Every word has an example sentence** in all six languages, stored with `exampleTokens` (the sentence split into chunks – phrases for Chinese / Japanese, words elsewhere) for the sentence-builder and fill-in-the-blank exercises.

Readings: IPA (English), Pinyin (Chinese), kana + Romaji (Japanese), Romanization (Korean); none for Spanish and Vietnamese.

**Lesson tips:** a lesson can start with a tip card that explains a rule of the language being learned, in the app language. The Numbers lesson uses one: how 0–10 are said and how bigger numbers are built in each language (English -teen / -ty, Vietnamese mốt / lăm / tư, Chinese 两 and 万, Japanese よん / なな and さんびゃく, Korean native vs Sino-Korean numbers, Spanish dieci- / veinti- / y).

Content is edited in the **Google Sheet "LinguaPath – Course Content"** (one row per word, all six languages side by side) and converted with the content tool:

```bash
python3 Tools/content/build_courses.py --sheet-id <SHEET_ID>     # or --xlsx <downloaded.xlsx>
```

The script validates the sheet (missing translations/readings, duplicate ids, broken references…), writes the six `course_xx.json` files and bumps each course's `version` when its content changed. On the next launch, `ContentImporter` updates the texts by `id`, keeps the learner's progress and SRS schedule (also when a word moves to another lesson) and deletes words/lessons/units that were removed from the sheet. Word ids must stay stable and must never be reused. See [`Tools/content/README.md`](Tools/content/README.md) for the sheet format and all checks.

Generated item format:

```json
{ "id": "ja-0007", "term": "はい", "reading": "hai",
  "meaning": { "en": "yes", "vi": "vâng / có", "zh": "是", "ja": "はい", "ko": "네", "es": "sí" },
  "example": "はい、学生です。", "exampleTokens": ["はい、", "学生", "です。"],
  "exampleMeaning": { "en": "Yes, I am a student.", "vi": "Vâng, tôi là học sinh.", … } }
```

Lesson icons are SF Symbol names in the lesson's `icon` field.

### Adding UI strings

Add a **lowercase** key to all six `lang_*.json` files, then use `"key".localized()` or `"key".localizedFormat(n)` (with `%ld` placeholders).

## Monetization (App Store)

- **Freemium + "Plus" subscription**, similar to Duolingo:
  - Free: 5 hearts (1 heart refills every 30 minutes), up to 20 cards per review session
  - Plus: unlimited hearts and reviews, early access to new courses
- Product IDs (create them in App Store Connect as auto-renewable subscriptions in one subscription group):
  - `com.haonguyen.app.LanguageApp.plus.monthly`
  - `com.haonguyen.app.LanguageApp.plus.yearly` (a 7-day free trial is recommended)
- Local testing: `LanguageApp/LinguaPath.storekit` holds both products (1-week free trial) and is selected in Scheme ▸ Run ▸ Options ▸ StoreKit Configuration, so purchases work in the simulator without App Store Connect. Transactions: Debug ▸ StoreKit ▸ Manage Transactions.

## Roadmap

See [ROADMAP.md](ROADMAP.md). Current focus: make the app complete before publishing – stabilize (v0.9), more content (v0.10), new exercise types (v0.11), engagement features (v0.12), polish (v0.13), then release (v1.0.0).

## Technical notes

- **Icons:** every icon in the app is an **SF Symbol** (`Image(systemName:)`); there are no image icons in Assets. Languages are shown with `LanguageBadge` (a colored circle with "VI", "EN", "中", "あ", "한", "ES") instead of flag emoji, because flag emoji can render as "?" boxes. The launch screen uses a background color only. The App Store icon (`AppIcon`, 1024×1024) still needs to be designed.
- **Buttons:** primary actions use the flat `FilledButtonStyle` (`.filled(color)`); answer and choice cards use `OptionButtonStyle(state:)`; secondary actions use `TextButtonStyle`. Lesson nodes on the Learn path are simple flat circles.
- **Navigation:** pushed screens use the system back button (tinted with the primary color) and support swipe-back. `NavRouter` keeps its internal stack in sync when the system pops `path`. Lessons, reviews and the paywall are presented modally via `Router.Study`.
- **Tab bar:** the main screen uses a custom container (`ZStack`) plus a custom tab bar instead of `TabView`, so the system tab bar never shows placeholder icons on iOS 26.
- The project was originally created as a **macOS app** and was converted to iOS (`SDKROOT = iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, iPhone only).
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (the Xcode 26 default), so every type runs on the main actor. Unit tests are marked `@MainActor`.
- SwiftData models don't use `@Attribute(.unique)`, every property has a default value, and all relationships are optional, as required by CloudKit.
