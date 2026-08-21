import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Top-level helper function for background isolate image packing
Float32List _packImageToFloat32(img.Image image, int targetWidth, int targetHeight, bool isNHWC) {
  final resized = img.copyResize(image, width: targetWidth, height: targetHeight);
  final inputBytes = Float32List(1 * targetHeight * targetWidth * 3);

  if (isNHWC) {
    int idx = 0;
    for (var y = 0; y < targetHeight; y++) {
      for (var x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixelSafe(x, y);
        inputBytes[idx++] = pixel.r / 255.0;
        inputBytes[idx++] = pixel.g / 255.0;
        inputBytes[idx++] = pixel.b / 255.0;
      }
    }
  } else {
    final int planeSize = targetHeight * targetWidth;
    for (var y = 0; y < targetHeight; y++) {
      for (var x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixelSafe(x, y);
        final int idx = y * targetWidth + x;
        inputBytes[0 * planeSize + idx] = pixel.r / 255.0;
        inputBytes[1 * planeSize + idx] = pixel.g / 255.0;
        inputBytes[2 * planeSize + idx] = pixel.b / 255.0;
      }
    }
  }
  return inputBytes;
}

/// Top-level helper function for background isolate JPEG decode + resize + packing
Float32List? _decodeJpegAndPack(Uint8List jpegBytes, int targetWidth, int targetHeight, bool isNHWC) {
  final decoded = img.decodeImage(jpegBytes);
  if (decoded == null) return null;
  return _packImageToFloat32(decoded, targetWidth, targetHeight, isNHWC);
}

/// Top-level helper function for YUV420 conversion
img.Image _convertYUV420(int width, int height, Uint8List yBuffer, Uint8List uBuffer, Uint8List vBuffer,
    int yRowStride, int yPixelStride, int uvRowStride, int uvPixelStride) {
  final res = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int yIndex = y * yRowStride + x * yPixelStride;
      final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

      final yp = yBuffer[yIndex];
      final up = uBuffer[uvIndex] - 128;
      final vp = vBuffer[uvIndex] - 128;

      int r = (yp + vp * 1436 / 1024).round().clamp(0, 255);
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
      int b = (yp + up * 1814 / 1024).round().clamp(0, 255);

      res.setPixelRgb(x, y, r, g, b);
    }
  }
  return res;
}

