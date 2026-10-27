import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/quit_plan.dart';
import 'package:ember/models/user_profile.dart';

void main() {
  group('QuitPlan Calendar & Monday Transition Tests', () {
    test('calculateMondaysElapsed accurately counts Monday transitions across weeks', () {
      // Start on Wednesday, Nov 4, 2026
      final start = DateTime(2026, 11, 4, 14, 30);

      // Same week Thursday (Nov 5) -> 0 Mondays
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 5)), 0);

      // Same week Sunday (Nov 8) -> 0 Mondays
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 8, 23, 59)), 0);

      // Next Monday (Nov 9) -> 1 Monday elapsed (Week 2 starts)
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 9, 0, 1)), 1);

      // Next Wednesday (Nov 11) -> 1 Monday elapsed
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 11)), 1);

      // Next Sunday (Nov 15) -> 1 Monday elapsed
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 15, 22, 0)), 1);

      // Two Mondays later (Nov 16) -> 2 Mondays elapsed (Week 3 starts)
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 16)), 2);

      // 10 Mondays later (Jan 11, 2027)
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2027, 1, 11)), 10);

      // Future/Past boundary: past date returns 0
      expect(QuitPlan.calculateMondaysElapsed(start, DateTime(2026, 11, 1)), 0);
    });

    test('isMondayAdjustmentDay and daysUntilNextMonday return correct calendar values', () {
      final monday = DateTime(2026, 11, 9); // Monday
      final tuesday = DateTime(2026, 11, 10); // Tuesday
      final friday = DateTime(2026, 11, 13); // Friday
      final sunday = DateTime(2026, 11, 15); // Sunday

      final plan = QuitPlan(
        strategyType: QuitStrategyType.gradualReduction,
        planStartDate: DateTime(2026, 11, 2),
        baselinePuffs: 20,
      );

      // Monday checks
      expect(plan.isMondayAdjustmentDay(atDate: monday), isTrue);
      expect(plan.daysUntilNextMonday(atDate: monday), 7);

      // Tuesday checks
      expect(plan.isMondayAdjustmentDay(atDate: tuesday), isFalse);
      expect(plan.daysUntilNextMonday(atDate: tuesday), 6);

      // Friday checks
      expect(plan.isMondayAdjustmentDay(atDate: friday), isFalse);
      expect(plan.daysUntilNextMonday(atDate: friday), 3);

      // Sunday checks
      expect(plan.isMondayAdjustmentDay(atDate: sunday), isFalse);
      expect(plan.daysUntilNextMonday(atDate: sunday), 1);
    });
  });

  group('Gradual 10% Weekly Step-Down Strategy Tests', () {
    test('Steps down baseline puffs by 10% every Monday', () {
      final start = DateTime(2026, 11, 2); // Monday
      final plan = QuitPlan(
        strategyType: QuitStrategyType.gradualReduction,
        planStartDate: start,
        baselinePuffs: 20,
        weeklyReductionPercent: 10.0,
      );

      // Week 1 (Nov 2 - Nov 8): 0% reduction -> 20 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 2)), 20);
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 8)), 20);
      expect(plan.currentWeekNumber(atDate: DateTime(2026, 11, 5)), 1);

      // Week 2 (Nov 9 - Nov 15): 10% reduction -> 18 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 9)), 18);
      expect(plan.calculatePreviousWeekCeiling(atDate: DateTime(2026, 11, 9)), 20);
      expect(plan.currentWeekNumber(atDate: DateTime(2026, 11, 9)), 2);

      // Week 3 (Nov 16 - Nov 22): 20% reduction -> 16 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 16)), 16);
      expect(plan.currentWeekNumber(atDate: DateTime(2026, 11, 16)), 3);

      // Week 4 (Nov 23): 30% reduction -> 14 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 23)), 14);

      // Week 11 (10 Mondays later, Jan 11, 2027): 100% reduction -> 0 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2027, 1, 11)), 0);
      expect(plan.isCompleted(atDate: DateTime(2027, 1, 11)), isTrue);

      // Week 15: remains clamped at 0
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2027, 2, 8)), 0);
    });

    test('Widens inter-puff session intervals progressively each Monday', () {
      final start = DateTime(2026, 11, 2); // Monday
      final plan = QuitPlan(
        strategyType: QuitStrategyType.gradualReduction,
        planStartDate: start,
        baselinePuffs: 20,
      );

      // Week 1 baseline interval: (16 * 60) / 20 = 48 minutes
      final w1Interval = plan.calculateTargetIntervalMinutes(atDate: DateTime(2026, 11, 2));
      expect(w1Interval, 48);

      // Week 2 (1 Monday later): +15m expansion -> 63 minutes
      final w2Interval = plan.calculateTargetIntervalMinutes(atDate: DateTime(2026, 11, 9));
      expect(w2Interval, 63);

      // Week 3 (2 Mondays later): +30m expansion -> 78 minutes
      final w3Interval = plan.calculateTargetIntervalMinutes(atDate: DateTime(2026, 11, 16));
      expect(w3Interval, 78);
    });

    test('Generates preview schedule with weekly milestones', () {
      final plan = QuitPlan(
        strategyType: QuitStrategyType.gradualReduction,
        planStartDate: DateTime(2026, 11, 2),
        baselinePuffs: 20,
      );

      final schedule = plan.generateWeeklySchedule(maxWeeks: 12, atDate: DateTime(2026, 11, 2));
      expect(schedule.isNotEmpty, isTrue);
      expect(schedule.first.weekNumber, 1);
      expect(schedule.first.dailyCeiling, 20);
      expect(schedule.first.isCurrentWeek, isTrue);

      // Finds the smoke-free week where ceiling hits 0
      final smokeFreeMilestone = schedule.last;
      expect(smokeFreeMilestone.dailyCeiling, 0);
    });
  });

  group('Cold Turkey Strategy Tests', () {
    test('Targets 0 puffs immediately from day one', () {
      final plan = QuitPlan(
        strategyType: QuitStrategyType.coldTurkey,
        planStartDate: DateTime(2026, 11, 2),
        baselinePuffs: 20,
      );

      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 2)), 0);
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 20)), 0);
      expect(plan.calculateTargetIntervalMinutes(), 9999);
      expect(plan.planProgressPercentage(), 1.0);
      expect(plan.isCompleted(), isTrue);
    });
  });

  group('Target Quit Date Strategy Tests', () {
    test('Tapers smoothly to reach zero by target quit date', () {
      final start = DateTime(2026, 11, 2); // Monday
      final quitDate = DateTime(2026, 11, 30); // 4 weeks later (28 days)

      final plan = QuitPlan(
        strategyType: QuitStrategyType.targetQuitDate,
        planStartDate: start,
        targetQuitDate: quitDate,
        baselinePuffs: 20,
      );

      // Week 1: ~20 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 2)), 20);

      // Week 2: ~15 puffs (1/4 done)
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 9)), 15);

      // Week 3: ~10 puffs (2/4 done)
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 16)), 10);

      // On or after target quit date: 0 puffs
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 11, 30)), 0);
      expect(plan.calculateCurrentDailyCeiling(atDate: DateTime(2026, 12, 5)), 0);
    });
  });

  group('UserProfile Integration & Serialization Tests', () {
    test('UserProfile seamlessly derives QuitPlan and calculates effective goals', () {
      final profile = UserProfile(
        id: 'user-123',
        createdAt: DateTime(2026, 11, 2),
        baselinePuffsPerDay: 20,
        yearsSmokedOrVaped: 3,
        quitStrategy: 'gradual_reduction',
        planStartDate: DateTime(2026, 11, 2),
      );

      expect(profile.quitPlan.strategyType, QuitStrategyType.gradualReduction);
      expect(profile.effectiveDailyGoal, 20); // Week 1 ceiling
      expect(profile.targetIntervalMinutes, 48);

      // JSON roundtrip
      final json = profile.toJson();
      expect(json['quit_strategy'], 'gradual_reduction');
      expect(json['plan_start_date'], isNotNull);

      final restored = UserProfile.fromJson(json);
      expect(restored.quitStrategy, 'gradual_reduction');
      expect(restored.effectiveDailyGoal, 20);

      // Base JSON for legacy schema fallback excludes quit plan fields
      final baseJson = profile.toBaseJson();
      expect(baseJson.containsKey('quit_strategy'), isFalse);
      expect(baseJson.containsKey('plan_start_date'), isFalse);
      expect(baseJson['baseline_puffs_per_day'], 20);
    });

    test('Custom goal fallback works when quit strategy is null but dailyPuffGoal is set', () {
      final profile = UserProfile(
        id: 'legacy-user',
        createdAt: DateTime(2026, 1, 1),
        baselinePuffsPerDay: 25,
        dailyPuffGoal: 12,
        quitStrategy: 'custom',
      );

      expect(profile.quitPlan.strategyType, QuitStrategyType.customGoal);
      expect(profile.effectiveDailyGoal, 12);
    });
  });
}
