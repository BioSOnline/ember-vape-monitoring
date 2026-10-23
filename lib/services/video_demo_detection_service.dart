import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:ember/services/puff_detection_service.dart';

class VideoDetectionResult {
  final int offsetSeconds;
  final double confidence;
  final String label;
  final int classId;
  final double durationSeconds;

  const VideoDetectionResult({
    required this.offsetSeconds,
    required this.confidence,
    required this.label,
    this.classId = 0,
    this.durationSeconds = 1.0,
  });
}

class VideoAnalysisResult {
  final List<VideoDetectionResult> detections;
  final String summary;
  final int totalFrames;
  final double durationSeconds;

  const VideoAnalysisResult({
    required this.detections,
    required this.summary,
    this.totalFrames = 0,
    this.durationSeconds = 0.0,
  });
}

class _RawFrameDetection {
  final double timestamp;
  final PuffDetection detection;

  _RawFrameDetection({required this.timestamp, required this.detection});
}

class VideoDemoDetectionService {
  static const int analysisFps = 4;
  static const int frameIntervalMs = 1000 ~/ analysisFps; // 250ms interval for high-accuracy puff detection
  static const MethodChannel _metadataChannel = MethodChannel('com.mite.cse.ember/video_metadata');
  final PuffDetectionService _detectionService = PuffDetectionService();

