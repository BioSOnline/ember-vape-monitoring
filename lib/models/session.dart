class Session {
  final String id;
  final String userId;
  final DateTime startedAt;
  DateTime? endedAt;
  int puffCount;
  double? avgIntervalSec;

  Session({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.puffCount = 0,
    this.avgIntervalSec,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      puffCount: json['puff_count'] as int? ?? 0,
      avgIntervalSec: json['avg_interval_sec'] != null
          ? (json['avg_interval_sec'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'puff_count': puffCount,
      'avg_interval_sec': avgIntervalSec,
    };
  }

  double? get durationMinutes {
    if (endedAt == null) return null;
    return endedAt!.difference(startedAt).inSeconds / 60.0;
  }

  bool get isActive => endedAt == null;

  void incrementPuff() {
    puffCount++;
  }

  void calculateAvgInterval(List<DateTime> puffTimestamps) {
    if (puffTimestamps.length < 2) {
      avgIntervalSec = null;
      return;
    }

    double totalInterval = 0;
    for (int i = 1; i < puffTimestamps.length; i++) {
      totalInterval += puffTimestamps[i]
          .difference(puffTimestamps[i - 1])
          .inSeconds
          .toDouble();
    }
    avgIntervalSec = totalInterval / (puffTimestamps.length - 1);
  }

  Session copyWith({
    String? id,
    String? userId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? puffCount,
    double? avgIntervalSec,
  }) {
    return Session(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      puffCount: puffCount ?? this.puffCount,
      avgIntervalSec: avgIntervalSec ?? this.avgIntervalSec,
    );
  }
}
