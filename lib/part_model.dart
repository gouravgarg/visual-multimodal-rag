class AgentResponse {
  final String query;
  final String unifiedAnswer;
  final String kbAId;
  final String kbBId;
  // User feedback tracking: 0 = unvoted, 1 = KB Alpha preferred, 2 = KB Beta preferred
  int selectedPreference; 

  AgentResponse({
    required this.query,
    required this.unifiedAnswer,
    required this.kbAId,
    required this.kbBId,
    this.selectedPreference = 0,
  });

  /// Factory constructor matching your live AWS Lambda JSON response layout structure
  // factory AgentResponse.fromJson(String userQuery, Map<String, dynamic> json) {
  //   final tracking = json['feedback_tracking'] as Map<String, dynamic>? ?? {};
    
  //   return AgentResponse(
  //     query: userQuery,
  //     unifiedAnswer: json['answer'] as String? ?? 'No response generated from the catalog context.',
  //     kbAId: tracking['kb_a_id'] as String? ?? 'KB_ALPHA',
  //     kbBId: tracking['kb_b_id'] as String? ?? 'KB_BETA',
  //   );
  // }

   factory AgentResponse.fromJson(String userQuery, Map<String, dynamic> json) {
    final tracking = json['feedback_tracking'] as Map<String, dynamic>? ?? {};
    
    // 💡 Cleans up unescaped backend line break characters automatically
    final rawAnswer = json['answer'] as String? ?? 'No response generated.';
    final cleanAnswer = rawAnswer.replaceAll('\\n', '\n');

    return AgentResponse(
      query: userQuery,
      unifiedAnswer: cleanAnswer,
      kbAId: tracking['kb_a_id'] as String? ?? 'KB_ALPHA',
      kbBId: tracking['kb_b_id'] as String? ?? 'KB_BETA',
    );
  }
}
