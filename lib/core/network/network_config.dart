import 'package:drop/core/config/app_environment.dart';

/// Configuration for the external NestJS API (chat backend).
///
/// This stays the **single source of truth** for the base URL used by both the
/// REST `ApiClient` and the Socket.IO namespace — one value wires the whole
/// backend. The value itself now comes from the typed [AppEnvironment], which
/// resolves it from the compile-time `API_BASE_URL` define (see
/// `config/<env>.json` + `--dart-define-from-file`). Selecting an environment
/// therefore never requires editing source:
///
/// ```bash
/// flutter run       --dart-define-from-file=config/local.json
/// flutter run       --dart-define-from-file=config/staging.json
/// flutter build apk --dart-define-from-file=config/production.json
/// ```
///
/// A **release build with no `API_BASE_URL` fails fast** (see [AppEnvironment]);
/// debug/profile still default to `localhost` for convenience.
class NetworkConfig {
  NetworkConfig._();

  /// Backend origin for REST and Socket.IO. Resolved once via [AppEnvironment].
  static String get apiBaseUrl => AppEnvironment.current.apiBaseUrl;

  /// One ceiling for connect / send / receive — the API is a small internal
  /// service; anything slower than this is down, not slow.
  static const Duration timeout = Duration(seconds: 20);
}
