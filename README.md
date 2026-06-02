# Sonalika Knowledge Agent

Flutter application for authenticated catalogue search and answer feedback.

## Runtime Configuration

This app is configured at build/run time with `--dart-define`. Environment-specific values must not be hardcoded in source.

Required:

```bash
--dart-define=API_BASE_URL=https://<search-api-id>.execute-api.<region>.amazonaws.com
--dart-define=FEEDBACK_API_BASE_URL=https://<feedback-api-id>.execute-api.<region>.amazonaws.com
--dart-define=COGNITO_USER_POOL_ID=<user-pool-id>
--dart-define=COGNITO_APP_CLIENT_ID=<app-client-id>
--dart-define=COGNITO_REGION=<region>
```

Optional:

```bash
--dart-define=APP_NAME="Sonalika Knowledge Agent"
--dart-define=LOGIN_TITLE="Sonalika Spare Parts"
--dart-define=LOGIN_SUBTITLE="Catalog Portal Authentication"
--dart-define=APP_VERSION=1.0
--dart-define=APP_ENVIRONMENT=UAT
--dart-define=QUERY_ENDPOINT=/query
--dart-define=FEEDBACK_ENDPOINT=/feedback
--dart-define=EMPTY_STATE_TITLE="Ask anything about Sonalika Catalogues"
--dart-define=EMPTY_STATE_SUBTITLE="Your prompt will resolve across available knowledge repositories securely."
--dart-define=QUERY_HINT_TEXT="Ask your technical engine question..."
```

Local-only optional test credentials:

```bash
--dart-define=INITIAL_USERNAME=<test-user-email>
--dart-define=INITIAL_PASSWORD=<test-user-password>
```

Do not use `INITIAL_USERNAME` or `INITIAL_PASSWORD` for shared, UAT, or production builds.

## Example Run

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://<search-api-id>.execute-api.eu-north-1.amazonaws.com \
  --dart-define=FEEDBACK_API_BASE_URL=https://<feedback-api-id>.execute-api.eu-north-1.amazonaws.com \
  --dart-define=COGNITO_USER_POOL_ID=<user-pool-id> \
  --dart-define=COGNITO_APP_CLIENT_ID=<app-client-id> \
  --dart-define=COGNITO_REGION=eu-north-1 \
  --dart-define=APP_ENVIRONMENT=Local
```
