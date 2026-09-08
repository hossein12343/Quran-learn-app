import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

enum LogLevel { info, warn, error }

/// Local, best-effort diagnostic logging.
///
/// The app does not POST raw exception details from an unauthenticated
/// browser client. Logging must never be able to break the app, so it is
/// printed locally and intentionally never throws into the caller.
abstract class AppLog {
  /// Set by main.dart once a route is known, so entries carry roughly
  /// where in the app they happened without every call site passing it.
  static String currentRoute = '';

  static void info(String message, {Map<String, dynamic>? context}) =>
      _send(LogLevel.info, message, context: context);

  static void warn(String message, {Object? error, Map<String, dynamic>? context}) =>
      _send(LogLevel.warn, message, error: error, context: context);

  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? context,
  }) =>
      _send(LogLevel.error, message, error: error, stack: stack, context: context);

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

  static Future<void> _post(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? context,
  ) async {
    // Do not send raw exception data from a public client to a writable
    // database table. It can contain implementation details and makes the
    // endpoint a trivial telemetry-spam target. Keep diagnostics local until
    // a rate-limited, authenticated Edge Function is introduced.
    _trim(stack?.toString());
    safeContext(context ?? <String, dynamic>{});
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
      error(err.toString(), error: err, stack: stack, context: {'source': 'platform'});
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
