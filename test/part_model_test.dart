import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/part_model.dart';

void main() {
  group('AgentResponse Tests', () {
    test('AgentResponse.fromJson parses kb_model from root json', () {
      final json = {
        'answer': 'Sample answer',
        'kb_model': 'TIGER_V1',
        'feedback_tracking': {
          'kb_a_id': 'ALPHA_01',
          'kb_b_id': 'BETA_01',
          'kb_a_has_data': false,
          'kb_b_has_data': false,
        },
        'sources': [],
      };

      final response = AgentResponse.fromJson('test query', json);

      expect(response.kbModel, equals('TIGER_V1'));
      expect(response.kbAHasData, isFalse);
      expect(response.kbBHasData, isFalse);
    });

    test(
      'AgentResponse.fromJson parses kb_model from feedback_tracking map',
      () {
        final json = {
          'answer': 'Sample answer',
          'feedback_tracking': {
            'kb_a_id': 'ALPHA_01',
            'kb_b_id': 'BETA_01',
            'kb_a_has_data': false,
            'kb_b_has_data': false,
            'kb_model': 'RX_CATALOG_v2',
          },
          'sources': [],
        };

        final response = AgentResponse.fromJson('test query', json);

        expect(response.kbModel, equals('RX_CATALOG_v2'));
      },
    );

    test('AgentResponse.fromJson handles absent kb_model elegantly', () {
      final json = {
        'answer': 'Sample answer',
        'feedback_tracking': {
          'kb_a_id': 'ALPHA_01',
          'kb_b_id': 'BETA_01',
          'kb_a_has_data': false,
          'kb_b_has_data': false,
        },
        'sources': [],
      };

      final response = AgentResponse.fromJson('test query', json);

      expect(response.kbModel, isNull);
    });
  });
}
