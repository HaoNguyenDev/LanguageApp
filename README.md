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

Unit tests (`⌘U`) cover the SRS scheduler, exercise generator, lesson state machine, streaks, content import/upsert, and localization (UI languages match courses, every UI language has a strings file, English fallback).

## MVP features

| Screen | What it does |
|---|---|
| Onboarding | Asks for the **app language** (the UI switches immediately) → the **language to learn** (the course in the app language is hidden) → daily XP goal → daily reminder |
| Learn | Unit → lesson path in a zig-zag layout; lessons unlock in order; header shows the course badge, streak 🔥, XP ⚡ and hearts ❤️ |
| Lesson | New-word card → choose the meaning → choose the word → listen & choose → match pairs. A wrong answer costs a heart and the question comes back at the end of the lesson |
| Lesson result | XP (+5 bonus for a perfect lesson), accuracy, streak, daily goal |
| Review | Flashcards with a 3D flip, graded Again/Hard/Good/Easy; SM-2 schedules the next review; word list with memory strength and search |
| Profile | Daily goal ring, stats, 7-day XP chart (Swift Charts), achievements, editable display name |
| Settings | Course, daily goal, sound effects, auto-play pronunciation, reminder + time, app language, theme, reset course progress, restore purchases |
| Plus (paywall) | StoreKit 2: unlimited hearts and unlimited reviews (free tier: 20 cards per session) |

Pronunciation uses `AVSpeechSynthesizer`: offline, free, with built-in voices for all 6 languages.

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

Each course currently has 2 units × 2 lessons × 6 words (24 words per course, 144 in total), content `version` 3:

- Unit 1 "Basics 1": Greetings, Essentials
- Unit 2 "Everyday life": Numbers, Food & drink

Readings: IPA (English), Pinyin (Chinese), kana + Romaji (Japanese), Romanization (Korean); none for Spanish and Vietnamese.

Content is edited in the **Google Sheet "LinguaPath – Course Content"** (one row per word, all six languages side by side) and converted with the content tool:

```bash
python3 Tools/content/build_courses.py --sheet-id <SHEET_ID>     # or --xlsx <downloaded.xlsx>
```

The script validates the sheet (missing translations/readings, duplicate ids, broken references…), writes the six `course_xx.json` files and bumps each course's `version` when its content changed. On the next launch, `ContentImporter` updates the texts by `id`, keeps the learner's progress and SRS schedule (also when a word moves to another lesson) and deletes words/lessons/units that were removed from the sheet. Word ids must stay stable and must never be reused. See [`Tools/content/README.md`](Tools/content/README.md) for the sheet format and all checks.

Generated item format:

```json
{ "id": "ja-0007", "term": "はい", "reading": "hai",
  "meaning": { "en": "yes", "vi": "vâng / có", "zh": "是", "ja": "はい", "ko": "네", "es": "sí" },
  "example": "…", "exampleMeaning": { "en": "…", "vi": "…" } }
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
- Local testing: File ▸ New ▸ **StoreKit Configuration File**, add the two products above, then select the file in Scheme ▸ Run ▸ Options ▸ StoreKit Configuration.

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
