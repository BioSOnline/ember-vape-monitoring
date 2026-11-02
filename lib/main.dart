import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/core/theme/theme_provider.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/services/notification_service.dart';
import 'package:ember/services/puff_detection_service.dart';
import 'package:ember/widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    Logger.info('Environment variables loaded');

    await SupabaseConfig.initialize();
    Logger.info('Supabase initialized');

    // Run non-critical background services asynchronously to achieve instant app launch
    unawaited(NotificationService().initialize());
    unawaited(PuffDetectionService().initialize());

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const EmberApp(),
      ),
    );
  } catch (e, stackTrace) {
    Logger.error('Error during app initialization', error: e, stackTrace: stackTrace);
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const EmberApp(),
      ),
    );
  }
}

class EmberApp extends StatelessWidget {
  const EmberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          themeAnimationDuration: Duration.zero,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
