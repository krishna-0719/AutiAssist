import 'dart:developer' as developer;

/// Centralized, structured logger for the entire app.
///
/// Usage:
/// ```dart
/// AppLogger.info('User logged in', tag: 'AUTH');
/// AppLogger.error('Network failed', error: e, tag: 'NET');
/// ```
class AppLogger {
  AppLogger._();

  static void info(String message, {String tag = 'APP'}) {
    _log('INFO', tag, message);
  }

  static void warning(String message, {String tag = 'APP'}) {
    _log('WARN', tag, message);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String tag = 'APP'}) {
    _log('ERROR', tag, '$message${error != null ? ' | $error' : ''}');
    if (stackTrace != null) {
      developer.log(stackTrace.toString(), name: tag);
    }
  }

  static void room(String message) => _log('INFO', 'ROOM', message);
  static void ai(String message) => _log('INFO', 'AI', message);
  static void auth(String message) => _log('INFO', 'AUTH', message);
  static void track(String message) => _log('INFO', 'TRACK', message);

  static void _log(String level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    developer.log('[$timestamp] [$level] [$tag] $message', name: tag);
  }
}
