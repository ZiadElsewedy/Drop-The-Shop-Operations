import 'package:flutter/foundation.dart';

/// The deployment targets the app can be built/run against.
enum AppEnvironmentType { local, staging, production }

/// The resolved runtime environment — the single typed source of truth for
/// "which backend am I talking to and what environment am I".
///
/// Values are injected at **compile time** via dart-defines (best resolved from
/// a committed `config/<env>.json` with `--dart-define-from-file`), so the
/// target can never drift at runtime and switching environments never requires
/// editing source:
///
/// ```bash
/// flutter run       --dart-define-from-file=config/local.json
/// flutter run       --dart-define-from-file=config/staging.json
/// flutter build apk --dart-define-from-file=config/production.json
/// ```
///
/// Two defines drive it:
///  - `API_BASE_URL` — the NestJS backend origin (REST **and** Socket.IO);
///  - `APP_ENV` — `local` | `staging` | `production` (diagnostics + `isProduction`).
///
/// Resolution is intentionally strict about release builds: a **release build
/// with no `API_BASE_URL` fails fast** rather than silently shipping pointed at
/// localhost. Debug/profile builds keep the localhost default so a bare
/// `flutter run` still works for everyday local development.
@immutable
class AppEnvironment {
  const AppEnvironment._({required this.type, required this.apiBaseUrl});

  /// The environment name (`local` | `staging` | `production`).
  final AppEnvironmentType type;

  /// Backend origin used for both the REST `ApiClient` and the Socket.IO
  /// namespace. No trailing slash.
  final String apiBaseUrl;

  bool get isProduction => type == AppEnvironmentType.production;
  String get name => type.name;

  // ── Raw compile-time defines (const, tree-shakeable) ──────────────
  static const String _rawBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _rawEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');

  /// Convenience fallback so a bare `flutter run` (no config file) still targets
  /// a local backend in debug/profile. Never used in release.
  static const String _debugFallbackBaseUrl = 'http://localhost:3000';

  /// The resolved environment for this build. Computed once at first access.
  static final AppEnvironment current = _resolve();

  static AppEnvironment _resolve() {
    final type = _parseType(_rawEnv);
    var baseUrl = _rawBaseUrl.trim();

    if (baseUrl.isEmpty) {
      if (kReleaseMode) {
        // Fail fast: a production/release artifact must know its backend.
        throw StateError(
          'API_BASE_URL is not set for this release build. Build with '
          '--dart-define-from-file=config/production.json (or pass an explicit '
          '--dart-define=API_BASE_URL=...). Refusing to default to localhost '
          'in a release build.',
        );
      }
      // Debug/profile convenience only.
      baseUrl = _debugFallbackBaseUrl;
    }

    // Strip a trailing slash so `$apiBaseUrl/chat` and REST paths compose cleanly.
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return AppEnvironment._(type: type, apiBaseUrl: baseUrl);
  }

  static AppEnvironmentType _parseType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'production':
        return AppEnvironmentType.production;
      case 'staging':
        return AppEnvironmentType.staging;
      case 'local':
        return AppEnvironmentType.local;
      default:
        // Unknown APP_ENV: default to local rather than guessing production.
        return AppEnvironmentType.local;
    }
  }

  @override
  String toString() => 'AppEnvironment($name, apiBaseUrl: $apiBaseUrl)';
}
