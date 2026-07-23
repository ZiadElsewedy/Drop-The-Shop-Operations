# Environment configuration

Each file here is the **single declarative source of truth** for one backend
environment. They carry no secrets (a base URL is public), so they are
committed. Selecting an environment is choosing a file — never editing source.

| File              | `APP_ENV`    | Backend                                         |
| ----------------- | ------------ | ----------------------------------------------- |
| `local.json`      | `local`      | `http://localhost:3000`                         |
| `staging.json`    | `staging`    | `https://drop-api-staging.up.railway.app` (TBD) |
| `production.json` | `production` | `https://drop-api-production.up.railway.app`    |

The keys are injected as compile-time dart-defines and read by
`lib/core/config/app_environment.dart` (`API_BASE_URL`, `APP_ENV`).

## Run

```bash
flutter run --dart-define-from-file=config/local.json        # local backend
flutter run --dart-define-from-file=config/staging.json      # staging
flutter run --dart-define-from-file=config/production.json   # Railway production
```

In VS Code, use the **DROP Local / DROP Staging / DROP Production** launch
profiles (`.vscode/launch.json`) — same thing, one click.

## Build / CI / release

Release artifacts **must** pass the production config; a release build with no
`API_BASE_URL` fails fast by design (no silent localhost).

```bash
flutter build apk    --release --dart-define-from-file=config/production.json
flutter build appbundle --release --dart-define-from-file=config/production.json
flutter build ipa    --release --dart-define-from-file=config/production.json
```

CI should invoke the same commands. A bare `flutter build ... --release`
(without the config) is intentionally a hard error at startup.
