# Privacy Policy

**Last updated: 2026-06-05**
**Policy version: 1**

## Plain-English summary

WineMind is designed to be private by default. Your wine collection lives in your private iCloud — not on any server we control. The only data ever shared with anyone else is anonymized rating data, and only if you explicitly opt in.

## What data we collect

### On your device (always)

- **Wines you save** — name, winery, variety, region, vintage, your score, your tasting notes, and the photo you take
- **Taste profile** from the one-time calibration quiz
- **Privacy consent choices** (which permissions you've granted)
- **An anonymous contributor UUID** stored in iOS Keychain (only used if you opt into community contributions)

### In your private iCloud (only if you opt into iCloud Sync)

- All of the above. Stored in CloudKit's private database, which is encrypted with your iCloud key. Apple cannot read it. We cannot read it. Only you can.

### In the public community pool (only if you opt into "Contribute Anonymously")

Per rated wine, we publish:

- Wine name, winery, variety, region, vintage
- Your numeric score (1–10)
- Color, body, sweetness
- An opaque, locally-generated anonymous ID

We **never** publish: tasting notes, photos, your name, email, Apple ID, location, device ID, the date you tried the wine, or any identifier that could link the rating to you.

## What we do not collect

- Crash reports
- Analytics events
- Advertising identifiers
- Your location (the app never requests it)
- Your contacts
- Anything outside this app

## Third parties

WineMind communicates only with Apple's iCloud service. We do **not** use Google Analytics, Firebase, Mixpanel, Facebook, Twitter, Stripe, RevenueCat, or any external AI/ML/SDK. The wine label recognition runs entirely on-device using Apple Vision.

## Your GDPR rights

Under EU/UK GDPR (and equivalent regimes in the UK, Switzerland, California, etc.) you have the right to:

| Right | How to exercise it in the app |
|---|---|
| **Access** | Settings → Manage Your Data → Export My Data (downloads a JSON archive of everything we hold about you) |
| **Rectification** | Edit any wine, quiz answer, or consent toggle at any time |
| **Erasure** ("right to be forgotten") | Settings → Manage Your Data → Delete Everything (permanent, instant) |
| **Restrict processing** | Toggle off community contribution in Settings — your data stays only on your device |
| **Portability** | The exported JSON file is machine-readable and standardized |
| **Object** | Decline any optional permission with no impact on app function |
| **Withdraw consent** | Revoke any granular permission at any time in Settings |

## Lawful basis for processing

We rely on **consent** (GDPR Article 6(1)(a)) for all optional data processing. The base app (offline wine tracking) requires no personal data beyond what you voluntarily enter, and uses no third-party processors.

## Data retention

Your data lives on your device until you delete it. There is no server-side retention because there is no server we control. If you opt into community contributions, your anonymous ratings remain in CloudKit's public pool until you delete your account — which removes them too, identified by your local contributor UUID.

## Children

WineMind is intended for users **18 and older** (wine, after all). We do not knowingly collect data from anyone under 18.

## Changes to this policy

When we update this policy, the version number is bumped and the app will require you to re-consent on next launch.

## Contact

For privacy questions or rights requests, email the developer address listed in App Store Connect for this app.

---

*This document is also presented in-app at Settings → Manage Your Data → Read full privacy policy.*
