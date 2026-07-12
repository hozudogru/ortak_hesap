---
name: release
description: Release process for Ortak Hesap — Codemagic Android/iOS build workflows and version bumping. Use when preparing a release, bumping the app version, or debugging a Codemagic build/signing/submission failure.
---

# Release process

Two workflows in `codemagic.yaml`:
- **`android-workflow`**: builds AAB, signs with `Ortak_Hesap_Takip` keystore (env vars `CM_KEYSTORE`, `CM_KEYSTORE_PATH`), publishes to Google Play internal track via `GPLAY_SERVICE_ACCOUNT_JSON`.
- **`ios-workflow`**: builds IPA using `ortakhesap-cert` / `ortakhesap-profile`, submits to TestFlight.

Version bumping: update `version` in `pubspec.yaml` (format: `1.0.0+<build-number>`). The build number maps to Android `versionCode` and iOS `CFBundleVersion` — App Store Connect rejects a build whose `CFBundleVersion` doesn't strictly exceed every previously uploaded value, so bump it even for a resubmit of the same source.

Manual local build commands:
```bash
flutter build appbundle --release            # Android AAB for Play Store
flutter build ios --release --no-codesign    # iOS (Codemagic handles signing)
```

Firebase Functions deploy (in `functions/`):
```bash
cd functions && npm install
firebase deploy --only functions
```
