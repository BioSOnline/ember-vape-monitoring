import 'package:flutter/foundation.dart';

class Logger {
  static bool _debugMode = true;

  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  static void info(String message) {
    if (_debugMode) debugPrint('[INFO] $message');
  }

  static void warning(String message) {
    if (_debugMode) debugPrint('[WARNING] $message');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (_debugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }
  }

  static void debug(String message) {
    if (_debugMode) debugPrint('[DEBUG] $message');
  }
}
