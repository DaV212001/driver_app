# AMN Driver — iOS TestFlight CI/CD & Release Pipeline

This document details the automated iOS release architecture for **AMN Driver** (`com.amn.driverApp`), allowing developers on Windows to build, sign, and upload production `.ipa` binaries directly to **Apple TestFlight / App Store Connect** with a single command.

---

## 1. Architecture Overview

```
 ┌─────────────────────────────────────────────────────────────┐
 │                     Windows Workstation                     │
 │  dart run tool/release_ios.dart --bump=build                │
 └──────────────────────────────┬──────────────────────────────┘
                                │ 1. Git push (pubspec.yaml)
                                │ 2. Trigger gh workflow dispatch
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │            GitHub Actions Cloud (macos-latest)              │
 │                                                             │
 │  1. Decode & Import Apple Distribution Certificate (.p12)   │
 │  2. Install AMN Driver Provisioning Profile (.mobileprovision)
 │  3. Configure App Store Connect API Private Key (.p8)        │
 │  4. Generate dynamic ios/ExportOptions.plist                │
 │  5. Disable SwiftPM & Resolve dependencies via CocoaPods    │
 │  6. Compile, Link & Archive Release IPA                     │
 │  7. Upload to Apple TestFlight via `xcrun altool`           │
 └──────────────────────────────┬──────────────────────────────┘
                                │ 3. Apple Ingestion
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │                Apple App Store Connect                      │
 │  • TestFlight Internal & External Testing Groups            │
 │  • Public App Store Production Review                       │
 └─────────────────────────────────────────────────────────────┘
```

---

## 2. Key Identifiers & Metadata

| Property | Value | Notes |
| :--- | :--- | :--- |
| **App Name** | AMN Driver | Companion driver app for on-demand orders |
| **Bundle ID** | `com.amn.driverApp` | Explicit App ID registered in Apple Developer |
| **Apple Team ID** | `T6N9PJTZS6` | Natnael Chibssa (Company Team ID) |
| **Provisioning Profile Name** | `AMN Driver` | App Store Distribution Profile |
| **Provisioning Profile UUID** | `a01ecc71-66a6-4df9-aa8c-edc9d9a47d50` | Embedded in `AMN_Driver (1).mobileprovision` |
| **Signing Certificate** | `Apple Distribution: Natnael Chibssa (T6N9PJTZS6)` | `.p12` distribution certificate |
| **App Store Connect Key ID**| `VQV5J6AQ78` | App Store Connect API Key |
| **App Store Connect Issuer** | `db70cb7b-56b1-4a06-b8ea-1c3fea1448dc` | Organization API Issuer ID |
| **Minimum iOS Target** | `15.6` | Configured for MapLibre vector tiles & Firebase |

---

## 3. GitHub Repository Secrets

Configure these secrets in the GitHub repository (`https://github.com/DaV212001/driver_app/settings/secrets/actions`):

| Secret Name | Description | Example / Encoding |
| :--- | :--- | :--- |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `AMNCertificate.p12` | `base64 -w 0 AMNCertificate.p12` |
| `P12_PASSWORD` | Password for the `.p12` certificate file | `1234AMN@` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded `AMN_Driver (1).mobileprovision` | `base64 -w 0 "AMN_Driver (1).mobileprovision"` |
| `KEYCHAIN_PASSWORD` | Password for temporary runner keychain | Random string (e.g. `temporary_runner_keychain_pwd_2026`) |
| `APPSTORE_API_KEY_BASE64` | Base64-encoded `AuthKey_VQV5J6AQ78.p8` | `base64 -w 0 AuthKey_VQV5J6AQ78.p8` |
| `APPSTORE_KEY_ID` | App Store Connect API Key ID | `VQV5J6AQ78` |
| `APPSTORE_ISSUER_ID` | App Store Connect Issuer ID | `db70cb7b-56b1-4a06-b8ea-1c3fea1448dc` |

---

## 4. Critical Build Engineering & Lessons Learned

