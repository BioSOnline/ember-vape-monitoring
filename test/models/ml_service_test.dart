import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';
import 'package:ember/services/ml_service.dart';

void main() {
  group('MLService Linear Regression Craving Prediction', () {
    test('predicts realistic craving window from session intervals', () async {
      final ml = MLService();
      final now = DateTime.now();

      // Create 3 sessions separated by ~90 minutes
      final sessions = [
        Session(
          id: 's1',
          userId: 'u1',
          startedAt: now.subtract(const Duration(minutes: 210)),
          endedAt: now.subtract(const Duration(minutes: 195)),
          puffCount: 8,
          avgIntervalSec: 60.0,
        ),
        Session(
          id: 's2',
          userId: 'u1',
          startedAt: now.subtract(const Duration(minutes: 120)),
          endedAt: now.subtract(const Duration(minutes: 105)),
          puffCount: 8,
          avgIntervalSec: 60.0,
        ),
        Session(
          id: 's3',
          userId: 'u1',
          startedAt: now.subtract(const Duration(minutes: 30)),
          endedAt: now.subtract(const Duration(minutes: 15)),
          puffCount: 8,
          avgIntervalSec: 60.0,
        ),
      ];

      final puffEvents = [
        PuffEvent(id: 'p1', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 16)), inputMode: 'manual'),
        PuffEvent(id: 'p2', userId: 'u1', detectedAt: now.subtract(const Duration(minutes: 15)), inputMode: 'manual'),
      ];

      final minutes = await ml.predictNextCravingMinutes(
        puffEvents: puffEvents,
        sessions: sessions,
      );

      expect(minutes, isNotNull);
      // Gaps between sessions are ~90 min. Last session ended 15 min ago.
      // Expected remaining minutes: ~60 to ~80 minutes.
      expect(minutes!, greaterThan(40));
      expect(minutes, lessThan(100));
    });

    test('returns null when insufficient data is provided', () async {
      final ml = MLService();
      final minutes = await ml.predictNextCravingMinutes(
        puffEvents: [],
        sessions: [],
      );
      expect(minutes, isNull);
    });
  });
}
