import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/search_history_service.dart';

void main() {
  group('SearchHistoryService Tests', () {
    late SearchHistoryService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SearchHistoryService();
    });

    test(
      'saveSearch and getHistory store and retrieve search logs successfully',
      () async {
        final userEmail = 'gourav@test.com';
        final query = 'tractor spare tire';
        final rawEnvelope = {
          'answer': 'We found 3 matching items in our database.',
          'kb_model': 'TIGER_V1',
          'feedback_tracking': {
            'kb_a_id': 'ALPHA_01',
            'kb_b_id': 'BETA_01',
            'kb_a_has_data': true,
            'kb_b_has_data': false,
          },
          'sources': [],
        };

        await service.saveSearch(
          userEmail: userEmail,
          query: query,
          rawEnvelope: rawEnvelope,
          processingTimeSeconds: 1.45,
        );

        final history = await service.getHistory(userEmail);

        expect(history.length, equals(1));
        expect(history.first.query, equals(query));
        expect(
          history.first.unifiedAnswer,
          contains('We found 3 matching items'),
        );
        expect(history.first.kbModel, equals('TIGER_V1'));
        expect(history.first.processingTimeSeconds, equals(1.45));
      },
    );

    test('User histories are perfectly isolated per email', () async {
      final userA = 'userA@test.com';
      final userB = 'userB@test.com';
      final rawEnvelope = {'answer': 'Success response', 'sources': []};

      await service.saveSearch(
        userEmail: userA,
        query: 'Query A',
        rawEnvelope: rawEnvelope,
      );
      await service.saveSearch(
        userEmail: userB,
        query: 'Query B',
        rawEnvelope: rawEnvelope,
      );

      final historyA = await service.getHistory(userA);
      final historyB = await service.getHistory(userB);

      expect(historyA.length, equals(1));
      expect(historyA.first.query, equals('Query A'));

      expect(historyB.length, equals(1));
      expect(historyB.first.query, equals('Query B'));
    });

    test('History older than 3 days is automatically pruned on load', () async {
      final userEmail = 'gourav@test.com';
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final oldRecord = {
        'query': 'old query',
        'envelope': {'answer': 'Old answer', 'sources': []},
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 4))
            .toUtc()
            .toIso8601String(),
      };

      final newRecord = {
        'query': 'new query',
        'envelope': {'answer': 'New answer', 'sources': []},
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 12))
            .toUtc()
            .toIso8601String(),
      };

      // Set raw mock values directly in shared_preferences
      final String storageKey = 'search_history_v1_gourav@test.com';
      await prefs.setStringList(storageKey, [
        jsonEncode(oldRecord),
        jsonEncode(newRecord),
      ]);

      // Loading history should trigger auto-pruning
      final history = await service.getHistory(userEmail);

      expect(history.length, equals(1));
      expect(history.first.query, equals('new query'));

      // Verify that the old record is also pruned from SharedPreferences storage
      final updatedList = prefs.getStringList(storageKey) ?? [];
      expect(updatedList.length, equals(1));
      expect(jsonDecode(updatedList.first)['query'], equals('new query'));
    });

    test('clearAllHistory completely wipes out the user history', () async {
      final userEmail = 'gourav@test.com';
      final rawEnvelope = {'answer': 'Sample answer', 'sources': []};

      await service.saveSearch(
        userEmail: userEmail,
        query: 'Query 1',
        rawEnvelope: rawEnvelope,
      );
      await service.saveSearch(
        userEmail: userEmail,
        query: 'Query 2',
        rawEnvelope: rawEnvelope,
      );

      await service.clearAllHistory(userEmail);

      final history = await service.getHistory(userEmail);
      expect(history, isEmpty);
    });
  });
}
