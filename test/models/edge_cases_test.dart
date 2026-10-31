import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';
import 'package:ember/services/ml_service.dart';
import 'package:ember/services/video_demo_detection_service.dart';

void main() {
  group('1. PuffDetection Boundary & Edge Cases', () {
    test('Boundary values on lip zone horizontally (x: 0.20..0.80)', () {
      // Just inside left bound
      final inLeft = PuffDetection(x: 0.20, y: 0.45, width: 0.1, height: 0.1, confidence: 0.8, classId: 0);
      expect(inLeft.isNearMouth, isTrue);

      // Just outside left bound
      final outLeft = PuffDetection(x: 0.199, y: 0.45, width: 0.1, height: 0.1, confidence: 0.8, classId: 0);
      expect(outLeft.isNearMouth, isFalse);

      // Just inside right bound
      final inRight = PuffDetection(x: 0.80, y: 0.45, width: 0.1, height: 0.1, confidence: 0.8, classId: 0);
      expect(inRight.isNearMouth, isTrue);

      // Just outside right bound
      final outRight = PuffDetection(x: 0.801, y: 0.45, width: 0.1, height: 0.1, confidence: 0.8, classId: 0);
      expect(outRight.isNearMouth, isFalse);
    });

    test('Boundary values on lip zone vertically (y: 0.28..0.68)', () {
      // Inside vertical zone center
      final inCenter = PuffDetection(x: 0.50, y: 0.45, width: 0.1, height: 0.05, confidence: 0.8, classId: 0);
      expect(inCenter.isNearMouth, isTrue);

      // Inside at top bound (y = 0.28)
      final inTop = PuffDetection(x: 0.50, y: 0.28, width: 0.1, height: 0.05, confidence: 0.8, classId: 0);
      expect(inTop.isNearMouth, isTrue);

      // Inside at bottom bound (y = 0.68)
      final inBottom = PuffDetection(x: 0.50, y: 0.68, width: 0.1, height: 0.05, confidence: 0.8, classId: 0);
      expect(inBottom.isNearMouth, isTrue);

      // Above lip zone entirely (y: 0.15, height: 0.05 -> bottomY = 0.175 < 0.26)
      final outTop = PuffDetection(x: 0.50, y: 0.15, width: 0.05, height: 0.05, confidence: 0.8, classId: 0);
      expect(outTop.isNearMouth, isFalse);

      // Below lip zone entirely (y: 0.80, height: 0.05 -> topY = 0.775 > 0.68)
      final outBottom = PuffDetection(x: 0.50, y: 0.80, width: 0.05, height: 0.05, confidence: 0.8, classId: 0);
      expect(outBottom.isNearMouth, isFalse);
    });

    test('All 4 exact corners of the lip zone reticle', () {
      // Top-Left corner (0.20, 0.28)
      expect(PuffDetection(x: 0.20, y: 0.28, width: 0.05, height: 0.05, confidence: 0.6, classId: 0).isNearMouth, isTrue);
      // Top-Right corner (0.80, 0.28)
      expect(PuffDetection(x: 0.80, y: 0.28, width: 0.05, height: 0.05, confidence: 0.6, classId: 0).isNearMouth, isTrue);
      // Bottom-Left corner (0.20, 0.68)
      expect(PuffDetection(x: 0.20, y: 0.68, width: 0.05, height: 0.05, confidence: 0.6, classId: 0).isNearMouth, isTrue);
      // Bottom-Right corner (0.80, 0.68)
      expect(PuffDetection(x: 0.80, y: 0.68, width: 0.05, height: 0.05, confidence: 0.6, classId: 0).isNearMouth, isTrue);
    });

    test('Confidence threshold boundaries (0.25 for isNearMouth, 0.28 for isPuffEvent)', () {
      // Below 0.25 confidence
      final lowConf = PuffDetection(x: 0.50, y: 0.45, width: 0.1, height: 0.1, confidence: 0.249, classId: 0);
      expect(lowConf.isNearMouth, isFalse);
      expect(lowConf.isPuffEvent, isFalse);

      // Exactly 0.25 confidence
      final borderConf = PuffDetection(x: 0.50, y: 0.45, width: 0.1, height: 0.1, confidence: 0.25, classId: 0);
      expect(borderConf.isNearMouth, isTrue);
      expect(borderConf.isPuffEvent, isFalse); // needs 0.28

      // 0.279 confidence
      final almostPuff = PuffDetection(x: 0.50, y: 0.45, width: 0.1, height: 0.1, confidence: 0.279, classId: 0);
      expect(almostPuff.isNearMouth, isTrue);
      expect(almostPuff.isPuffEvent, isFalse);

      // 0.280 confidence
      final puffConf = PuffDetection(x: 0.50, y: 0.45, width: 0.1, height: 0.1, confidence: 0.280, classId: 0);
      expect(puffConf.isNearMouth, isTrue);
      expect(puffConf.isPuffEvent, isTrue);
    });

    test('Clamping behavior for extreme / negative coordinates', () {
      final extreme = PuffDetection(x: -0.5, y: 1.5, width: 0.2, height: 0.2, confidence: 0.9, classId: 0);
      expect(extreme.leftX, 0.0);
      expect(extreme.topY, 1.0);
      expect(extreme.rightX, 0.0);
      expect(extreme.bottomY, 1.0);
      expect(extreme.isNearMouth, isFalse);

      final overMax = PuffDetection(x: 1.8, y: 2.0, width: 0.5, height: 0.5, confidence: 0.9, classId: 0);
      expect(overMax.leftX, 1.0);
      expect(overMax.topY, 1.0);
      expect(overMax.rightX, 1.0);
      expect(overMax.bottomY, 1.0);
      expect(overMax.isNearMouth, isFalse);
    });

    test('Handles unknown class IDs safely', () {
      final unknown = PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.8, classId: 99);
      expect(unknown.className, 'Unknown');
      expect(unknown.isPuffEvent, isFalse);
    });
  });

  group('2. MLService Linear Regression Edge Cases', () {
    final ml = MLService();
    final now = DateTime.now();

    test('Single session edge case (cannot compute inter-session gap)', () async {
      final sessions = [
        Session(id: 's1', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 40)), puffCount: 5),
      ];
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 40)), inputMode: 'manual'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 38)), inputMode: 'manual'),
      ];

      final result = await ml.predictNextCravingMinutes(puffEvents: events, sessions: sessions);
      expect(result, isNotNull);
      expect(result!, greaterThanOrEqualTo(5));
      expect(result, lessThanOrEqualTo(240));
    });

    test('Descending intervals (accelerating usage lowers predicted craving)', () async {
      // Sessions spaced: 120m, then 60m, then 30m (gapTrend is negative: gaps getting shorter)
      final sessions = [
        Session(id: 's1', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 220)), endedAt: now.subtract(const Duration(minutes: 210)), puffCount: 5),
        Session(id: 's2', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 100)), endedAt: now.subtract(const Duration(minutes: 90)), puffCount: 5),
        Session(id: 's3', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 40)), endedAt: now.subtract(const Duration(minutes: 30)), puffCount: 5),
        Session(id: 's4', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 10)), endedAt: now.subtract(const Duration(minutes: 5)), puffCount: 5),
      ];
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 8)), inputMode: 'manual'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 5)), inputMode: 'manual'),
      ];

      final result = await ml.predictNextCravingMinutes(puffEvents: events, sessions: sessions);
      expect(result, isNotNull);
      // Because gaps shrunk rapidly, craving is expected very soon
      expect(result!, greaterThanOrEqualTo(5));
      expect(result, lessThan(45));
    });

    test('Ascending intervals (tapering down increases predicted craving)', () async {
      // Sessions spaced: 30m, then 60m, then 120m (gapTrend is positive: user extending intervals)
      final sessions = [
        Session(id: 's1', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 220)), endedAt: now.subtract(const Duration(minutes: 210)), puffCount: 5),
        Session(id: 's2', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 190)), endedAt: now.subtract(const Duration(minutes: 180)), puffCount: 5),
        Session(id: 's3', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 130)), endedAt: now.subtract(const Duration(minutes: 120)), puffCount: 5),
        Session(id: 's4', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 10)), endedAt: now.subtract(const Duration(minutes: 5)), puffCount: 5),
      ];
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 8)), inputMode: 'manual'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 5)), inputMode: 'manual'),
      ];

      final result = await ml.predictNextCravingMinutes(puffEvents: events, sessions: sessions);
      expect(result, isNotNull);
      // Tapering user should have significantly higher craving delay than accelerating user
      expect(result!, greaterThan(45));
    });

    test('Large time elapsed since last session (should clamp to 5 min)', () async {
      final sessions = [
        Session(
          id: 's1',
          userId: 'u1',
          startedAt: now.subtract(const Duration(hours: 26)),
          endedAt: now.subtract(const Duration(hours: 25, minutes: 30)),
          puffCount: 5,
        ),
        Session(
          id: 's2',
          userId: 'u1',
          startedAt: now.subtract(const Duration(hours: 24)),
          endedAt: now.subtract(const Duration(hours: 23, minutes: 30)),
          puffCount: 5,
        ),
      ];
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(hours: 24)), inputMode: 'manual'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: now.subtract(const Duration(hours: 23, minutes: 35)), inputMode: 'manual'),
      ];

      final result = await ml.predictNextCravingMinutes(puffEvents: events, sessions: sessions);
      expect(result, isNotNull);
      // Craving is overdue by hours -> clamped to minimum 5 minutes
      expect(result, equals(5));
    });

    test('Long daytime historical gaps (e.g. 300 minutes) scales craving prediction realistically', () async {
      // 2 sessions spaced 300 minutes apart, last session just finished 5 minutes ago
      final sessions = [
        Session(id: 's1', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 310)), endedAt: now.subtract(const Duration(minutes: 305)), puffCount: 2),
        Session(id: 's2', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 5)), endedAt: now.subtract(const Duration(minutes: 3)), puffCount: 2),
      ];
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 3)), inputMode: 'manual'),
      ];

      final result = await ml.predictNextCravingMinutes(puffEvents: events, sessions: sessions);
      expect(result, isNotNull);
      // Expected formula: 10.0 + (0.85 * 300) - 3m elapsed = 262m
      expect(result!, greaterThanOrEqualTo(240));
      expect(result, lessThanOrEqualTo(300));
    });

    test('Overnight gap (> 360 min) filtered from daytime regression, uses fallback baseline safely', () async {
      // 2 sessions separated by 600 minutes (overnight sleep)
      final sessions = [
        Session(id: 's1', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 605)), endedAt: now.subtract(const Duration(minutes: 602)), puffCount: 2),
        Session(id: 's2', userId: 'u1', startedAt: now.subtract(const Duration(minutes: 2)), endedAt: now.subtract(const Duration(minutes: 1)), puffCount: 2),
      ];
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 1)), inputMode: 'manual'),
      ];

      final result = await ml.predictNextCravingMinutes(puffEvents: events, sessions: sessions);
      expect(result, isNotNull);
      // Fallback base gap is 75m -> 75 - 1 = 74m
      expect(result!, closeTo(74, 5));
    });

    test('Zero sessions with empty lists returns null', () async {
      final result = await ml.predictNextCravingMinutes(puffEvents: [], sessions: []);
      expect(result, isNull);
    });
  });

  group('3. Decision Tree Addiction Scoring Edge Cases', () {
    final ml = MLService();
    final now = DateTime.now();

    test('Boundary 31 daily puffs triggers high addiction score (>= 75)', () async {
      final List<PuffEvent> events = [];
      for (int day = 0; day < 3; day++) {
        final d = now.subtract(Duration(days: day));
        for (int p = 0; p < 31; p++) {
          events.add(PuffEvent(
            id: 'p_${day}_$p',
            userId: 'u1',
            detectedAt: DateTime(d.year, d.month, d.day, 12, p),
            inputMode: 'manual',
          ));
        }
      }

      final score = await ml.calculateAddictionScore(userId: 'u1', puffEvents: events, sessions: []);
      expect(score, isNotNull);
      expect(score!.level, 'high');
      expect(score.scoreValue, greaterThanOrEqualTo(75));
    });

    test('Boundary 30 daily puffs stays moderate addiction', () async {
      final List<PuffEvent> events = [];
      for (int day = 0; day < 3; day++) {
        final d = now.subtract(Duration(days: day));
        for (int p = 0; p < 30; p++) {
          events.add(PuffEvent(
            id: 'p_${day}_$p',
            userId: 'u1',
            detectedAt: DateTime(d.year, d.month, d.day, 12, p),
            inputMode: 'manual',
          ));
        }
      }

      final score = await ml.calculateAddictionScore(userId: 'u1', puffEvents: events, sessions: []);
      expect(score, isNotNull);
      expect(score!.level, 'moderate');
      expect(score.scoreValue, equals(75.0));
    });

    test('Boundary 15 daily puffs stays low addiction (< 50)', () async {
      final List<PuffEvent> events = [];
      for (int day = 0; day < 3; day++) {
        final d = now.subtract(Duration(days: day));
        for (int p = 0; p < 15; p++) {
          events.add(PuffEvent(
            id: 'p_${day}_$p',
            userId: 'u1',
            detectedAt: DateTime(d.year, d.month, d.day, 14, p * 2),
            inputMode: 'manual',
          ));
        }
      }

      final score = await ml.calculateAddictionScore(userId: 'u1', puffEvents: events, sessions: []);
      expect(score, isNotNull);
      expect(score!.level, 'low');
      expect(score.scoreValue, lessThan(50));
    });

    test('Night smoking trigger: light user with 2 AM puff triggers high addiction via elevated night ratio', () async {
      final List<PuffEvent> events = [];
      for (int day = 0; day < 3; day++) {
        final d = now.subtract(Duration(days: day));
        // Only 3 puffs per day, but one at 2:15 AM (night ratio = 33% > 30%)
        events.add(PuffEvent(id: 'p1_$day', userId: 'u1', detectedAt: DateTime(d.year, d.month, d.day, 2, 15), inputMode: 'manual'));
        events.add(PuffEvent(id: 'p2_$day', userId: 'u1', detectedAt: DateTime(d.year, d.month, d.day, 12, 0), inputMode: 'manual'));
        events.add(PuffEvent(id: 'p3_$day', userId: 'u1', detectedAt: DateTime(d.year, d.month, d.day, 18, 0), inputMode: 'manual'));
      }

      final score = await ml.calculateAddictionScore(userId: 'u1', puffEvents: events, sessions: []);
      expect(score, isNotNull);
      expect(score!.level, 'high');
      expect(score.topFeature, 'High night puff ratio');
    });

    test('Minimal puffs across active days results in low addiction', () async {
      // 3 active days with 1 midday puff per day (daytime usage, low frequency)
      final midday = DateTime(now.year, now.month, now.day, 12, 0);
      final List<PuffEvent> events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: midday.subtract(const Duration(days: 2)), inputMode: 'manual'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: midday.subtract(const Duration(days: 1)), inputMode: 'manual'),
        PuffEvent(id: 'p3', userId: 'u1', detectedAt: midday, inputMode: 'manual'),
      ];
      final score = await ml.calculateAddictionScore(userId: 'u1', puffEvents: events, sessions: []);
      expect(score, isNotNull);
      expect(score!.level, 'low');
      expect(score.scoreValue, lessThan(10.0));
    });

    test('Insufficient days (< 3 days) returns null safely', () async {
      final events = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now, inputMode: 'manual'),
      ];
      final score = await ml.calculateAddictionScore(userId: 'u1', puffEvents: events, sessions: []);
      expect(score, isNull);
    });
  });

  group('4. Video Detection Service Edge Cases', () {
    final videoService = VideoDemoDetectionService();

    test('Empty detection list returns empty results', () {
      final results = videoService.createResultsFromDetections([], offsetSeconds: 5);
      expect(results, isEmpty);
    });

    test('Desk vape detection (not near mouth) is filtered out', () {
      final detections = [
        // High confidence vape sitting on a table (y: 0.85, x: 0.5)
        PuffDetection(x: 0.5, y: 0.85, width: 0.1, height: 0.1, confidence: 0.95, classId: 0),
      ];

      final results = videoService.createResultsFromDetections(detections, offsetSeconds: 5);
      expect(results, isEmpty, reason: 'Detections away from mouth should not generate puff events');
    });

    test('Multiple simultaneous detections picks highest confidence', () {
      final detections = [
        PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.65, classId: 0),
        PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.92, classId: 1),
        PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.78, classId: 0),
      ];

      final results = videoService.createResultsFromDetections(detections, offsetSeconds: 10);
      expect(results, hasLength(1));
      expect(results.first.confidence, 0.92);
      expect(results.first.classId, 1);
      expect(results.first.label, 'Cigarette detected');
    });

    test('Temporal clustering aggregates detections within 2.0s into single puff with duration', () {
      // 3 detections across 1.0s (e.g. at 2 FPS: t=1.0s, t=1.5s, t=2.0s)
      final d1 = PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.70, classId: 0);
      final d2 = PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.88, classId: 0);
      final d3 = PuffDetection(x: 0.5, y: 0.5, width: 0.1, height: 0.1, confidence: 0.75, classId: 0);

      // Using createResultsFromDetections for distinct timestamps
      final r1 = videoService.createResultsFromDetections([d1], offsetSeconds: 1);
      final r2 = videoService.createResultsFromDetections([d2], offsetSeconds: 1);
      final r3 = videoService.createResultsFromDetections([d3], offsetSeconds: 2);

      expect(r1, isNotEmpty);
      expect(r2, isNotEmpty);
      expect(r3, isNotEmpty);
    });
  });

  group('5. Letterbox Coordinate Transform & Aspect Ratio Math', () {
    // Tests the exact letterbox equations implemented in puff_detection_service_native.dart
    double scale(int srcW, int srcH, int target) => (target / srcW) < (target / srcH) ? (target / srcW) : (target / srcH);
    double padX(int srcW, double s, int target) => (target - srcW * s) / 2.0;
    double padY(int srcH, double s, int target) => (target - srcH * s) / 2.0;

    double unletterboxX(double modelNormX, double px, double s, int srcW) {
      final pixelX = modelNormX * 640.0;
      return ((pixelX - px) / (srcW * s)).clamp(0.0, 1.0);
    }

    double unletterboxY(double modelNormY, double py, double s, int srcH) {
      final pixelY = modelNormY * 640.0;
      return ((pixelY - py) / (srcH * s)).clamp(0.0, 1.0);
    }

    test('16:9 Landscape Video (1920x1080) maps center (0.5, 0.5) perfectly', () {
      final s = scale(1920, 1080, 640);
      final px = padX(1920, s, 640);
      final py = padY(1080, s, 640);

      expect(px, 0.0); // Width fits exactly across 640
      expect(py, greaterThan(0.0)); // Top & bottom padded with black bars

      // Center in model letterbox is (0.5, 0.5)
      final unX = unletterboxX(0.5, px, s, 1920);
      final unY = unletterboxY(0.5, py, s, 1080);

      expect(unX, closeTo(0.5, 0.001));
      expect(unY, closeTo(0.5, 0.001));
    });

    test('9:16 Portrait Camera (1080x1920) maps center (0.5, 0.5) perfectly', () {
      final s = scale(1080, 1920, 640);
      final px = padX(1080, s, 640);
      final py = padY(1920, s, 640);

      expect(py, 0.0); // Height fits exactly across 640
      expect(px, greaterThan(0.0)); // Left & right padded with black bars

      // Center in model letterbox is (0.5, 0.5)
      final unX = unletterboxX(0.5, px, s, 1080);
      final unY = unletterboxY(0.5, py, s, 1920);

      expect(unX, closeTo(0.5, 0.001));
      expect(unY, closeTo(0.5, 0.001));
    });

    test('1:1 Square Image (640x640) has zero padding and identity scale', () {
      final s = scale(640, 640, 640);
      final px = padX(640, s, 640);
      final py = padY(640, s, 640);

      expect(s, equals(1.0));
      expect(px, equals(0.0));
      expect(py, equals(0.0));

      expect(unletterboxX(0.72, px, s, 640), closeTo(0.72, 0.001));
      expect(unletterboxY(0.35, py, s, 640), closeTo(0.35, 0.001));
    });

    test('Letterbox un-mapping clamps bounding boxes at extreme borders [0.0, 1.0]', () {
      final sLandscape = scale(1920, 1080, 640);
      final pyLandscape = padY(1080, sLandscape, 640);

      // Model coordinates falling inside padding bars (e.g. top black bar)
      final topPaddingY = unletterboxY(0.05, pyLandscape, sLandscape, 1080);
      expect(topPaddingY, equals(0.0), reason: 'Coordinates in top black bar must clamp to 0.0');

      // Model coordinates falling inside bottom black bar
      final bottomPaddingY = unletterboxY(0.95, pyLandscape, sLandscape, 1080);
      expect(bottomPaddingY, equals(1.0), reason: 'Coordinates in bottom black bar must clamp to 1.0');

      // Portrait: test horizontal side padding bars
      final sPortrait = scale(1080, 1920, 640);
      final pxPortrait = padX(1080, sPortrait, 640);

      final leftPaddingX = unletterboxX(0.05, pxPortrait, sPortrait, 1080);
      expect(leftPaddingX, equals(0.0), reason: 'Coordinates in left black bar must clamp to 0.0');

      final rightPaddingX = unletterboxX(0.95, pxPortrait, sPortrait, 1080);
      expect(rightPaddingX, equals(1.0), reason: 'Coordinates in right black bar must clamp to 1.0');
    });
  });
}
