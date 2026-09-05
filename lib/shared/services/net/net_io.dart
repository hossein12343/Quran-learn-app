import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'net.dart';

class Net {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  static Future<NetResponse> request(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    try {
      final req = await _client.openUrl(method, Uri.parse(url));
      headers.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 10));
      final text = await res.transform(utf8.decoder).join();
      return NetResponse(res.statusCode, text);
    } on TimeoutException catch (e) {
      throw NetException(
        'درخواست خیلی طول کشید. لطفاً دوباره امتحان کنید.',
        technicalDetail: e.toString(),
      );
    } on Object catch (e) {
      // See `NetException`'s doc comment — a raw exception's `toString()`
      // is never safe to show a user, only to log.
      throw NetException(
        'اتصال به سرور برقرار نشد. اتصال اینترنت خود را بررسی کنید.',
        technicalDetail: e.toString(),
      );
    }
  }
}
