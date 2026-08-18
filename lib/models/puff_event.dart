class PuffEvent {
  final String id;
  final String userId;
  final String? sessionId;
  final DateTime detectedAt;
  final String inputMode; // 'manual' | 'video_upload' | 'live_camera'
  final double? confidenceScore; // null for manual entries

  PuffEvent({
    required this.id,
    required this.userId,
    this.sessionId,
    required this.detectedAt,
    required this.inputMode,
    this.confidenceScore,
  });

  factory PuffEvent.fromJson(Map<String, dynamic> json) {
    return PuffEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as String?,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      inputMode: json['input_mode'] as String,
      confidenceScore: json['confidence_score'] != null
          ? (json['confidence_score'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'detected_at': detectedAt.toIso8601String(),
      'input_mode': inputMode,
      'confidence_score': confidenceScore,
    };
  }

  // Manual entries are always valid; ML-detected ones need a confidence above 50%.
  bool get isValid {
    if (inputMode == 'manual') return true;
    return confidenceScore != null && confidenceScore! > 0.5;
  }

  PuffEvent copyWith({
    String? id,
    String? userId,
    String? sessionId,
    DateTime? detectedAt,
    String? inputMode,
    double? confidenceScore,
  }) {
    return PuffEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      detectedAt: detectedAt ?? this.detectedAt,
      inputMode: inputMode ?? this.inputMode,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}
