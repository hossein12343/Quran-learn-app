import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend.dart';

enum LogLevel { info, warn, error }

/// Best-effort diagnostic logging. Everything prints locally; errors and
/// crashes are also reported to the server (`report_error`), so problems
/// testers hit can be seen. Reports carry no account id, the server blanks
/// email addresses and limits how many it accepts, and each session sends
/// at most a handful, each distinct problem once. Warnings (mostly an
/// offline phone) stay local. Logging must never be able to break the app,
/// so nothing here throws into the caller.
abstract class AppLog {
  /// Set by main.dart once a route is known, so entries carry roughly
  /// where in the app they happened without every call site passing it.
  static String currentRoute = '';

  static void info(String message, {Map<String, dynamic>? context}) =>
      _send(LogLevel.info, message, context: context);

  static void warn(String message,
          {Object? error, Map<String, dynamic>? context}) =>
      _send(LogLevel.warn, message, error: error, context: context);

  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? context,
  }) =>
      _send(LogLevel.error, message,
          error: error, stack: stack, context: context);

  static void _send(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? context,
  }) {
    final tag = level.name.toUpperCase();
    debugPrint('[$tag] $message${error != null ? ' — $error' : ''}');
    unawaited(_post(level, message, error, stack, context));
  }

  static const _maxReportsPerSession = 10;
  static final Set<String> _reported = <String>{};

  /// Off in tests, which have no server to report to.
  static bool reportingEnabled = kIsWeb && !kDebugMode;

  static Future<void> _post(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? context,
  ) async {
    if (level != LogLevel.error || !reportingEnabled) return;
    if (_reported.length >= _maxReportsPerSession) return;
    if (!_reported.add('$message|$error')) return;
    try {
      await Backend.reportError(
        level: level.name,
        message: message,
        error: error?.toString(),
        stack: _trim(stack?.toString()),
        route: currentRoute,
        platform: defaultTargetPlatform.name,
      );
    } on Object {
      // Reporting is best effort.
    }
  }

  static String _trim(String? s) {
    if (s == null) return '';
    return s.length > 8000 ? s.substring(0, 8000) : s;
  }

  /// Wire up global crash capture. Call once, early in main().
  static void captureUncaught() {
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previous?.call(details);
      error(
        details.exceptionAsString(),
        error: details.exception,
        stack: details.stack,
        context: {
          'library': details.library ?? '',
          'context': details.context?.toString() ?? '',
        },
      );
    };
    PlatformDispatcher.instance.onError = (Object err, StackTrace stack) {
      error(err.toString(),
          error: err, stack: stack, context: {'source': 'platform'});
      return true;
    };
  }
}

/// JSON helper for context maps that might contain non-encodable values —
/// keeps a bad log call from throwing instead of just logging less.
Map<String, dynamic> safeContext(Map<String, dynamic> raw) {
  try {
    jsonEncode(raw);
    return raw;
  } on Object {
    return raw.map((k, v) => MapEntry(k, v.toString()));
  }
}
