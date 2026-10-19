import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Holds the preprocessed packed input tensor and letterbox geometry
/// required to map coordinates back to the original image coordinates.
class _LetterboxResult {
  final Float32List inputBytes;
  final double scale;
  final double padX;
  final double padY;
  final int origWidth;
  final int origHeight;
  final bool isFrontCamera;

  const _LetterboxResult({
    required this.inputBytes,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.origWidth,
    required this.origHeight,
    this.isFrontCamera = false,
  });
}

/// Helper function to perform aspect-ratio-preserving letterboxing with bilinear interpolation.
_LetterboxResult _letterboxAndPack(
  img.Image image,
  int targetWidth,
  int targetHeight,
  bool isNHWC, {
  bool isFrontCamera = false,
}) {
  final origWidth = image.width;
  final origHeight = image.height;

  final double scale = (targetWidth / origWidth < targetHeight / origHeight)
      ? targetWidth / origWidth
      : targetHeight / origHeight;
  final int newWidth = (origWidth * scale).round().clamp(1, targetWidth);
  final int newHeight = (origHeight * scale).round().clamp(1, targetHeight);
  final double padX = (targetWidth - newWidth) / 2.0;
  final double padY = (targetHeight - newHeight) / 2.0;

  final resized = (origWidth == newWidth && origHeight == newHeight)
      ? image
      : img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );

  final inputBytes = Float32List(1 * targetHeight * targetWidth * 3);
  // Fill letterbox canvas with standard YOLO gray padding (114 / 255.0)
  inputBytes.fillRange(0, inputBytes.length, 114.0 / 255.0);
  final int startX = padX.round();
  final int startY = padY.round();

  if (isNHWC) {
    for (int y = 0; y < newHeight; y++) {
      final int targetY = startY + y;
      if (targetY < 0 || targetY >= targetHeight) continue;
      for (int x = 0; x < newWidth; x++) {
        final int targetX = startX + x;
        if (targetX < 0 || targetX >= targetWidth) continue;
        final pixel = resized.getPixel(x, y);
        final int idx = (targetY * targetWidth + targetX) * 3;
        inputBytes[idx] = pixel.r / 255.0;
        inputBytes[idx + 1] = pixel.g / 255.0;
        inputBytes[idx + 2] = pixel.b / 255.0;
      }
    }
  } else {
    final int planeSize = targetHeight * targetWidth;
    for (int y = 0; y < newHeight; y++) {
      final int targetY = startY + y;
      if (targetY < 0 || targetY >= targetHeight) continue;
      for (int x = 0; x < newWidth; x++) {
        final int targetX = startX + x;
        if (targetX < 0 || targetX >= targetWidth) continue;
        final pixel = resized.getPixel(x, y);
        final int offset = targetY * targetWidth + targetX;
        inputBytes[0 * planeSize + offset] = pixel.r / 255.0;
        inputBytes[1 * planeSize + offset] = pixel.g / 255.0;
        inputBytes[2 * planeSize + offset] = pixel.b / 255.0;
      }
    }
  }

  return _LetterboxResult(
    inputBytes: inputBytes,
    scale: scale,
    padX: padX,
    padY: padY,
    origWidth: origWidth,
    origHeight: origHeight,
    isFrontCamera: isFrontCamera,
  );
}

/// Helper function for background isolate JPEG decode + letterbox packing
_LetterboxResult? _decodeJpegAndLetterboxPack(
  Uint8List jpegBytes,
  int targetWidth,
  int targetHeight,
  bool isNHWC, {
  bool isFrontCamera = false,
}) {
  var decoded = img.decodeImage(jpegBytes);
  if (decoded == null) return null;
  decoded = img.bakeOrientation(decoded);
  return _letterboxAndPack(decoded, targetWidth, targetHeight, isNHWC, isFrontCamera: isFrontCamera);
}

