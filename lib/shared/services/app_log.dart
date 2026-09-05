import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend.dart';

enum LogLevel { info, warn, error }

/// Fire-and-forget logging to the `logs` table in the app's Supabase
/// project (public insert, no read access — see the migration in
/// backend/README.md's schema section).
///
/// This must never be able to break the app: every send is best-effort,
/// swallows its own failures, and never throws back into the caller —
/// logging a problem is not allowed to cause a second one. It also always
/// prints locally first, so nothing is lost to a network hiccup while you
/// have the console open.
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
    try {
      await Backend.insertLog({
        'level': level.name,
        'message': message.length > 2000 ? message.substring(0, 2000) : message,
        'error': error?.toString() ?? '',
        'stack': _trim(stack?.toString()),
        'context': safeContext(context ?? <String, dynamic>{}),
        'platform': kIsWeb ? 'web' : 'desktop',
        'route': currentRoute,
      });
    } on Object {
      // No backend reachable — this entry is lost. Acceptable trade-off
      // for "never blocks or crashes the app"; see BACKEND.md if a local
      // durable queue is ever worth adding.
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
