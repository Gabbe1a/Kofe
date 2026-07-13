/// Compile-time / default API config for Kofe.
abstract final class AppConfig {
  /// Override: `flutter run --dart-define=API_BASE_URL=http://host`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://94.249.239.210',
  );
}
