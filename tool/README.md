# Google Play Release Automation Tool (Driver App)

An automated, native Dart release script for **AMN Driver** (`com.amn.driver`) that:
1. **Increments version/build numbers** in `pubspec.yaml`.
2. **Builds a signed release Android App Bundle (`.aab`)** via `flutter build appbundle --release`.
3. **Uploads and commits the release** to Google Play Console (Internal, Closed, or Production track) via the Google Play Android Developer API.

---

## Quick Start

### 1. Service Account JSON Key
Your Google Cloud Service Account JSON key is located at:
```text
android/play-service-account.json
```
*(This path is already configured in `.gitignore` so your private key will never be committed to version control).*

### 2. Test with a Dry Run
Simulates the entire workflow without touching `pubspec.yaml` or uploading:
```powershell
dart run tool/release.dart --dry-run
```

### 3. Deploy to Google Play (Internal Testing Track)
Builds, signs, increments build number, and uploads to the Internal track:
```powershell
dart run tool/release.dart
```

---

## Common Release Commands

| Goal | Command |
|---|---|
| **Standard build bump to Internal track** (e.g. `1.0.0+1` $\rightarrow$ `1.0.0+2`) | `dart run tool/release.dart` |
| **Patch release to Production** (e.g. `1.0.0+1` $\rightarrow$ `1.0.1+2`) | `dart run tool/release.dart --bump=patch --track=production` |
| **Minor release with release notes** (e.g. `1.0.0+1` $\rightarrow$ `1.1.0+2`) | `dart run tool/release.dart --bump=minor --notes="Driver live routing & delivery flow updates"` |
| **Dry run** (simulates everything without touching files or uploading) | `dart run tool/release.dart --dry-run` |
| **Only build & increment version** (skip upload) | `dart run tool/release.dart --skip-upload` |
| **Upload existing `.aab`** (skip rebuild) | `dart run tool/release.dart --skip-build` |
| **Upload as draft** | `dart run tool/release.dart --draft` |

---

## CLI Options Reference

| Flag | Default | Description |
|---|---|---|
| `--track=<name>` | `internal` | Target track: `internal`, `alpha`, `beta`, or `production` |
| `--bump=<type>` | `build` | Version bump type: `build`, `patch`, `minor`, `major`, or `none` |
| `--version=<x.y.z+n>` | *(auto)* | Specify an exact version string (e.g. `--version=1.2.0+15`) |
| `--notes="<text>"` | `'Bug fixes...'` | Release notes displayed in Play Console |
| `--key=<path>` | *(auto)* | Custom path to the Service Account JSON key |
| `--package-name=<id>` | *(auto)* | Override package name (auto-detected from `build.gradle.kts`: `com.amn.driver`) |
| `--dry-run` | `false` | Run simulation without modifying `pubspec.yaml` or uploading |
| `--skip-build` | `false` | Upload existing `.aab` without running `flutter build` |
| `--skip-upload` | `false` | Bump version and build `.aab` without uploading |
| `--draft` | `false` | Create a draft release in Play Console instead of publishing |
| `-h, --help` | - | Display help menu |

---

## Signing Configuration

App signing is configured in `android/app/build.gradle.kts`:
* **Keystore**: `android/app/upload-keystore.jks`
* **Keystore credentials**: `android/key.properties` (protected by `.gitignore`)

When `dart run tool/release.dart` runs, it executes `flutter build appbundle --release`, which Gradle signs using this configuration before upload.

---

## Troubleshooting & Notes

> [!NOTE]
> **Track Status**:
> - `internal`: Internal testing track (fastest distribution, recommended for staging and QA).
> - `alpha` / `closed`: Closed testing track.
> - `beta` / `open`: Open testing track.
> - `production`: Public Google Play release.

> [!TIP]
> **Draft Releases**:
> If you want to inspect the release in the Google Play Console UI before rolling it out to users, pass the `--draft` flag:
> ```powershell
> dart run tool/release.dart --draft
> ```
