import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';
import 'package:ember/models/puff_detection.dart';
import 'package:ember/services/puff_detection_service.dart';
import 'package:ember/services/supabase_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart' show DateFormat;

/// Temporal inhalation state machine for accurate puff confirmation
enum PuffGestureState {
  idle,
  inhaling,
  confirmed,
  cooldown,
}

/// Detailed record of a confirmed puff event during the live session
class SessionPuffRecord {
  final int puffNumber;
  final DateTime timestamp;
  final String deviceName;
  final double durationSeconds;
  final double confidence;
  final bool isSynced;
  final String id;

  SessionPuffRecord({
    required this.puffNumber,
    required this.timestamp,
    required this.deviceName,
    required this.durationSeconds,
    required this.confidence,
    this.isSynced = false,
    required this.id,
  });

  String get timeFormatted => DateFormat('h:mm:ss a').format(timestamp);
}

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? _cameraController;
  final _service = SupabaseService();
  final _detectionService = PuffDetectionService();
  final _uuid = const Uuid();
  Timer? _frameLoopTimer;

  bool _isInitializing = true;
  bool _hasCameraPermission = true;
  String _cameraError = '';
  bool _isProcessingFrame = false;
  bool _isDisposed = false;
  bool _isStreaming = false;
  final ValueNotifier<List<PuffDetection>> _detectionsNotifier = ValueNotifier<List<PuffDetection>>([]);
  int _captureIntervalMs = 280; // Snappy 3.5 FPS on-device inference with 60 FPS preview rendering
  List<PuffDetection> _currentDetections = [];
  
  // Lip / Mouth Proximity & Temporal Inhalation Gesture State Tracking
  PuffGestureState _gestureState = PuffGestureState.idle;
  DateTime? _inhaleStartTime;
  DateTime? _lastNearMouthTime;
  DateTime? _cooldownStartTime;
  String _currentInhaleDevice = 'Vape';
  double _currentInhaleConfidence = 0.0;
  double _currentInhaleDwellSeconds = 0.0;
  bool _puffLoggedForCurrentInhale = false;

  bool get _isPuffingNow => _gestureState == PuffGestureState.confirmed;

  int _sessionPuffCount = 0;
  Session? _activeSession;
  final List<DateTime> _sessionPuffTimestamps = [];
  final List<SessionPuffRecord> _sessionPuffHistory = [];
  
  // HUD UI State
  String _activeSettingTab = 'device'; // 'device' | 'fps' | 'sensitivity' | 'debug'
  bool _showControls = true;
  bool _isDebugOverlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeCameraAndSession();
  }

  Future<void> _initializeCameraAndSession() async {
    setState(() {
      _isInitializing = true;
      _cameraError = '';
    });

    final userId = SupabaseConfig.currentUserId;
    if (userId != null && _activeSession == null) {
      final session = Session(
        id: _uuid.v4(),
        userId: userId,
        startedAt: DateTime.now(),
      );
      _activeSession = await _service.createSession(session);
    }

    await _detectionService.initialize();
    _detectionService.confidenceThreshold = 0.22;
    _detectionService.targetDevice = 'both';

    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    // Release any previous controller before attempting new acquisition
    await _stopCameraStream();
    if (isWindows) {
      // Allow Windows Media Foundation to cleanly release the hardware sensor handle
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera devices detected on this system.');
      }

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      bool initialized = false;
      // Medium is universally supported by virtually all webcams; fallback to low then high
      final presets = [ResolutionPreset.medium, ResolutionPreset.low, ResolutionPreset.high];

      for (var preset in presets) {
        CameraController? controller;
        try {
          controller = CameraController(
            frontCamera,
            preset,
            enableAudio: false,
          );
          await controller.initialize();
          _cameraController = controller;
          _hasCameraPermission = true;
          _cameraError = '';
          initialized = true;
          break;
        } catch (err) {
          _cameraError = err.toString();
          try {
            await controller?.dispose();
          } catch (_) {}
        }
      }

      if (initialized && _cameraController != null) {
        _startInferenceStream();
      } else {
        _hasCameraPermission = false;
      }
    } catch (e) {
      _hasCameraPermission = false;
      _cameraError = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _startInferenceStream() {
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    if (isWindows) {
      _frameLoopTimer?.cancel();
      // Allow the camera preview texture to establish before starting snapshot inference
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isDisposed) {
          _runWindowsInferenceLoop();
        }
      });
    } else {
      try {
        final sensorOrientation = _cameraController!.description.sensorOrientation;
        final isFrontCamera = _cameraController!.description.lensDirection == CameraLensDirection.front;
        _isStreaming = true;
        _cameraController!.startImageStream((CameraImage image) {
          if (_isProcessingFrame || !_isStreaming || _isDisposed) return;
          _isProcessingFrame = true;

          _detectionService.detectFromFrame(
            image,
            sensorOrientation: sensorOrientation,
            isFrontCamera: isFrontCamera,
          ).then((detections) {
            if (mounted && !_isDisposed) {
              _processDetections(detections);
            }
            _isProcessingFrame = false;
          }).catchError((e, st) {
            Logger.error('Frame inference error: $e', error: e, stackTrace: st);
            _isProcessingFrame = false;
          });
        });
      } catch (e, st) {
        Logger.error('Failed to start camera image stream: $e', error: e, stackTrace: st);
      }
    }
  }

  void _processDetections(List<PuffDetection> detections) {
    // Filter detection class by user's selected target device
    final target = _detectionService.targetDevice.toLowerCase().trim();
    final mapped = target == 'vape'
        ? detections.where((d) => d.isVape).toList()
        : target == 'cigarette'
            ? detections.where((d) => d.isCigarette).toList()
            : detections;

    final now = DateTime.now();
    final nearMouthDetections = mapped.where((d) => d.isNearMouth).toList();

    PuffGestureState nextState = _gestureState;
    double liveDwellSec = 0.0;

    // 1. Evaluate Cooldown Expiry (600ms refractory window between distinct puffs)
    if (_gestureState == PuffGestureState.cooldown) {
      if (_cooldownStartTime != null && now.difference(_cooldownStartTime!).inMilliseconds >= 600) {
        nextState = PuffGestureState.idle;
      }
    }

    // 2. Evaluate Near-Mouth Inhalation Presence
    if (nearMouthDetections.isNotEmpty) {
      _lastNearMouthTime = now;
      final best = nearMouthDetections.reduce((a, b) => a.confidence >= b.confidence ? a : b);

      if (nextState != PuffGestureState.cooldown) {
        if (nextState == PuffGestureState.idle) {
          nextState = PuffGestureState.inhaling;
          _inhaleStartTime = now;
          _currentInhaleDevice = best.className;
          _currentInhaleConfidence = best.confidence;
          _puffLoggedForCurrentInhale = false;
        }

        if (nextState == PuffGestureState.inhaling) {
          final dwellMs = now.difference(_inhaleStartTime!).inMilliseconds;
          liveDwellSec = dwellMs / 1000.0;

          // Snappy dwell time (450ms) to confirm intentional inhale without false resets
          const int requiredDwellMs = 450;
          if (dwellMs >= requiredDwellMs && !_puffLoggedForCurrentInhale) {
            nextState = PuffGestureState.confirmed;
            _puffLoggedForCurrentInhale = true;
            _currentInhaleDevice = best.className;
            _currentInhaleConfidence = best.confidence;
            _onPuffConfirmed(now, liveDwellSec, best.className, best.confidence);
          }
        } else if (nextState == PuffGestureState.confirmed) {
          final dwellMs = now.difference(_inhaleStartTime!).inMilliseconds;
          liveDwellSec = dwellMs / 1000.0;

          // Update live draw duration for the ongoing puff in the history record
          if (_sessionPuffHistory.isNotEmpty) {
            final latest = _sessionPuffHistory.first;
            _sessionPuffHistory[0] = SessionPuffRecord(
              puffNumber: latest.puffNumber,
              timestamp: latest.timestamp,
              deviceName: latest.deviceName,
              durationSeconds: liveDwellSec,
              confidence: latest.confidence,
              isSynced: latest.isSynced,
              id: latest.id,
            );
          }
        }
      }
    } else {
      // 3. Device departed from lips or momentary camera frame flicker
      // Snappy grace period: 400ms for active inhale, 250ms for departure after confirmed puff
      final int gracePeriodMs = (_gestureState == PuffGestureState.confirmed) ? 250 : 400;
      final hasRecentContact = _lastNearMouthTime != null &&
          now.difference(_lastNearMouthTime!).inMilliseconds < gracePeriodMs;

      if (!hasRecentContact) {
        if (nextState == PuffGestureState.confirmed) {
          // Device departed lips after confirmed puff: enter short refractory cooldown (600ms)
          nextState = PuffGestureState.cooldown;
          _cooldownStartTime = now;
          _inhaleStartTime = null;
        } else if (nextState == PuffGestureState.inhaling) {
          // Hand pulled away before reaching required dwell: aborted approach
          nextState = PuffGestureState.idle;
          _inhaleStartTime = null;
        }
      } else if (nextState == PuffGestureState.inhaling || nextState == PuffGestureState.confirmed) {
        final dwellMs = _inhaleStartTime != null ? now.difference(_inhaleStartTime!).inMilliseconds : 0;
        liveDwellSec = dwellMs / 1000.0;
      }
    }

    _detectionsNotifier.value = mapped;
    _currentDetections = mapped;

    // Eliminate UI thread lag: only call setState when gesture state transitions
    // or when live inhale draw progress advances.
    if (mounted) {
      final stateChanged = _gestureState != nextState;
      final dwellChanged = _gestureState == PuffGestureState.inhaling &&
          (liveDwellSec - _currentInhaleDwellSeconds).abs() >= 0.08;

      if (stateChanged || dwellChanged) {
        setState(() {
          _gestureState = nextState;
          _currentInhaleDwellSeconds = liveDwellSec;
        });
      }
    }
  }

  Future<void> _onPuffConfirmed(
    DateTime puffTime,
    double initialDurationSec,
    String deviceName,
    double confidence,
  ) async {
    // Tactile haptic pulse on device
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final puffNum = _sessionPuffCount + 1;
    final eventId = _uuid.v4();
    final userId = SupabaseConfig.currentUserId;

    final record = SessionPuffRecord(
      puffNumber: puffNum,
      timestamp: puffTime,
      deviceName: deviceName,
      durationSeconds: initialDurationSec > 0 ? initialDurationSec : 0.8,
      confidence: confidence,
      isSynced: userId != null,
      id: eventId,
    );

    setState(() {
      _sessionPuffCount = puffNum;
      _sessionPuffTimestamps.add(puffTime);
      _sessionPuffHistory.insert(0, record);
    });

    // Store in Supabase database with exact timestamp when smoked
    if (userId != null) {
      final event = PuffEvent(
        id: eventId,
        userId: userId,
        sessionId: _activeSession?.id,
        detectedAt: puffTime,
        inputMode: AppConstants.inputModeLiveCamera,
        confidenceScore: double.parse(confidence.toStringAsFixed(3)),
      );

      final success = await _service.insertPuffEvent(event);
      if (success) {
        Logger.info('Puff #$puffNum stored in DB at $puffTime for $deviceName (${(confidence * 100).toInt()}% conf)');
      }

      // Update session metrics in Supabase (puff count + avg interval)
      if (_activeSession != null) {
        _activeSession!.incrementPuff();
        _activeSession!.calculateAvgInterval(_sessionPuffTimestamps);
        await _service.updateSession(_activeSession!);
      }
    } else {
      Logger.info('Puff #$puffNum recorded locally (Guest session) at $puffTime');
    }
  }

  Future<void> _logManualPuff() async {
    final now = DateTime.now();
    final device = _detectionService.targetDevice == 'cigarette' ? 'Cigarette' : 'Vape';
    await _onPuffConfirmed(now, 1.0, device, 1.0);
  }

  Future<void> _stopCameraStream() async {
    _isStreaming = false;
    _frameLoopTimer?.cancel();
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
      } catch (_) {}
      try {
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
  }

  Future<void> _endSessionAndExit() async {
    _isDisposed = true;
    await _stopCameraStream();
    if (_activeSession != null) {
      _activeSession!.endedAt = DateTime.now();
      _activeSession!.calculateAvgInterval(_sessionPuffTimestamps);
      final userId = SupabaseConfig.currentUserId;
      if (userId != null) {
        await _service.updateSession(_activeSession!);
      }
    }

    if (mounted) {
      Navigator.pop(context, _sessionPuffCount);
    }
  }

  void _showPuffHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Puffs Smoked Timeline',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_sessionPuffCount puffs recorded in this session',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _sessionPuffHistory.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_toggle_off, size: 48, color: Colors.white24),
                              SizedBox(height: 12),
                              Text(
                                'No puffs recorded yet',
                                style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Bring vape or cigarette to lips for >= 0.55s to log a puff',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _sessionPuffHistory.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final puff = _sessionPuffHistory[index];
                            final timeFormatted = DateFormat('h:mm:ss a').format(puff.timestamp);
                            final isVape = puff.deviceName.toLowerCase().contains('vape');
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isVape
                                          ? const Color(0xFF00E676).withValues(alpha: 0.15)
                                          : const Color(0xFFFF9100).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isVape ? Icons.smoke_free_rounded : Icons.smoking_rooms,
                                        color: isVape ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Puff #${puff.puffNumber}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                puff.deviceName,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Smoked at $timeFormatted • ${puff.durationSeconds.toStringAsFixed(1)}s draw',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(puff.confidence * 100).toInt()}% conf',
                                        style: TextStyle(
                                          color: puff.confidence >= 0.5 ? const Color(0xFF00E676) : Colors.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            puff.isSynced ? Icons.cloud_done : Icons.cloud_off,
                                            size: 13,
                                            color: puff.isSynced ? const Color(0xFF00E676) : Colors.white38,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            puff.isSynced ? 'Stored' : 'Local',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: puff.isSynced ? const Color(0xFF00E676) : Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _testWithImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        if (mounted) {
          setState(() {
            _isProcessingFrame = true;
            _currentDetections = [];
          });
        }

        final File file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          final detections = await _detectionService.detectFromImage(decodedImage);
          if (mounted) {
            _processDetections(detections);
            setState(() {
              _isProcessingFrame = false;
            });
            final nearMouth = detections.where((d) => d.isNearMouth).toList();
            final msg = detections.isEmpty
                ? 'No smoking device detected in image.'
                : 'Found ${detections.length} device(s).\n'
                    '${nearMouth.isNotEmpty ? "👄 Positioned at lips (Puff Inhalation Zone)!" : "✋ Held in hand (Not at lips)."}\n\n'
                    '${detections.map((d) => "${d.className} (${(d.confidence * 100).toInt()}% conf)").join("\n")}';

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Test Image Detection'),
                content: Text(msg),
                actions: [
                  if (nearMouth.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _onPuffConfirmed(
                          DateTime.now(),
                          1.5,
                          nearMouth.first.className,
                          nearMouth.first.confidence,
                        );
                      },
                      child: const Text('Log as Puff Event'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingFrame = false;
          _cameraError = 'Error testing image: $e';
        });
      }
    }
  }

  Future<void> _runWindowsInferenceLoop() async {
    while (mounted && !_isDisposed) {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_isProcessingFrame) {
        _isProcessingFrame = true;
        XFile? xfile;
        try {
          xfile = await _cameraController!.takePicture();
          final bytes = await xfile.readAsBytes();
          if (mounted && !_isDisposed) {
            final detections = await _detectionService.detectFromJpegBytes(bytes);
            if (mounted && !_isDisposed) {
              _processDetections(detections);
            }
          }
        } catch (e) {
          Logger.warning('Windows snapshot capture failed: $e');
        } finally {
          if (xfile != null) {
            try {
              final f = File(xfile.path);
              if (await f.exists()) {
                await f.delete();
              }
            } catch (_) {}
          }
          _isProcessingFrame = false;
        }
      }
      // Pacing interval: gives the camera preview thread time to render at full 30-60 FPS without shutter starvation
      await Future.delayed(Duration(milliseconds: _captureIntervalMs));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopCameraStream();
    _detectionsNotifier.dispose();
    // Do not dispose global singleton _detectionService here
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _endSessionAndExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _endSessionAndExit,
          ),
          title: const Text('Live Detection'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _endSessionAndExit,
            ),
          ],
        ),
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Feed with 1:1 Pixel-Aligned Bounding Box Canvas
            _isInitializing
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _hasCameraPermission && _cameraController != null && _cameraController!.value.isInitialized
                    ? Center(
                        child: Builder(
                          builder: (context) {
                            final rawAr = _cameraController!.value.aspectRatio;
                            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                            final effectiveAr = (isPortrait && rawAr > 1.0) ? (1.0 / rawAr) : rawAr;
                            return AspectRatio(
                              aspectRatio: effectiveAr,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_cameraController!),
                                  // Precision 60 FPS Interpolated Bounding Boxes (repaints without rebuilding CameraPreview)
                                  ValueListenableBuilder<List<PuffDetection>>(
                                    valueListenable: _detectionsNotifier,
                                    builder: (context, detections, _) {
                                      return AnimatedBoundingBoxesWidget(
                                        detections: detections,
                                        isPuffing: _gestureState == PuffGestureState.confirmed,
                                        gestureState: _gestureState,
                                        inhaleProgress: (_currentInhaleDwellSeconds / 0.55).clamp(0.0, 1.0),
                                        isDebugOverlay: _isDebugOverlayEnabled,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : _buildCameraUnavailableView(),

            // Top Dynamic Status Badge (Puffing vs Holding vs Searching)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildTopStatusBanner(),
            ),

            // Controls Overlay
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Sleek Unified Detection Controls Bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white24, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tab switcher header wrapped in FittedBox to eliminate pixel overflow on any screen
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTabItem(Icons.smoke_free_rounded, 'Device', 'device'),
                              const SizedBox(width: 3),
                              _buildTabItem(Icons.speed_rounded, 'Speed', 'fps'),
                              const SizedBox(width: 3),
                              _buildTabItem(Icons.tune_rounded, 'Accuracy', 'sensitivity'),
                              const SizedBox(width: 3),
                              _buildTabItem(Icons.bug_report_rounded, 'Debug', 'debug'),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _showControls = !_showControls),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white10,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _showControls ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showControls) ...[
                          const SizedBox(height: 6),
                          Container(
                            height: 1,
                            width: 240,
                            color: Colors.white12,
                          ),
                          const SizedBox(height: 6),
                          // Dynamic active options row wrapped in FittedBox
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Builder(
                              builder: (context) {
                                if (_activeSettingTab == 'device') {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildDeviceChip('Vape (Only)', 'vape'),
                                      const SizedBox(width: 4),
                                      _buildDeviceChip('Auto (Both)', 'both'),
                                      const SizedBox(width: 4),
                                      _buildDeviceChip('Cigarette', 'cigarette'),
                                    ],
                                  );
                                } else if (_activeSettingTab == 'fps') {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildModeChip('Snappy AI', 280),
                                      const SizedBox(width: 4),
                                      _buildModeChip('Balanced', 450),
                                      const SizedBox(width: 4),
                                      _buildModeChip('Battery Saver', 700),
                                    ],
                                  );
                                } else if (_activeSettingTab == 'sensitivity') {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSensitivityChip('Sensitive (20%)', 0.20),
                                      const SizedBox(width: 4),
                                      _buildSensitivityChip('Standard (28%)', 0.28),
                                      const SizedBox(width: 4),
                                      _buildSensitivityChip('Strict (45%)', 0.45),
                                    ],
                                  );
                                } else if (_activeSettingTab == 'debug') {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildToggleChip(
                                        _isDebugOverlayEnabled ? 'Debug Overlay: ON' : 'Debug Overlay: OFF',
                                        _isDebugOverlayEnabled,
                                        () => setState(() => _isDebugOverlayEnabled = !_isDebugOverlayEnabled),
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Session Stats Badge with Pulse Glow on Puff (Tappable for Timeline)
                  GestureDetector(
                    onTap: () => _showPuffHistorySheet(context),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isPuffingNow
                            ? const Color(0xFF00E676).withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isPuffingNow
                              ? const Color(0xFF00E676)
                              : AppTheme.primaryColor.withValues(alpha: 0.5),
                          width: _isPuffingNow ? 2.0 : 1.0,
                        ),
                        boxShadow: _isPuffingNow
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: _isPuffingNow ? const Color(0xFF00E676) : AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_sessionPuffCount Puffs Recorded',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.history, color: Colors.white70, size: 12),
                                    SizedBox(width: 3),
                                    Text(
                                      'Timeline',
                                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_sessionPuffHistory.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Latest: ${DateFormat('h:mm:ss a').format(_sessionPuffHistory.first.timestamp)} (${_sessionPuffHistory.first.deviceName})',
                              style: const TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Manual Log Action Button (Quick Tap)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _logManualPuff,
                        icon: const Icon(Icons.touch_app),
                        label: const Text('+1 Manual Puff'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _endSessionAndExit,
                        icon: const Icon(Icons.stop),
                        label: const Text('End Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTabItem(IconData icon, String label, String tab) {
    final isSelected = _activeSettingTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeSettingTab = tab;
          _showControls = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String label, int intervalMs) {
    final isSelected = _captureIntervalMs == intervalMs;
    return GestureDetector(
      onTap: () {
        setState(() {
          _captureIntervalMs = intervalMs;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSensitivityChip(String label, double threshold) {
    final isSelected = (_detectionService.confidenceThreshold - threshold).abs() < 0.01;
    return GestureDetector(
      onTap: () {
        setState(() {
          _detectionService.confidenceThreshold = threshold;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceChip(String label, String mode) {
    final isSelected = _detectionService.targetDevice == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _detectionService.targetDevice = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatusBanner() {
    Color bannerColor;
    Color borderColor;
    IconData icon;
    String text;

    switch (_gestureState) {
      case PuffGestureState.confirmed:
        bannerColor = const Color(0xFF00E676).withValues(alpha: 0.95);
        borderColor = const Color(0xFF00E676);
        icon = Icons.local_fire_department;
        text = '🔥 PUFF RECORDED: ${_currentInhaleDevice.toUpperCase()} (${(_currentInhaleConfidence * 100).toInt()}% conf • ${_currentInhaleDwellSeconds.toStringAsFixed(1)}s draw)';
        break;
      case PuffGestureState.inhaling:
        bannerColor = const Color(0xFFFFB300).withValues(alpha: 0.92);
        borderColor = const Color(0xFFFFB300);
        icon = Icons.face;
        final pct = ((_currentInhaleDwellSeconds / 0.55) * 100).clamp(0, 100).toInt();
        text = '👄 INHALING: $_currentInhaleDevice ($pct% • ${(_currentInhaleDwellSeconds * 1000).toInt()}ms/550ms)';
        break;
      case PuffGestureState.cooldown:
        bannerColor = const Color(0xFF6C63FF).withValues(alpha: 0.90);
        borderColor = const Color(0xFF6C63FF);
        icon = Icons.hourglass_top_rounded;
        text = '⏸️ Puff Stored • Cooldown (1.2s)';
        break;
      case PuffGestureState.idle:
        if (_currentDetections.isNotEmpty) {
          bannerColor = const Color(0xFFFF9100).withValues(alpha: 0.85);
          borderColor = const Color(0xFFFF9100);
          icon = Icons.pan_tool;
          text = '✋ ${_currentDetections.first.className} in Hand (Bring to mouth to log puff)';
        } else {
          bannerColor = Colors.black.withValues(alpha: 0.75);
          borderColor = Colors.white24;
          icon = Icons.shield_outlined;
          text = 'On-device real-time puff detection active';
        }
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraUnavailableView() {
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Camera Feed Unavailable',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isWindows) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.settings, color: AppTheme.primaryColor, size: 28),
                    SizedBox(height: 8),
                    Text(
                      'Windows Camera Permission Required',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Open Windows Settings\n'
                      '2. Go to Privacy & Security → Camera\n'
                      '3. Turn ON "Camera access"\n'
                      '4. Turn ON "Let desktop apps access your camera"\n'
                      '5. Restart the app',
                      textAlign: TextAlign.left,
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_cameraError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _cameraError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade300, fontSize: 11),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeCameraAndSession,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Camera Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _testWithImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Test Model with Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'You can still manually tap below to log puffs during this active session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedBoundingBoxesWidget extends StatefulWidget {
  final List<PuffDetection> detections;
  final bool isPuffing;
  final PuffGestureState gestureState;
  final double inhaleProgress;
  final bool isDebugOverlay;

  const AnimatedBoundingBoxesWidget({
    super.key,
    required this.detections,
    required this.isPuffing,
    this.gestureState = PuffGestureState.idle,
    this.inhaleProgress = 0.0,
    this.isDebugOverlay = false,
  });

  @override
  State<AnimatedBoundingBoxesWidget> createState() => _AnimatedBoundingBoxesWidgetState();
}

class _AnimatedBoundingBoxesWidgetState extends State<AnimatedBoundingBoxesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  List<PuffDetection> _fromDetections = [];
  List<PuffDetection> _toDetections = [];

  @override
  void initState() {
    super.initState();
    _fromDetections = widget.detections;
    _toDetections = widget.detections;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBoundingBoxesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detections != oldWidget.detections) {
      _fromDetections = _interpolateCurrent(_animController.value);
      _toDetections = widget.detections;
      _animController.forward(from: 0.0);
    }
  }

  List<PuffDetection> _interpolateCurrent(double t) {
    final curvedT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    if (_toDetections.isEmpty) return [];
    if (_fromDetections.isEmpty) return _toDetections;

    List<PuffDetection> result = [];
    for (int i = 0; i < _toDetections.length; i++) {
      final target = _toDetections[i];
      PuffDetection? source;
      for (var f in _fromDetections) {
        if (f.classId == target.classId) {
          source = f;
          break;
        }
      }

      if (source != null) {
        result.add(PuffDetection(
          x: source.x + (target.x - source.x) * curvedT,
          y: source.y + (target.y - source.y) * curvedT,
          width: source.width + (target.width - source.width) * curvedT,
          height: source.height + (target.height - source.height) * curvedT,
          confidence: target.confidence,
          classId: target.classId,
        ));
      } else {
        result.add(target);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final current = _interpolateCurrent(_animController.value);
        return CustomPaint(
          painter: BoundingBoxPainter(
            current,
            isPuffing: widget.isPuffing,
            gestureState: widget.gestureState,
            inhaleProgress: widget.inhaleProgress,
            isDebugOverlay: widget.isDebugOverlay,
          ),
        );
      },
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<PuffDetection> detections;
  final bool isPuffing;
  final PuffGestureState gestureState;
  final double inhaleProgress;
  final bool isDebugOverlay;

  BoundingBoxPainter(
    this.detections, {
    this.isPuffing = false,
    this.gestureState = PuffGestureState.idle,
    this.inhaleProgress = 0.0,
    this.isDebugOverlay = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width;
    final scaleY = size.height;

    // 1. Draw Lip/Mouth Target Zone Guide (x: 0.20-0.80, y: 0.22-0.72)
    final mouthZoneRect = Rect.fromLTWH(
      0.20 * scaleX,
      0.22 * scaleY,
      0.60 * scaleX,
      0.50 * scaleY,
    );

    Color zoneColor;
    double zoneStrokeWidth;
    String zoneLabel;

    switch (gestureState) {
      case PuffGestureState.confirmed:
        zoneColor = const Color(0xFF00E676);
        zoneStrokeWidth = 3.0;
        zoneLabel = '🔥 PUFF RECORDED & STORED';
        break;
      case PuffGestureState.inhaling:
        zoneColor = const Color(0xFFFFB300);
        zoneStrokeWidth = 2.5;
        zoneLabel = '👄 INHALING... (${(inhaleProgress * 100).toInt()}%)';
        break;
      case PuffGestureState.cooldown:
        zoneColor = const Color(0xFF6C63FF);
        zoneStrokeWidth = 1.8;
        zoneLabel = '⏸️ PUFF LOGGED';
        break;
      case PuffGestureState.idle:
        zoneColor = isDebugOverlay
            ? const Color(0xFF00E5FF).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.25);
        zoneStrokeWidth = isDebugOverlay ? 2.0 : 1.5;
        zoneLabel = isDebugOverlay
            ? '🔍 DEBUG: MOUTH ZONE [X:0.20-0.80, Y:0.22-0.72]'
            : '👄 MOUTH / PUFF ZONE';
        break;
    }

    final zonePaint = Paint()
      ..color = zoneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = zoneStrokeWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(mouthZoneRect, const Radius.circular(20)),
      zonePaint,
    );

    // Draw Inhale Progress Bar along top edge of mouth zone when actively inhaling
    if (gestureState == PuffGestureState.inhaling && inhaleProgress > 0) {
      final progressPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      final barWidth = mouthZoneRect.width * inhaleProgress.clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(mouthZoneRect.left, mouthZoneRect.top),
        Offset(mouthZoneRect.left + barWidth, mouthZoneRect.top),
        progressPaint,
      );
    }

    // Zone watermark label
    final zoneTextPainter = TextPainter(
      text: TextSpan(
        text: zoneLabel,
        style: TextStyle(
          color: zoneColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zoneTextPainter.paint(canvas, Offset(mouthZoneRect.left + 12, mouthZoneRect.top + 8));

    // Telemetry badge when debug overlay is enabled
    if (isDebugOverlay) {
      final debugHudPainter = TextPainter(
        text: TextSpan(
          text: ' DEBUG OVERLAY ON • ${detections.length} DETECTION(S) ',
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            backgroundColor: Color(0xCC000000),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      debugHudPainter.paint(canvas, const Offset(12, 12));
    }

    // 2. Draw Detected Objects
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var det in detections) {
      final bool nearMouth = det.isNearMouth;
      Color boxColor;
      String statusTag;

      if (nearMouth) {
        if (gestureState == PuffGestureState.confirmed) {
          boxColor = const Color(0xFF00E676);
          statusTag = '🔥 PUFFED';
        } else if (gestureState == PuffGestureState.inhaling) {
          boxColor = const Color(0xFFFFD600);
          statusTag = '👄 INHALING';
        } else {
          boxColor = const Color(0xFF00E676);
          statusTag = '👄 AT LIPS';
        }
      } else {
        boxColor = const Color(0xFFFF9100);
        statusTag = '✋ IN HAND';
      }

      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = nearMouth ? 3.5 : 2.5;

      final rect = Rect.fromLTWH(
        (det.x - det.width / 2) * scaleX,
        (det.y - det.height / 2) * scaleY,
        det.width * scaleX,
        det.height * scaleY,
      );

      // Draw box with rounded corners
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );

      // Label text: Status + Class + Confidence + Coordinates if Debug
      final labelText = isDebugOverlay
          ? '$statusTag: ${det.className} ${det.confidencePercent} (${det.x.toStringAsFixed(2)}, ${det.y.toStringAsFixed(2)})'
          : '$statusTag: ${det.className} ${det.confidencePercent}';

      textPainter.text = TextSpan(
        text: ' $labelText ',
        style: const TextStyle(
          color: Colors.black,
          backgroundColor: Colors.transparent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();

      // Background pill for label
      final labelBgRect = Rect.fromLTWH(
        rect.left,
        (rect.top - 20).clamp(0.0, size.height - 20),
        textPainter.width + 4,
        18,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBgRect, const Radius.circular(4)),
        Paint()..color = boxColor,
      );

      textPainter.paint(canvas, Offset(labelBgRect.left + 2, labelBgRect.top + 1));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return true;
  }
}
