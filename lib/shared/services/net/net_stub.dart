import 'net.dart';

/// Neither dart:io nor dart:html is available on this target. Every backend
/// call fails soft, and AppState keeps working in local-only mode.
class Net {
  static Future<NetResponse> request(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    throw const NetException('اتصال به شبکه در این پلتفرم در دسترس نیست.');
  }
}
