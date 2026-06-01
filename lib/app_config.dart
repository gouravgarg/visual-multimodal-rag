class AppConfig {
  /// Base API Gateway Invoke URL injected via --dart-define parameters during compilation
  /// Leave empty by default so missing configuration fails before a web fetch.
  static const String apiGatewayBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// API Route endpoints
  static const String queryEndpoint = '/query';
}
