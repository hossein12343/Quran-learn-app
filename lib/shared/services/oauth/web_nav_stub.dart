/// Redirect-based OAuth only makes sense inside a real browser tab — this
/// platform has no `window.location` to redirect or read back.
class WebNav {
  static void captureInitialFragment() {}
  static String? queryParam(String key) => null;
  static String? fragmentParam(String key) => null;
  static bool get hasOAuthCallback => false;
  static void redirectTo(String url) {}
  static void clearQuery() {}
}
