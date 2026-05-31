class AppConfig {
  /// Base API Gateway Invoke URL injected via --dart-define parameters during compilation
  /// Fallback provided for local development environment baseline
  static const String apiGatewayBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://amazonaws.com',
  );

  /// API Route endpoints
  static const String queryEndpoint = '/query';
}
