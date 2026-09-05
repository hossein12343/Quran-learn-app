import 'dart:html' as html;

class WebNav {
  /// The raw URL fragment (leading `#` included, as `location.hash`
  /// gives it), captured once at the very start of `main()` — **before**
  /// `usePathUrlStrategy()` runs. That call (or Flutter's own Router
  /// initializing right after) rewrites the address bar to match its
  /// resolved route almost immediately, silently dropping any existing
  /// fragment — verified live: by the time `SplashPage.initState()` ran
  /// and read `Uri.base.fragment`, Supabase's `#access_token=...` was
  /// already gone, even though nothing in this app's own code had
  /// touched the URL yet. Reading from this captured snapshot instead of
  /// the live URL is what actually fixes it.
  static String? _capturedFragment;

  static void captureInitialFragment() {
    _capturedFragment = html.window.location.hash;
  }

  static String? queryParam(String key) => Uri.base.queryParameters[key];

  /// Supabase's implicit OAuth flow appends the session as a URL
  /// *fragment* (`#access_token=...&refresh_token=...`), not query
  /// params — browsers never send fragments to a server, which is the
  /// whole point (see AppState.completeOAuthRedirectIfPresent).
  static String? fragmentParam(String key) {
    var fragment = _capturedFragment ?? Uri.base.fragment;
    // Defensive, not just cosmetic: an empty fragment we ourselves sent as
    // part of a redirect_to URL (see auth_pages.dart's _oauthRedirectUrl)
    // once caused Supabase to append its own fragment straight onto ours,
    // producing a real `##access_token=...` — strip every leading `#`,
    // not just one.
    fragment = fragment.replaceFirst(RegExp(r'^#+'), '');
    if (fragment.isEmpty) return null;
    return Uri.splitQueryString(fragment)[key];
  }

  static bool get hasOAuthCallback => fragmentParam('access_token') != null;

  static void redirectTo(String url) {
    html.window.location.href = url;
  }

  /// Drops the `#access_token=...` Supabase appended after the OAuth
  /// redirect, so a manual refresh doesn't try to reuse it — and clears
  /// the captured snapshot too, so it's only ever consumed once.
  static void clearQuery() {
    _capturedFragment = null;
    html.window.history.replaceState(null, '', Uri.base.path);
  }
}
