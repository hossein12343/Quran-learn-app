/// Sharing an ayah's text out of the app — the Web Share API where the
/// browser supports it (opens the device's native share sheet: WhatsApp,
/// Telegram, etc.), a clipboard-copy fallback everywhere else.
///
/// Real on web: `share_impl/share_factory_web.dart`, same hand-installed-
/// JS-engine pattern as every other browser API this app wraps that
/// `dart:html` has no typed binding for. Off-web, [UnavailableShare]
/// makes both operations safely no-op rather than throw.
abstract class ShareService {
  /// Whether `navigator.share` exists on this browser — most mobile
  /// browsers, most desktop Chrome/Edge; notably not desktop Firefox.
  bool get canShare;

  /// Opens the native share sheet with [text]. Returns false if the
  /// browser has no Web Share API, the user cancelled, or it otherwise
  /// failed — callers should fall back to [copyToClipboard] on false.
  Future<bool> share({required String text, String? title});

  Future<bool> copyToClipboard(String text);
}

class UnavailableShare implements ShareService {
  @override
  bool get canShare => false;

  @override
  Future<bool> share({required String text, String? title}) async => false;

  @override
  Future<bool> copyToClipboard(String text) async => false;
}

ShareService shareService = UnavailableShare();
