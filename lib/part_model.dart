class AgentResponse {
  final String query;
  final String unifiedAnswer;
  final String kbAId;
  final String kbBId;
  final bool kbAHasData; 
  final bool kbBHasData; 
  int selectedFeedback; 

  AgentResponse({
    required this.query,
    required this.unifiedAnswer,
    required this.kbAId,
    required this.kbBId,
    required this.kbAHasData,
    required this.kbBHasData,
    this.selectedFeedback = 0,
  });

  /// Decodes your live Lambda JSON keys dynamically into typed values
  factory AgentResponse.fromJson(String userQuery, Map<String, dynamic> json) {
    final tracking = json['feedback_tracking'] as Map<String, dynamic>? ?? {};
    
    final rawAnswer = json['answer'] as String? ?? 'No response generated.';
    final cleanAnswer = rawAnswer.replaceAll('\\n', '\n');

    return AgentResponse(
      query: userQuery,
      unifiedAnswer: cleanAnswer,
      kbAId: tracking['kb_a_id'] as String? ?? 'KB_ALPHA',
      kbBId: tracking['kb_b_id'] as String? ?? 'KB_BETA',
      kbAHasData: tracking['kb_a_has_data'] as bool? ?? false, 
      kbBHasData: tracking['kb_b_has_data'] as bool? ?? false, 
    );
  }
}
