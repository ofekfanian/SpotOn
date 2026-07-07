<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/assets/logo-light.png">
  <img src="docs/assets/logo-light.png" alt="SpotOn logo" width="200">
</picture>

<br>
<br>

# SpotOn

### *Master English, One Word at a Time*

<br>

An elegant English vocabulary companion for Hebrew speakers.
Capture words from real life, practice them in five game modes,
and talk them through with an AI tutor.

<br>

![Swift](https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative_UI-0071E3?logo=apple&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth_·_Firestore_·_RTDB-FFCA28?logo=firebase&logoColor=black)
![Gemini](https://img.shields.io/badge/Gemini_1.5_Flash-AI_Tutor_·_Vision_·_Enrichment-4285F4?logo=google&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-Local_Persistence-8E44AD)
![MVVM](https://img.shields.io/badge/Architecture-MVVM-2ECC71)

</div>

<br>

---

## Overview

You hear a new English word in a meeting, a series, or on the street.
**SpotOn turns that moment into lasting vocabulary.** Save the word with its
context, let AI enrich it with a definition, part of speech and real usage
examples, then lock it in through fast, beautiful practice games. Fully
bilingual, English and Hebrew.

<br>

## Features

| Feature | Description |
|---|---|
| **Personal Word Bank** | Save words with context, tags, level and Hebrew translation. Synced to the cloud, searchable, paginated |
| **AI Enrichment** | Every saved word is automatically enriched by Gemini: definition, part of speech, and business, casual and tech example sentences |
| **Reading Pathways** | Leveled reading passages with tappable vocabulary, glassmorphism word popups, text to speech and comprehension quizzes |
| **60 Second Blitz** | Race the clock. Swipe and tap through your words before time runs out |
| **Flashcards** | Flip between English and Hebrew. Study your own bank or curated level packs |
| **Sentence Completion** | Fill in the blank, then see the full Hebrew translation |
| **Snap and Learn** | Point your camera at anything and Gemini Vision names it in English and Hebrew |
| **AI English Tutor** | Chat or hold a live voice call with a Gemini powered tutor that gently corrects your mistakes |
| **Friends and Leaderboard** | Invite friends with a six character code and compete on XP, streaks and word counts |
| **Streaks and Reminders** | Daily streak tracking and a configurable practice reminder |
| **Full Dark Mode** | The entire Crystal design system adapts, including the app icon and splash screen |
| **Home Screen Widget** | Idiom of the Day, straight on your home screen |

<br>

## Gamification

Every activity feeds one XP economy, synced live via Firebase Realtime Database.

| Action | Reward |
|---|:---:|
| Add a word, manually or with the camera | +10 XP |
| Blitz, per correct answer | +5 XP |
| Sentence Completion, per correct answer | +5 XP |
| Reading quiz, per correct answer, first completion | +5 XP |
| Daily practice | Streak +1 |

<br>

## Architecture

Clean **MVVM** with SwiftUI, structured concurrency with async await, and a
strict service layer.

```
SpotOn/
├── Models/          Word · ReadingPassage · UserProfile · Idiom · ChatMessage
├── ViewModels/      Auth · WordBank · Blitz · Chat · VoiceCall · ReadingPathway
├── Views/           Dashboard · WordBank · Learn Hub · Reading · Settings
├── Services/        Firestore · RealtimeDatabase · LLMEnrichment · Vision
│                    Speech · SpeechRecognizer · Friends · Notifications
├── Extensions/      CrystalTheme (design system) · helpers
└── Resources/       passages.json · sentences.json · vocabulary.json
```

**Data layer**

| Store | Role |
|---|---|
| Firestore | Word bank, user profiles, idioms, friends |
| Realtime Database | XP and streaks, with atomic server side increments |
| SwiftData | Reading passages and per word progress, seeded on first launch |
| Gemini 1.5 Flash | Tutor chat, voice call replies, image recognition, word enrichment |

<br>

## Getting Started

**Requirements:** Xcode 16 or newer, iOS 17 or newer

```bash
git clone https://github.com/ofekfanian/SpotOn.git
cd SpotOn
```

**Step 1 · Gemini API key**

```bash
cp SpotOn/Config/APIKeys.example.xcconfig SpotOn/Config/APIKeys.xcconfig
```

Paste your key from [Google AI Studio](https://aistudio.google.com/apikey) into
`APIKeys.xcconfig`. The file is gitignored, so your key never leaves your machine.

**Step 2 · Firebase**

Add your own `GoogleService-Info.plist` from the
[Firebase console](https://console.firebase.google.com) to the `SpotOn/` folder,
with Auth (Email and Password), Firestore and Realtime Database enabled.

**Step 3 · Run**

Open `SpotOn.xcodeproj`, select the **SpotOn** scheme, and press **⌘R**.

<br>

## The Crystal Design System

A single design language across every screen, defined in
[`CrystalTheme.swift`](SpotOn/Extensions/CrystalTheme.swift).

| Element | Detail |
|---|---|
| Crystal palette | crystalBlue, crystalMint and crystalGold gradients |
| Glassmorphism | Ultra thin material cards with gradient stroke borders |
| Scattered letters | A subtle alphabet backdrop on every screen |
| Adaptive | Every component ships with light and dark variants |

<br>

---

<div align="center">

<sub>Built with SwiftUI and Firebase · iOS course final project</sub>

<sub>© 2026 SpotOn · Ofek Fanian</sub>

</div>
