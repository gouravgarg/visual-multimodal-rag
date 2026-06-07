import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';
import 'package:myapp/app_config.dart';

void main() {
  testWidgets('Login Screen renders correctly smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app with isCoreInitialized as false to avoid active Cognito session checks
    await tester.pumpWidget(const TractorCatalogApp(isCoreInitialized: false));
    await tester.pumpAndSettle();

    // Verify that the login screen components are rendered
    expect(find.text(AppConfig.loginTitle), findsOneWidget);
    expect(find.text(AppConfig.loginSubtitle), findsOneWidget);
    expect(
      find.byType(TextFormField),
      findsNWidgets(2),
    ); // Username and Password fields
    expect(find.text('Sign In Securely'), findsOneWidget);
  });
}
