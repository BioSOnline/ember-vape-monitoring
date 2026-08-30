import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models/puff_detection.dart';

void main() {
  group('PuffDetection Model Tests', () {
    test('maps class 0 to Vape', () {
      final detection = PuffDetection(
        x: 0.5,
        y: 0.4,
        width: 0.1,
        height: 0.2,
        confidence: 0.85,
        classId: 0,
      );
      expect(detection.className, equals('Vape'));
      expect(detection.isVape, isTrue);
      expect(detection.isCigarette, isFalse);
    });

    test('consolidates class 2 (IQOS) to Vape', () {
      final detection = PuffDetection(
        x: 0.5,
        y: 0.4,
        width: 0.1,
        height: 0.2,
        confidence: 0.85,
        classId: 2,
      );
      expect(detection.className, equals('Vape'));
      expect(detection.isVape, isTrue);
      expect(detection.isCigarette, isFalse);
    });

    test('maps class 1 to Cigarette', () {
      final detection = PuffDetection(
        x: 0.5,
        y: 0.4,
        width: 0.1,
        height: 0.2,
        confidence: 0.85,
        classId: 1,
      );
      expect(detection.className, equals('Cigarette'));
      expect(detection.isVape, isFalse);
      expect(detection.isCigarette, isTrue);
    });

    test('correctly identifies puff event near mouth', () {
      final detection = PuffDetection(
        x: 0.5,
        y: 0.4,
        width: 0.1,
        height: 0.2,
        confidence: 0.70,
        classId: 2,
      );
      expect(detection.isNearMouth, isTrue);
      expect(detection.isPuffEvent, isTrue);
    });
  });
}
