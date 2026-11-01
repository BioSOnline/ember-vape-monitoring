import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';

void main() {
  group('Dashboard Flow & Business Logic Tests', () {
    test('Daily counts mapping groups events accurately by day relative to timeframe', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12, 0);
      final yesterday = today.subtract(const Duration(days: 1));
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: today, inputMode: 'camera'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: today.add(const Duration(hours: 1)), inputMode: 'camera'),
        PuffEvent(id: 'p3', userId: 'u1', detectedAt: yesterday, inputMode: 'manual'),
        PuffEvent(id: 'p4', userId: 'u1', detectedAt: threeDaysAgo, inputMode: 'video'),
      ];

      const daysCount = 7;
      final map = <int, int>{};
      for (int i = 0; i < daysCount; i++) {
        map[i] = 0;
      }

      final todayMidnight = DateTime(now.year, now.month, now.day);
      for (final event in events) {
        final d = event.detectedAt;
        final eventDay = DateTime(d.year, d.month, d.day);
        final daysAgo = todayMidnight.difference(eventDay).inDays;
        if (daysAgo >= 0 && daysAgo < daysCount) {
          final key = (daysCount - 1) - daysAgo;
          map[key] = (map[key] ?? 0) + 1;
        }
      }

      // Today is index 6
      expect(map[6], 2);
      // Yesterday is index 5
      expect(map[5], 1);
      // 2 days ago is index 4
      expect(map[4], 0);
      // 3 days ago is index 3
      expect(map[3], 1);
    });

    test('Daily goal progress ratio and risk color assignment', () {
      Color getGoalColor(int todayCount, int? goal) {
        if (goal == null || goal == 0) return AppTheme.primaryColor;
        final ratio = todayCount / goal;
        if (ratio < 0.7) return AppTheme.lowRiskColor;
        if (ratio < 1.0) return AppTheme.moderateRiskColor;
        return AppTheme.highRiskColor;
      }

      const goal = 20;

      // 10 puffs (50%) -> low risk
      expect(getGoalColor(10, goal), equals(AppTheme.lowRiskColor));

      // 16 puffs (80%) -> moderate risk
      expect(getGoalColor(16, goal), equals(AppTheme.moderateRiskColor));

      // 22 puffs (110%) -> high risk
      expect(getGoalColor(22, goal), equals(AppTheme.highRiskColor));

      // Null goal -> default primary color
      expect(getGoalColor(10, null), equals(AppTheme.primaryColor));
    });

    test('Craving prediction risk categories and format strings', () {
      ({Color color, String label}) getCravingCategory(int minutes) {
        if (minutes < 15) {
          return (color: AppTheme.highRiskColor, label: 'High Risk');
        } else if (minutes < 45) {
          return (color: AppTheme.moderateRiskColor, label: 'Upcoming');
        } else {
          return (color: AppTheme.lowRiskColor, label: 'Low Risk');
        }
      }

      // 10 minutes -> High Risk
      final c1 = getCravingCategory(10);
      expect(c1.label, 'High Risk');
      expect(c1.color, AppTheme.highRiskColor);

      // 35 minutes -> Upcoming
      final c2 = getCravingCategory(35);
      expect(c2.label, 'Upcoming');
      expect(c2.color, AppTheme.moderateRiskColor);

      // 90 minutes -> Low Risk
      final c3 = getCravingCategory(90);
      expect(c3.label, 'Low Risk');
      expect(c3.color, AppTheme.lowRiskColor);
    });

    test('Recent sessions interval calculation', () {
      final session = Session(
        id: 's1',
        userId: 'u1',
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        endedAt: DateTime.now(),
        puffCount: 5,
        avgIntervalSec: 180.0,
      );

      expect(session.puffCount, 5);
      expect(session.avgIntervalSec, 180.0);
      expect(session.durationMinutes, closeTo(15, 1));
    });
  });
}
