import 'dart:convert';
import 'net/net.dart';

/// Client for the app's Supabase project (see `backend/README.md`).
/// Switched from a self-hosted PocketBase to Supabase (2026-09-04) at the
/// user's request — Supabase's free tier is already hosted (no PC/Fly.io
/// deploy needed) and sends auth emails itself with zero SMTP setup.
///
/// There is no `supabase_flutter` package here — pub.dev is still blocked
/// on this machine (see BACKEND.md) — so this talks to Supabase's plain
/// REST APIs directly: GoTrue for auth (`/auth/v1/...`), PostgREST for data
/// (`/rest/v1/...`), both callable with nothing but the publishable key.
///
/// Every call is best-effort: if the project is unreachable, callers catch
/// [NetException] and fall back to local-only state. The app must never
/// block on the network.
class Backend {
  static const String baseUrl = 'https://axrcelnxjdcbadngtxaa.supabase.co';

  /// Publishable ("anon") key — safe to ship in a client, that's what it's
  /// for. Required as the `apikey` header on every request, auth or data.
  static const String publishableKey =
      'sb_publishable_cQhXR5D8nuZBnhw4q1LVrA_HbWBWRNO';

  static Map<String, String> _headers([String? token]) => {
        'apikey': publishableKey,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ------------------------------------------------------------------ auth

  /// Creates the account. With "Confirm email" on (the project default)
  /// this does **not** return a usable session — it returns the new
  /// user's id and triggers Supabase's own confirmation email in the same
  /// call. [confirmSignup] is what actually signs them in.
  static Future<String> signUp({
    required String name,
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/auth/v1/signup',
      headers: _headers(),
      body: {
        'email': email,
        'password': password,
        'data': {'display_name': name},
        if (captchaToken != null)
          'gotrue_meta_security': {'captcha_token': captchaToken},
      },
    );
    if (!res.ok) throw _authException(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    // A brand-new signup with confirmation required nests the user under
    // `user`; a project with confirmation off returns a full session with
    // the user at the top level instead — handle both.
    final user = (data['user'] ?? data) as Map<String, dynamic>;
    return user['id'] as String;
  }

  /// Confirms the code Supabase emailed after [signUp]. Success returns a
  /// real session — this is the actual "signed in" moment.
  static Future<AuthSession> confirmSignup(String email, String code) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/auth/v1/verify',
      headers: _headers(),
      body: {'type': 'signup', 'email': email, 'token': code},
    );
    if (!res.ok) throw _authException(res.body);
    return AuthSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Re-sends the signup confirmation email (e.g. the code expired).
  static Future<void> resendSignupCode(String email) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/auth/v1/resend',
      headers: _headers(),
      body: {'type': 'signup', 'email': email},
    );
    if (!res.ok) throw _authException(res.body);
  }

  static Future<AuthSession> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/auth/v1/token?grant_type=password',
      headers: _headers(),
      body: {
        'email': email,
        'password': password,
        if (captchaToken != null)
          'gotrue_meta_security': {'captcha_token': captchaToken},
      },
    );
    if (!res.ok) throw _authException(res.body);
    return AuthSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Validates a stored refresh token on cold start, returning a fresh
  /// session, or throws if it's no longer valid.
  static Future<AuthSession> refresh(String refreshToken) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/auth/v1/token?grant_type=refresh_token',
      headers: _headers(),
      body: {'refresh_token': refreshToken},
    );
    if (!res.ok) throw _authException(res.body);
    return AuthSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Checks GoTrue's public settings endpoint so the UI can fail with a
  /// friendly message instead of redirecting into a raw JSON error page
  /// when nobody has configured the Google provider yet.
  static Future<bool> isGoogleSignInEnabled() async {
    final res = await Net.request(
      'GET',
      '$baseUrl/auth/v1/settings',
      headers: _headers(),
    );
    if (!res.ok) throw _authException(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final external = data['external'] as Map<String, dynamic>?;
    return external?['google'] == true;
  }

  /// The redirect URL to send the browser to for Google sign-in. Supabase
  /// itself brokers the OAuth2/PKCE dance (state, code verifier, talking
  /// to Google) — the app just redirects here and, on return, reads the
  /// session Supabase appends to the URL fragment. See
  /// `AppState.startGoogleSignIn`/`completeOAuthRedirectIfPresent`.
  static String googleAuthUrl(String redirectUrl) =>
      '$baseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}';

  // --------------------------------------------------------------- profile

  static Future<Map<String, dynamic>> getProfile(
      String token, String userId) async {
    final res = await Net.request(
      'GET',
      '$baseUrl/rest/v1/profiles?id=eq.$userId&select=*',
      headers: _headers(token),
    );
    if (!res.ok) throw _pgException(res.body);
    final rows = jsonDecode(res.body) as List;
    if (rows.isEmpty) {
      throw const NetException('پروفایل هنوز آماده نیست. کمی بعد دوباره امتحان کنید.');
    }
    return rows.first as Map<String, dynamic>;
  }

  static Future<void> updateProfile(
    String token,
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final res = await Net.request(
      'PATCH',
      '$baseUrl/rest/v1/profiles?id=eq.$userId',
      headers: {..._headers(token), 'Prefer': 'return=minimal'},
      body: fields,
    );
    if (!res.ok) throw _pgException(res.body);
  }

  // -------------------------------------------------------------- progress

  static Future<List<Map<String, dynamic>>> listSurahProgress(
      String token) async {
    final res = await Net.request(
      'GET',
      '$baseUrl/rest/v1/surah_progress?select=*',
      headers: _headers(token),
    );
    if (!res.ok) throw _pgException(res.body);
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  /// A single upsert call — PostgREST's `on_conflict` + `merge-duplicates`
  /// does what PocketBase needed a look-up-then-write round trip for.
  static Future<void> upsertSurahProgress(
    String token,
    String userId, {
    required int surah,
    required int heldCount,
    required bool sealed,
  }) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/rest/v1/surah_progress?on_conflict=user_id,surah',
      headers: {
        ..._headers(token),
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: {
        'user_id': userId,
        'surah': surah,
        'held_count': heldCount,
        'sealed': sealed,
        if (sealed) 'sealed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!res.ok) throw _pgException(res.body);
  }

  // ------------------------------------------------------------- bookmarks

  static Future<List<Map<String, dynamic>>> listBookmarks(
      String token) async {
    final res = await Net.request(
      'GET',
      '$baseUrl/rest/v1/bookmarks?select=*&order=created_at.desc',
      headers: _headers(token),
    );
    if (!res.ok) throw _pgException(res.body);
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<String> addBookmark(
    String token,
    String userId, {
    required int surah,
    required int ayah,
  }) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/rest/v1/bookmarks',
      headers: {..._headers(token), 'Prefer': 'return=representation'},
      body: {'user_id': userId, 'surah': surah, 'ayah': ayah},
    );
    if (!res.ok) throw _pgException(res.body);
    final rows = jsonDecode(res.body) as List;
    return (rows.first as Map<String, dynamic>)['id'] as String;
  }

  static Future<void> removeBookmark(String token, String recordId) async {
    final res = await Net.request(
      'DELETE',
      '$baseUrl/rest/v1/bookmarks?id=eq.$recordId',
      headers: _headers(token),
    );
    if (!res.ok) throw _pgException(res.body);
  }

  // -------------------------------------------------------- push (web push)

  /// Upserts on the unique `endpoint` column — re-subscribing the same
  /// browser (e.g. after the subscription's keys rotate, which browsers
  /// do occasionally) updates the existing row instead of duplicating it.
  static Future<void> upsertPushSubscription(
    String token,
    String userId, {
    required String endpoint,
    required String p256dh,
    required String authKey,
  }) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/rest/v1/push_subscriptions?on_conflict=endpoint',
      headers: {
        ..._headers(token),
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: {
        'user_id': userId,
        'endpoint': endpoint,
        'p256dh': p256dh,
        'auth_key': authKey,
      },
    );
    if (!res.ok) throw _pgException(res.body);
  }

  static Future<void> deletePushSubscription(String token, String endpoint) async {
    final res = await Net.request(
      'DELETE',
      '$baseUrl/rest/v1/push_subscriptions?endpoint=eq.${Uri.encodeComponent(endpoint)}',
      headers: _headers(token),
    );
    if (!res.ok) throw _pgException(res.body);
  }

  // -------------------------------------------------------------- logging

  static Future<void> insertLog(Map<String, dynamic> fields) async {
    final res = await Net.request(
      'POST',
      '$baseUrl/rest/v1/logs',
      headers: {..._headers(), 'Prefer': 'return=minimal'},
      body: fields,
    );
    if (!res.ok) throw _pgException(res.body);
  }

  // ------------------------------------------------------------- errors

  /// GoTrue (auth) error bodies look like `{"error_code": "...",
  /// "msg": "..."}` (or the older `{"error": "...", "error_description":
  /// "..."}` shape). Supabase designs these `msg`/`error_description`
  /// strings to be shown to a user directly ("Invalid login credentials",
  /// "User already registered", ...) — safe to surface as-is when present.
  /// The fallback path (unparseable body, or a shape with none of those
  /// fields — e.g. a proxy's raw HTML error page, or an unexpected 5xx)
  /// used to return the **raw response body** here, which is exactly the
  /// kind of internal detail (could be anything — server internals, stack-
  /// shaped text) that should never reach a user. It now returns a fixed,
  /// generic, safe message instead; the raw body still reaches
  /// `AppLog.warn`/`.error` in full via [NetException.technicalDetail].
  static NetException _authException(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final msg =
          (data['msg'] ?? data['error_description'] ?? data['error'])?.toString();
      if (msg != null && msg.isNotEmpty) {
        return NetException(msg, technicalDetail: body);
      }
    } on Object {
      // Not JSON, or not the expected shape — fall through to the safe
      // generic message below.
    }
    return NetException(
      'مشکلی در ارتباط با سرور پیش آمد. لطفاً دوباره امتحان کنید.',
      technicalDetail: body,
    );
  }

  /// PostgREST error bodies look like `{"message": "...", "details": ...,
  /// "hint": ...}` — but unlike GoTrue's, this `message` is raw database
  /// text (constraint names, column names, sometimes literal SQL) and is
  /// **never** safe to show a user directly, regardless of whether it
  /// parsed. Always returns a fixed, generic, safe message; the real
  /// database error still reaches `AppLog.warn`/`.error` in full via
  /// [NetException.technicalDetail] for actual debugging.
  static NetException _pgException(String body) {
    String detail;
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      detail = data['message']?.toString() ?? body;
    } on Object {
      detail = body;
    }
    return NetException(
      'مشکلی در ذخیره اطلاعات پیش آمد. لطفاً دوباره امتحان کنید.',
      technicalDetail: detail,
    );
  }
}

/// A GoTrue auth response, normalized — the same shape whether it came
/// from signup confirmation, password login, or a token refresh.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;

  /// `user_metadata` from the auth response — for a password signup this
  /// is just `{display_name: ...}` (what we sent), but for Google it also
  /// carries whatever Google returned (`full_name`, `name`, `avatar_url`),
  /// which the `profiles` row doesn't automatically pick up.
  final Map<String, dynamic> metadata;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    this.metadata = const {},
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      userId: user['id'] as String,
      email: user['email'] as String? ?? '',
      metadata:
          (user['user_metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
