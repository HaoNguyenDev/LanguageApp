# LinguaPath – Product Roadmap

iOS language-learning app (SwiftUI + SwiftData, iOS 17+) for **Vietnamese, English, Chinese, Japanese, Korean and Spanish**, combining Duolingo-style gamified lessons with Anki-style spaced-repetition reviews.

**Direction:** make the app complete and worth using every day *before* publishing. App Store work is grouped into the release milestone (v1.0.0).

_Last updated: 2026-10-03_

## Overview

| Version | Theme | Status | Branches |
|---|---|---|---|
| **0.8** | MVP foundation | ✅ Done | `feature/app-scaffold`, `feature/content-tooling` (merged) |
| **0.9** | Stabilize | ✅ Done | `fix/first-build`, `fix/translation-review` |
| **0.10** | Content | ✅ Done | `feature/more-units`, `feature/more-words` |
| **0.11** | New exercise types | ✅ Done | `feature/sentence-builder`, `feature/typing-exercise`, `feature/fill-in-blank`, `feature/practice-mistakes` |
| **0.12** | Engagement | ✅ Done | `feature/streak-freeze`, `feature/daily-quests`, `feature/unit-checkpoint`, `feature/smart-notifications` |
| **0.13** | Polish | 🟡 Next | `feature/native-audio`, `feature/accessibility` |
| **1.0.0** | Release on the App Store | ⚪ Planned | `release/1.0.0` |
| **1.1.0** | Sync & accounts | ⚪ Planned | `feature/icloud-sync`, `feature/sign-in-with-apple` |
| **1.2.0** | Remote content | ✅ Done early | `feature/remote-content` |
| **2.x** | Social, skills & platforms | ⚪ Idea | `feature/leaderboard`, `feature/speaking`, `feature/writing`, `feature/widgets`, `feature/ai-conversation` |

Legend: ✅ done · 🟡 in progress / next · ⚪ planned

---

## ✅ v0.8 – MVP foundation (done)

- [x] Xcode project converted from macOS to iOS 17 (iPhone), Lottie via SPM
- [x] Architecture ported from `SwiftUI-BaseApp` (Coordinator + `NavRouter`, `@Observable` managers, Theme)
- [x] SwiftData models (CloudKit-ready) + `ContentImporter` (upsert by id, keeps progress, prunes removed content)
- [x] 6 courses × 2 units × 2 lessons × 6 words (144 words), meanings in 6 languages
- [x] Onboarding: app language → language to learn → daily goal → reminder
- [x] Learn path, lessons (intro, choose meaning/word, listen, match pairs), hearts, XP, streak
- [x] SRS flashcard review (SM-2), word list with memory strength
- [x] Profile (daily goal, stats, weekly chart, achievements), Settings
- [x] StoreKit 2 paywall "LinguaPath Plus"
- [x] UI localized in the same 6 languages, English fallback
- [x] SF Symbols only, `LanguageBadge`, flat button styles, custom tab bar, system back button
- [x] Content tooling: Google Sheet → course JSON with validation (`Tools/content/build_courses.py`)
- [x] Unit tests, README, roadmap

## ✅ v0.9 – Stabilize (done)

**Goal:** the app builds, every test passes, and one full learning loop works on a real iPhone.

- [x] First full build on iOS 17 and iOS 26 simulators, fix compile/runtime issues
- [x] Fix failing unit test `testCorrectAnswerFlow`, run all tests (`⌘U`)
- [x] Manual pass: onboarding → lesson (right/wrong/match) → result → review → profile → settings
- [x] Fix blank screen after onboarding (routes appended to `NavigationPath` as `AnyHashable`)
- [x] Test on a real iPhone: TTS voices for 6 languages, notifications, haptics, silent mode
- [x] `fix/translation-review` – first-pass review of ja / ko / es UI strings (native-speaker review moved to v1.0.0)
- [x] Add `.DS_Store` to `.gitignore`
- [x] Warn when the app language and the language being learned are the same (course picker + app language in Settings)

## ✅ Developer tools (done)

- [x] Debug / Release environments: "LinguaPath Dev" app name, Settings ▸ Developer menu in Debug only
- [x] Developer switches: unlock all lessons, unlimited hearts, force Free / Plus, force question type, skip intro / match, short lessons, show answers
- [x] Developer actions: complete unit / all lessons, make words due, mark words weak, add XP, build streak, replay onboarding
- [x] Local StoreKit configuration (`LinguaPath.storekit`) used by the Run scheme – buy / restore Plus in the simulator
- [x] CI: GitHub Actions builds the app and runs the unit tests on every PR into `develop` / `main` (`.github/workflows/ci.yml`)
- [ ] Require the CI check ("Build & unit tests") in the `develop` ruleset

## ✅ Learning experience improvements (done, Oct 2026)

