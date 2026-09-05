/// A tiny HTTP abstraction with zero pub.dev dependencies.
///
/// `dart:io`'s HttpClient does not exist on the web, and `package:http`
/// cannot be fetched while pub.dev is refusing this machine (see
/// BACKEND.md). Both platforms ship a real HTTP client in the SDK itself —
/// `dart:io` natively, `dart:html`'s `HttpRequest` on the web — so this
/// picks the right one at compile time via conditional export.
library net;

export 'net_stub.dart' if (dart.library.io) 'net_io.dart' if (dart.library.html) 'net_web.dart';

class NetResponse {
  final int statusCode;
  final String body;
  const NetResponse(this.statusCode, this.body);
  bool get ok => statusCode >= 200 && statusCode < 300;
}

/// [message] must always be safe to show a user directly — never a raw
/// server response body, a raw Postgres/PostgREST error, or a raw
/// exception's own `toString()`. Those can leak internal detail (table/
/// constraint names, stack-shaped text) that has no business reaching an
/// end user. [technicalDetail] carries that real detail instead, for logs
/// only — it's folded into [toString], so every existing
/// `AppLog.warn(..., error: e)` call site already captures it in full
/// with zero changes needed there; only the *constructors* of this class
/// (here and in `backend.dart`/`net_web.dart`/`net_io.dart`) need to get
/// the split right.
class NetException implements Exception {
  final String message;
  final String technicalDetail;
  const NetException(this.message, {this.technicalDetail = ''});
  @override
  String toString() => technicalDetail.isEmpty
      ? 'NetException: $message'
      : 'NetException: $message ($technicalDetail)';
}
