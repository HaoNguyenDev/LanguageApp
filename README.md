# LinguaPath (LanguageApp)

An iOS language-learning app for **English, Chinese, Japanese, Korean and Spanish**. It combines **Duolingo-style gamified lessons** with **Anki-style spaced-repetition (SRS) flashcard reviews**.

- SwiftUI + SwiftData, **iOS 17+** (the first iOS version with SwiftData), iPhone only
- Architecture based on `SwiftUI-BaseApp`: Coordinator + `NavRouter`, `@Observable` managers injected via `.environment`, Theme, `LanguageManager` (JSON strings), toast/alert/inform messages
- No backend required yet. The data model is CloudKit-compatible so iCloud sync can be enabled in phase 2
- Localized UI: Vietnamese / English / Chinese

> "LinguaPath" is a placeholder name. Change it in `INFOPLIST_KEY_CFBundleDisplayName` and the `app_name` key in `lang_*.json`.

## Getting started

1. Open `LanguageApp/LanguageApp.xcodeproj` in Xcode 26.
2. Xcode resolves the **Lottie** package (`lottie-spm`) automatically.
3. Select an iPhone simulator and run.

Unit tests: `⌘U` (SRS scheduler, exercise generator, lesson state machine, streaks, content import).

## MVP features

| Screen | What it does |
|---|---|
| Onboarding | Asks for the **app language** (vi/en/中文, the UI switches immediately) → the **language to learn** (the course matching the app language is hidden) → daily XP goal → daily reminder |
| Learn | Unit → lesson path in a zig-zag layout; lessons unlock in order; header shows streak 🔥 · XP ⚡ · hearts ❤️ |
| Lesson | New-word card → choose the meaning → choose the word → listen & choose → match pairs. A wrong answer costs a heart and the question comes back at the end of the lesson |
| Lesson result | XP (+5 bonus for a perfect lesson), accuracy, streak, daily goal |
| Review | Flashcards with a 3D flip, graded Again/Hard/Good/Easy; SM-2 schedules the next review; word list with memory strength |
| Profile | Daily goal, stats, 7-day XP chart (Swift Charts), achievements |
| Settings | Course, daily goal, sound effects, auto-play pronunciation, reminder, app language, theme, reset progress, restore purchases |
| Plus (paywall) | StoreKit 2: unlimited hearts and unlimited reviews (free tier: 20 cards per session) |

Pronunciation uses `AVSpeechSynthesizer`: offline, free, with built-in voices for all 5 languages.

## Project structure

```
LanguageApp/
├── App/                    LanguageAppApp (entry point, DI, ModelContainer)
├── AppCoordinator/         Root NavigationStack + sheet/full-screen routing (Router.Study)
├── Router/                 NavRouter, Routable, ScreenCoordinator   (from BaseApp)
├── Managers/               UserSettings, AppState, AppSettings, LanguageManager
├── Theme/                  Light/Dark themes + gamification color tokens
├── Data/
│   ├── Models/             Course, CourseUnit, Lesson, VocabItem (+SRS state), DailyActivity
│   ├── Content/            CourseDTO + ContentImporter (upsert by remoteId)
│   └── PersistenceController.swift
├── Services/               SRSScheduler, ExerciseGenerator, ProgressService,
│                           GamificationManager (hearts), SpeechService, PremiumManager,
│                           NotificationManager, FeedbackService
├── Scenes/                 Splash, Onboarding, MainTab, Learn, Lesson, Review,
│                           Profile, Settings, CourseSelection, WordList, Paywall, ThemeChange
├── CustomUI/               BaseApp components + FilledButtonStyle, OptionButtonStyle, LanguageBadge…
└── Resources/
    ├── Content/            course_{en,zh,ja,ko,es}.json
    ├── Languages/          lang_{en,vi,cn}.json (UI strings)
    ├── Animation/          Lottie
    └── Font/               Nunito
```

### Adding course content

Edit `Resources/Content/course_xx.json` and **bump `version`**. On the next launch, `ContentImporter` updates the text by `id` while keeping the learner's progress and SRS schedule. Item `id`s must stay stable and must never change.

```json
{ "id": "ja-0007", "term": "はい", "reading": "hai",
  "meaning": { "en": "yes", "vi": "vâng / có", "zh": "是" },
  "example": "…", "exampleMeaning": { "en": "…" } }
```

### Adding UI strings

Add a **lowercase** key to all three files `lang_en.json`, `lang_vi.json` and `lang_cn.json`, then use `"key".localized()` or `"key".localizedFormat(n)` (with `%ld` placeholders).

## Monetization (App Store)

- **Freemium + "Plus" subscription**, similar to Duolingo:
  - Free: 5 hearts (1 heart refills every 30 minutes), up to 20 cards per review session
  - Plus: unlimited hearts and reviews, early access to new courses
- Product IDs (create them in App Store Connect as auto-renewable subscriptions in one subscription group):
  - `com.haonguyen.app.LanguageApp.plus.monthly`
  - `com.haonguyen.app.LanguageApp.plus.yearly` (a 7-day free trial is recommended)
- Local testing: File ▸ New ▸ **StoreKit Configuration File**, add the two products above, then select the file in Scheme ▸ Run ▸ Options ▸ StoreKit Configuration.

## Roadmap

**Phase 1 (MVP, current):** offline lessons, SRS, gamification, paywall.

**Phase 2:**
- iCloud sync: enable the iCloud + CloudKit capability and switch to `cloudKitDatabase: .automatic`
- Sign in with Apple (when leaderboards/friends are needed)
- Download courses from a server/CDN (reuse `ContentImporter.importCourse(from:)`)
- Native-speaker audio instead of TTS

**Phase 3:**
- Weekly leaderboards (leagues), streak freeze, daily quests
- Typing/speaking exercises (Speech framework), writing practice for Hanzi/Kana/Hangul
- Streak widget, Live Activity, Apple Watch review reminders
- AI conversation practice

## Technical notes

- **Icons:** every icon in the app is an **SF Symbol** (`Image(systemName:)`); there are no image icons in Assets. Lesson icons are SF Symbol names declared in the course JSON (`icon` field). Languages are shown with `LanguageBadge` (a colored circle with "EN", "中", "あ", "한", "ES") instead of flag emoji, because flag emoji can render as "?" boxes. The launch screen uses a background color only.
- **Buttons:** primary actions use the flat `FilledButtonStyle` (`.filled(color)`); answer and choice cards use `OptionButtonStyle(state:)`; secondary actions use `TextButtonStyle`. Lesson nodes on the Learn path are simple flat circles.
- **Navigation:** pushed screens use the system back button (tinted with the primary color) and support swipe-back. `NavRouter` keeps its internal stack in sync when the system pops `path`.
- **Tab bar:** the main screen uses a custom container (`ZStack`) plus a custom tab bar instead of `TabView`, so the system tab bar never shows placeholder icons on iOS 26.
- The project was originally created as a **macOS app** and was converted to iOS (`SDKROOT = iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, iPhone only).
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (the Xcode 26 default), so every type runs on the main actor. Unit tests are marked `@MainActor`.
- SwiftData models don't use `@Attribute(.unique)`, every property has a default value, and all relationships are optional, as required by CloudKit.
