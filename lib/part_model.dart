import 'dart:typed_data';

class KbSource {
  final String kbModel;
  final String text;
  final double score;
  final String sourceUri;
  final String? s3ImageUriPresigned;
  final String? s3PresignedUrl;

  KbSource({
    required this.kbModel,
    required this.text,
    required this.score,
    required this.sourceUri,
    this.s3ImageUriPresigned,
    this.s3PresignedUrl,
  });

  factory KbSource.fromJson(Map<String, dynamic> json) {
    return KbSource(
      kbModel: json['kb_model'] as String? ?? 'Unknown',
      text: (json['text'] as String? ?? '').replaceAll('\\n', '\n'),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      sourceUri: json['source_uri'] as String? ?? 'Unknown Source',
      s3ImageUriPresigned: json['s3_image_uri_presigned'] as String?,
      s3PresignedUrl: json['s3_presigned_url'] as String?,
    );
  }
}

class AgentResponse {
  final String query;
  final String unifiedAnswer;
  final String kbAId;
  final String kbBId;
  final bool kbAHasData;
  final bool kbBHasData;
  int selectedFeedback;
  final List<Uint8List>? attachedImages;
  final List<KbSource> sources;
  final String? s3ImageUriPresigned;
  final String? kbModel;
  final double? processingTimeSeconds;

  AgentResponse({
    required this.query,
    required this.unifiedAnswer,
    required this.kbAId,
    required this.kbBId,
    required this.kbAHasData,
    required this.kbBHasData,
    this.selectedFeedback = 0,
    this.attachedImages,
    required this.sources,
    this.s3ImageUriPresigned,
    this.kbModel,
    this.processingTimeSeconds,
  });

  /// Decodes your live Lambda JSON keys dynamically into typed values
  factory AgentResponse.fromJson(
    String userQuery,
    Map<String, dynamic> json, {
    List<Uint8List>? attachedImages,
    double? processingTimeSeconds,
  }) {
    final tracking = json['feedback_tracking'] as Map<String, dynamic>? ?? {};

    final rawAnswer = json['answer'] as String? ?? 'No response generated.';
    final cleanAnswer = rawAnswer.replaceAll('\\n', '\n');

    final rawSources = json['sources'] as List<dynamic>? ?? [];
    final List<KbSource> parsedSources = rawSources
        .map((s) => KbSource.fromJson(s as Map<String, dynamic>))
        .toList();

    return AgentResponse(
      query: userQuery,
      unifiedAnswer: cleanAnswer,
      kbAId: tracking['kb_a_id'] as String? ?? 'KB_ALPHA',
      kbBId: tracking['kb_b_id'] as String? ?? 'KB_BETA',
      kbAHasData: tracking['kb_a_has_data'] as bool? ?? false,
      kbBHasData: tracking['kb_b_has_data'] as bool? ?? false,
      attachedImages: attachedImages,
      sources: parsedSources,
      s3ImageUriPresigned:
          json['s3_image_uri_presigned'] as String? ??
          tracking['s3_image_uri_presigned'] as String?,
      kbModel: json['kb_model'] as String? ?? tracking['kb_model'] as String?,
      processingTimeSeconds: processingTimeSeconds,
    );
  }
}
