import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class AuthService {
  /// Signs in your user pool test user account securely
  Future<bool> signIn(String username, String password) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
      );
      return result.isSignedIn;
    } on AuthException catch (e) {
      safePrint('Cognito Auth Core Rejection: ${e.message}');
      rethrow;
    } catch (e) {
      safePrint('Low-Level Transport Exception: $e');
      rethrow;
    }
  }

  /// Sign out the current mobile device profile session
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      safePrint('AuthService: Session cleared.');
    } catch (e) {
      safePrint('AuthService Error [signOut]: $e');
    }
  }

  /// Direct type-safe lookup for the user pool JWT identity token string
  Future<String?> getActiveAccessToken() async {
    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
      final session = await cognitoPlugin.fetchAuthSession();
      
      if (session.isSignedIn) {
        // Direct, type-safe fallback extract bypassing Identity Pool infrastructure dependencies
        final tokens = session.userPoolTokensResult.value;
        return tokens.idToken.raw;
      }
      return null;
    } catch (e) {
      safePrint('Enterprise Failure extracting Cognito JWT Token: $e');
      return null;
    }
  }
}
