class AddictionScore {
  final String id;
  final String userId;
  final DateTime scoredAt;
  final String level; // 'low' | 'moderate' | 'high'
  final double scoreValue; // 0–100
  final String topFeature; // e.g., "High night puff ratio"

  AddictionScore({
    required this.id,
    required this.userId,
    required this.scoredAt,
    required this.level,
    required this.scoreValue,
    required this.topFeature,
  });

  factory AddictionScore.fromJson(Map<String, dynamic> json) {
    return AddictionScore(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      scoredAt: DateTime.parse(json['scored_at'] as String),
      level: json['level'] as String,
      scoreValue: (json['score_value'] as num).toDouble(),
      topFeature: json['top_feature'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'scored_at': scoredAt.toIso8601String(),
      'level': level,
      'score_value': scoreValue,
      'top_feature': topFeature,
    };
  }

  int get levelColor {
    switch (level.toLowerCase()) {
      case 'low':
        return 0xFF4CAF50;
      case 'moderate':
        return 0xFFFFA726;
      case 'high':
        return 0xFFEF5350;
      default:
        return 0xFF9E9E9E;
    }
  }

  String get levelDescription {
    switch (level.toLowerCase()) {
      case 'low':
        return 'You\'re managing well. Keep it up!';
      case 'moderate':
        return 'Your usage shows concerning patterns. Consider reducing.';
      case 'high':
        return 'High addiction risk detected. Please seek support.';
      default:
        return 'Unable to determine addiction level.';
    }
  }

  bool get isValid => scoreValue >= 0 && scoreValue <= 100;

  AddictionScore copyWith({
    String? id,
    String? userId,
    DateTime? scoredAt,
    String? level,
    double? scoreValue,
    String? topFeature,
  }) {
    return AddictionScore(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scoredAt: scoredAt ?? this.scoredAt,
      level: level ?? this.level,
      scoreValue: scoreValue ?? this.scoreValue,
      topFeature: topFeature ?? this.topFeature,
    );
  }
}