  static bool _areBytesIdentical(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Extracts duration in seconds from byte sequence containing 'mvhd' atom
  static double? _extractMvhd(Uint8List bytes) {
    if (bytes.length < 32) return null;
    final data = ByteData.sublistView(bytes);
    for (int i = 0; i <= bytes.length - 32; i++) {
      // 'mvhd' marker in big-endian bytes: 0x6D, 0x76, 0x68, 0x64
      if (bytes[i] == 0x6D && bytes[i + 1] == 0x76 && bytes[i + 2] == 0x68 && bytes[i + 3] == 0x64) {
        final version = data.getUint8(i + 4);
        if (version == 0) {
          final timescale = data.getUint32(i + 16, Endian.big);
          final duration = data.getUint32(i + 20, Endian.big);
          if (timescale > 0 && duration > 0) return duration / timescale;
        } else if (version == 1) {
          final timescale = data.getUint32(i + 24, Endian.big);
          final duration = data.getUint64(i + 28, Endian.big);
          if (timescale > 0 && duration > 0) return duration / timescale;
        }
      }
    }
    return null;
  }

  /// Parses duration in seconds directly from MP4 container bytes (tail, head, and box traversal)
  static double? parseMp4Duration(File file) {
    try {
      final raf = file.openSync(mode: FileMode.read);
      final len = raf.lengthSync();

      // Check tail first (where phone camera recordings place 'moov')
      final tailLen = len < 4194304 ? len : 4194304;
      raf.setPositionSync(len - tailLen);
      final tailBytes = raf.readSync(tailLen);
      final tailDur = _extractMvhd(tailBytes);
      if (tailDur != null && tailDur > 0) {
        raf.closeSync();
        return tailDur;
      }

      // If not in tail, check head (standard web-optimized MP4 files with faststart)
      if (len > tailLen) {
        final headLen = len < 4194304 ? len : 4194304;
        raf.setPositionSync(0);
        final headBytes = raf.readSync(headLen);
        final headDur = _extractMvhd(headBytes);
        if (headDur != null && headDur > 0) {
          raf.closeSync();
          return headDur;
        }
      }

      // Box traversal fallback for very large files (>4MB) where 'moov' might be anywhere
      raf.setPositionSync(0);
      int pos = 0;
      final headerBuf = Uint8List(8);
      while (pos < len - 8) {
        raf.setPositionSync(pos);
        final read = raf.readIntoSync(headerBuf);
        if (read < 8) break;
        final bd = ByteData.sublistView(headerBuf);
        int boxSize = bd.getUint32(0, Endian.big);
        final type = String.fromCharCodes(headerBuf.sublist(4, 8));

        if (type == 'moov') {
          final readMoovLen = (boxSize > 8 && boxSize <= 8388608) ? boxSize - 8 : (len - pos - 8).clamp(0, 8388608);
          final moovBytes = raf.readSync(readMoovLen);
          final moovDur = _extractMvhd(moovBytes);
          if (moovDur != null && moovDur > 0) {
            raf.closeSync();
            return moovDur;
          }
        }

        if (boxSize == 0) break; // extends to EOF
        if (boxSize == 1) {
          // 64-bit size
          final size64Buf = Uint8List(8);
          if (raf.readIntoSync(size64Buf) < 8) break;
          final size64 = ByteData.sublistView(size64Buf).getUint64(0, Endian.big);
          if (size64 < 16) break;
          pos += size64;
        } else {
          if (boxSize < 8) break;
          pos += boxSize;
        }
      }

      raf.closeSync();
    } catch (e) {
      Logger.warning('Dart parseMp4Duration failed: $e');
    }
    return null;
  }

  /// Gets true video duration using native Android MediaMetadataRetriever with Dart MP4 fallback
  static Future<double?> getVideoDuration(File file) async {
    // 1. First attempt: Native Android MediaMetadataRetriever (works for MP4, MOV, MKV, AVI, etc.)
    try {
      final durationMs = await _metadataChannel.invokeMethod<num>('getVideoDurationMs', {'path': file.path});
      if (durationMs != null && durationMs > 0) {
        final sec = durationMs.toDouble() / 1000.0;
        Logger.info('Native MediaMetadataRetriever video duration: ${sec.toStringAsFixed(2)}s ($durationMs ms)');
        return sec;
      }
    } catch (e) {
      Logger.info('Native video metadata channel fallback ($e)');
    }

    // 2. Second attempt: Comprehensive Dart MP4 parser
    final parsed = parseMp4Duration(file);
    if (parsed != null && parsed > 0) {
      Logger.info('Parsed MP4 duration: ${parsed.toStringAsFixed(2)}s');
      return parsed;
    }
    return null;
  }

  Future<VideoAnalysisResult> analyzeVideo(
    File videoFile, {
    Function(double progress, String status)? onProgress,
  }) async {
    if (!await videoFile.exists()) {
      Logger.warning('Video file does not exist: ${videoFile.path}');
      return const VideoAnalysisResult(
        detections: [],
        summary: 'Video file could not be found or read.',
      );
    }

    final fileName = videoFile.path.split(Platform.pathSeparator).last;
    final sizeKb = (videoFile.lengthSync() / 1024).round();
    Logger.info('Starting video analysis for $fileName ($sizeKb KB)');

    onProgress?.call(0.08, 'Initializing TFLite detector model...');
    final initialized = await _detectionService.initialize();
    if (!initialized) {
      return const VideoAnalysisResult(
        detections: [],
        summary: 'The on-device detector could not be initialized, so no video detections were produced.',
      );
    }

    // Set detection target to both vape and cigarette with balanced confidence
    _detectionService.targetDevice = 'both';
    _detectionService.confidenceThreshold = 0.20;

    final rawFrameDetections = <_RawFrameDetection>[];
    List<File> frameFiles = <File>[];
    Directory? tempDir;
    double? videoDurationSec;

    try {
      videoDurationSec = await getVideoDuration(videoFile);
      tempDir = await Directory.systemTemp.createTemp('ember_frames_');
      onProgress?.call(0.15, 'Extracting video frames for analysis...');

      // Strategy 1: Attempt FFmpeg if installed on desktop host
      if (!kIsWeb) {
        try {
          final outputPathPattern = '${tempDir.path}${Platform.pathSeparator}frame_%04d.jpg';
          final ffmpegResult = await Process.run('ffmpeg', [
            '-y',
            '-i',
            videoFile.path,
            '-vf',
            'fps=$analysisFps',
            '-q:v',
            '2',
            outputPathPattern,
          ]);

          if (ffmpegResult.exitCode == 0 && tempDir.existsSync()) {
            frameFiles = tempDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.jpg'))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
          }
        } catch (e) {
          Logger.info('Host FFmpeg not available or failed ($e), falling back to native video thumbnail extractor');
        }
      }

      // Strategy 2: If FFmpeg did not produce frames (e.g. on Android/iOS), use native VideoThumbnail
      if (frameFiles.isEmpty) {
        try {
          onProgress?.call(0.18, 'Extracting frames using native video decoder ($analysisFps FPS)...');

          int maxFrames = 240; // safe fallback up to 60s at 4 FPS
          if (videoDurationSec != null && videoDurationSec > 0) {
            maxFrames = (videoDurationSec * analysisFps).ceil();
            Logger.info('Determined video duration: ${videoDurationSec.toStringAsFixed(2)}s => extracting up to $maxFrames frames ($analysisFps FPS)');
          }

          int duplicateStreak = 0;
          Uint8List? lastFrameBytes;

          for (int frameIdx = 0; frameIdx < maxFrames; frameIdx++) {
            final timeMs = frameIdx * frameIntervalMs;
            // If duration is known, never request frames beyond the video duration
            if (videoDurationSec != null && (timeMs / 1000.0) >= videoDurationSec) {
              break;
            }

            // CRITICAL FIX: Android video_thumbnail requires thumbnailPath to end with .jpg
            // so it saves each frame as an independent file rather than overwriting the video name!
            final frameTargetName = 'frame_${frameIdx.toString().padLeft(4, '0')}.jpg';
            final frameTargetPath = '${tempDir.path}${Platform.pathSeparator}$frameTargetName';

            final path = await VideoThumbnail.thumbnailFile(
              video: videoFile.path,
              thumbnailPath: frameTargetPath,
              imageFormat: ImageFormat.JPEG,
              timeMs: timeMs,
              quality: 85,
            );

            if (path != null && File(path).existsSync()) {
              final file = File(path);
              if (file.lengthSync() == 0) {
                try { file.deleteSync(); } catch (_) {}
                break;
              }

              // Detect MediaMetadataRetriever EOF clamping when duration was not pre-determined
              if (videoDurationSec == null && frameIdx >= 4) {
                final currBytes = await file.readAsBytes();
                if (lastFrameBytes != null && _areBytesIdentical(lastFrameBytes, currBytes)) {
                  duplicateStreak++;
                  // If 2 duplicate frames extracted in a row at the end, EOF has been reached
                  if (duplicateStreak >= 2) {
                    try { file.deleteSync(); } catch (_) {}
                    break;
                  }
                } else {
                  duplicateStreak = 0;
                }
                lastFrameBytes = currBytes;
              }

              frameFiles.add(file);
            } else {
              break;
            }
          }
        } catch (e) {
          Logger.warning('Native VideoThumbnail extraction failed: $e');
        }
      }

      if (frameFiles.isNotEmpty) {
        final total = frameFiles.length;
        Logger.info('Extracted $total frames from $fileName for TFLite inference ($analysisFps FPS)');

        for (int i = 0; i < total; i++) {
          final progress = 0.20 + (0.75 * (i + 1) / total);
          final timestampSec = i / analysisFps;
          final timeStr = _formatTimestamp(timestampSec.round());
          onProgress?.call(
            progress,
            'Analyzing frame ${i + 1}/$total (timestamp $timeStr)...',
          );

          final frameFile = frameFiles[i];
          final bytes = await frameFile.readAsBytes();

          // Run through the exact same inference pipeline as live camera frames
          final frameDetections = await _detectionService.detectFromJpegBytes(bytes);

          // Accept detections that are:
          // 1) Positioned near lips/mouth with standard confidence (>= 0.25), OR
          // 2) Strong device detections (>= 0.38) within the general upper body framing (for landscape or off-center uploads)
          final valid = frameDetections.where((d) {
            if (d.confidence < 0.25) return false;
            if (d.isNearMouth) return true;
            final bool inUpperBodyZone = d.x >= 0.10 && d.x <= 0.90 && d.y >= 0.10 && d.y <= 0.85;
            return inUpperBodyZone && d.confidence >= 0.38;
          }).toList();

          if (valid.isNotEmpty) {
            final best = valid.reduce((a, b) => a.confidence >= b.confidence ? a : b);
            rawFrameDetections.add(_RawFrameDetection(timestamp: timestampSec, detection: best));
          }
        }
      } else {
        Logger.warning('No frames could be extracted from $fileName');
      }
    } catch (e, st) {
      Logger.error('Error during video frame analysis: $e', error: e, stackTrace: st);
    } finally {
      // Privacy Guarantee: completely purge all temporary frame images immediately after analysis
      if (tempDir != null && tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
          Logger.info('Temporary video frames directory cleaned up successfully');
        } catch (_) {}
      }
    }

    // Group raw frame detections into distinct temporal puff events
    final groupedEvents = _aggregatePuffEvents(rawFrameDetections);

    onProgress?.call(1.0, 'Analysis complete!');

    final total = frameFiles.length;
    final effectiveDuration = (videoDurationSec != null && videoDurationSec > 0)
        ? videoDurationSec
        : (total / analysisFps);

    final summary = groupedEvents.isNotEmpty
        ? 'Analyzed $total frame(s) across ${effectiveDuration.toStringAsFixed(1)}s (at $analysisFps FPS). Identified ${groupedEvents.length} distinct puff moment(s) with YOLO.'
        : 'Analyzed $total frame(s) across ${effectiveDuration.toStringAsFixed(1)}s (at $analysisFps FPS). No puff events detected near lips.';

    Logger.info('Video analysis completed for $fileName => $total frames, ${groupedEvents.length} aggregated puff events');
    return VideoAnalysisResult(
      detections: groupedEvents,
      summary: summary,
      totalFrames: total,
      durationSeconds: effectiveDuration,
    );
  }

