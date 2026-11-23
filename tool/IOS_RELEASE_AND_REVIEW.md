# AMN Driver — iOS Cloud Release & App Store Review Automation

Complete guide to building, releasing to TestFlight, and submitting **AMN Driver** (`com.amn.driverApp`) to Apple App Store Review from Windows without local macOS hardware.

---

## Architecture Overview

```
                                      [Windows Dev Machine]
                                                │
                          dart run tool/release_ios.dart [--bump=...]
                                                │
                                                ▼
                                     [GitHub origin/master]
                                                │
                                                ▼
                         ┌──────────────────────────────────────────────┐
                         │ .github/workflows/ios_release.yml (macOS)    │
                         │ 1. Checkout repository & setup Flutter/Java  │
                         │ 2. Install distribution cert & profile       │
                         │ 3. Build release IPA via flutter build ipa   │
                         │ 4. Upload IPA to TestFlight via xcrun altool │
                         └──────────────────────┬───────────────────────┘
                                                │
                                 on success (workflow_run)
                                                │
                                                ▼
                         ┌──────────────────────────────────────────────┐
                         │ .github/workflows/ios_submit_review.yml      │
                         │ (Runs on free, lightweight ubuntu-latest)    │
                         │ 1. Generate App Store Connect JWT token      │
                         │ 2. Poll Apple API until build is VALID       │
                         │ 3. Auto-set export compliance (exempt)       │
                         │ 4. Find or create App Store version          │
                         │ 5. Update "What's New" release notes         │
                         │ 6. Attach build to App Store version         │
                         │ 7. Submit to Apple App Review via API        │
                         └──────────────────────────────────────────────┘
```

---

## 1. Fast Command Reference

All commands run from the root of `driver_app`:

### A. Deploy New iOS Build to TestFlight & Auto-Submit to Review
```powershell
# Bump patch (e.g. 1.0.12+18 -> 1.0.13+19), push to git, and trigger cloud release
dart run tool/release_ios.dart --bump=patch

# Bump build number only (e.g. 1.0.12+18 -> 1.0.12+19)
dart run tool/release_ios.dart --bump=build

# Release current version without bumping
dart run tool/release_ios.dart --bump=none

# Trigger without streaming logs in terminal (returns immediately)
dart run tool/release_ios.dart --bump=none --no-watch

# Preview actions without triggering CI
dart run tool/release_ios.dart --dry-run
```

### B. Manually Trigger Just the Review Submitter (Without Rebuilding)
If you already uploaded an IPA or want to re-submit an existing build to App Review without re-running the 8-minute macOS build:
```powershell
# Auto-detects version & build from pubspec.yaml
gh workflow run ios_submit_review.yml

# Or specify custom build number and release notes:
gh workflow run ios_submit_review.yml -f build_number=18 -f version_name=1.0.12 -f release_notes="Bug fixes and optimizations"
```

### C. Monitor Progress
```powershell
# Watch latest release workflow run
gh run watch

# View recent runs of both workflows
gh run list --workflow=ios_release.yml
gh run list --workflow=ios_submit_review.yml
```

---

## 2. Workflows & Scripts Breakdown

| File | Environment | Role | Trigger |
|:---|:---|:---|:---|
| [`.github/workflows/ios_release.yml`](file:///c:/flutter_dev/projects/driver_app/.github/workflows/ios_release.yml) | `macos-latest` | Archives Flutter IPA, signs with manual distribution profile, and uploads to App Store Connect via `xcrun altool`. | `workflow_dispatch`, Git tags `v*` |
| [`.github/workflows/ios_submit_review.yml`](file:///c:/flutter_dev/projects/driver_app/.github/workflows/ios_submit_review.yml) | `ubuntu-latest` | Runs independent review submitter script. Fast boot, zero minute costs. | Automatically on completion of `iOS TestFlight Release`, or manually via `workflow_dispatch` |
| [`tool/submit_appstore_review.py`](file:///c:/flutter_dev/projects/driver_app/tool/submit_appstore_review.py) | Python 3 | Pure REST client for App Store Connect API. Handles JWT auth, polling build status, export compliance, version creation, and review submission. | Invoked by CI or locally |
| [`tool/release_ios.dart`](file:///c:/flutter_dev/projects/driver_app/tool/release_ios.dart) | Dart CLI | Local Windows CLI tool to bump versions, commit, push, and dispatch the GitHub Actions workflow. | `dart run tool/release_ios.dart` |

---

## 3. Required GitHub Secrets

All required secrets are stored in repository secrets (`https://github.com/DaV212001/driver_app/settings/secrets/actions`):

| Secret Name | Description |
|:---|:---|
| `APPSTORE_KEY_ID` | 10-character Key ID from App Store Connect (Users and Access > Integrations > App Store Connect API). |
| `APPSTORE_ISSUER_ID` | UUID Issuer ID from App Store Connect API page. |
| `APPSTORE_API_KEY_BASE64` | Base64-encoded content of the `.p8` private key file. |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution Certificate (`.p12`). |
| `P12_PASSWORD` | Password protecting the `.p12` certificate file. |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded `AMN_Driver.mobileprovision` distribution profile. |
| `KEYCHAIN_PASSWORD` | Temporary password used to create and lock the ephemeral macOS keychain. |

---

## 4. Export Compliance & Encryption Exemption

By default, Apple flags new builds with **"Missing Export Compliance"** unless explicitly declared.

To ensure automated review submissions never block on manual compliance questions:
1. In [`ios/Runner/Info.plist`](file:///c:/flutter_dev/projects/driver_app/ios/Runner/Info.plist):
   ```xml
   <key>ITSAppUsesNonExemptEncryption</key>
   <false/>
   ```
2. Additionally, [`tool/submit_appstore_review.py`](file:///c:/flutter_dev/projects/driver_app/tool/submit_appstore_review.py) automatically issues a `PATCH /v1/builds/{id}` with `usesNonExemptEncryption: false` during the processing polling phase if Apple has not already marked it exempt.

---

## 5. Troubleshooting & FAQ

### Q: Why is the submitter workflow separate from the build workflow?
**A:** Decoupling provides three major benefits:
1. **Cost & Queue Efficiency**: macOS runners on GitHub are arm64 hardware and take longer to queue. The submitter runs on `ubuntu-latest`, which boots instantly and is 100% free with unlimited minutes on public repositories.
2. **Apple Processing Delay**: Apple takes 5–20 minutes to process an uploaded IPA. Running the polling on Linux frees up the macOS runner immediately after the upload finishes.
3. **Independent Retries**: If Apple's review submission fails due to missing store metadata, you can fix the issue and re-run `gh workflow run ios_submit_review.yml` without rebuilding the entire 8-minute iOS app.

### Q: What if Apple's servers take longer than 30 minutes to process?
The submitter script defaults to a 30-minute timeout (`--max-wait-mins=30`). If Apple experiences severe processing backlog, you can re-run:
```powershell
gh workflow run ios_submit_review.yml -f build_number=<build>
```
once the build reaches `Ready to Submit` in App Store Connect.
