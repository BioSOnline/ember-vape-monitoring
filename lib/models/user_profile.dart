class UserProfile {
  final String id;
  final DateTime createdAt;
  int? dailyPuffGoal;
  int? baselinePuffsPerDay;
  int? yearsSmokedOrVaped;
  String? productType;
  String? preferredStrategy;
  String? primaryTrigger;

  UserProfile({
    required this.id,
    required this.createdAt,
    this.dailyPuffGoal,
    this.baselinePuffsPerDay,
    this.yearsSmokedOrVaped,
    this.productType,
    this.preferredStrategy,
    this.primaryTrigger,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      dailyPuffGoal: json['daily_puff_goal'] as int?,
      baselinePuffsPerDay: json['baseline_puffs_per_day'] as int?,
      yearsSmokedOrVaped: json['years_smoked'] as int?,
      productType: json['product_type'] as String?,
      preferredStrategy: json['preferred_strategy'] as String?,
      primaryTrigger: json['primary_trigger'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'daily_puff_goal': dailyPuffGoal,
      'baseline_puffs_per_day': baselinePuffsPerDay,
      'years_smoked': yearsSmokedOrVaped,
    };
    if (productType != null) map['product_type'] = productType;
    if (preferredStrategy != null) map['preferred_strategy'] = preferredStrategy;
    if (primaryTrigger != null) map['primary_trigger'] = primaryTrigger;
    return map;
  }

  bool get hasCompletedOnboarding {
    return baselinePuffsPerDay != null && yearsSmokedOrVaped != null;
  }

  double get profileCompletionPercentage {
    int total = 6;
    int filled = 0;
    if (baselinePuffsPerDay != null) filled++;
    if (yearsSmokedOrVaped != null) filled++;
    if (dailyPuffGoal != null) filled++;
    if (productType != null && productType!.isNotEmpty) filled++;
    if (preferredStrategy != null && preferredStrategy!.isNotEmpty) filled++;
    if (primaryTrigger != null && primaryTrigger!.isNotEmpty) filled++;
    return filled / total;
  }

  UserProfile copyWith({
    String? id,
    DateTime? createdAt,
    int? dailyPuffGoal,
    int? baselinePuffsPerDay,
    int? yearsSmokedOrVaped,
    String? productType,
    String? preferredStrategy,
    String? primaryTrigger,
  }) {
    return UserProfile(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      dailyPuffGoal: dailyPuffGoal ?? this.dailyPuffGoal,
      baselinePuffsPerDay: baselinePuffsPerDay ?? this.baselinePuffsPerDay,
      yearsSmokedOrVaped: yearsSmokedOrVaped ?? this.yearsSmokedOrVaped,
      productType: productType ?? this.productType,
      preferredStrategy: preferredStrategy ?? this.preferredStrategy,
      primaryTrigger: primaryTrigger ?? this.primaryTrigger,
    );
  }
}
