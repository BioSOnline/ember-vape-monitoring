import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/services/video_demo_detection_service.dart';
import 'package:uuid/uuid.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _service = SupabaseService();
  final _uuid = const Uuid();
  final _demoDetectionService = VideoDemoDetectionService();

  File? _selectedVideoFile;
  String? _videoFileName;
  int _videoSizeKb = 0;
  double? _videoDurationSeconds;
  int? _videoTotalFrames;
  int? _analyzedFramesCount;

  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = '';

  List<VideoDetectionResult>? _detectedResults;
  String? _analysisSummary;
  bool _savedToLog = false;

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false, // Avoid loading multi-MB videos into heap memory across IPC
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;

      File? file;
      if (picked.path != null && File(picked.path!).existsSync()) {
        file = File(picked.path!);
      } else if (picked.bytes != null) {
        // Fallback for Web or platforms returning raw bytes
        final tempDir = await getTemporaryDirectory();
        final ext = picked.extension ?? 'mp4';
        final tempFile = File('${tempDir.path}/ember_video_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await tempFile.writeAsBytes(picked.bytes!);
        file = tempFile;
      }

      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access selected video file. Please try another file.')),
          );
        }
        return;
      }

      final sizeKb = (file.lengthSync() / 1024).round();
      final duration = await VideoDemoDetectionService.getVideoDuration(file);
      final estimatedFrames = duration != null && duration > 0
          ? (duration * VideoDemoDetectionService.analysisFps).ceil()
          : null;

      setState(() {
        _selectedVideoFile = file;
        _videoFileName = picked.name;
        _videoSizeKb = sizeKb;
        _videoDurationSeconds = duration;
        _videoTotalFrames = estimatedFrames;
        _analyzedFramesCount = null;
        _detectedResults = null;
        _analysisSummary = null;
        _savedToLog = false;
      });
      Logger.info('Selected video for analysis: ${picked.name} ($sizeKb KB)');
    } catch (e, st) {
      Logger.error('Failed to pick video file: $e', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting video: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processVideo() async {
    if (_selectedVideoFile == null && _videoFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or drag a video file first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.05;
      _processingStatus = 'Initializing TFLite model...';
    });

    try {
      final analysis = await _demoDetectionService.analyzeVideo(
        _selectedVideoFile!,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _processingProgress = progress;
              _processingStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _processingProgress = 1.0;
          _processingStatus = 'Analysis complete!';
          _isProcessing = false;
          _detectedResults = analysis.detections;
          _analysisSummary = analysis.summary;
          _analyzedFramesCount = analysis.totalFrames;
          _videoTotalFrames = analysis.totalFrames;
          if (analysis.durationSeconds > 0) {
            _videoDurationSeconds = analysis.durationSeconds;
          }
        });
      }
    } catch (e, st) {
      Logger.error('Video processing error: $e', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Analysis failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing video: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDetectedPuffsToLog() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null || _detectedResults == null || _detectedResults!.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      int maxOffset = 0;
      for (final r in _detectedResults!) {
        if (r.offsetSeconds > maxOffset) maxOffset = r.offsetSeconds;
      }

      bool success = true;

      for (final result in _detectedResults!) {
        final secondsAgo = maxOffset - result.offsetSeconds;
        final puffTime = now.subtract(Duration(seconds: secondsAgo));
        final event = PuffEvent(
          id: _uuid.v4(),
          userId: userId,
          detectedAt: puffTime,
          inputMode: AppConstants.inputModeVideoUpload,
          confidenceScore: result.confidence,
        );

        final inserted = await _service.insertPuffEvent(event);
        if (!inserted) success = false;
      }

      if (mounted) {
        if (success) {
          setState(() => _savedToLog = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully saved ${_detectedResults!.length} detected puffs to your daily log!'),
              backgroundColor: AppTheme.lowRiskColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save puff events.'),
              backgroundColor: AppTheme.highRiskColor,
            ),
          );
        }
      }
    } catch (e, st) {
      Logger.error('Error saving puffs to Supabase: $e', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving to log: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatSeconds(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Puff Detection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card
            Card(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.video_file, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Video Analysis',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upload a recorded video to run the on-device detector on extracted frames and view the detected moments.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Video Picker Area
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedVideoFile != null
                      ? AppTheme.primaryColor
                      : Theme.of(context).colorScheme.outline,
                  width: _selectedVideoFile != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
                color: _selectedVideoFile != null
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedVideoFile != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                    size: 48,
                    color: _selectedVideoFile != null ? AppTheme.primaryColor : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedVideoFile != null
                        ? 'Selected: $_videoFileName'
                        : 'Select or Choose Video File',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedVideoFile != null
                        ? (_videoDurationSeconds != null
                            ? 'Size: ${(_videoSizeKb / 1024).toStringAsFixed(1)} MB • ${_videoDurationSeconds!.toStringAsFixed(1)}s • ${_videoTotalFrames ?? _analyzedFramesCount ?? (_videoDurationSeconds! * VideoDemoDetectionService.analysisFps).ceil()} frames (${VideoDemoDetectionService.analysisFps} FPS)'
                            : 'Size: ${(_videoSizeKb / 1024).toStringAsFixed(1)} MB')
                        : 'Supports MP4, MOV, AVI formats',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // Pick video from device
                  ElevatedButton.icon(
                    onPressed: _pickVideoFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Browse Video File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Process Button / Progress Indicator
            if (_isProcessing) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _processingProgress,
                        color: AppTheme.primaryColor,
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _processingStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _selectedVideoFile != null ? _processVideo : null,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text(
                  'Analyze Video for Puffs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],

            // Analysis Results View
            if (_detectedResults != null) ...[
              const SizedBox(height: 24),
              Text(
                'Detection Results',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_detectedResults!.length} Puff Events Detected',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'High confidence detections in video timeline',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_analyzedFramesCount ?? _videoTotalFrames ?? 0} Frames Analyzed',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_videoDurationSeconds != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_videoDurationSeconds!.toStringAsFixed(1)}s (2 FPS)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      if (_analysisSummary != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _analysisSummary!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],

                      ..._detectedResults!.map((item) {
                        final durationStr = item.durationSeconds > 1.0
                            ? ' (${item.durationSeconds.toStringAsFixed(1)}s)'
                            : '';
                        final isVape = item.classId == 0 || item.classId == 2;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isVape ? const Color(0xFF6C63FF) : const Color(0xFFFF5722)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isVape ? Icons.air_rounded : Icons.local_fire_department_rounded,
                                color: isVape ? const Color(0xFF6C63FF) : const Color(0xFFFF5722),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              '${item.label}$durationStr',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Text('Timeline offset: ${_formatSeconds(item.offsetSeconds)}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(item.confidence * 100).toStringAsFixed(0)}% conf',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _savedToLog ? null : _saveDetectedPuffsToLog,
                icon: Icon(_savedToLog ? Icons.check : Icons.save_alt),
                label: Text(_savedToLog ? 'Saved to Daily Log' : 'Save Detected Puffs to Log'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _savedToLog ? Colors.green : AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
