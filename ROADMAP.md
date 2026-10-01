# LinguaPath – Product Roadmap

iOS language-learning app (SwiftUI + SwiftData, iOS 17+) for **Vietnamese, English, Chinese, Japanese, Korean and Spanish**, combining Duolingo-style gamified lessons with Anki-style spaced-repetition reviews.

**Direction:** make the app complete and worth using every day *before* publishing. App Store work is grouped into the release milestone (v1.0.0).

_Last updated: 2026-09-30_

## Overview

| Version | Theme | Status | Branches |
|---|---|---|---|
| **0.8** | MVP foundation | ✅ Done | `feature/app-scaffold`, `feature/content-tooling` (merged) |
| **0.9** | Stabilize | 🟡 Next | `fix/first-build`, `fix/translation-review` |
| **0.10** | Content | 🟡 In progress | `feature/more-units` |
| **0.11** | New exercise types | ⚪ Planned | `feature/sentence-builder`, `feature/typing-exercise`, `feature/fill-in-blank`, `feature/practice-mistakes` |
| **0.12** | Engagement | ⚪ Planned | `feature/streak-freeze`, `feature/daily-quests`, `feature/unit-checkpoint`, `feature/smart-notifications` |
| **0.13** | Polish | ⚪ Planned | `feature/native-audio`, `feature/accessibility` |
| **1.0.0** | Release on the App Store | ⚪ Planned | `release/1.0.0` |
| **1.1.0** | Sync & accounts | ⚪ Planned | `feature/icloud-sync`, `feature/sign-in-with-apple` |
| **1.2.0** | Remote content | ⚪ Planned | `feature/remote-content` |
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

## 🟡 v0.9 – Stabilize (next)

**Goal:** the app builds, every test passes, and one full learning loop works on a real iPhone.

- [ ] First full build on iOS 17 and iOS 26 simulators, fix compile/runtime issues
- [x] Fix failing unit test `testCorrectAnswerFlow`, run all tests (`⌘U`)
- [ ] Manual pass: onboarding → lesson (right/wrong/match) → result → review → profile → settings
- [x] Fix blank screen after onboarding (routes appended to `NavigationPath` as `AnyHashable`)
- [ ] Test on a real iPhone: TTS voices for 6 languages, notifications, haptics, silent mode
- [ ] `fix/translation-review` – native-speaker review of ja / ko / es UI strings and course meanings
- [x] Add `.DS_Store` to `.gitignore`
- [x] Warn when the app language and the language being learned are the same (course picker + app language in Settings)

## 🟡 v0.10 – Content (in progress)

**Goal:** enough content to learn for weeks, not minutes.

- [x] Plan the curriculum: 10 units per course (greetings, family, numbers & time, food, shopping, travel & directions, work, hobbies, weather, health)
- [x] Units 3–10 added, 3–4 lessons per unit (39 lessons, 235 words per course)
- [ ] ~20–30 words per unit, 4–8 words per lesson (all edited in the Google Sheet) – currently 18–25 per unit
- [ ] Example sentence for every word (all 6 languages) – currently 1–2 per lesson
- [ ] Review readings (Pinyin, kana/Romaji, Romanization, IPA) and meanings per language
- [ ] Keep word ids stable; run `build_courses.py --check` before every commit

## ⚪ v0.11 – New exercise types

**Goal:** varied practice beyond multiple choice.

- [ ] Sentence builder – tap words in the right order (uses example sentences)
- [ ] Typing – listen and type / translate and type (with lenient matching for accents and kana)
- [ ] Fill in the blank – choose the missing word in an example sentence
- [ ] Practice mistakes – a lesson built from the learner's weakest / most-missed words
- [ ] Exercise mix tuned by difficulty (new lesson vs. replay)

## ⚪ v0.12 – Engagement

**Goal:** reasons to come back every day.

- [ ] Streak freeze – protect the streak for a missed day (earned with XP, unlimited for Plus)
- [ ] Daily quests – e.g. "Finish 2 lessons", "Review 20 cards", with XP rewards
- [ ] Unit checkpoint – a short test at the end of each unit
- [ ] Smart notifications – streak at risk, cards due, reminder at the learner's usual time
- [ ] More achievements and a celebration when a unit is completed

## ⚪ v0.13 – Polish

- [ ] Native-speaker audio for words (fallback to TTS); pick the best installed TTS voice
- [ ] Animations and transitions (lesson start/finish, unit complete)
- [ ] Dynamic Type and VoiceOver support
- [ ] Performance check with the full content set (import time, SwiftData queries)
- [ ] iPad layout (optional)

## ⚪ v1.0.0 – Release on the App Store

- [ ] Final app name (currently "LinguaPath" placeholder) and App Store icon (1024×1024)
- [ ] Subscription products in App Store Connect (`…plus.monthly`, `…plus.yearly`), tested with a StoreKit configuration file
- [ ] Privacy policy & terms of use URLs (required for subscriptions)
- [ ] App Store metadata in 6 languages: name, subtitle, description, keywords, screenshots
- [ ] TestFlight beta with a few learners per language
- [ ] `release/1.0.0` → merge into `main`, tag `v1.0.0`, submit for review

---

## After release

### v1.1.0 – Sync & accounts
- [ ] `feature/icloud-sync` – enable iCloud + CloudKit, switch to `cloudKitDatabase: .automatic`, merge progress across devices
- [ ] `feature/sign-in-with-apple` – optional account (needed for leaderboards / friends)
- [ ] Sync `DailyActivity`, hearts and settings

### v1.2.0 – Remote content
- [ ] `feature/remote-content` – download courses from a server/CDN via `ContentImporter.importCourse(from:)`, update content without an App Store release

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
