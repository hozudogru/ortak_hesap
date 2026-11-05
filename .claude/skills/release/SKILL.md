---
name: release
description: Release process for Ortak Hesap — Codemagic Android/iOS build workflows and version bumping. Use when preparing a release, bumping the app version, or debugging a Codemagic build/signing/submission failure.
---

# Release process

Two workflows in `codemagic.yaml`, both pinned to Flutter 3.47.9. There is no `triggering` section, so a push does **not** start a build: after pushing, start each workflow by hand in the Codemagic UI (app → Start new build → pick the workflow and the `main` branch).

- **`android-workflow`**: builds an AAB, signs with the `Ortak_Hesap_Takip` keystore (env vars `CM_KEYSTORE`, `CM_KEYSTORE_PATH`), publishes to the Google Play **production** track via `GPLAY_SERVICE_ACCOUNT_JSON`. Play Console still requires a manual review/rollout of the release it creates.
- **`ios-workflow`**: automatic code signing through the `Codemagic3` App Store Connect integration (new team L8VSGNGQPG, bundle id `com.hasimozudogru.ortakhesap`), builds the IPA, submits to TestFlight. No manually uploaded certificate or profile is used; Codemagic creates/renews them, including after a capability change such as Sign in with Apple.

Version bumping: update `version` in `pubspec.yaml` (format: `1.0.0+<build-number>`). The build number maps to Android `versionCode` and iOS `CFBundleVersion` — App Store Connect rejects a build whose `CFBundleVersion` doesn't strictly exceed every previously uploaded value, so bump it even for a resubmit of the same source. Commit messages for releases follow `feat|fix: release X.Y.Z — summary`.

After the stores accept the build, update `config/appVersion` in Firestore (`latestVersion`, optionally `minVersion`) so the in-app update prompt matches.

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
