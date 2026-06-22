# DROP

**DROP — Operations Management System.** A role-based branch/shift operations
app (admin · manager · employee) for running daily branch work: task assignment
and review with proof, weekly scheduling and shift swaps, branch administration,
and live operations dashboards.

> The Flutter/Dart package identifier remains `fbro` for build stability — only
> the product/brand name is **DROP**.

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
