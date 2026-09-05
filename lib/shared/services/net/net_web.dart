import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'net.dart';

class Net {
  static Future<NetResponse> request(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    try {
      final h = Map<String, String>.from(headers);
      String? data;
      if (body != null) {
        h['Content-Type'] = 'application/json';
        data = jsonEncode(body);
      }
      final xhr = await html.HttpRequest.request(
        url,
        method: method,
        requestHeaders: h,
        sendData: data,
      ).timeout(const Duration(seconds: 10));
      return NetResponse(xhr.status ?? 0, xhr.responseText ?? '');
    } on html.ProgressEvent catch (e) {
      final xhr = e.target as html.HttpRequest?;
      // The browser XHR API throws on any non-2xx status instead of just
      // returning it, so the real body/status has to be recovered here —
      // PocketBase's error payloads (validation messages) live in it.
      if (xhr != null) {
        return NetResponse(xhr.status ?? 0, xhr.responseText ?? '');
      }
      throw const NetException('اتصال به سرور برقرار نشد. اتصال اینترنت خود را بررسی کنید.');
    } on TimeoutException catch (e) {
      throw NetException(
        'درخواست خیلی طول کشید. لطفاً دوباره امتحان کنید.',
        technicalDetail: e.toString(),
      );
    } on Object catch (e) {
      // A genuinely unexpected exception here (not a recognized HTTP
      // error response, not a timeout) — its `toString()` is Dart/JS
      // internals, never something to show a user. Logged in full via
      // `technicalDetail` (see `NetException`'s doc comment); the user
      // only ever sees the generic message.
      throw NetException(
        'اتصال به سرور برقرار نشد. اتصال اینترنت خود را بررسی کنید.',
        technicalDetail: e.toString(),
      );
    }
  }
}
