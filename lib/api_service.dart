import 'dart:async'; // 1. Crucial addition: Required to intercept TimeoutException
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'app_config.dart';
import 'log_helper.dart';
import 'package:amplify_flutter/amplify_flutter.dart'; // 💡 Exposes safePrint

class ApiService {
  final AuthService _authService = AuthService();
  final http.Client _httpClient = http.Client();

  static const Duration _networkTimeout = Duration(seconds: 60);

  Future<Map<String, dynamic>> searchCatalog(
    String searchPrompt, {
    List<String>? base64Images,
  }) async {
    final String apiBaseUrl = AppConfig.apiGatewayBaseUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    if (apiBaseUrl.isEmpty) {
      throw const HttpException(
        'API_BASE_URL is not configured. Run the app with --dart-define=API_BASE_URL=<your API Gateway invoke URL>.',
      );
    }

    if (!apiBaseUrl.startsWith('https://')) {
      throw const HttpException(
        'Security Error: Insecure HTTP protocol detected. API_BASE_URL must use HTTPS.',
      );
    }

    final Uri targetUrl = Uri.parse('$apiBaseUrl${AppConfig.queryEndpoint}');

    final String? idToken = await _authService.getActiveIdToken();
    if (idToken == null) {
      throw const HttpException(
        'Authentication Error: Session token missing or expired.',
      );
    }

    final Map<String, dynamic> requestBody = {
      'query': searchPrompt,
      if (base64Images != null && base64Images.isNotEmpty)
        'images': base64Images,
    };

    try {
      final http.Response response = await _httpClient
          .post(
            targetUrl,
            headers: {
              HttpHeaders.authorizationHeader: idToken,
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_networkTimeout);

      return _processResponse(response);
    } on http.ClientException catch (e) {
      throw HttpException('Network transport layer failure: ${e.message}');
    } on TimeoutException {
      throw const HttpException(
        'The connection timed out. Please verify connectivity.',
      );
    } on HttpException {
      rethrow;
    } catch (e) {
      throw HttpException('Unexpected service failure: $e');
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        final Map<String, dynamic> decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        saveResponseLog(decoded);
        return decoded;
      case 401:
        throw const HttpException(
          'Unauthorized request. Session validation failed.',
        );
      case 403:
        throw const HttpException('Forbidden payload access. Policy denial.');
      case 500:
        throw const HttpException(
          'Internal backend processing failure. Please retry later.',
        );
      default:
        throw HttpException(
          'Server returned error status code: ${response.statusCode}',
        );
    }
  }

  /// Transmits user feedback for answer quality and source attribution.
  Future<bool> submitAgentFeedback({
    required String originalQuery,
    required bool isHelpful,
    required String kbAId,
    required String kbBId,
    required bool kbAHasData,
    required bool kbBHasData,
  }) async {
    final String feedbackApiBaseUrl = AppConfig.feedbackApiBaseUrl
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
    if (feedbackApiBaseUrl.isEmpty) return false;

    if (!feedbackApiBaseUrl.startsWith('https://')) {
      safePrint(
        'Telemetry Security Error: Insecure HTTP protocol detected for FEEDBACK_API_BASE_URL. Must use HTTPS.',
      );
      return false;
    }

    final Uri targetUrl = Uri.parse(
      '$feedbackApiBaseUrl${AppConfig.feedbackEndpoint}',
    );
    final String? idToken = await _authService.getActiveIdToken();
    final String? userEmail = await _authService.getCurrentUserEmail();

    if (idToken == null) return false;

    final Map<String, dynamic> feedbackPayload = {
      'query': originalQuery,
      'question': originalQuery,
      'userEmail': userEmail,
      'feedback': isHelpful ? 'helpful' : 'not_helpful',
      'isHelpful': isHelpful,
      'sources': {
        'alpha': {'knowledgeBaseId': kbAId, 'hasData': kbAHasData},
        'beta': {'knowledgeBaseId': kbBId, 'hasData': kbBHasData},
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _httpClient
          .post(
            targetUrl,
            headers: {
              HttpHeaders.authorizationHeader: idToken,
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(feedbackPayload),
          )
          .timeout(_networkTimeout);

      return response.statusCode == 200;
    } catch (e) {
      safePrint('Telemetry Error: Failed to drop feedback packet -> $e');
      return false;
    }
  }
}
