# AMN Driver — Release Automation Tools

Unified automated release suite for **AMN Driver** (`com.amn.driver` / `com.amn.driverApp`):
- **Android**: Automated build, version bump, and upload to Google Play Console via the Android Publisher API.
- **iOS**: Automated cloud build, TestFlight deployment, and App Store Review submission via GitHub Actions and App Store Connect API.

---

## Quick Navigation

- [1. Android (Google Play Release)](#1-android-google-play-release)
- [2. iOS (TestFlight & App Store Review Release)](#2-ios-testflight--app-store-review-release)
- [3. Full iOS Architecture & Submitter Docs](file:///c:/flutter_dev/projects/driver_app/tool/IOS_RELEASE_AND_REVIEW.md)

---

## 1. Android (Google Play Release)

Native Dart release tool (`tool/release.dart`) that increments version numbers, builds the signed `.aab`, and uploads to Google Play Console.

### Service Account Key
Your Google Cloud Service Account JSON key is located at:
```text
android/play-service-account.json
```
*(Protected by `.gitignore`).*

### Common Android Commands
| Goal | Command |
|---|---|
| **Standard build bump to Internal track** | `dart run tool/release.dart` |
| **Patch release to Production track** | `dart run tool/release.dart --bump=patch --track=production` |
| **Release current version to Production** | `dart run tool/release.dart --bump=none --track=production --notes="Bug fixes and optimizations"` |
| **Dry run** (preview without building/uploading) | `dart run tool/release.dart --dry-run` |
| **Skip build** (upload existing `.aab`) | `dart run tool/release.dart --skip-build` |

---

## 2. iOS (TestFlight & App Store Review Release)

Dual-stage cloud automation that builds and submits your iOS app to TestFlight and Apple App Store Review from Windows without local macOS hardware.

### Stage 1: Build & Upload to TestFlight (`ios_release.yml`)
Runs on GitHub Actions macOS runner, signs with distribution profile, and uploads the `.ipa` to App Store Connect.
```powershell
# Bump patch and trigger cloud build + TestFlight upload
dart run tool/release_ios.dart --bump=patch

# Trigger current version without bumping
dart run tool/release_ios.dart --bump=none

# Trigger without streaming logs
dart run tool/release_ios.dart --bump=none --no-watch
```

### Stage 2: Independent Review Submitter (`ios_submit_review.yml`)
Runs on GitHub Actions `ubuntu-latest` (fast, free, unlimited minutes for public repos).
- **Automatic**: Triggers automatically as soon as Stage 1 completes successfully.
- **Manual**: Can be triggered anytime to submit an existing build without rebuilding:
  ```powershell
  gh workflow run ios_submit_review.yml
  gh workflow run ios_submit_review.yml -f build_number=18 -f version_name=1.0.12
  ```

---

## Detailed Guides
For full iOS architecture diagrams, secret specifications, export compliance settings, and API details, see:
- [IOS_RELEASE_AND_REVIEW.md](file:///c:/flutter_dev/projects/driver_app/tool/IOS_RELEASE_AND_REVIEW.md)
