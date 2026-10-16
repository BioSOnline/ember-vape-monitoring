// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ember/services/puff_detection_service_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TFLite Native Inference & Parsing Verification', () {
    late PuffDetectionServiceImpl service;

    setUp(() async {
      service = PuffDetectionServiceImpl();
      final ok = await service.initialize();
      expect(ok, isTrue, reason: 'Service should initialize successfully');
    });

    tearDown(() {
      service.dispose();
    });

    test('Inference on real vape image detects Vape with high confidence', () async {
      final file = File('test/assets/test_vape.jpg');
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);

      service.targetDevice = 'both';
      service.confidenceThreshold = 0.25;

      final detections = await service.detectFromImage(decoded!);
      print('Vape test detections: $detections');
      expect(detections, isNotEmpty, reason: 'Should detect at least 1 object');

      final best = detections.first;
      expect(best.classId, equals(0), reason: 'Class ID 0 must be Vape');
      expect(best.className, equals('Vape'));
      expect(best.confidence, greaterThan(0.80));
      expect(best.x, inInclusiveRange(0.0, 1.0));
      expect(best.y, inInclusiveRange(0.0, 1.0));
      expect(best.width, inInclusiveRange(0.0, 1.0));
      expect(best.height, inInclusiveRange(0.0, 1.0));
    });

    test('Inference on real cigarette image detects Cigarette with high confidence', () async {
      final file = File('test/assets/test_cigarette.jpg');
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);

      service.targetDevice = 'both';
      service.confidenceThreshold = 0.25;

      final detections = await service.detectFromImage(decoded!);
      print('Cigarette test detections: $detections');
      expect(detections, isNotEmpty, reason: 'Should detect at least 1 object');

      final best = detections.first;
      expect(best.classId, equals(1), reason: 'Class ID 1 must be Cigarette');
      expect(best.className, equals('Cigarette'));
      expect(best.confidence, greaterThan(0.80));
    });

    test('Inference on user uploaded vape image', () async {
      final file = File('test/assets/user_vape.jpg');
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);

      service.targetDevice = 'both';
      service.confidenceThreshold = 0.20;

      final detections = await service.detectFromImage(decoded!);
      print('User vape test detections: $detections');
      expect(detections, isNotEmpty);
      final best = detections.first;
      expect(best.classId, equals(0), reason: 'Must detect Vape');
      expect(best.className, equals('Vape'));
      expect(best.confidence, greaterThan(0.60));
      expect(best.isNearMouth, isTrue);
      expect(best.isPuffEvent, isTrue);
    });
  });
}
