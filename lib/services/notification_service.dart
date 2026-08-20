import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/utils/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final result = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (result == true) {
      _initialized = true;
      await _createNotificationChannel();
      Logger.info('Notification service initialized');
    } else {
      Logger.error('Failed to initialize notification service');
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    Logger.info('Notification tapped: ${response.payload}');
  }

  Future<void> requestPermissions() async {
    // Android 13+ needs an explicit runtime permission grant.
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> showCravingAlert({
    required int predictedMinutes,
    String? customMessage,
  }) async {
    if (!_initialized) {
      Logger.warning('Notification service not initialized');
      return;
    }

    final message = customMessage ??
        'Based on your patterns, you may experience a craving in $predictedMinutes minutes. '
        'Consider using a coping strategy now.';

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      0,
      'Craving Alert',
      message,
      details,
      payload: 'craving_alert',
    );

    Logger.info('Craving alert sent');
  }

  Future<void> showGoalAchieved({required String message}) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(1, 'Goal Achieved!', message, details);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
