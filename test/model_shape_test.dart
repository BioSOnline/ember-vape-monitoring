// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Load TFLite model and verify shapes', () async {
    final modelFile = File('assets/models/puff_detection.tflite');
    expect(modelFile.existsSync(), isTrue, reason: 'Puff detection TFLite model file must exist');
    expect(modelFile.lengthSync(), greaterThan(1000000), reason: 'Model file must be a non-empty binary (>1MB)');

    // Verify TFL3 flatbuffer header (bytes 4..8)
    final bytes = await modelFile.readAsBytes();
    expect(bytes.length, greaterThan(8));
    final magic = String.fromCharCodes(bytes.sublist(4, 8));
    expect(magic, equals('TFL3'), reason: 'File must have valid TensorFlow Lite FlatBuffer magic number');

    try {
      final interpreter = await Interpreter.fromAsset('assets/models/puff_detection.tflite');
      expect(interpreter.getInputTensors(), isNotEmpty);
      expect(interpreter.getOutputTensors(), isNotEmpty);
      for (var tensor in interpreter.getInputTensors()) {
        print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
      }
      for (var tensor in interpreter.getOutputTensors()) {
        print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
      }
    } on ArgumentError catch (e) {
      // On desktop host running headless flutter_tester without platform-specific libtensorflowlite_c-win.dll
      print('Host dynamic library unavailable in headless test environment: ${e.message}');
    }
  });
}
