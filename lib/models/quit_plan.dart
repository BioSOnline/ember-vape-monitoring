import 'dart:math';
import 'package:ember/models/user_profile.dart';

/// Supported smoking and vaping quit strategies
enum QuitStrategyType {
  gradualReduction(
    'gradual_reduction',
    'Gradual 10% Weekly Step-Down',
    'Automatically lowers your daily puff ceiling by 10% every Monday and widens your inter-puff intervals.',
  ),
  coldTurkey(
    'cold_turkey',
    'Cold Turkey (Immediate Cessation)',
    'Targets 0 puffs immediately with maximal craving-relief exercises and mindful delay techniques.',
  ),
  targetQuitDate(
    'target_quit_date',
    'Target Quit Date',
    'Calculates an automated weekly Monday step-down schedule towards your target smoke-free date.',
  ),
  customGoal(
    'custom',
    'Custom Fixed Goal',
    'A constant user-defined daily puff ceiling without automated tapering.',
  );

  final String code;
  final String title;
  final String description;

  const QuitStrategyType(this.code, this.title, this.description);

  static QuitStrategyType fromCode(String? code) {
    if (code == null) return QuitStrategyType.gradualReduction;
    for (final type in QuitStrategyType.values) {
      if (type.code == code || type.name == code) return type;
    }
    return QuitStrategyType.gradualReduction;
  }
}

/// A single week's tapering milestone for schedule previews
class WeeklyMilestone {
  final int weekNumber;
  final DateTime weekStartDate;
  final int dailyCeiling;
  final int targetIntervalMinutes;
  final bool isCurrentWeek;

  const WeeklyMilestone({
    required this.weekNumber,
    required this.weekStartDate,
    required this.dailyCeiling,
    required this.targetIntervalMinutes,
    required this.isCurrentWeek,
  });
}

/// Comprehensive personalized tapering and step-down quit plan
class QuitPlan {
  final QuitStrategyType strategyType;
  final DateTime planStartDate;
  final DateTime? targetQuitDate;
  final double weeklyReductionPercent; // e.g., 10.0%
  final int baselinePuffs;
  final int? customDailyGoal;

  const QuitPlan({
    required this.strategyType,
    required this.planStartDate,
    this.targetQuitDate,
    this.weeklyReductionPercent = 10.0,
    required this.baselinePuffs,
    this.customDailyGoal,
  });

  factory QuitPlan.fromProfile(UserProfile profile, {DateTime? now}) {
    final start = profile.planStartDate ?? profile.createdAt;
    final strategy = QuitStrategyType.fromCode(profile.quitStrategy);
    final baseline = profile.baselinePuffsPerDay ?? 20;

    return QuitPlan(
      strategyType: strategy,
      planStartDate: start,
      targetQuitDate: profile.targetQuitDate,
      weeklyReductionPercent: profile.weeklyReductionRate ?? 10.0,
      baselinePuffs: baseline,
      customDailyGoal: profile.dailyPuffGoal,
    );
  }

  /// Calculates the exact number of calendar Mondays that have passed between [start] and [current].
  /// This ensures that the user's plan transitions on Monday morning local time.
  static int calculateMondaysElapsed(DateTime start, DateTime current) {
    final s = DateTime(start.year, start.month, start.day);
    final c = DateTime(current.year, current.month, current.day);
    if (c.isBefore(s)) return 0;

    // Normalize to the Monday of the respective weeks
    final startMonday = s.subtract(Duration(days: s.weekday - DateTime.monday));
    final currentMonday = c.subtract(Duration(days: c.weekday - DateTime.monday));

    final diffDays = currentMonday.difference(startMonday).inDays;
    final weeks = diffDays ~/ 7;
    return weeks < 0 ? 0 : weeks;
  }

  /// Calculates the active daily puff ceiling for the given date.
  int calculateCurrentDailyCeiling({DateTime? atDate}) {
    final now = atDate ?? DateTime.now();

    switch (strategyType) {
      case QuitStrategyType.coldTurkey:
        return 0;

      case QuitStrategyType.customGoal:
        return customDailyGoal ?? baselinePuffs;

      case QuitStrategyType.gradualReduction:
        final mondays = calculateMondaysElapsed(planStartDate, now);
        final reductionRatio = (weeklyReductionPercent / 100.0) * mondays;
        final target = (baselinePuffs * (1.0 - reductionRatio)).ceil();
        return max(0, target);

      case QuitStrategyType.targetQuitDate:
        if (targetQuitDate == null) return baselinePuffs;

        final targetMidnight = DateTime(targetQuitDate!.year, targetQuitDate!.month, targetQuitDate!.day);
        final nowMidnight = DateTime(now.year, now.month, now.day);
        if (nowMidnight.isAfter(targetMidnight) || nowMidnight.isAtSameMomentAs(targetMidnight)) {
          return 0;
        }

        final totalDays = targetMidnight.difference(DateTime(planStartDate.year, planStartDate.month, planStartDate.day)).inDays;
        if (totalDays <= 0) return 0;

        final totalWeeks = max(1, (totalDays / 7.0).ceil());
        final mondays = calculateMondaysElapsed(planStartDate, now);
        if (mondays >= totalWeeks) return 0;

        final remainingFraction = 1.0 - (mondays / totalWeeks);
        final target = (baselinePuffs * remainingFraction).ceil();
        return max(0, target);
    }
  }

