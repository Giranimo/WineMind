# Security Policy

## Reporting a vulnerability

If you discover a security issue, **do not open a public GitHub issue**. Email the developer at the address listed in App Store Connect for the WineMind app. Include:

- A description of the issue and potential impact
- Steps to reproduce (or a proof-of-concept)
- Your name/handle if you'd like credit in the fix notes

We aim to acknowledge reports within 72 hours and ship a fix as quickly as feasible. Severe issues affecting user data will trigger immediate disclosure to affected users per GDPR Article 33.

## Security posture

### Authentication

- **Sign in with Apple** is the only sign-in mechanism. No passwords are stored. Apple handles all auth.
- The Apple user identifier is stored only in Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) — never sent to our backend (we have no backend).

### Data at rest

- **Local storage**: SwiftData (encrypted by iOS file-system protection while device is locked).
- **Private CloudKit**: end-to-end encrypted via the user's iCloud Keychain. Apple cannot read it.
- **Keychain**: stores the anonymous contributor UUID with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Not shared via iCloud.

### Data in transit

- All CloudKit traffic uses Apple's mandatory TLS 1.3.
- The app makes no other network calls (no analytics, no third-party services).

### Anonymization

- The "contributor ID" used for collaborative recommendations is a **locally generated UUID v4**, not derived from any user identifier. It is impossible to reverse to a user identity.
- Old design (≤ v0.x): used a djb2 non-cryptographic hash of the Apple record name. **Replaced** because non-cryptographic hashes are predictable and could leak structure of the input.

### Photo sanitization

- Wine photos are stripped of **EXIF, GPS, TIFF, and IPTC metadata** before being saved or uploaded. The user is never location-tracked through their photos.

### What is sent to the public CloudKit pool

| Field | Sent? |
|---|---|
| Wine name, winery, variety, region, vintage, color, body, sweetness | Yes |
| Numeric score (1–10) | Yes |
| Anonymous contributor UUID | Yes |
| Tasting notes | **Never** |
| Photo | **Never** |
| Apple ID / email / name | **Never** |
| Device identifier | **Never** |
| Date the user tried the wine | **Never** |
| Location data | **Never** |

### Consent gating

The app enforces consent at the service layer, not just the UI:

- `CloudKitService.saveWine(_:contributeAnonymously:)` requires an explicit boolean — there is no way to accidentally send data to the public DB
- `WineSyncService.restoreIfNeeded(context:allowsCloudSync:)` short-circuits when consent is missing
- `CollaborativeRecommender.refreshRecommendations(from:allowsCommunityRecs:)` returns empty when consent is missing

This means a UI bug cannot leak data — the service refuses.

### Threat model summary

| Threat | Mitigation |
|---|---|
| Stolen device | iOS device passcode + Keychain encryption + iCloud encryption |
| Compromised iCloud account | Apple's iCloud Keychain encryption (we can't access data) |
| Compromised CloudKit public DB | No PII in public DB; contributor IDs are unlinkable UUIDs |
| Photo metadata leak | EXIF/GPS stripped before storage and upload |
| Identity correlation across ratings | Same contributor UUID groups your ratings (necessary for collaborative filtering) but cannot be linked to your identity |
| Network MITM | TLS 1.3 enforced by iOS for all CloudKit traffic |
| Code injection / XSS | Native iOS app, no web views, no user-generated HTML rendered |
| Supply chain attack | Zero third-party dependencies (no SPM packages, no CocoaPods, no Carthage) |

### Known limitations

- **Wine name, winery, variety, region in the public DB are not encrypted**. They're public by design (they're attributes of the wine, not the user). If a user enters personal info into a wine's name field (e.g. "Mom's birthday Bordeaux"), that text will appear in the public DB tied to their anonymous contributor ID. This is a UX risk addressed by the in-app help text reminding users that the wine name is shared.
- **Anonymous contributor UUID is stable per device**. If you contribute many ratings, your set of ratings is grouped under one ID. The ID is unlinkable to identity, but the rating set itself could in theory be fingerprintable if it's unusual enough. Mitigation: users can rotate their contributor ID by deleting + re-creating their account.
- **CloudKit free-tier rate limits** could be abused by a malicious user creating many fake ratings. Apple enforces some rate limits at the CloudKit level. We do not currently have additional abuse detection.

## Dependency policy

WineMind has **zero third-party runtime dependencies**. Every line of runtime code is either ours or Apple's. This is deliberate to minimize supply chain risk.

The build-time tooling we use:

- **XcodeGen** (build only, generates `.xcodeproj` from `project.yml`)
- **GitHub Actions** (CI runner — runs Apple's tooling)
- **Codemagic** (alternative CI — runs Apple's tooling)

## Compliance

- **GDPR** — see [PRIVACY.md](PRIVACY.md). Right to access, erasure, portability, and consent are implemented in-app.
- **App Store Privacy Nutrition Labels** — to be configured before submission. Declared collection types: contact info (Apple ID — for app function only), user content (your wine entries — linked to you), usage data (none), identifiers (none beyond Apple ID).
- **App Tracking Transparency** — not required (we do not track).
- **CCPA** — equivalent rights to GDPR are exposed in-app.

## Audit log

This file documents changes to the security posture.

| Date | Change |
|---|---|
| 2026-06-05 | Initial security policy |
| 2026-06-05 | Replaced djb2 hash with Keychain-backed UUID contributor ID |
| 2026-06-05 | Added EXIF stripping for all photo uploads |
| 2026-06-05 | Added granular consent enforcement at service layer |
| 2026-06-05 | Added in-app data export (JSON) and account deletion |
