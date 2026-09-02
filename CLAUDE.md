# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

**Ortak Hesap** is a Turkish-language shared expense tracker mobile app (Flutter + Firebase). Users create or join groups, log expenses with flexible split modes, track who owes whom, and settle debts. The UI is entirely in Turkish.

## Commands

Run all Flutter commands from the repo root; Cloud Functions commands from `functions/`.

```
flutter pub get                        # install/sync Dart dependencies
flutter analyze                        # static analysis (flutter_lints via analysis_options.yaml)
flutter test                           # run tests (test/ currently only has the default widget_test.dart, not app-specific)
flutter run                            # run on a connected device/emulator
flutter build apk|appbundle|ios        # local builds (CI release builds go through Codemagic — see the `release` skill)

cd functions
npm install
npm run serve                          # firebase emulators:start --only functions
npm run deploy                         # firebase deploy --only functions
npm run logs                           # firebase functions:log
```

There is no dedicated test suite for app logic (debt calculation, split types, etc.) — verify changes by running the app.

Release builds (version bumping, Codemagic Android/iOS workflows, signing) are handled by the `release` skill — use it rather than reconstructing the process by hand.

## Architecture

### Single-file Flutter app
All Dart code lives in **`lib/main.dart`** (~5000 lines). There are no separate files, feature modules, or state management packages — everything is co-located. The entry point initializes Firebase then runs `MyApp`.

### Screen flow
```
AuthGate (StreamBuilder on FirebaseAuth.authStateChanges)
├── LoginPage / RegisterPage  (unauthenticated)
└── HomePage                  (authenticated)
    └── GroupDetailPage (5 tabs)
        ├── Expenses tab      (_buildExpensesTab)
        ├── Members tab       (_buildMembersTab)
        ├── Debts tab         (_buildDebtsTab)
        ├── Chart tab         (_buildChartTab, fl_chart pie chart)
        └── History tab       (_buildPaymentsHistoryTab)
```
Additional screens: `GroupQrPage`, `GroupQrScannerPage`, `NotificationsPage`.

### Firestore data model

```
groups/{groupName}                    ← group name IS the document ID (must be unique)
  .currency, .ownerId, .memberIds[], .groupCode (6-digit timestamp suffix)
  /members/{uid}                      ← email, name, nickname, role, isAnonymous
  /expenses/{auto-id}                 ← title, amount, currency, paidBy (email), participants[], splitType, category, shares{}
  /payments/{auto-id}                 ← fromEmail, toEmail, amount (settled debts)

users/{uid}                           ← email, name, nickname, fcmToken
notificationRequests/{auto-id}        ← toEmail, fromEmail, title, body, isRead, status
```

**Critical**: Group document IDs equal the group name. Renaming a group is not supported.

### Expense split types
- `equal` — amount divided evenly across all participants
- `custom` — each participant's exact share is specified (must sum to total)
- `weighted` — weight ratios entered per participant; app converts to amounts

### Debt calculation
`calculateBalanceFromExpenses` → `applyPaymentsToBalance` → `calculateDebtsFromBalance`. Uses a greedy creditor/debtor matching algorithm (minimize number of transactions). Balance >0 means owed-to, <0 means owes.

### Anonymous members
Members can be added without a Firebase account (`isAnonymous: true`). Their email field is set to a generated `anonymous_<name>_<timestamp>` string. `displayNameForEmail` handles these by stripping the prefix.

### Push notifications
`functions/index.js` — a Firestore-triggered Cloud Function fires on `notificationRequests` creation, looks up the recipient's `fcmToken`, and sends via FCM Admin SDK. Debt reminders are sent by writing to this collection from the app.

### Firestore security rules
`firestore.rules` — all reads/writes require `request.auth != null` (no per-field validation beyond that), except: group `create` requires `ownerId == request.auth.uid`, group `delete` requires the caller to be the owner, and expense `update`/`delete` requires the caller to be either the expense's `createdByUid` or the group owner.

