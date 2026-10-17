import 'dart:math';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';
import 'package:ember/models/addiction_score.dart';
import 'package:uuid/uuid.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  final _uuid = const Uuid();

  // Requires at least 3 days of data to produce a meaningful classification.
  Future<AddictionScore?> calculateAddictionScore({
    required String userId,
    required List<PuffEvent> puffEvents,
    required List<Session> sessions,
  }) async {
    try {
      final daysCovered = _daysCovered(puffEvents);
      if (daysCovered < AppConstants.minDaysForAddictionScore) {
        Logger.warning('Insufficient data for addiction score: $daysCovered days (need ${AppConstants.minDaysForAddictionScore})');
        return null;
      }

      final features = _extractAddictionFeatures(puffEvents, sessions);
      final score = _runDecisionTree(features);

      Logger.info('Addiction score: ${score.level} (${score.scoreValue})');
      return score;
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate addiction score', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Predicts remaining minutes until the next craving window using Multivariate Linear Regression.
  // Adapts gracefully: uses historical session gaps and trends to forecast the next craving window.
  Future<int?> predictNextCravingMinutes({
    required List<PuffEvent> puffEvents,
    required List<Session> sessions,
  }) async {
    try {
      if (sessions.isEmpty && puffEvents.length < 2) {
        Logger.warning('Insufficient session data for craving prediction');
        return null;
      }

      final features = _extractCravingFeatures(puffEvents, sessions);
      final predictedMinutes = _runLinearRegression(features);

      Logger.info('Predicted craving in $predictedMinutes minutes (features: gaps=${features.interSessionGapsMinutes.length}, sinceLast=${features.timeSinceLastSessionMinutes.round()}m, trend=${features.dailyPuffTrend.toStringAsFixed(2)})');
      return predictedMinutes;
    } catch (e, stackTrace) {
      Logger.error('Failed to predict craving', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, double> _extractAddictionFeatures(
    List<PuffEvent> puffEvents,
    List<Session> sessions,
  ) {
    final days = _daysCovered(puffEvents);
    final dailyPuffCount = puffEvents.length / days;
    final sessionFrequency = sessions.length / days;

    double totalInterval = 0;
    int intervalCount = 0;
    for (final session in sessions) {
      if (session.avgIntervalSec != null) {
        totalInterval += session.avgIntervalSec!;
        intervalCount++;
      }
    }
    // Convert seconds to minutes for the decision tree thresholds (default to neutral 60m if no interval data).
    final avgInterPuffInterval = intervalCount > 0 ? totalInterval / intervalCount / 60 : 60.0;

    // Puffs logged during overnight hours (10 PM to 6 AM) — elevated night ratio is a strong addiction signal.
    final nightPuffs = puffEvents.where((p) => p.detectedAt.hour >= 22 || p.detectedAt.hour < 6).length;
    final nightPuffRatio = puffEvents.isNotEmpty ? nightPuffs / puffEvents.length : 0.0;

    return {
      'daily_puff_count': dailyPuffCount,
      'session_frequency': sessionFrequency,
      'avg_inter_puff_interval': avgInterPuffInterval,
      'night_puff_ratio': nightPuffRatio,
    };
  }

  AddictionScore _runDecisionTree(Map<String, double> features) {
    final dailyPuffs = features['daily_puff_count']!;
    final nightRatio = features['night_puff_ratio']!;
    final interval = features['avg_inter_puff_interval']!;

    final String level;
    final double scoreValue;
    final String topFeature;

    if (dailyPuffs > 30 || nightRatio > 0.3) {
      level = AppConstants.addictionLevelHigh;
      scoreValue = 75 + (nightRatio * 25);
      topFeature = nightRatio > 0.3 ? 'High night puff ratio' : 'High daily puff count';
    } else if (dailyPuffs > 15 || (interval > 0 && interval < 15)) {
      level = AppConstants.addictionLevelModerate;
      scoreValue = 50 + (dailyPuffs / 30 * 25);
      topFeature = (interval > 0 && interval < 15) ? 'Short inter-puff intervals' : 'Moderate daily puff count';
    } else {
      level = AppConstants.addictionLevelLow;
      scoreValue = dailyPuffs * 2;
      topFeature = 'Low usage patterns';
    }

    return AddictionScore(
      id: _uuid.v4(),
      userId: '', // Caller is responsible for setting the userId before persisting.
      scoredAt: DateTime.now(),
      level: level,
      scoreValue: scoreValue.clamp(0, 100),
      topFeature: topFeature,
    );
  }

  ({
    List<double> interSessionGapsMinutes,
    double timeSinceLastSessionMinutes,
    double dayOfWeek,
    double dailyPuffTrend,
    double gapTrend,
  }) _extractCravingFeatures(
    List<PuffEvent> puffEvents,
    List<Session> sessions,
  ) {
    // Sort sessions chronologically (oldest to newest)
    final sortedSessions = List<Session>.from(sessions)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    // Calculate real gaps between consecutive sessions in minutes
    final List<double> interSessionGaps = [];
    for (int i = 1; i < sortedSessions.length; i++) {
      final prevEnd = sortedSessions[i - 1].endedAt ?? sortedSessions[i - 1].startedAt;
      final gapMin = sortedSessions[i].startedAt.difference(prevEnd).inMinutes.toDouble();
      // Filter realistic daytime gaps (10 min to 360 min)
      if (gapMin >= 10 && gapMin <= 360) {
        interSessionGaps.add(gapMin);
      }
    }

    // Time since last session ended or last puff
    final lastSession = sortedSessions.isNotEmpty ? sortedSessions.last : null;
    final lastActivity = lastSession?.endedAt ??
        (puffEvents.isNotEmpty
            ? puffEvents.map((e) => e.detectedAt).reduce((a, b) => a.isAfter(b) ? a : b)
            : DateTime.now());
    final timeSinceLastSession = DateTime.now()
        .difference(lastActivity)
        .inMinutes
        .toDouble()
        .clamp(0.0, 720.0);

    final dayOfWeek = (DateTime.now().weekday - 1).toDouble();
    final dailyPuffTrend = _calculateTrend(puffEvents, 7);

    // OLS slope on recent session gaps to see if cravings are accelerating
    double gapTrend = 0.0;
    if (interSessionGaps.length >= 3) {
      final recentGaps = interSessionGaps.sublist(
        interSessionGaps.length - min(interSessionGaps.length, 5),
      );
      final n = recentGaps.length.toDouble();
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (int i = 0; i < recentGaps.length; i++) {
        final x = i.toDouble();
        final y = recentGaps[i];
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumX2 += x * x;
      }
      final denom = (n * sumX2 - sumX * sumX);
      if (denom != 0) {
        gapTrend = (n * sumXY - sumX * sumY) / denom;
      }
    }

    return (
      interSessionGapsMinutes: interSessionGaps,
      timeSinceLastSessionMinutes: timeSinceLastSession,
      dayOfWeek: dayOfWeek,
      dailyPuffTrend: dailyPuffTrend,
      gapTrend: gapTrend,
    );
  }

  int _runLinearRegression(({
    List<double> interSessionGapsMinutes,
    double timeSinceLastSessionMinutes,
    double dayOfWeek,
    double dailyPuffTrend,
    double gapTrend,
  }) features) {
    // Baseline mean session gap (defaults to 75 minutes if initial dataset is small)
    final meanGap = features.interSessionGapsMinutes.isEmpty
        ? 75.0
        : features.interSessionGapsMinutes.reduce((a, b) => a + b) /
            features.interSessionGapsMinutes.length;

    // Multivariate Linear Regression equation:
    // y_hat = beta0 + beta1 * meanGap + beta2 * gapTrend + beta3 * dailyTrend
    // beta0: 10.0 (baseline refractory minimum)
    // beta1: 0.85 (weight of historical session cycle)
    // beta2: 1.20 (if gaps are expanding/positive slope, next interval expands; if shortening, interval contracts)
    // beta3: -3.0 (if daily puffs are increasing, cravings accelerate)
    final predictedCycleMinutes = 10.0 +
        (0.85 * meanGap) +
        (1.20 * features.gapTrend) -
        (3.0 * features.dailyPuffTrend);

    // Remaining minutes until craving window hits
    final remainingMinutes = predictedCycleMinutes - features.timeSinceLastSessionMinutes;
    return remainingMinutes.clamp(5, 240).round();
  }

  int _daysCovered(List<PuffEvent> events) {
    if (events.isEmpty) return 0;
    final uniqueDays = events.map((e) {
      final d = e.detectedAt;
      return DateTime(d.year, d.month, d.day);
    }).toSet();
    return uniqueDays.length;
  }

  double _calculateTrend(List<PuffEvent> events, int days) {
    if (events.length < days) return 0;

    final dailyCounts = <DateTime, int>{};
    for (final event in events) {
      final d = event.detectedAt;
      final date = DateTime(d.year, d.month, d.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    if (dailyCounts.length < 2) return 0;

    // Ordinary least-squares slope over the sorted day sequence.
    final sortedDates = dailyCounts.keys.toList()..sort();
    final n = sortedDates.length.toDouble();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < sortedDates.length; i++) {
      final x = i.toDouble();
      final y = dailyCounts[sortedDates[i]]!.toDouble();
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  }
}