  /// Groups consecutive frame detections within 1.5s into unified puff events.
  List<VideoDetectionResult> _aggregatePuffEvents(List<_RawFrameDetection> raw) {
    if (raw.isEmpty) return const [];

    raw.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<List<_RawFrameDetection>> clusters = [];
    List<_RawFrameDetection> currentCluster = [raw.first];

    for (int i = 1; i < raw.length; i++) {
      final prev = currentCluster.last;
      final curr = raw[i];

      // If detection occurs within 1.5 seconds, group into the same event
      if ((curr.timestamp - prev.timestamp) <= 1.5) {
        currentCluster.add(curr);
      } else {
        clusters.add(currentCluster);
        currentCluster = [curr];
      }
    }
    clusters.add(currentCluster);

    final List<VideoDetectionResult> results = [];

    for (final cluster in clusters) {
      // Find highest confidence detection in the cluster
      final best = cluster.reduce((a, b) => a.detection.confidence >= b.detection.confidence ? a : b);

      // Filter out isolated single-frame low-confidence detections (spurious noise)
      if (cluster.length < 2 && best.detection.confidence < 0.45) {
        continue;
      }

      final startTime = cluster.first.timestamp;
      final endTime = cluster.last.timestamp;
      final duration = (endTime - startTime) > 0.4 ? (endTime - startTime) : 1.0;

      results.add(VideoDetectionResult(
        offsetSeconds: startTime.round(),
        confidence: best.detection.confidence,
        label: '${best.detection.className} puff',
        classId: best.detection.classId,
        durationSeconds: duration,
      ));
    }

    return results;
  }

  String _formatTimestamp(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<VideoDetectionResult> createResultsFromDetections(List<PuffDetection> detections, {required int offsetSeconds}) {
    if (detections.isEmpty) return const <VideoDetectionResult>[];
    final valid = detections.where((d) => d.confidence >= 0.25 && d.isNearMouth).toList();
    if (valid.isEmpty) return const <VideoDetectionResult>[];
    final bestDetection = valid.reduce((a, b) => a.confidence >= b.confidence ? a : b);
    return [
      VideoDetectionResult(
        offsetSeconds: offsetSeconds,
        confidence: bestDetection.confidence,
        label: '${bestDetection.className} detected',
        classId: bestDetection.classId,
      ),
    ];
  }
}
