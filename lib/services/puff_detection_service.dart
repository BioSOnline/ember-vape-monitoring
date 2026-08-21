import 'package:camera/camera.dart';
import 'package:ember/models/puff_detection.dart';

// Conditional import: use native TFLite on mobile/desktop, stub on web
import 'package:ember/services/puff_detection_service_stub.dart'
    if (dart.library.ffi) 'package:ember/services/puff_detection_service_native.dart';

/// Entry point for puff detection. The actual implementation is selected
/// at compile time via conditional imports (TFLite on native, stub on web).
class PuffDetectionService {
  static PuffDetectionService? _instance;
  late final PuffDetectionServiceImpl _impl;

  PuffDetectionService._() {
    _impl = PuffDetectionServiceImpl();
  }

  factory PuffDetectionService() {
    _instance ??= PuffDetectionService._();
    return _instance!;
  }

  Future<bool> initialize() => _impl.initialize();

  Future<List<PuffDetection>> detectFromFrame(CameraImage frame, {int sensorOrientation = 0}) =>
      _impl.detectFromFrame(frame, sensorOrientation: sensorOrientation);

  // Expose inference from static image for testing
  Future<List<PuffDetection>> detectFromImage(dynamic image) =>
      _impl.detectFromImage(image);

  // High-performance background Isolate inference directly from raw bytes
  Future<List<PuffDetection>> detectFromJpegBytes(dynamic bytes) =>
      _impl.detectFromJpegBytes(bytes);

  void dispose() => _impl.dispose();
}
