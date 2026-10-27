import 'package:ember/models/quit_plan.dart';

class UserProfile {
  final String id;
  final DateTime createdAt;
  int? dailyPuffGoal;
  int? baselinePuffsPerDay;
  int? yearsSmokedOrVaped;
  String? productType;
  String? preferredStrategy;
  String? primaryTrigger;
  String? quitStrategy;
  DateTime? planStartDate;
  DateTime? targetQuitDate;
  double? weeklyReductionRate;

  UserProfile({
    required this.id,
    required this.createdAt,
    this.dailyPuffGoal,
    this.baselinePuffsPerDay,
    this.yearsSmokedOrVaped,
    this.productType,
    this.preferredStrategy,
    this.primaryTrigger,
    this.quitStrategy,
    this.planStartDate,
    this.targetQuitDate,
    this.weeklyReductionRate,
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
      quitStrategy: json['quit_strategy'] as String?,
      planStartDate: json['plan_start_date'] != null
          ? DateTime.tryParse(json['plan_start_date'] as String)
          : null,
      targetQuitDate: json['target_quit_date'] != null
          ? DateTime.tryParse(json['target_quit_date'] as String)
          : null,
      weeklyReductionRate: (json['weekly_reduction_rate'] as num?)?.toDouble(),
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
    if (quitStrategy != null) map['quit_strategy'] = quitStrategy;
    if (planStartDate != null) map['plan_start_date'] = planStartDate!.toIso8601String();
    if (targetQuitDate != null) map['target_quit_date'] = targetQuitDate!.toIso8601String();
    if (weeklyReductionRate != null) map['weekly_reduction_rate'] = weeklyReductionRate;
    return map;
  }

  /// Returns base fields map that conforms to legacy schema without optional quit plan columns
  Map<String, dynamic> toBaseJson() {
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

  QuitPlan get quitPlan => QuitPlan.fromProfile(this);

  /// Dynamically calculated daily puff ceiling for today based on the active strategy
  int get effectiveDailyGoal => quitPlan.calculateCurrentDailyCeiling();

  /// Recommended minimum inter-puff session interval in minutes
  int get targetIntervalMinutes => quitPlan.calculateTargetIntervalMinutes();

  bool get hasCompletedOnboarding {
    return baselinePuffsPerDay != null && yearsSmokedOrVaped != null;
  }

  double get profileCompletionPercentage {
    int total = 7;
    int filled = 0;
    if (baselinePuffsPerDay != null) filled++;
    if (yearsSmokedOrVaped != null) filled++;
    if (dailyPuffGoal != null || quitStrategy != null) filled++;
    if (productType != null && productType!.isNotEmpty) filled++;
    if (preferredStrategy != null && preferredStrategy!.isNotEmpty) filled++;
    if (primaryTrigger != null && primaryTrigger!.isNotEmpty) filled++;
    if (quitStrategy != null && quitStrategy!.isNotEmpty) filled++;
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
    String? quitStrategy,
    DateTime? planStartDate,
    DateTime? targetQuitDate,
    double? weeklyReductionRate,
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
      quitStrategy: quitStrategy ?? this.quitStrategy,
      planStartDate: planStartDate ?? this.planStartDate,
      targetQuitDate: targetQuitDate ?? this.targetQuitDate,
      weeklyReductionRate: weeklyReductionRate ?? this.weeklyReductionRate,
    );
  }
}
