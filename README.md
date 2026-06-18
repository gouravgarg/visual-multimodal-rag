# Visual Multimodel AI Agent

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
--dart-define=APP_NAME="Gourav Garg AI"
--dart-define=LOGIN_TITLE="Gourav Garg"
--dart-define=LOGIN_SUBTITLE="Visual Multimodel AI Agent"
--dart-define=APP_VERSION=1.0
--dart-define=APP_ENVIRONMENT=UAT
--dart-define=QUERY_ENDPOINT=/query
--dart-define=FEEDBACK_ENDPOINT=/feedback
--dart-define=EMPTY_STATE_TITLE="Ask anything about Visual Multimodel Catalogues"
--dart-define=EMPTY_STATE_SUBTITLE="Your prompt will resolve across available knowledge repositories securely."
--dart-define=QUERY_HINT_TEXT="Ask your technical engine question..."
--dart-define=ABOUT_SCREEN_STYLE=MinimalistSeal # Layout options for the Premium Developer card: SapphirePlaque, MinimalistSeal, CyberGlow
```

### Premium Developer Card Customization

You can customize the 'About' dialog aesthetic via the `--dart-define=ABOUT_SCREEN_STYLE` parameter. The available styles are:

1. **`SapphirePlaque`** (Default): An elegant, royal deep blue sapphire and gold card design featuring a gold shield badge, metallic gold accents, and a gold button.
2. **`MinimalistSeal`**: A clean, modern Apple/Tesla-style white design featuring a slate SP monogram emblem, extensive whitespace, and clear border button highlights.
3. **`CyberGlow`**: A state-of-the-art cyberpunk dark mode layout featuring glowing electric cyan gradients, futuristic neon borders, a cyberbolt badge, and glowing command-terminal link buttons.

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
