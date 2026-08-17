class AppConstants {
  static const String appName = 'EMBER';
  static const String appFullName = 'Early Monitoring of Behavioral & Environmental Risk';
  static const String appVersion = '1.0.0';

  static const String privacyDisclaimer =
    'EMBER never stores or transmits raw camera frames or video. '
    'Only behavioral metadata (timestamps, counts, intervals) is saved.';

  // ML model config
  static const String tfliteModelPath = 'assets/models/puff_detection.tflite';
  static const int modelInputSize = 640; // 640x640 for YOLOv8
  static const double minConfidenceThreshold = 0.5;
  static const int maxInferenceLatencyMs = 500;

  // Detection class IDs from the YOLOv8 model
  static const int classIdPuffEvent = 0;
  static const int classIdNoPuff = 1;

  // Minimum history needed before running each ML model
  static const int minDaysForAddictionScore = 3;
  static const int minDaysForCravingPrediction = 7;

  static const int sessionTimeoutMinutes = 30;

  static const String addictionLevelLow = 'low';
  static const String addictionLevelModerate = 'moderate';
  static const String addictionLevelHigh = 'high';

  static const String inputModeManual = 'manual';
  static const String inputModeVideoUpload = 'video_upload';
  static const String inputModeLiveCamera = 'live_camera';

  static const String notificationChannelId = 'ember_craving_alerts';
  static const String notificationChannelName = 'Craving Alerts';
  static const String notificationChannelDescription = 'Notifications for predicted craving windows';

  // Academic performance targets for the project report
  static const double targetYoloMapAt05 = 0.85;
  static const double targetDecisionTreeF1 = 0.80;
  static const double targetLinearRegressionMAE = 30.0;

  static const String institution = 'MITE CSE';
  static const String guide = 'Dr. Rejeesh Rayaroth';
  static const List<String> teamMembers = [
    'Abdullah Kola',
    'Adnan Irfan Rahiman',
    'Ayush C. Umeshan',
    'Eashan Y. Poojary',
  ];
}