/// Native (Android/iOS/Desktop) implementation using TFLite with multi-threading & isolates.
class PuffDetectionServiceImpl {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<PuffDetection> _previousDetections = [];

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final options = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        'assets/models/puff_detection.tflite',
        options: options,
      );
      _isInitialized = true;

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      Logger.info('TFLite Float16 model loaded successfully.');
      Logger.info('  Input shape:  ${inputTensor.shape}  type: ${inputTensor.type}');
      Logger.info('  Output shape: ${outputTensor.shape}  type: ${outputTensor.type}');
      return true;
    } catch (e) {
      Logger.error('Failed to load TFLite model: $e');
      return false;
    }
  }

  /// High-performance inference directly from raw JPEG snapshot bytes (offloads to background isolate)
  Future<List<PuffDetection>> detectFromJpegBytes(Uint8List jpegBytes) async {
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

      // Decode JPEG, resize, and pack in Background Isolate (Zero UI thread blocking)
      final inputBytes = await Isolate.run(() {
        return _decodeJpegAndPack(jpegBytes, inputWidth, inputHeight, isNHWC);
      });

      if (inputBytes == null) return [];

      return _runInferenceOnPackedBytes(inputBytes, inputWidth, inputHeight, isNHWC, stopwatch);
    } catch (e) {
      Logger.error('Error during JPEG inference: $e');
      return [];
    }
  }

  Future<List<PuffDetection>> detectFromFrame(CameraImage frame, {int sensorOrientation = 0}) async {
    if (!_isInitialized || _interpreter == null) {
      Logger.warning('Puff detection disabled — TFLite model not available');
      return [];
    }

    final stopwatch = Stopwatch()..start();
    try {
      img.Image? convertedImage;
      if (frame.format.group == ImageFormatGroup.yuv420) {
        final yPlane = frame.planes[0];
        final uPlane = frame.planes[1];
        final vPlane = frame.planes[2];
        convertedImage = _convertYUV420(
          frame.width,
          frame.height,
          yPlane.bytes,
          uPlane.bytes,
          vPlane.bytes,
          yPlane.bytesPerRow,
          yPlane.bytesPerPixel ?? 1,
          uPlane.bytesPerRow,
          uPlane.bytesPerPixel ?? 1,
        );
      } else if (frame.format.group == ImageFormatGroup.bgra8888) {
        convertedImage = img.Image.fromBytes(
          width: frame.width,
          height: frame.height,
          bytes: frame.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      }

      if (convertedImage == null) {
        return [];
      }

      img.Image rotatedImage = convertedImage;
      if (sensorOrientation != 0) {
        rotatedImage = img.copyRotate(convertedImage, angle: sensorOrientation);
      }

      return await detectFromImage(rotatedImage);
    } catch (e) {
      Logger.error('Error during frame inference: $e');
      return [];
    }
  }

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

      // Pack pixels in background isolate
      final inputBytes = await Isolate.run(() {
        return _packImageToFloat32(image, inputWidth, inputHeight, isNHWC);
      });

      return _runInferenceOnPackedBytes(inputBytes, inputWidth, inputHeight, isNHWC, stopwatch);
    } catch (e) {
      Logger.error('Error during image inference: $e');
      return [];
    }
  }

  List<PuffDetection> _runInferenceOnPackedBytes(
    Float32List inputBytes,
    int inputWidth,
    int inputHeight,
    bool isNHWC,
    Stopwatch stopwatch,
  ) {
    try {
      final input = isNHWC
          ? inputBytes.reshape([1, inputHeight, inputWidth, 3])
          : inputBytes.reshape([1, 3, inputHeight, inputWidth]);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      bool isTransposed = outputShape[1] < outputShape[2];
      final numProposals = isTransposed ? outputShape[2] : outputShape[1];
      final numAttributes = isTransposed ? outputShape[1] : outputShape[2];

      var outputBuffer = List.generate(
          1, (_) => List.generate(outputShape[1], (_) => List.filled(outputShape[2], 0.0)));

      final inferenceStart = stopwatch.elapsedMilliseconds;
      _interpreter!.run(input, outputBuffer);
      final inferenceTime = stopwatch.elapsedMilliseconds - inferenceStart;

      List<PuffDetection> rawCandidates = [];
      const confidenceThreshold = 0.25;
      double maxConfObserved = 0.0;

      for (var i = 0; i < numProposals; i++) {
        final cx = isTransposed ? outputBuffer[0][0][i] : outputBuffer[0][i][0];
        final cy = isTransposed ? outputBuffer[0][1][i] : outputBuffer[0][i][1];
        final w  = isTransposed ? outputBuffer[0][2][i] : outputBuffer[0][i][2];
        final h  = isTransposed ? outputBuffer[0][3][i] : outputBuffer[0][i][3];

        double bestConf = 0.0;
        int bestClass = -1;

        for (int c = 4; c < numAttributes; c++) {
          final conf = isTransposed ? outputBuffer[0][c][i] : outputBuffer[0][i][c];
          if (conf > bestConf) {
            bestConf = conf;
            bestClass = c - 4;
          }
        }

        if (numAttributes == 6) {
          final confVal = isTransposed ? outputBuffer[0][4][i] : outputBuffer[0][i][4];
          if (confVal > 0.0) {
            bestConf = confVal;
            bestClass = (isTransposed ? outputBuffer[0][5][i] : outputBuffer[0][i][5]).round();
          }
        }

        if (bestConf > maxConfObserved) {
          maxConfObserved = bestConf;
        }

        if (bestConf <= 0.0) continue;

        if (bestConf > confidenceThreshold) {
          final double scaleX = (cx > 1.1 || w > 1.1) ? inputWidth.toDouble() : 1.0;
          final double scaleY = (cy > 1.1 || h > 1.1) ? inputHeight.toDouble() : 1.0;

          rawCandidates.add(PuffDetection(
            x: cx / scaleX,
            y: cy / scaleY,
            width: w / scaleX,
            height: h / scaleY,
            confidence: bestConf,
            classId: bestClass,
          ));
        }
      }

      final rawDetections = _applyNMS(rawCandidates, iouThreshold: 0.45);
      final detections = _smoothDetections(rawDetections);

      final totalTime = stopwatch.elapsedMilliseconds;
      Logger.info('Inference Complete: total=${totalTime}ms, inference=${inferenceTime}ms, max_conf=${maxConfObserved.toStringAsFixed(3)}, raw=${rawCandidates.length}, detections=${detections.length}');

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
    _interpreter?.close();
    _isInitialized = false;
    Logger.info('Puff detection service disposed');
  }
}
