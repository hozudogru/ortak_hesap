# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

**Ortak Hesap** is a Turkish-language shared expense tracker mobile app (Flutter + Firebase). Users create or join groups, log expenses with flexible split modes, track who owes whom, and settle debts. The UI is entirely in Turkish.

## Architecture

### Single-file Flutter app
All Dart code lives in **`lib/main.dart`** (~3600 lines). There are no separate files, feature modules, or state management packages — everything is co-located. The entry point initializes Firebase then runs `MyApp`.

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