- [x] Lesson tips: a rule of the language on a card before the lesson (used by the Numbers lesson)
- [x] Slower tortoise playback (25 % speed); listen to example sentences (normal + slow)
- [x] Speaker button on each word option in "Select the correct word" and "Fill in the blank"
- [x] Typing exercises open the keyboard of the language being learned (hint to add it when it isn't installed)
- [x] iOS 26 glass tab bar (material fallback on iOS 17–18)
- [x] Fixes: course picker navigation, Swift 6 concurrency warnings, launch hang while importing content

## ✅ v0.10 – Content (done)

**Goal:** enough content to learn for weeks, not minutes.

- [x] Plan the curriculum: 10 units per course (greetings, family, numbers & time, food, shopping, travel & directions, work, hobbies, weather, health)
- [x] Units 3–10 added, 3–4 lessons per unit (39 lessons, 235 words per course)
- [x] ~20–30 words per unit, 4–8 words per lesson – 41 new words (ids 0236–0276): 24–28 per unit, 7–8 per lesson, 276 words per course
- [x] Example sentence for every word (all 6 languages), split into chunks (`tokens_xx`, required for zh / ja) for the sentence builder
- [x] Automated reading check: Pinyin (pypinyin), kana / Romaji (pykakasi), Korean Revised Romanization (korean-romanizer), IPA present for every English word – all differences reviewed, one fix (할인 `halin` → `harin`)
- [x] Meanings and example sentences → native-speaker review in v1.0.0
- [x] Numbers rebuilt as one lesson: all of 0–10, then 11, 15, 20, 21, 45, 99, 100, 300, 1,000, 10,000 (new ids 0277, 0280, 0283, 0286–0288, 0290), with a **lesson tip** explaining how numbers are said and built in that language (new optional `tips` tab → tip card before the lesson)
- [x] Word ids kept stable (new words appended); `build_courses.py --check` passes with no errors

## ✅ v0.11 – New exercise types (done)

**Goal:** varied practice beyond multiple choice.

- [x] Sentence builder – tap words in the right order (uses example sentences)
- [x] Typing – listen and type / translate and type (with lenient matching for accents and kana)
- [x] Fill in the blank – choose the missing word in an example sentence
- [x] Practice mistakes – a lesson built from the learner's weakest / most-missed words
- [x] Exercise mix tuned by difficulty (new lesson vs. replay)

## ✅ v0.12 – Engagement (done)

**Goal:** reasons to come back every day.

- [x] Streak freeze – protect the streak for a missed day (50 XP each, hold up to 2; Plus always fully equipped), streak sheet with the last 7 days
- [x] Daily quests – 3 a day (earn the daily goal + two of: complete 2 lessons, review 15 cards, perfect lesson) with automatic XP rewards
- [x] Unit checkpoint – a short test at the end of each unit (10 words, ≥ 80 % to pass, unlocks the next unit)
- [x] Smart notifications – streak at risk (21:00), cards due, reminder at the learner's usual time (planned 7 days ahead, re-planned when the app opens / closes)
- [x] More achievements (15, kept once unlocked, with progress) and a celebration (confetti) when a unit is completed

## ⚪ v0.13 – Polish

- [ ] Native-speaker audio for words (fallback to TTS); pick the best installed TTS voice
- [ ] Animations and transitions (lesson start/finish, unit complete)
- [ ] Dynamic Type and VoiceOver support
- [ ] Performance check with the full content set (import time, SwiftData queries) – launch import no longer blocks the splash; SwiftData queries still to check
- [ ] iPad layout (optional)

## ⚪ v1.0.0 – Release on the App Store

- [ ] Final app name (currently "LinguaPath" placeholder) and App Store icon (1024×1024)
- [ ] Subscription products in App Store Connect (`…plus.monthly`, `…plus.yearly`) – the local StoreKit configuration file already exists
- [ ] Privacy policy & terms of use URLs (required for subscriptions)
- [ ] App Store metadata in 6 languages: name, subtitle, description, keywords, screenshots
- [ ] Native-speaker review of ja / ko / es / zh UI strings, course meanings and example sentences
- [ ] "Beta" build configuration + scheme for TestFlight: Release optimizations with `DEVELOPER_MENU` on
- [ ] TestFlight beta with a few learners per language
- [ ] `release/1.0.0` → merge into `main`, tag `v1.0.0`, submit for review

---

## After release

### v1.1.0 – Sync & accounts
- [ ] `feature/icloud-sync` – enable iCloud + CloudKit, switch to `cloudKitDatabase: .automatic`, merge progress across devices
- [ ] `feature/sign-in-with-apple` – optional account (needed for leaderboards / friends)
- [ ] Sync `DailyActivity`, hearts and settings

### v1.2.0 – Remote content
- [x] `feature/remote-content` – done early (Oct 2026): Google Sheet → *Publish content* workflow → GitHub Pages (`LanguageApp-content`, staging / production) → app downloads newer courses on launch and imports them keeping progress

### v2.x – Social, skills & platforms
- [ ] `feature/leaderboard` – weekly leagues (requires accounts + backend), friends, sharing achievements
- [ ] `feature/speaking` – pronunciation practice with the Speech framework
- [ ] `feature/writing` – stroke practice for Hanzi / Kana / Hangul
- [ ] `feature/widgets` – streak & daily-goal widgets, Live Activity, Apple Watch reminders
- [ ] `feature/ai-conversation` – role-play conversations with AI feedback (Plus feature)

---

## Monetization plan

| Tier | Includes |
|---|---|
| Free | All courses, 5 hearts (refill 1 every 30 min), up to 20 cards per review session |
| Plus (monthly / yearly, 7-day trial) | Unlimited hearts & reviews, unlimited streak freezes, early access to new courses; later: offline audio packs, AI conversation |

## Success metrics

- Day-1 / Day-7 / Day-30 retention
- Average streak length and % of users hitting the daily goal
- Lessons and review cards per active user per day
- Free → Plus conversion rate and trial → paid rate

## Git workflow

```
main                    ← released versions, tagged v1.0.0, v1.1.0…
└── develop             ← integration branch, always builds
    ├── feature/…       ← one branch per feature, created from develop when work starts, PR into develop
    ├── fix/…           ← bug fixes during development
    └── release/x.y.z   ← release preparation (version bump, last fixes, metadata)
hotfix/x.y.z            ← from main after a release, merged into main and develop
```

Create a branch when work on it starts (`git feature <name>`), so it starts from the latest `develop`.
