# WineMind

A native iOS app for wine lovers — photograph any wine label, get a verdict on whether you'll love it, and discover similar wines from a private community of ratings.

![Mockup preview](mockup.html)

## Features

- **Scan & recognize** wine labels using Apple Vision (on-device OCR, free)
- **Taste quiz** — quick 6-question calibration before your first scan
- **Verdict predictions** — get a word ("You'll Love This", "Probably Skip") before tasting
- **Rate & remember** every bottle with score, notes, and photo
- **CloudKit sync** — your cellar follows you across devices
- **Collaborative recommendations** — anonymized community ratings power suggestions
- **Dark wine cellar UI** — burgundy, gold, and serif fonts throughout

## Tech stack

- SwiftUI + SwiftData (iOS 17+)
- Apple Vision (wine label OCR)
- Apple NaturalLanguage (tasting notes similarity)
- CloudKit (private + public databases)
- Sign in with Apple

## Project structure

```
.
├── codemagic.yaml          # Codemagic CI/CD config (cloud builds)
├── .github/workflows/      # GitHub Actions CI config (alternative)
├── project.yml             # XcodeGen project definition
├── mockup.html             # HTML visual mockup of all screens
└── WineMind/               # Source code
    ├── WineMindApp.swift
    ├── Info.plist
    ├── WineMind.entitlements
    ├── Assets.xcassets/
    ├── Models/
    ├── Services/
    ├── Theme/
    └── Views/
```

The `.xcodeproj` is **not** committed — it's generated from `project.yml` by XcodeGen.

## Building

### Without a Mac (recommended for you)

This repo is set up for cloud builds. You have two options:

#### Option A — Codemagic (easiest)

1. Sign up at [codemagic.io](https://codemagic.io) (free tier: 500 minutes/month)
2. Connect this GitHub repo
3. Configure your **Apple Developer account** in Codemagic UI → Teams → Integrations
4. Push to `main` — Codemagic runs `codemagic.yaml` automatically
5. Get a TestFlight link in ~10 minutes
6. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) on your iPhone, scan the QR code, app runs

#### Option B — GitHub Actions

1. Push to `main` — `.github/workflows/ios.yml` runs automatically
2. Download the unsigned `.ipa` from the Actions tab
3. For signed/TestFlight builds, add these secrets in repo Settings → Secrets:
   - `APPLE_ID`
   - `APP_STORE_CONNECT_API_KEY` (base64 of the .p8 file)
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`

### With a Mac

```bash
brew install xcodegen
xcodegen generate
open WineMind.xcodeproj
```

## Requirements (mandatory)

- **Apple Developer Program**: $99/year — required for any iOS distribution
- iCloud container `iCloud.com.winemind.app` (created automatically when you first build with Sign in with Apple + CloudKit capability)
- An iPhone for testing (or use simulator on cloud Mac)

## How recommendations work

1. **Quiz** — seeds a `TasteProfile` (preferred colors, body, sweetness, varieties, regions)
2. **As you rate wines** — quiz weight tapers down, your actual ratings dominate
3. **CloudKit public DB** — your ratings (anonymized via hash) help recommend wines to similar-taste users
4. **Verdict** — for each scanned wine, signals combine into a word: *You'll Love This*, *Right Up Your Alley*, *Worth a Try*, *Probably Skip*, etc.

## License

Personal project — no license yet.
