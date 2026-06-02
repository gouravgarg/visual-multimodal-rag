class AppConfig {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Sonalika Knowledge Agent',
  );

  static const String loginTitle = String.fromEnvironment(
    'LOGIN_TITLE',
    defaultValue: 'Sonalika Spare Parts',
  );

  static const String loginSubtitle = String.fromEnvironment(
    'LOGIN_SUBTITLE',
    defaultValue: 'Catalog Portal Authentication',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0',
  );

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'Local',
  );

  static const String emptyStateTitle = String.fromEnvironment(
    'EMPTY_STATE_TITLE',
    defaultValue: 'Ask anything about Sonalika Catalogues',
  );

  static const String emptyStateSubtitle = String.fromEnvironment(
    'EMPTY_STATE_SUBTITLE',
    defaultValue:
        'Your prompt will resolve across available knowledge repositories securely.',
  );

  static const String queryHintText = String.fromEnvironment(
    'QUERY_HINT_TEXT',
    defaultValue: 'Ask your technical engine question...',
  );

  /// Base API Gateway Invoke URL injected via --dart-define parameters during compilation
  /// Leave empty by default so missing configuration fails before a web fetch.
  static const String apiGatewayBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Feedback API Gateway Invoke URL.
  static const String feedbackApiBaseUrl = String.fromEnvironment(
    'FEEDBACK_API_BASE_URL',
    defaultValue: '',
  );

  /// API Route endpoints
  static const String queryEndpoint = String.fromEnvironment(
    'QUERY_ENDPOINT',
    defaultValue: '/query',
  );
  static const String feedbackEndpoint = String.fromEnvironment(
    'FEEDBACK_ENDPOINT',
    defaultValue: '/feedback',
  );

  static const String cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
    defaultValue: '',
  );

  static const String cognitoAppClientId = String.fromEnvironment(
    'COGNITO_APP_CLIENT_ID',
    defaultValue: '',
  );

  static const String cognitoRegion = String.fromEnvironment(
    'COGNITO_REGION',
    defaultValue: '',
  );

  /// Optional local test credentials. Keep empty in shared and production builds.
  static const String initialUsername = String.fromEnvironment(
    'INITIAL_USERNAME',
    defaultValue: '',
  );

  static const String initialPassword = String.fromEnvironment(
    'INITIAL_PASSWORD',
    defaultValue: '',
  );
}