### A. CocoaPods CDN vs Legacy Git Clone
* **Issue**: Declaring `source 'https://github.com/CocoaPods/Specs.git'` forces CocoaPods to clone the entire 2.5 GB git repository, consuming 12+ minutes of CI runner time.
* **Resolution**: Default to CocoaPods standard CDN (`https://cdn.cocoapods.org/`), which resolves dependencies in under 3 seconds.

### B. Gebeta GL (`maplibre_gl`) Module Conflict with SwiftPM
* **Issue**: Flutter 3.29+ / 3.50+ enables experimental Swift Package Manager (SwiftPM) by default. The `gebeta_gl` plugin's `Package.swift` registers its target as `maplibre_gl`, but Flutter's plugin registrant generates `@import gebeta_gl;`, resulting in `Parse Issue: Module 'gebeta_gl' not found`.
* **Resolution**: Explicitly disable SwiftPM in `pubspec.yaml` and the CI workflow:
  ```yaml
  flutter:
    config:
      enable-swift-package-manager: false
  ```
  ```bash
  flutter config --no-enable-swift-package-manager
  ```
  This routes all plugins through CocoaPods where `gebeta_gl.podspec` generates a matching `gebeta_gl` Clang module.

### C. User Script Sandboxing (`ENABLE_USER_SCRIPT_SANDBOXING`)
* **Issue**: Xcode 15/16 enables user script sandboxing by default. This blocks CocoaPods' `[CP] Check Pods Manifest.lock` phase from reading `Podfile.lock`, triggering `Error: The sandbox is not in sync with the Podfile.lock`.
* **Resolution**: Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` across the target build settings in `project.pbxproj` and CocoaPods' `post_install` hook:
  ```ruby
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
  end
  ```

### D. Manual Code Signing Configuration
* **Issue**: By default, Xcode targets set `CODE_SIGN_STYLE = Automatic` and `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer"`, which fails on headless CI runners without a personal developer account signed in.
* **Resolution**:
  - `ios/Flutter/Release.xcconfig` sets `CODE_SIGN_STYLE = Manual`, `DEVELOPMENT_TEAM = T6N9PJTZS6`, `CODE_SIGN_IDENTITY = Apple Distribution`, and `PROVISIONING_PROFILE_SPECIFIER = AMN Driver`.
  - The workflow creates a temporary keychain, sets it as the default keychain, imports the certificate with partition keys, and copies the provisioning profile by both UUID and name.

---

## 5. Releasing from Windows (CLI Guide)

From the `driver_app` root directory on Windows:

### 1. Release with an incremented build number (Standard update)
```bash
dart run tool/release_ios.dart --bump=build
```
* Bumps `1.0.10+13` -> `1.0.10+14`.
* Updates `pubspec.yaml`, commits, pushes to `master`, and triggers cloud release.

### 2. Release with a patch version increment (Feature/Bugfix update)
```bash
dart run tool/release_ios.dart --bump=patch
```
* Bumps `1.0.10+13` -> `1.0.11+14`.

### 3. Release with a custom version
```bash
dart run tool/release_ios.dart --version=1.1.0+20
```

### 4. Dry Run (Preview without committing or triggering CI)
```bash
dart run tool/release_ios.dart --dry-run
```

### 5. Fire and forget (Do not stream live logs in terminal)
```bash
dart run tool/release_ios.dart --bump=build --no-watch
```
You can check progress at any time with:
```bash
gh run watch
```

---

## 6. App Store Submission & Review Guidelines

1. **TestFlight Processing**:
   - Each build uploaded via `altool` takes ~5 to 15 minutes to process in [App Store Connect](https://appstoreconnect.apple.com/).
   - When asked for **Export Compliance**, select **"No"** (app uses standard HTTPS encryption).

2. **Apple Guideline 2.1 (Information Needed) Checklist**:
   - **Demo Credentials**: Provide active driver login credentials (e.g., driver phone number and PIN/password).
   - **Demonstration Video**: If requested, provide a 1–2 minute screen recording demonstrating:
     - Driver login.
     - Toggling online/available status.
     - Receiving or simulating an incoming delivery request.
     - Navigating with the map.
     - Profile and in-app account deletion under **Profile > Delete Account**.
   - **Background Location Note**: State that background location updates (`UIBackgroundModes: location`) are strictly used to dispatch real-time location to the customer while an active order is in transit.
