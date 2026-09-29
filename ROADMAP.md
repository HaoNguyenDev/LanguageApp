# LinguaPath – Product Roadmap

iOS language-learning app (SwiftUI + SwiftData, iOS 17+) for **Vietnamese, English, Chinese, Japanese, Korean and Spanish**, combining Duolingo-style gamified lessons with Anki-style spaced-repetition reviews.

_Last updated: 2026-09-29_

## Overview

| Version | Theme | Status | Branches |
|---|---|---|---|
| **1.0.0** | MVP – offline learning, SRS, gamification, Plus subscription | 🟡 In progress | `feature/app-scaffold` (merged), `fix/translation-review`, `release/1.0.0` |
| **1.1.0** | Sync & accounts | ⚪ Planned | `feature/icloud-sync`, `feature/sign-in-with-apple` |
| **1.2.0** | Content & audio | ⚪ Planned | `feature/remote-content`, `feature/native-audio`, `feature/more-units` |
| **2.0.0** | Social & engagement | ⚪ Planned | `feature/leaderboard`, `feature/streak-freeze`, `feature/daily-quests` |
| **2.x** | Skills & platforms | ⚪ Idea | `feature/speaking`, `feature/writing`, `feature/widgets`, `feature/ai-conversation` |

Legend: ✅ done · 🟡 in progress · ⚪ planned

---

## Phase 1 – MVP (v1.0.0)

**Goal:** a complete offline learning loop that can be submitted to the App Store.

### Done ✅
- [x] Xcode project converted from macOS to iOS 17 (iPhone), Lottie via SPM
- [x] Architecture ported from `SwiftUI-BaseApp` (Coordinator + `NavRouter`, `@Observable` managers, Theme)
- [x] SwiftData models (CloudKit-ready) + `ContentImporter` (upsert by id, keeps progress)
- [x] 6 courses × 2 units × 2 lessons × 6 words (144 words), meanings in 6 languages
- [x] Onboarding: app language → language to learn → daily goal → reminder
- [x] Learn path, lessons (intro, choose meaning/word, listen, match pairs), hearts, XP, streak
- [x] SRS flashcard review (SM-2), word list with memory strength
- [x] Profile (daily goal, stats, weekly chart, achievements), Settings
- [x] StoreKit 2 paywall "LinguaPath Plus"
- [x] UI localized in the same 6 languages, English fallback
- [x] SF Symbols only, `LanguageBadge`, flat button styles, custom tab bar, system back button
- [x] Unit tests + README

### To do before release 🟡
- [ ] First full build & run on iOS 17 and iOS 26 simulators, fix compile/runtime issues
- [ ] Run all unit tests (`⌘U`) and fix failures
- [ ] Test on a real iPhone (TTS voices, notifications, haptics)
- [ ] `fix/translation-review` – native-speaker review of ja / ko / es UI strings and course meanings
- [ ] Final app name (currently "LinguaPath" placeholder) and App Store icon (1024×1024)
- [ ] Create subscription products in App Store Connect (`…plus.monthly`, `…plus.yearly`), test with a StoreKit configuration file
- [ ] Privacy policy & terms of use URLs (required for subscriptions)
- [ ] App Store metadata in 6 languages: name, subtitle, description, keywords, screenshots
- [ ] TestFlight beta with a few learners per language
- [ ] `release/1.0.0` → merge into `main`, tag `v1.0.0`, submit for review

---

## Phase 2 – Sync, accounts & content (v1.1.0 – v1.2.0)

### v1.1.0 – Sync & accounts
- [ ] `feature/icloud-sync` – enable iCloud + CloudKit capability, switch to `cloudKitDatabase: .automatic`, handle merge of progress across devices
- [ ] `feature/sign-in-with-apple` – optional account (needed later for leaderboards / friends)
- [ ] Move `DailyActivity`, hearts and settings that should sync into SwiftData / iCloud key-value store

### v1.2.0 – Content & audio
- [ ] `feature/remote-content` – download courses from a server/CDN via `ContentImporter.importCourse(from:)`, versioned updates without an App Store release
- [ ] `feature/more-units` – grow each course to ~10 units (travel, shopping, time & dates, work, directions…)
- [ ] `feature/native-audio` – recorded native-speaker audio, fall back to TTS
- [x] Content tooling: Google Sheet → course JSON generator with validation (`Tools/content/build_courses.py`)

---

## Phase 3 – Engagement & social (v2.0.0)

- [ ] `feature/leaderboard` – weekly leagues (requires accounts + backend)
- [ ] `feature/streak-freeze` – protect the streak for a missed day (earned or bought)
- [ ] `feature/daily-quests` – small daily challenges with XP rewards
- [ ] Friends & sharing achievements
- [ ] Smarter notifications (remind at the user's usual study time, streak-at-risk alerts)

---

## Phase 4 – Skills & platforms (v2.x)

- [ ] `feature/speaking` – pronunciation practice with the Speech framework
- [ ] Typing exercises (translate the sentence)
- [ ] `feature/writing` – stroke practice for Hanzi / Kana / Hangul
- [ ] `feature/widgets` – streak & daily-goal widgets, Live Activity during a lesson
- [ ] Apple Watch: review reminders and quick flashcards
- [ ] iPad layout
- [ ] `feature/ai-conversation` – role-play conversations with AI feedback (Plus feature)

---

## Monetization plan

| Tier | Includes |
|---|---|
| Free | All courses, 5 hearts (refill 1 every 30 min), up to 20 cards per review session |
| Plus (monthly / yearly, 7-day trial) | Unlimited hearts & reviews, early access to new courses; later: offline audio packs, AI conversation |

## Success metrics

- Day-1 / Day-7 / Day-30 retention
- Average streak length and % of users hitting the daily goal
- Lessons and review cards per active user per day
- Free → Plus conversion rate and trial → paid rate

## Git workflow

```
main                    ← released versions, tagged v1.0.0, v1.1.0…
└── develop             ← integration branch, always builds
    ├── feature/…       ← one branch per feature, PR into develop
    ├── fix/…           ← bug fixes during development
    └── release/x.y.z   ← release preparation (version bump, last fixes, metadata)
hotfix/x.y.z            ← from main after a release, merged into main and develop
```
