import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/theme/app_theme.dart';
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

  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = '';

  List<VideoDetectionResult>? _detectedResults;
  String? _analysisSummary;
  bool _savedToLog = false;

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path == null) return;
    final file = File(path);
    final sizeKb = (picked.size / 1024).round();
    setState(() {
      _selectedVideoFile = file;
      _videoFileName = picked.name;
      _videoSizeKb = sizeKb;
      _detectedResults = null;
      _analysisSummary = null;
      _savedToLog = false;
    });
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
      });
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
                        ? 'Size: ${(_videoSizeKb / 1024).toStringAsFixed(1)} MB'
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
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.play_circle_fill, color: AppTheme.primaryColor),
                          title: Text('${item.label} at ${_formatSeconds(item.offsetSeconds)}'),
                          subtitle: Text('Confidence score: ${(item.confidence * 100).toStringAsFixed(1)}%'),
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
