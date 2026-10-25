import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:ember/services/video_demo_detection_service.dart';

void main() {
  group('Video Upload & Analysis Flow Tests', () {
    final service = VideoDemoDetectionService();

    test('Filters out detections with confidence below threshold (0.25)', () {
      final lowConfDetections = [
        PuffDetection(x: 0.5, y: 0.45, width: 0.1, height: 0.1, confidence: 0.15, classId: 0),
        PuffDetection(x: 0.5, y: 0.45, width: 0.1, height: 0.1, confidence: 0.24, classId: 0),
      ];

      final results = service.createResultsFromDetections(lowConfDetections, offsetSeconds: 5);
      expect(results, isEmpty);
    });

    test('Filters out detections outside lip proximity zone', () {
      final outsideLipDetections = [
        // x = 0.10 is well outside lip horizontal center (0.28..0.72)
        PuffDetection(x: 0.10, y: 0.45, width: 0.1, height: 0.1, confidence: 0.85, classId: 0),
        // y = 0.85 is below mouth region
        PuffDetection(x: 0.50, y: 0.85, width: 0.1, height: 0.1, confidence: 0.90, classId: 0),
      ];

      final results = service.createResultsFromDetections(outsideLipDetections, offsetSeconds: 5);
      expect(results, isEmpty);
    });

    test('Selects highest confidence candidate when valid in frame', () {
      final validDetections = [
        PuffDetection(x: 0.50, y: 0.45, width: 0.1, height: 0.1, confidence: 0.65, classId: 0),
        PuffDetection(x: 0.52, y: 0.44, width: 0.1, height: 0.1, confidence: 0.88, classId: 1),
      ];

      final results = service.createResultsFromDetections(validDetections, offsetSeconds: 12);
      expect(results, hasLength(1));
      expect(results.first.confidence, 0.88);
      expect(results.first.classId, 1);
      expect(results.first.offsetSeconds, 12);
      expect(results.first.label, 'Cigarette detected');
    });

    test('VideoDetectionResult models custom duration and formatting', () {
      const result = VideoDetectionResult(
        offsetSeconds: 45,
        confidence: 0.912,
        label: 'Vape puff',
        classId: 0,
        durationSeconds: 2.5,
      );

      expect(result.offsetSeconds, 45);
      expect(result.durationSeconds, 2.5);
      expect(result.label, 'Vape puff');
      expect((result.confidence * 100).toStringAsFixed(1), '91.2');
    });
  });
}
