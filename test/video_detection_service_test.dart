// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:ember/services/video_demo_detection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoDemoDetectionService End-to-End Tests', () {
    late VideoDemoDetectionService service;

    setUp(() {
      service = VideoDemoDetectionService();
    });

    test('creates a result from detections', () {
      final results = service.createResultsFromDetections([
        PuffDetection(x: 0.5, y: 0.5, width: 0.2, height: 0.2, confidence: 0.91, classId: 0),
      ], offsetSeconds: 12);

      expect(results, hasLength(1));
      expect(results.first.offsetSeconds, 12);
      expect(results.first.confidence, 0.91);
      expect(results.first.label, 'Vape detected');
    });

    test('returns empty results for missing file', () async {
      final result = await service.analyzeVideo(File('does_not_exist.mp4'));
      expect(result.detections, isEmpty);
    });

    test('processes sample vape video and detects Vape puff event', () async {
      final vapeFile = File('test/assets/sample_vape.mp4');
      expect(vapeFile.existsSync(), isTrue);

      final analysis = await service.analyzeVideo(vapeFile);
      print('Vape video detections: ${analysis.detections.length}');
      for (var d in analysis.detections) {
        print('  Offset: ${d.offsetSeconds}s, Duration: ${d.durationSeconds}s, Label: ${d.label}, Conf: ${d.confidence}');
      }

      expect(analysis.detections, isNotEmpty, reason: 'Must detect at least 1 puff in vape video');
      final first = analysis.detections.first;
      expect(first.classId, equals(0), reason: 'Class ID must be 0 for Vape');
      expect(first.label.toLowerCase(), contains('vape'));
      expect(first.confidence, greaterThanOrEqualTo(0.50));
    });

    test('processes sample cigarette video and detects Cigarette puff event', () async {
      final cigFile = File('test/assets/sample_cigarette.mp4');
      expect(cigFile.existsSync(), isTrue);

      final analysis = await service.analyzeVideo(cigFile);
      print('Cigarette video detections: ${analysis.detections.length}');
      for (var d in analysis.detections) {
        print('  Offset: ${d.offsetSeconds}s, Duration: ${d.durationSeconds}s, Label: ${d.label}, Conf: ${d.confidence}');
      }

      expect(analysis.detections, isNotEmpty, reason: 'Must detect at least 1 puff in cigarette video');
      final first = analysis.detections.first;
      expect(first.classId, equals(1), reason: 'Class ID must be 1 for Cigarette');
      expect(first.label.toLowerCase(), contains('cigarette'));
      expect(first.confidence, greaterThanOrEqualTo(0.50));
    });

    test('processes sample negative video with no false positives', () async {
      final neitherFile = File('test/assets/sample_neither.mp4');
      expect(neitherFile.existsSync(), isTrue);

      final analysis = await service.analyzeVideo(neitherFile);
      print('Negative control video detections: ${analysis.detections.length}');
      expect(analysis.detections, isEmpty, reason: 'Must detect 0 puffs for non-smoking video');
    });
  });
}