  /// Calculates the ceiling that was active the previous week (for Monday adjustment comparisons).
  int calculatePreviousWeekCeiling({DateTime? atDate}) {
    final now = atDate ?? DateTime.now();
    final mondays = calculateMondaysElapsed(planStartDate, now);
    if (mondays == 0) return baselinePuffs;

    final prevMonday = now.subtract(const Duration(days: 7));
    return calculateCurrentDailyCeiling(atDate: prevMonday);
  }

  /// Calculates the recommended minimum inter-puff session interval in minutes.
  /// As daily puffs decrease, the interval between sessions widens to retrain dopamine receptors.
  int calculateTargetIntervalMinutes({DateTime? atDate}) {
    final now = atDate ?? DateTime.now();

    switch (strategyType) {
      case QuitStrategyType.coldTurkey:
        return 9999; // Complete abstinence target

      case QuitStrategyType.gradualReduction:
        final baseInterval = ((16 * 60) / max(1, baselinePuffs)).round().clamp(30, 120);
        final mondays = calculateMondaysElapsed(planStartDate, now);
        final expansion = mondays * 15; // Expands by 15 minutes each Monday
        return (baseInterval + expansion).clamp(30, 240);

      case QuitStrategyType.targetQuitDate:
        final ceiling = calculateCurrentDailyCeiling(atDate: now);
        if (ceiling <= 0) return 9999;
        return ((16 * 60) / ceiling).round().clamp(30, 240);

      case QuitStrategyType.customGoal:
        final goal = customDailyGoal ?? baselinePuffs;
        if (goal <= 0) return 9999;
        return ((16 * 60) / goal).round().clamp(30, 240);
    }
  }

  /// Returns true if the evaluated date is a Monday (the weekly step-down adjustment day).
  bool isMondayAdjustmentDay({DateTime? atDate}) {
    final now = atDate ?? DateTime.now();
    return now.weekday == DateTime.monday;
  }

  /// Returns the number of days until the next Monday step-down (1 to 7).
  int daysUntilNextMonday({DateTime? atDate}) {
    final now = atDate ?? DateTime.now();
    if (now.weekday == DateTime.monday) return 7;
    return 8 - now.weekday;
  }

  /// Current week index in the plan (1-based: Week 1, Week 2, etc.)
  int currentWeekNumber({DateTime? atDate}) {
    final now = atDate ?? DateTime.now();
    return calculateMondaysElapsed(planStartDate, now) + 1;
  }

  /// Progress towards the final smoke-free goal (0.0 to 1.0).
  double planProgressPercentage({DateTime? atDate}) {
    if (baselinePuffs <= 0) return 1.0;
    final currentCeiling = calculateCurrentDailyCeiling(atDate: atDate);
    final progress = (baselinePuffs - currentCeiling) / baselinePuffs;
    return progress.clamp(0.0, 1.0);
  }

  /// Returns true if the user has reached the 0-puff smoke-free target.
  bool isCompleted({DateTime? atDate}) {
    return calculateCurrentDailyCeiling(atDate: atDate) == 0;
  }

  /// Generates a preview list of weekly milestones from Week 1 until completion or [maxWeeks].
  List<WeeklyMilestone> generateWeeklySchedule({int maxWeeks = 10, DateTime? atDate}) {
    final now = atDate ?? DateTime.now();
    final currentWeek = currentWeekNumber(atDate: now);
    final List<WeeklyMilestone> milestones = [];

    // First Monday of the plan
    final s = DateTime(planStartDate.year, planStartDate.month, planStartDate.day);
    final startMonday = s.subtract(Duration(days: s.weekday - DateTime.monday));

    for (int i = 0; i < maxWeeks; i++) {
      final weekStartDate = startMonday.add(Duration(days: i * 7));
      final ceiling = calculateCurrentDailyCeiling(atDate: weekStartDate);
      final interval = calculateTargetIntervalMinutes(atDate: weekStartDate);
      final weekNum = i + 1;

      milestones.add(
        WeeklyMilestone(
          weekNumber: weekNum,
          weekStartDate: weekStartDate,
          dailyCeiling: ceiling,
          targetIntervalMinutes: interval,
          isCurrentWeek: weekNum == currentWeek,
        ),
      );

      if (ceiling == 0 && strategyType != QuitStrategyType.customGoal) {
        break; // Stop after hitting smoke-free week
      }
    }

    return milestones;
  }

  Map<String, dynamic> toJson() {
    return {
      'strategy_type': strategyType.code,
      'plan_start_date': planStartDate.toIso8601String(),
      'target_quit_date': targetQuitDate?.toIso8601String(),
      'weekly_reduction_percent': weeklyReductionPercent,
      'baseline_puffs': baselinePuffs,
      'custom_daily_goal': customDailyGoal,
    };
  }

  factory QuitPlan.fromJson(Map<String, dynamic> json) {
    return QuitPlan(
      strategyType: QuitStrategyType.fromCode(json['strategy_type'] as String?),
      planStartDate: DateTime.parse(json['plan_start_date'] as String),
      targetQuitDate: json['target_quit_date'] != null
          ? DateTime.tryParse(json['target_quit_date'] as String)
          : null,
      weeklyReductionPercent: (json['weekly_reduction_percent'] as num?)?.toDouble() ?? 10.0,
      baselinePuffs: (json['baseline_puffs'] as int?) ?? 20,
      customDailyGoal: json['custom_daily_goal'] as int?,
    );
  }
}
