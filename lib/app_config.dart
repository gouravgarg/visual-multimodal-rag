class AppConfig {
  /// Base API Gateway Invoke URL injected via --dart-define parameters during compilation
  /// Leave empty by default so missing configuration fails before a web fetch.
  static const String apiGatewayBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Feedback API Gateway Invoke URL.
  static const String feedbackApiBaseUrl = String.fromEnvironment(
    'FEEDBACK_API_BASE_URL',
    defaultValue: 'https://5x9zznni68.execute-api.eu-north-1.amazonaws.com',
  );

  /// API Route endpoints
  static const String queryEndpoint = '/query';
  static const String feedbackEndpoint = '/feedback';
}
