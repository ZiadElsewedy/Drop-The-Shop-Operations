import 'package:drop/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the environment resolution plumbing. Runs green with a plain
/// `flutter test` (no defines → debug localhost fallback) and asserts the
/// injected target when run with a config file, e.g.:
///
///   flutter test test/core/app_environment_test.dart \
///     --dart-define-from-file=config/production.json
void main() {
  const injectedEnv = String.fromEnvironment('APP_ENV');
  const injectedUrl = String.fromEnvironment('API_BASE_URL');

  test('resolves a non-empty backend origin with no trailing slash', () {
    final env = AppEnvironment.current;
    expect(env.apiBaseUrl, isNotEmpty);
    expect(env.apiBaseUrl.endsWith('/'), isFalse);
  });

  test('uses the injected API_BASE_URL when provided', () {
    if (injectedUrl.isEmpty) {
      // No config file: debug builds fall back to localhost.
      expect(AppEnvironment.current.apiBaseUrl, 'http://localhost:3000');
      return;
    }
    final expected = injectedUrl.replaceAll(RegExp(r'/$'), '');
    expect(AppEnvironment.current.apiBaseUrl, expected);
  });

  test('maps APP_ENV to the typed environment', () {
    final env = AppEnvironment.current;
    switch (injectedEnv) {
      case 'production':
        expect(env.type, AppEnvironmentType.production);
        expect(env.isProduction, isTrue);
      case 'staging':
        expect(env.type, AppEnvironmentType.staging);
        expect(env.isProduction, isFalse);
      default:
        // 'local' or unset both resolve to local.
        expect(env.type, AppEnvironmentType.local);
        expect(env.isProduction, isFalse);
    }
  });
}
