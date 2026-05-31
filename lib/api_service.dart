import 'dart:async'; // 1. Crucial addition: Required to intercept TimeoutException
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'app_config.dart';
import 'package:amplify_flutter/amplify_flutter.dart'; // 💡 Exposes safePrint


class ApiService {
  final AuthService _authService = AuthService();
  final http.Client _httpClient = http.Client();

  static const Duration _networkTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> searchCatalog(String searchPrompt) async {
    final Uri targetUrl = Uri.parse('${AppConfig.apiGatewayBaseUrl}${AppConfig.queryEndpoint}');

    final String? idToken = await _authService.getActiveAccessToken();
    if (idToken == null) {
      throw const HttpException('Authentication Error: Session token missing or expired.');
    }

    final Map<String, String> requestHeaders = {
      HttpHeaders.authorizationHeader: idToken,
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };

    final Map<String, dynamic> requestBody = {
      'query': searchPrompt,
    };

    try {
      final http.Response response = await _httpClient
          .post(
            targetUrl,
            headers: requestHeaders,
            body: jsonEncode(requestBody),
          )
          .timeout(_networkTimeout);

      return _processResponse(response);
    } on http.ClientException catch (e) {
      throw HttpException('Network transport layer failure: ${e.message}');
    } on TimeoutException { // 2. Corrected Catch Target
      throw const HttpException('The connection timed out. Please verify connectivity.');
    } catch (e) {
      throw HttpException('Unexpected service failure: $e');
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    safePrint('RAW BACKEND RESPONSE BODY: ${response.body}');
    switch (response.statusCode) {
      case 200:
        return jsonDecode(response.body) as Map<String, dynamic>;
      case 401:
        throw const HttpException('Unauthorized request. Session validation failed.');
      case 403:
        throw const HttpException('Forbidden payload access. Policy denial.');
      case 500:
        throw const HttpException('Internal backend processing failure. Please retry later.');
      default:
        throw HttpException('Server returned error status code: ${response.statusCode}');
    }
  }

    /// Transmits user telemetry data scoring which Knowledge Base returned an optimal solution
  Future<bool> submitAgentFeedback({
    required String originalQuery,
    required String preferredKbId,
    required String rejectedKbId,
  }) async {
    final Uri targetUrl = Uri.parse('${AppConfig.apiGatewayBaseUrl}/feedback');
    final String? idToken = await _authService.getActiveAccessToken();
    
    if (idToken == null) return false;

    final Map<String, dynamic> feedbackPayload = {
      'query': originalQuery,
      'chosenKnowledgeBase': preferredKbId,
      'omittedKnowledgeBase': rejectedKbId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _httpClient.post(
        targetUrl,
        headers: {
          HttpHeaders.authorizationHeader: idToken,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(feedbackPayload),
      ).timeout(_networkTimeout);

      return response.statusCode == 200;
    } catch (e) {
      safePrint('Telemetry Error: Failed to drop feedback packet -> $e');
      return false;
    }
  }

}
