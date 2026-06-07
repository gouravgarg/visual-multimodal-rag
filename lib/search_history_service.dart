import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'part_model.dart';

class SearchHistoryService {
  static const String _keyPrefix = 'search_history_v1_';
  static const Duration _maxAge = Duration(days: 3);

  /// Generates a storage key scoped to a specific user's email to isolate history.
  String _getStorageKey(String userEmail) {
    // Normalizing email format for consistent key generation
    final cleanEmail = userEmail.trim().toLowerCase();
    return '$_keyPrefix$cleanEmail';
  }

  /// Appends a search query and its raw response envelope to the user's client-side history logs.
  Future<void> saveSearch({
    required String userEmail,
    required String query,
    required Map<String, dynamic> rawEnvelope,
    List<Uint8List>? attachedImages,
    double? processingTimeSeconds,
  }) async {
    if (userEmail.trim().isEmpty) {
      safePrint(
        'SearchHistoryService Error: Cannot save history for empty user email.',
      );
      return;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String storageKey = _getStorageKey(userEmail);

      // Load existing records
      final List<String> rawList = prefs.getStringList(storageKey) ?? [];
      final List<Map<String, dynamic>> records = [];

      for (final rawStr in rawList) {
        try {
          final decoded = jsonDecode(rawStr);
          if (decoded is Map<String, dynamic>) {
            records.add(decoded);
          }
        } catch (e) {
          safePrint(
            'SearchHistoryService [saveSearch] warning: corrupted item ignored -> $e',
          );
        }
      }

      // Convert images to base64 strings
      List<String>? base64Images;
      if (attachedImages != null && attachedImages.isNotEmpty) {
        base64Images = attachedImages
            .map((bytes) => base64Encode(bytes))
            .toList();
      }

      // Create new record
      final Map<String, dynamic> newRecord = {
        'query': query,
        'envelope': rawEnvelope,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'attachedImages': base64Images,
        'processingTimeSeconds': processingTimeSeconds,
      };

      records.add(newRecord);

      // Filter and clean old entries (anything older than 3 days)
      final DateTime nowUtc = DateTime.now().toUtc();
      final List<Map<String, dynamic>> activeRecords = [];
      int prunedCount = 0;

      for (final rec in records) {
        final String? timestampStr = rec['timestamp'] as String?;
        if (timestampStr != null) {
          try {
            final DateTime timestamp = DateTime.parse(timestampStr).toUtc();
            if (nowUtc.difference(timestamp) <= _maxAge) {
              activeRecords.add(rec);
            } else {
              prunedCount++;
            }
          } catch (e) {
            // Keep the record if parsing fails, or discard? Let's discard if invalid timestamp.
            safePrint(
              'SearchHistoryService [saveSearch] warning: invalid timestamp pruned.',
            );
          }
        }
      }

      // Save back updated list
      final List<String> encodedList = activeRecords
          .map((rec) => jsonEncode(rec))
          .toList();
      await prefs.setStringList(storageKey, encodedList);

      safePrint(
        'SearchHistoryService: Logged new search query for $userEmail. '
        'Active entries: ${activeRecords.length} (Pruned: $prunedCount old entries).',
      );
    } catch (e) {
      safePrint('SearchHistoryService Error saving search log: $e');
    }
  }

  /// Retrieves the search history for a user, automatically pruning entries older than 3 days.
  Future<List<AgentResponse>> getHistory(String userEmail) async {
    if (userEmail.trim().isEmpty) {
      safePrint(
        'SearchHistoryService Error: Cannot retrieve history for empty user email.',
      );
      return [];
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String storageKey = _getStorageKey(userEmail);

      final List<String> rawList = prefs.getStringList(storageKey) ?? [];
      final List<Map<String, dynamic>> decodedRecords = [];
      final DateTime nowUtc = DateTime.now().toUtc();
      final List<String> updatedEncodedList = [];
      bool dataChanged = false;

      for (final rawStr in rawList) {
        try {
          final decoded = jsonDecode(rawStr);
          if (decoded is Map<String, dynamic>) {
            final String? timestampStr = decoded['timestamp'] as String?;
            if (timestampStr != null) {
              final DateTime timestamp = DateTime.parse(timestampStr).toUtc();
              if (nowUtc.difference(timestamp) <= _maxAge) {
                decodedRecords.add(decoded);
                updatedEncodedList.add(rawStr);
              } else {
                dataChanged = true; // Pruned an old item
              }
            } else {
              dataChanged = true; // Pruned corrupted item with no timestamp
            }
          }
        } catch (e) {
          dataChanged = true; // Pruned corrupted JSON
          safePrint(
            'SearchHistoryService [getHistory] warning: skipped corrupt record -> $e',
          );
        }
      }

      // If old items were pruned, persist the cleaned history
      if (dataChanged) {
        await prefs.setStringList(storageKey, updatedEncodedList);
        safePrint(
          'SearchHistoryService: Automatically pruned expired logs. Updated active count: ${decodedRecords.length}',
        );
      }

      // Map JSON entries back to AgentResponse objects
      final List<AgentResponse> parsedHistory = [];
      for (final record in decodedRecords) {
        try {
          final String query = record['query'] as String? ?? '';
          final Map<String, dynamic> envelope =
              record['envelope'] as Map<String, dynamic>? ?? {};
          final double? processingTime = record['processingTimeSeconds'] != null
              ? (record['processingTimeSeconds'] as num).toDouble()
              : null;

          List<Uint8List>? attachedImages;
          if (record['attachedImages'] != null) {
            final List<dynamic> base64Images =
                record['attachedImages'] as List<dynamic>;
            attachedImages = base64Images
                .map((b64) => base64Decode(b64 as String))
                .toList();
          }

          parsedHistory.add(
            AgentResponse.fromJson(
              query,
              envelope,
              attachedImages: attachedImages,
              processingTimeSeconds: processingTime,
            ),
          );
        } catch (e) {
          safePrint(
            'SearchHistoryService Error reconstructing AgentResponse: $e',
          );
        }
      }

      safePrint(
        'SearchHistoryService: Successfully loaded ${parsedHistory.length} search records for $userEmail.',
      );
      return parsedHistory;
    } catch (e) {
      safePrint('SearchHistoryService Error loading history: $e');
      return [];
    }
  }

  /// Clears all stored search history for a specific user profile.
  Future<void> clearAllHistory(String userEmail) async {
    if (userEmail.trim().isEmpty) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String storageKey = _getStorageKey(userEmail);
      await prefs.remove(storageKey);
      safePrint(
        'SearchHistoryService: Cleared all client-side search logs for $userEmail.',
      );
    } catch (e) {
      safePrint('SearchHistoryService Error clearing history: $e');
    }
  }
}
