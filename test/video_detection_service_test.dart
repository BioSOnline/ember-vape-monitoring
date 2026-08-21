import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:ember/services/video_demo_detection_service.dart';

void main() {
  group('VideoDemoDetectionService', () {
    test('creates a result from detections', () {
      final service = VideoDemoDetectionService();
      final results = service.createResultsFromDetections([
        PuffDetection(x: 0.5, y: 0.5, width: 0.2, height: 0.2, confidence: 0.91, classId: 0),
      ], offsetSeconds: 12);

      expect(results, hasLength(1));
      expect(results.first.offsetSeconds, 12);
      expect(results.first.confidence, 0.91);
      expect(results.first.label, 'Vape detected');
    });

    test('returns empty results for missing file', () async {
      final service = VideoDemoDetectionService();
      final result = await service.analyzeVideo(File('does_not_exist.mp4'));
      expect(result.detections, isEmpty);
    });
  });
}
