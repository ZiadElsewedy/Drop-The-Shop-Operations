# DROP

**DROP — Operations Management System.** A role-based branch/shift operations
app (admin · manager · employee) for running daily branch work: task assignment
and review with proof, weekly scheduling and shift swaps, branch administration,
and live operations dashboards.

> Fully branded as **DROP**: the Dart package identifier is `drop` (every import
> is `package:drop/…`) and all platform display names read **DROP** /
> **DROP OPERATIONS**. The Firebase-registered bundle identifier
> `com.example.fbro` is intentionally retained — changing it requires
> re-registering the apps in the Firebase console (see CURRENT_STATE.md).

## Documentation

The source of truth lives in three repo-root docs, kept in sync with the code:

- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) — architecture, conventions, the
  documentation self-check.
- [`CURRENT_STATE.md`](CURRENT_STATE.md) — what's built and where it lives.
- [`CHANGELOG.md`](CHANGELOG.md) — dated history of changes.

## Getting started

```bash
flutter pub get
flutter run
```

Firebase (Auth, Firestore, Storage, FCM) backs the app. After changing security
rules, deploy them:

```bash
firebase deploy --only firestore:rules,storage
```
