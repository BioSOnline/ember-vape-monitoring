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

  // Requires at least 7 consecutive days of data for reliable regression.
  Future<int?> predictNextCravingMinutes({
    required List<PuffEvent> puffEvents,
    required List<Session> sessions,
  }) async {
    try {
      final daysCovered = _daysCovered(puffEvents);
      if (daysCovered < AppConstants.minDaysForCravingPrediction) {
        Logger.warning('Insufficient data for craving prediction: $daysCovered days (need ${AppConstants.minDaysForCravingPrediction})');
        return null;
      }

      final features = _extractCravingFeatures(puffEvents, sessions);
      final predictedMinutes = _runLinearRegression(features);

      Logger.info('Predicted craving in $predictedMinutes minutes');
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
    // Convert seconds to minutes for the decision tree thresholds.
    final avgInterPuffInterval = intervalCount > 0 ? totalInterval / intervalCount / 60 : 0.0;

    // Puffs logged after 10 PM — elevated night ratio is a strong addiction signal.
    final nightPuffs = puffEvents.where((p) => p.detectedAt.hour >= 22).length;
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
    } else if (dailyPuffs > 15 || interval < 15) {
      level = AppConstants.addictionLevelModerate;
      scoreValue = 50 + (dailyPuffs / 30 * 25);
      topFeature = interval < 15 ? 'Short inter-puff intervals' : 'Moderate daily puff count';
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

  // Returns a mix of typed values; the list entry holds per-session intervals.
  ({List<double> last5Intervals, double timeSinceLastPuff, double dayOfWeek, double dailyPuffTrend})
      _extractCravingFeatures(
    List<PuffEvent> puffEvents,
    List<Session> sessions,
  ) {
    final recentSessions = sessions.take(5).toList();
    final last5Intervals = recentSessions
        .where((s) => s.avgIntervalSec != null)
        .map((s) => s.avgIntervalSec! / 60)
        .toList();

    final lastPuff = puffEvents.isNotEmpty ? puffEvents.first.detectedAt : DateTime.now();
    final timeSinceLastPuff = DateTime.now().difference(lastPuff).inMinutes.toDouble();

    final dayOfWeek = (DateTime.now().weekday - 1).toDouble(); // 0 = Monday
    final dailyPuffTrend = _calculateTrend(puffEvents, 7);

    return (
      last5Intervals: last5Intervals,
      timeSinceLastPuff: timeSinceLastPuff,
      dayOfWeek: dayOfWeek,
      dailyPuffTrend: dailyPuffTrend,
    );
  }

  int _runLinearRegression(
    ({List<double> last5Intervals, double timeSinceLastPuff, double dayOfWeek, double dailyPuffTrend}) features,
  ) {
    final avgInterval = features.last5Intervals.isEmpty
        ? 45.0
        : features.last5Intervals.reduce((a, b) => a + b) / features.last5Intervals.length;

    final prediction = avgInterval - features.timeSinceLastPuff;
    return prediction.clamp(5, 180).toInt(); // clamp to a sensible [5, 180] minute range
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
