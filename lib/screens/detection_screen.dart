import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:camera/camera.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/theme/app_theme.dart';
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
  final ValueNotifier<List<PuffDetection>> _detectionsNotifier = ValueNotifier<List<PuffDetection>>([]);
  int _captureIntervalMs = 650; // Smooth 60 FPS camera preview with decoupled inference
  List<PuffDetection> _currentDetections = [];
  
  // Lip / Mouth Proximity State Tracking
  DateTime? _mouthDwellStartTime;
  bool _isPuffingNow = false;
  DateTime? _lastAutoLogTime;
  int _sessionPuffCount = 0;
  Session? _activeSession;
  final List<DateTime> _sessionPuffTimestamps = [];

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

    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    // Release any previous controller before attempting new acquisition
    try {
      _frameLoopTimer?.cancel();
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        if (isWindows) {
          // Allow Windows Media Foundation to cleanly release the hardware sensor handle
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (_) {}

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
        _cameraController!.startImageStream((CameraImage image) {
          if (_isProcessingFrame) return;
          _isProcessingFrame = true;

          _detectionService.detectFromFrame(image, sensorOrientation: sensorOrientation).then((detections) {
            if (mounted) {
              _processDetections(detections);
            }
            _isProcessingFrame = false;
          }).catchError((e) {
            _isProcessingFrame = false;
          });
        });
      } catch (e) {
        // Fallback
      }
    }
  }

  void _processDetections(List<PuffDetection> detections) {
    final now = DateTime.now();
    final nearMouthDetections = detections.where((d) => d.isNearMouth).toList();
    bool puffing = false;

    if (nearMouthDetections.isNotEmpty) {
      _mouthDwellStartTime ??= now;
      final dwellMs = now.difference(_mouthDwellStartTime!).inMilliseconds;

      // When the cigarette or vape is held at the lips for >= 600ms, count as puff
      if (dwellMs >= 600) {
        puffing = true;
        _logDetectedPuffAuto();
      }
    } else {
      _mouthDwellStartTime = null;
      puffing = false;
    }

    _detectionsNotifier.value = detections;
    _currentDetections = detections;
    if (_isPuffingNow != puffing) {
      setState(() {
        _isPuffingNow = puffing;
      });
    }
  }

  Future<void> _logDetectedPuffAuto() async {
    final now = DateTime.now();
    // 4 second cooldown between automatic puff counts
    if (_lastAutoLogTime == null || now.difference(_lastAutoLogTime!).inSeconds >= 4) {
      _lastAutoLogTime = now;
      await _logDetectedPuff(mode: AppConstants.inputModeLiveCamera);
    }
  }

  Future<void> _logDetectedPuff({String mode = AppConstants.inputModeLiveCamera}) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    _sessionPuffTimestamps.add(now);

    setState(() {
      _sessionPuffCount++;
    });

    final event = PuffEvent(
      id: _uuid.v4(),
      userId: userId,
      sessionId: _activeSession?.id,
      detectedAt: now,
      inputMode: mode,
      confidenceScore: mode == AppConstants.inputModeLiveCamera ? 0.95 : null,
    );

    await _service.insertPuffEvent(event);

    if (_activeSession != null) {
      _activeSession!.incrementPuff();
      _activeSession!.calculateAvgInterval(_sessionPuffTimestamps);
      await _service.updateSession(_activeSession!);
    }
  }

  Future<void> _endSessionAndExit() async {
    if (_activeSession != null) {
      _activeSession!.endedAt = DateTime.now();
      _activeSession!.calculateAvgInterval(_sessionPuffTimestamps);
      await _service.updateSession(_activeSession!);
    }

    if (mounted) {
      Navigator.pop(context, _sessionPuffCount);
    }
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
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Test Results'),
                content: Text('Found ${detections.length} detections.\n\n$detections'),
                actions: [
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
        } catch (_) {
          // Graceful handling of snapshot interval
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
    _frameLoopTimer?.cancel();
    _cameraController?.dispose();
    _detectionsNotifier.dispose();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Live Puff & Lip Detection'),
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
                        child: AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
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
                                    isPuffing: _isPuffingNow,
                                  );
                                },
                              ),
                            ],
                          ),
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
                  // Camera Performance Mode Selector
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        _buildModeChip('Smooth 60FPS', 650),
                        const SizedBox(width: 4),
                        _buildModeChip('Balanced', 350),
                        const SizedBox(width: 4),
                        _buildModeChip('Fast AI', 180),
                      ],
                    ),
                  ),

                  // Session Stats Badge with Pulse Glow on Puff
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: _isPuffingNow ? const Color(0xFF00E676) : AppTheme.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_sessionPuffCount Puffs Recorded',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manual Log Action Button (Quick Tap)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _logDetectedPuff(mode: AppConstants.inputModeManual),
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

  Widget _buildTopStatusBanner() {
    Color bannerColor;
    Color borderColor;
    IconData icon;
    String text;

    if (_isPuffingNow) {
      bannerColor = const Color(0xFF00E676).withValues(alpha: 0.9);
      borderColor = const Color(0xFF00E676);
      icon = Icons.smoking_rooms;
      text = '🔥 PUFFING DETECTED AT LIPS';
    } else if (_currentDetections.isNotEmpty) {
      final anyNearMouth = _currentDetections.any((d) => d.isNearMouth);
      if (anyNearMouth) {
        bannerColor = const Color(0xFFFFB300).withValues(alpha: 0.85);
        borderColor = const Color(0xFFFFB300);
        icon = Icons.face;
        text = '👄 Approaching Lips (Hold to register puff)...';
      } else {
        bannerColor = const Color(0xFFFF9100).withValues(alpha: 0.8);
        borderColor = const Color(0xFFFF9100);
        icon = Icons.pan_tool;
        text = '✋ Device in Hand (Bring to mouth to log puff)';
      }
    } else {
      bannerColor = Colors.black.withValues(alpha: 0.75);
      borderColor = Colors.white24;
      icon = Icons.shield_outlined;
      text = 'On-device real-time analysis (No video saved)';
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

  const AnimatedBoundingBoxesWidget({
    super.key,
    required this.detections,
    required this.isPuffing,
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
          ),
        );
      },
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<PuffDetection> detections;
  final bool isPuffing;

  BoundingBoxPainter(this.detections, {this.isPuffing = false});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width;
    final scaleY = size.height;

    // 1. Draw subtle Lip/Mouth Target Zone Guide (Top 15% to 65%, center 25% to 75%)
    final mouthZoneRect = Rect.fromLTWH(
      0.20 * scaleX,
      0.15 * scaleY,
      0.60 * scaleX,
      0.48 * scaleY,
    );

    final zonePaint = Paint()
      ..color = isPuffing
          ? const Color(0xFF00E676).withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(mouthZoneRect, const Radius.circular(24)),
      zonePaint,
    );

    // Zone watermark label
    final zoneTextPainter = TextPainter(
      text: TextSpan(
        text: isPuffing ? '👄 LIP CONTACT DETECTED' : '👄 MOUTH / LIP ZONE',
        style: TextStyle(
          color: isPuffing ? const Color(0xFF00E676) : Colors.white30,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zoneTextPainter.paint(canvas, Offset(mouthZoneRect.left + 12, mouthZoneRect.top + 8));

    // 2. Draw Detected Objects
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var det in detections) {
      final bool nearMouth = det.isNearMouth;
      final Color boxColor = nearMouth
          ? const Color(0xFF00E676) // Bright Green when near lips
          : const Color(0xFFFF9100); // Amber Orange when in hand

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

      // Label text: Status + Class + Confidence
      final String statusTag = nearMouth ? '👄 PUFFING' : '✋ HOLDING';
      final labelText = '$statusTag: ${det.className} ${det.confidencePercent}';

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