/// Ultra-fast single-pass YUV420 to letterbox sampler with built-in hardware rotation.
/// Eliminates all intermediate img.Image allocations, rotations, and bilinear resizers.
_LetterboxResult _directSampleYuv420ToLetterbox({
  required int width,
  required int height,
  required Uint8List yBuffer,
  required Uint8List uBuffer,
  required Uint8List vBuffer,
  required int yRowStride,
  required int yPixelStride,
  required int uvRowStride,
  required int uvPixelStride,
  required int sensorOrientation,
  required int targetWidth,
  required int targetHeight,
  required bool isNHWC,
  required bool isFrontCamera,
}) {
  final int rotationAngle = isFrontCamera
      ? (360 - sensorOrientation) % 360
      : sensorOrientation;

  final bool swapDims = (rotationAngle == 90 || rotationAngle == 270);
  final int rotW = swapDims ? height : width;
  final int rotH = swapDims ? width : height;

  final double scale = (targetWidth / rotW < targetHeight / rotH)
      ? targetWidth / rotW
      : targetHeight / rotH;
  final int newW = (rotW * scale).round().clamp(1, targetWidth);
  final int newH = (rotH * scale).round().clamp(1, targetHeight);
  final double padX = (targetWidth - newW) / 2.0;
  final double padY = (targetHeight - newH) / 2.0;
  final int startX = padX.round();
  final int startY = padY.round();

  final inputBytes = Float32List(1 * targetHeight * targetWidth * 3);
  inputBytes.fillRange(0, inputBytes.length, 114.0 / 255.0);

  final int yLen = yBuffer.length;
  final int uLen = uBuffer.length;
  final int vLen = vBuffer.length;

  final double invScale = 1.0 / scale;
  final int maxSrcX = width - 1;
  final int maxSrcY = height - 1;
  final int planeSize = targetHeight * targetWidth;

  for (int dy = 0; dy < newH; dy++) {
    final int targetY = startY + dy;
    if (targetY < 0 || targetY >= targetHeight) continue;
    final double rotY = dy * invScale;

    for (int dx = 0; dx < newW; dx++) {
      final int targetX = startX + dx;
      if (targetX < 0 || targetX >= targetWidth) continue;
      final double rotX = dx * invScale;

      int srcX;
      int srcY;
      if (rotationAngle == 90) {
        srcX = rotY.toInt();
        srcY = maxSrcY - rotX.toInt();
      } else if (rotationAngle == 270) {
        srcX = maxSrcX - rotY.toInt();
        srcY = rotX.toInt();
      } else if (rotationAngle == 180) {
        srcX = maxSrcX - rotX.toInt();
        srcY = maxSrcY - rotY.toInt();
      } else {
        srcX = rotX.toInt();
        srcY = rotY.toInt();
      }

      if (srcX < 0) {
        srcX = 0;
      } else if (srcX > maxSrcX) {
        srcX = maxSrcX;
      }
      if (srcY < 0) {
        srcY = 0;
      } else if (srcY > maxSrcY) {
        srcY = maxSrcY;
      }

      final int yIdx = srcY * yRowStride + srcX * yPixelStride;
      final int uvIdx = (srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride;

      if (yIdx >= yLen || uvIdx >= uLen || uvIdx >= vLen) continue;

      final int yp = yBuffer[yIdx];
      final int up = uBuffer[uvIdx] - 128;
      final int vp = vBuffer[uvIdx] - 128;

      final double r = (yp + 1.402 * vp).clamp(0, 255) / 255.0;
      final double g = (yp - 0.344136 * up - 0.714136 * vp).clamp(0, 255) / 255.0;
      final double b = (yp + 1.772 * up).clamp(0, 255) / 255.0;

      if (isNHWC) {
        final int idx = (targetY * targetWidth + targetX) * 3;
        inputBytes[idx] = r;
        inputBytes[idx + 1] = g;
        inputBytes[idx + 2] = b;
      } else {
        final int offset = targetY * targetWidth + targetX;
        inputBytes[0 * planeSize + offset] = r;
        inputBytes[1 * planeSize + offset] = g;
        inputBytes[2 * planeSize + offset] = b;
      }
    }
  }

  return _LetterboxResult(
    inputBytes: inputBytes,
    scale: scale,
    padX: padX,
    padY: padY,
    origWidth: rotW,
    origHeight: rotH,
    isFrontCamera: isFrontCamera,
  );
}

/// Ultra-fast single-pass BGRA to letterbox sampler with built-in hardware rotation.
_LetterboxResult _directSampleBgraToLetterbox({
  required int width,
  required int height,
  required Uint8List bgraBytes,
  required int sensorOrientation,
  required int targetWidth,
  required int targetHeight,
  required bool isNHWC,
  required bool isFrontCamera,
}) {
  final int rotationAngle = isFrontCamera
      ? (360 - sensorOrientation) % 360
      : sensorOrientation;

  final bool swapDims = (rotationAngle == 90 || rotationAngle == 270);
  final int rotW = swapDims ? height : width;
  final int rotH = swapDims ? width : height;

  final double scale = (targetWidth / rotW < targetHeight / rotH)
      ? targetWidth / rotW
      : targetHeight / rotH;
  final int newW = (rotW * scale).round().clamp(1, targetWidth);
  final int newH = (rotH * scale).round().clamp(1, targetHeight);
  final double padX = (targetWidth - newW) / 2.0;
  final double padY = (targetHeight - newH) / 2.0;
  final int startX = padX.round();
  final int startY = padY.round();

  final inputBytes = Float32List(1 * targetHeight * targetWidth * 3);
  inputBytes.fillRange(0, inputBytes.length, 114.0 / 255.0);

  final double invScale = 1.0 / scale;
  final int maxSrcX = width - 1;
  final int maxSrcY = height - 1;
  final int planeSize = targetHeight * targetWidth;

  for (int dy = 0; dy < newH; dy++) {
    final int targetY = startY + dy;
    if (targetY < 0 || targetY >= targetHeight) continue;
    final double rotY = dy * invScale;

    for (int dx = 0; dx < newW; dx++) {
      final int targetX = startX + dx;
      if (targetX < 0 || targetX >= targetWidth) continue;
      final double rotX = dx * invScale;

      int srcX;
      int srcY;
      if (rotationAngle == 90) {
        srcX = rotY.toInt();
        srcY = maxSrcY - rotX.toInt();
      } else if (rotationAngle == 270) {
        srcX = maxSrcX - rotY.toInt();
        srcY = rotX.toInt();
      } else if (rotationAngle == 180) {
        srcX = maxSrcX - rotX.toInt();
        srcY = maxSrcY - rotY.toInt();
      } else {
        srcX = rotX.toInt();
        srcY = rotY.toInt();
      }

      if (srcX < 0) {
        srcX = 0;
      } else if (srcX > maxSrcX) {
        srcX = maxSrcX;
      }
      if (srcY < 0) {
        srcY = 0;
      } else if (srcY > maxSrcY) {
        srcY = maxSrcY;
      }

      final int srcIdx = (srcY * width + srcX) * 4;
      if (srcIdx + 2 >= bgraBytes.length) continue;

      final double b = bgraBytes[srcIdx] / 255.0;
      final double g = bgraBytes[srcIdx + 1] / 255.0;
      final double r = bgraBytes[srcIdx + 2] / 255.0;

      if (isNHWC) {
        final int idx = (targetY * targetWidth + targetX) * 3;
        inputBytes[idx] = r;
        inputBytes[idx + 1] = g;
        inputBytes[idx + 2] = b;
      } else {
        final int offset = targetY * targetWidth + targetX;
        inputBytes[0 * planeSize + offset] = r;
        inputBytes[1 * planeSize + offset] = g;
        inputBytes[2 * planeSize + offset] = b;
      }
    }
  }

  return _LetterboxResult(
    inputBytes: inputBytes,
    scale: scale,
    padX: padX,
    padY: padY,
    origWidth: rotW,
    origHeight: rotH,
    isFrontCamera: isFrontCamera,
  );
}

/// Native (Android/iOS/Desktop) implementation using TFLite with multi-threading & isolates.
class PuffDetectionServiceImpl {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  bool _isInitialized = false;
  Future<bool>? _initFuture;
  List<List<List<double>>>? _cachedOutputBuffer;
  List<PuffDetection> _previousDetections = [];

  /// Tunable confidence threshold (defaults to 0.22 for responsive real-world device detection)
  double confidenceThreshold = 0.22;

  /// Target device mode: 'both' (default for EMBER - detects both Vape and Cigarette automatically)
  String targetDevice = 'both';

  int _framesReceived = 0;
  int _framesProcessed = 0;

  int get framesReceived => _framesReceived;
  int get framesProcessed => _framesProcessed;

  List<List<List<double>>> _getOutputBuffer(int d1, int d2) {
    if (_cachedOutputBuffer == null ||
        _cachedOutputBuffer![0].length != d1 ||
        _cachedOutputBuffer![0][0].length != d2) {
      _cachedOutputBuffer = List.generate(
        1,
        (_) => List.generate(d1, (_) => List.filled(d2, 0.0)),
      );
    }
    return _cachedOutputBuffer!;
  }

  Future<bool> initialize() {
    if (_isInitialized) return Future.value(true);
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<bool> _doInitialize() async {
    try {
      final options = InterpreterOptions()..threads = 4;

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final gpuDelegate = GpuDelegateV2();
          options.addDelegate(gpuDelegate);
          Logger.info('GpuDelegateV2 attached for Android hardware acceleration');
        } catch (e) {
          Logger.info('GPU delegate unavailable, using multi-threaded CPU: $e');
        }
      }

      try {
        _interpreter = await Interpreter.fromAsset(
          'assets/models/puff_detection.tflite',
          options: options,
        );
      } catch (e) {
        Logger.warning('GPU model load fallback ($e), falling back to standard CPU');
        _interpreter = await Interpreter.fromAsset(
          'assets/models/puff_detection.tflite',
          options: InterpreterOptions()..threads = 4,
        );
      }

      try {
        _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);
        Logger.info('IsolateInterpreter initialized for non-blocking background inference');
      } catch (e) {
        Logger.warning('IsolateInterpreter fallback to main thread interpreter: $e');
      }
      _isInitialized = true;

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      Logger.info('TFLite model loaded successfully.');
      Logger.info('  Input shape:  ${inputTensor.shape}  type: ${inputTensor.type}');
      Logger.info('  Output shape: ${outputTensor.shape}  type: ${outputTensor.type}');
      return true;
    } catch (e) {
      Logger.error('Failed to load TFLite model: $e');
      return false;
    }
  }

  /// High-performance inference directly from raw JPEG snapshot bytes (offloads to background isolate)
  Future<List<PuffDetection>> detectFromJpegBytes(
    Uint8List jpegBytes, {
    bool isFrontCamera = false,
  }) async {
    if (!_isInitialized || _interpreter == null) {
      Logger.warning('Puff detection disabled — TFLite model not available');
      return [];
    }

    final stopwatch = Stopwatch()..start();
    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final bool isNHWC = inputShape.length == 4 && inputShape[3] == 3;
      final int inputHeight = isNHWC ? inputShape[1] : inputShape[2];
      final int inputWidth = isNHWC ? inputShape[2] : inputShape[3];

      final letterboxResult = await Isolate.run(() {
        return _decodeJpegAndLetterboxPack(
          jpegBytes,
          inputWidth,
          inputHeight,
          isNHWC,
          isFrontCamera: isFrontCamera,
        );
      });

      if (letterboxResult == null) return [];

      return await _runInferenceOnPackedBytes(letterboxResult, inputWidth, inputHeight, isNHWC, stopwatch);
    } catch (e) {
      Logger.error('Error during JPEG inference: $e');
      return [];
    }
  }

  /// High-performance inference from live camera frame using direct single-pass sampling
  Future<List<PuffDetection>> detectFromFrame(
    CameraImage frame, {
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) async {
    _framesReceived++;
    if (!_isInitialized || _interpreter == null) {
      Logger.warning('Puff detection disabled — TFLite model not available');
      return [];
    }

    final stopwatch = Stopwatch()..start();
    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final bool isNHWC = inputShape.length == 4 && inputShape[3] == 3;
      final int inputHeight = isNHWC ? inputShape[1] : inputShape[2];
      final int inputWidth = isNHWC ? inputShape[2] : inputShape[3];

      _LetterboxResult? letterboxResult;

      if (frame.format.group == ImageFormatGroup.yuv420 && frame.planes.length >= 3) {
        letterboxResult = _directSampleYuv420ToLetterbox(
          width: frame.width,
          height: frame.height,
          yBuffer: frame.planes[0].bytes,
          uBuffer: frame.planes[1].bytes,
          vBuffer: frame.planes[2].bytes,
          yRowStride: frame.planes[0].bytesPerRow,
          yPixelStride: frame.planes[0].bytesPerPixel ?? 1,
          uvRowStride: frame.planes[1].bytesPerRow,
          uvPixelStride: frame.planes[1].bytesPerPixel ?? 1,
          sensorOrientation: sensorOrientation,
          targetWidth: inputWidth,
          targetHeight: inputHeight,
          isNHWC: isNHWC,
          isFrontCamera: isFrontCamera,
        );
      } else if (frame.format.group == ImageFormatGroup.bgra8888 && frame.planes.isNotEmpty) {
        letterboxResult = _directSampleBgraToLetterbox(
          width: frame.width,
          height: frame.height,
          bgraBytes: frame.planes[0].bytes,
          sensorOrientation: sensorOrientation,
          targetWidth: inputWidth,
          targetHeight: inputHeight,
          isNHWC: isNHWC,
          isFrontCamera: isFrontCamera,
        );
      }

      if (letterboxResult == null) return [];

      final detections = await _runInferenceOnPackedBytes(
        letterboxResult,
        inputWidth,
        inputHeight,
        isNHWC,
        stopwatch,
      );

      _framesProcessed++;
      if (_framesProcessed % 15 == 0 || detections.isNotEmpty) {
        Logger.info(
          'Live Frame #$_framesProcessed (received #$_framesReceived): latency=${stopwatch.elapsedMilliseconds}ms, detections=${detections.length}',
        );
      }

      return detections;
    } catch (e, st) {
      Logger.error('Error during frame inference: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Inference from static image (used for testing or frame-by-frame analysis)
  Future<List<PuffDetection>> detectFromImage(img.Image image) async {
    if (!_isInitialized || _interpreter == null) {
      Logger.warning('Puff detection disabled — TFLite model not available');
      return [];
    }

    final stopwatch = Stopwatch()..start();
    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final bool isNHWC = inputShape.length == 4 && inputShape[3] == 3;
      final int inputHeight = isNHWC ? inputShape[1] : inputShape[2];
      final int inputWidth = isNHWC ? inputShape[2] : inputShape[3];

      final orientedImage = img.bakeOrientation(image);

      final letterboxResult = await Isolate.run(() {
        return _letterboxAndPack(orientedImage, inputWidth, inputHeight, isNHWC);
      });

      return await _runInferenceOnPackedBytes(letterboxResult, inputWidth, inputHeight, isNHWC, stopwatch);
    } catch (e) {
      Logger.error('Error during image inference: $e');
      return [];
    }
  }

  Future<List<PuffDetection>> _runInferenceOnPackedBytes(
    _LetterboxResult packResult,
    int inputWidth,
    int inputHeight,
    bool isNHWC,
    Stopwatch stopwatch,
  ) async {
    try {
      final input = isNHWC
          ? packResult.inputBytes.reshape([1, inputHeight, inputWidth, 3])
          : packResult.inputBytes.reshape([1, 3, inputHeight, inputWidth]);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final bool isTransposed = outputShape[1] < outputShape[2];
      final int numProposals = isTransposed ? outputShape[2] : outputShape[1];

      final outputBuffer = _getOutputBuffer(outputShape[1], outputShape[2]);

      final inferenceStart = stopwatch.elapsedMilliseconds;
      if (_isolateInterpreter != null) {
        await _isolateInterpreter!.run(input, outputBuffer);
      } else {
        _interpreter!.run(input, outputBuffer);
      }
      final inferenceTime = stopwatch.elapsedMilliseconds - inferenceStart;

      List<PuffDetection> rawCandidates = [];
      double maxConfObserved = 0.0;

      final mode = targetDevice.toLowerCase().trim();

      for (var i = 0; i < numProposals; i++) {
        final cx = isTransposed ? outputBuffer[0][0][i] : outputBuffer[0][i][0];
        final cy = isTransposed ? outputBuffer[0][1][i] : outputBuffer[0][i][1];
        final w  = isTransposed ? outputBuffer[0][2][i] : outputBuffer[0][i][2];
        final h  = isTransposed ? outputBuffer[0][3][i] : outputBuffer[0][i][3];

        final double vapeConf = isTransposed ? outputBuffer[0][4][i] : outputBuffer[0][i][4];
        final double cigConf  = isTransposed ? outputBuffer[0][5][i] : outputBuffer[0][i][5];

        double bestConf = 0.0;
        int bestClass = -1;

        if (mode == 'vape') {
          if (vapeConf >= confidenceThreshold) {
            bestConf = vapeConf;
            bestClass = 0;
          }
        } else if (mode == 'cigarette') {
          if (cigConf >= confidenceThreshold) {
            bestConf = cigConf;
            bestClass = 1;
          }
        } else {
          // 'both' mode: select whichever class is higher
          final double maxC = vapeConf >= cigConf ? vapeConf : cigConf;
          if (maxC >= confidenceThreshold) {
            bestConf = maxC;
            bestClass = vapeConf >= cigConf ? 0 : 1;
          }
        }

        final double highestRaw = vapeConf >= cigConf ? vapeConf : cigConf;
        if (highestRaw > maxConfObserved) {
          maxConfObserved = highestRaw;
        }

        if (bestConf < confidenceThreshold || bestClass < 0) continue;

        // Coordinates in 640x640 space
        final double pixelCX = cx > 1.1 ? cx : cx * inputWidth;
        final double pixelCY = cy > 1.1 ? cy : cy * inputHeight;
        final double pixelW  = w > 1.1 ? w : w * inputWidth;
        final double pixelH  = h > 1.1 ? h : h * inputHeight;

        // Un-letterbox: remove padding and divide by scale
        final double origCX = (pixelCX - packResult.padX) / packResult.scale;
        final double origCY = (pixelCY - packResult.padY) / packResult.scale;
        final double origW  = pixelW / packResult.scale;
        final double origH  = pixelH / packResult.scale;

        double normX = (origCX / packResult.origWidth).clamp(0.0, 1.0);
        final double normY = (origCY / packResult.origHeight).clamp(0.0, 1.0);
        final double normW = (origW / packResult.origWidth).clamp(0.0, 1.0);
        final double normH = (origH / packResult.origHeight).clamp(0.0, 1.0);

        // Mirror X for front camera selfie preview alignment
        if (packResult.isFrontCamera) {
          normX = (1.0 - normX).clamp(0.0, 1.0);
        }

        rawCandidates.add(PuffDetection(
          x: normX,
          y: normY,
          width: normW,
          height: normH,
          confidence: bestConf,
          classId: bestClass,
        ));
      }

      final rawDetections = _applyNMS(rawCandidates, iouThreshold: 0.45);
      final detections = _smoothDetections(rawDetections);

      final totalTime = stopwatch.elapsedMilliseconds;
      Logger.info(
        'Inference: total=${totalTime}ms (model=${inferenceTime}ms), max_conf=${maxConfObserved.toStringAsFixed(3)}, raw=${rawCandidates.length}, detections=${detections.length}',
      );

      return detections;
    } catch (e) {
      Logger.error('Error during tensor inference: $e');
      return [];
    }
  }

  List<PuffDetection> _applyNMS(List<PuffDetection> boxes, {double iouThreshold = 0.45}) {
    if (boxes.isEmpty) return [];

    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<PuffDetection> selected = [];
    List<bool> suppressed = List.filled(boxes.length, false);

    for (int i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;
      selected.add(boxes[i]);

      final boxA = boxes[i];
      final x1A = boxA.x - boxA.width / 2;
      final y1A = boxA.y - boxA.height / 2;
      final x2A = boxA.x + boxA.width / 2;
      final y2A = boxA.y + boxA.height / 2;
      final areaA = (x2A - x1A) * (y2A - y1A);

      for (int j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;

        final boxB = boxes[j];
        // Only suppress overlapping boxes of the SAME class
        if (boxA.classId != boxB.classId) continue;

        final x1B = boxB.x - boxB.width / 2;
        final y1B = boxB.y - boxB.height / 2;
        final x2B = boxB.x + boxB.width / 2;
        final y2B = boxB.y + boxB.height / 2;
        final areaB = (x2B - x1B) * (y2B - y1B);

        final x1Inter = x1A > x1B ? x1A : x1B;
        final y1Inter = y1A > y1B ? y1A : y1B;
        final x2Inter = x2A < x2B ? x2A : x2B;
        final y2Inter = y2A < y2B ? y2A : y2B;

        final interW = (x2Inter - x1Inter) > 0 ? (x2Inter - x1Inter) : 0.0;
        final interH = (y2Inter - y1Inter) > 0 ? (y2Inter - y1Inter) : 0.0;
        final interArea = interW * interH;

        final unionArea = areaA + areaB - interArea;
        final iou = unionArea > 0 ? interArea / unionArea : 0.0;

        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return selected;
  }

  List<PuffDetection> _smoothDetections(List<PuffDetection> currentDetections) {
    if (currentDetections.isEmpty) {
      _previousDetections = [];
      return [];
    }
    if (_previousDetections.isEmpty) {
      _previousDetections = currentDetections;
      return currentDetections;
    }

    const double alpha = 0.65;
    List<PuffDetection> smoothed = [];

    for (var curr in currentDetections) {
      PuffDetection? match;
      double minDistance = double.infinity;
      for (var prev in _previousDetections) {
        if (prev.classId == curr.classId) {
          final dist = (curr.x - prev.x).abs() + (curr.y - prev.y).abs();
          if (dist < minDistance && dist < 0.25) {
            minDistance = dist;
            match = prev;
          }
        }
      }

      if (match != null) {
        smoothed.add(PuffDetection(
          x: alpha * curr.x + (1 - alpha) * match.x,
          y: alpha * curr.y + (1 - alpha) * match.y,
          width: alpha * curr.width + (1 - alpha) * match.width,
          height: alpha * curr.height + (1 - alpha) * match.height,
          confidence: alpha * curr.confidence + (1 - alpha) * match.confidence,
          classId: curr.classId,
        ));
      } else {
        smoothed.add(curr);
      }
    }

    _previousDetections = smoothed;
    return smoothed;
  }

  void dispose() {
    _isolateInterpreter?.close();
    _interpreter?.close();
    _interpreter = null;
    _isolateInterpreter = null;
    _isInitialized = false;
    _initFuture = null;
    _cachedOutputBuffer = null;
    Logger.info('Puff detection service disposed');
  }
}
