import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import 'amplifyconfiguration.dart';
import 'app_config.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AWS Amplify services before app rendering mounts
  final bool isAwsConfigured = await _configureAmplify();

  runApp(TractorCatalogApp(isCoreInitialized: isAwsConfigured));
}

Future<bool> _configureAmplify() async {
  if (AppConfig.cognitoUserPoolId.isEmpty ||
      AppConfig.cognitoAppClientId.isEmpty ||
      AppConfig.cognitoRegion.isEmpty) {
    safePrint(
      'Enterprise Critical Error: Cognito configuration is incomplete.',
    );
    return false;
  }

  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);
    await Amplify.configure(amplifyconfig);

    safePrint('Enterprise Core: AWS Amplify successfully initialized.');
    return true;
  } on AmplifyAlreadyConfiguredException {
    safePrint('Enterprise Warning: Amplify was already configured.');
    return true;
  } catch (e) {
    safePrint('Enterprise Critical Error: Failed to configure Amplify -> $e');
    return false;
  }
}

class TractorCatalogApp extends StatefulWidget {
  final bool isCoreInitialized;
  const TractorCatalogApp({super.key, required this.isCoreInitialized});

  @override
  State<TractorCatalogApp> createState() => _TractorCatalogAppState();
}

class _TractorCatalogAppState extends State<TractorCatalogApp> {
  bool _isAuthenticated = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    if (widget.isCoreInitialized) {
      _evaluateActiveSession();
    } else {
      setState(() => _isCheckingSession = false);
    }
  }

  /// Silently audits Cognito session persistence state on cold boot
  Future<void> _evaluateActiveSession() async {
    try {
      final authSession = await Amplify.Auth.fetchAuthSession();
      setState(() {
        _isAuthenticated = authSession.isSignedIn;
      });
    } catch (e) {
      safePrint('Session Auditor Alert: Session parse error -> $e');
    } finally {
      setState(() => _isCheckingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
      ),

      // Multi-state routing tree resolution engine
      home: _isCheckingSession
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              ),
            )
          : _isAuthenticated
          ? DashboardScreen(
              onSignOut: () => setState(() => _isAuthenticated = false),
            )
          : LoginScreen(
              onLoginSuccess: () => setState(() => _isAuthenticated = true),
            ),
    );
  }
}
