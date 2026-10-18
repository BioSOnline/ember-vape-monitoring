import 'package:camera/camera.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_detection.dart';

/// Stub implementation for web where TFLite (dart:ffi) is unavailable.
class PuffDetectionServiceImpl {
  double confidenceThreshold = 0.28;
  String targetDevice = 'vape';

  Future<bool> initialize() async {
    Logger.warning('TFLite not available on web — puff detection disabled');
    return false;
  }

  Future<List<PuffDetection>> detectFromFrame(
    CameraImage frame, {
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) async {
    return [];
  }

  Future<List<PuffDetection>> detectFromImage(dynamic image) async {
    return [];
  }

  Future<List<PuffDetection>> detectFromJpegBytes(dynamic bytes, {bool isFrontCamera = false}) async {
    return [];
  }

  void dispose() {}
}
