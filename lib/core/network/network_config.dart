/// Build-time configuration for the external NestJS API (chat backend).
///
/// The base URL is a compile-time constant so it can never drift at runtime and
/// carries no secret — override it per environment with a dart-define:
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.dropshop.example
/// ```
///
/// Defaults to a local development server. Note that an **Android emulator**
/// reaches the host machine at `http://10.0.2.2:3000`, not `localhost`.
class NetworkConfig {
  NetworkConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// One ceiling for connect / send / receive — the API is a small internal
  /// service; anything slower than this is down, not slow.
  static const Duration timeout = Duration(seconds: 20);
}
