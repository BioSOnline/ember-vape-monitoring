// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Load TFLite model and verify shapes', () async {
    final interpreter = await Interpreter.fromAsset('assets/models/puff_detection.tflite');
    expect(interpreter.getInputTensors(), isNotEmpty);
    expect(interpreter.getOutputTensors(), isNotEmpty);
    print('Input tensors:');
    for (var tensor in interpreter.getInputTensors()) {
      print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
    }
    print('Output tensors:');
    for (var tensor in interpreter.getOutputTensors()) {
      print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
    }
  });
}
