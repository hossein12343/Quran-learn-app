import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/quran_seed.dart';
import 'app_log.dart';
import 'backend.dart';
import 'net/net.dart';
import 'oauth/web_nav.dart';
import 'store/local_store.dart';

/// Single source of truth for the session. Local state is always the one
/// the UI reads — every screen keeps working with no backend reachable.
/// The app's Supabase project (see BACKEND.md) is synced to in the
/// background, best-effort: nothing here ever awaits the network before
/// updating the screen.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  String displayName = 'دانش‌آموز';
  String email = '';
  bool signedIn = false;
  bool darkMode = false;

  int totalXp = 0;
  int currentStreak = 0;
  int longestStreak = 0;

  /// 'yyyy-MM-dd' of the last calendar day a session was recorded — the
  /// only thing that actually drives [currentStreak]. Login/app-open does
  /// not touch it; only [recordSession] does.
  String? lastActiveDate;
  int dailyGoalMinutes = 10;
  int minutesToday = 0;
  String learningGoal = 'حفظ سوره‌های کوتاه';

  /// surah number -> indices (into that surah's ayat) actually held.
  final Map<int, Set<int>> _heldAyat = <int, Set<int>>{};

  /// surah number -> sealed (every level in it passed its gate)
  final Set<int> sealed = <int>{};

  /// `surahNumber * 1000 + chunkIndex` -> sealed. Chunk index never
  /// exceeds ~36 even for Al-Baqarah, so this is a safe, simple composite
  /// key without needing a real value type.
  final Set<int> sealedLevels = <int>{};

  /// levelKey -> when it's next due for review, and how many times in a
  /// row it's survived that review cleanly (widens the gap each time —
  /// see [ReviewSchedule]).
  final Map<int, DateTime> reviewDue = <int, DateTime>{};
  final Map<int, int> reviewCleanRecalls = <int, int>{};

  // ---------------------------------------------------------------- streak

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseYmd(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  int _daysBetween(String a, String b) =>
      _parseYmd(b).difference(_parseYmd(a)).inDays;

  /// The only place [currentStreak] changes upward. A session today after
  /// one yesterday extends it; a session today after a gap of 2+ days (or
  /// no prior session at all) restarts it at 1; a second session on the
  /// same day is a no-op.
  void _touchStreakForToday() {
    final today = _todayKey();
    if (lastActiveDate == today) return;
    currentStreak = lastActiveDate != null &&
            _daysBetween(lastActiveDate!, today) == 1
        ? currentStreak + 1
        : 1;
    lastActiveDate = today;
    if (currentStreak > longestStreak) longestStreak = currentStreak;
  }

  /// Call after loading state from anywhere (local disk or the server) so
  /// a streak that was already broken by the calendar shows as broken
  /// immediately, rather than sitting stale until the next session.
  void _reconcileStreakIfBroken() {
    final last = lastActiveDate;
    if (last == null) return;
    if (_daysBetween(last, _todayKey()) > 1) currentStreak = 0;
  }

  int levelKey(int surahNumber, int chunkIndex) =>
      surahNumber * 1000 + chunkIndex;

  bool isLevelSealed(int surahNumber, int chunkIndex) =>
      sealedLevels.contains(levelKey(surahNumber, chunkIndex));

  /// Every sealed level whose review date has arrived, most overdue first.
  List<({Surah surah, int chunkIndex, DateTime due})> get dueForReview {
    final due = <({Surah surah, int chunkIndex, DateTime due})>[];
    reviewDue.forEach((key, date) {
      if (!ReviewSchedule.isDue(date)) return;
      final surahNumber = key ~/ 1000;
      final chunkIndex = key % 1000;
      final surah = surahs.firstWhere(
        (s) => s.number == surahNumber,
        orElse: () => surahs.first,
      );
      if (surah.number != surahNumber) return; // surah data not loaded yet
      due.add((surah: surah, chunkIndex: chunkIndex, due: date));
    });
    due.sort((a, b) => a.due.compareTo(b.due));
    return due;
  }

  /// A level unlocks once the level before it (or, for a surah's first
  /// level, the surah itself) is unlocked — the same one-thing-at-a-time
  /// rule as surahs, just one level deeper.
  bool isLevelUnlocked(Surah surah, int chunkIndex) {
    if (chunkIndex == 0) {
      final si = surahs.indexWhere((s) => s.number == surah.number);
      return si == -1 ? false : isUnlocked(si);
    }
    return isLevelSealed(surah.number, chunkIndex - 1);
  }

  /// The first not-yet-sealed level in this surah — where "continue"
  /// should jump straight into.
  int nextChunkFor(Surah surah) {
    final count = chunkCountFor(surah);
    for (var i = 0; i < count; i++) {
      if (!isLevelSealed(surah.number, i)) return i;
    }
    return count - 1;
  }

  int quizzesTaken = 0;
  int quizzesPassed = 0;

  /// "surah:ayah" -> backend record id, or null while a remote add is
  /// still in flight. Present locally the instant you tap the star either
  /// way, so the UI never waits on the network.
  final Map<String, String?> bookmarks = <String, String?>{};

  String? _userId;
  String? _authToken;
  String? _refreshToken;
  bool syncing = false;
  String? syncNotice;
  bool get hasSyncedAccount => _authToken != null;

  /// Backward-compatible view: every existing screen reads `held[n]` as a
  /// plain count, which still works because Map access syntax is identical
  /// whether the map is stored or computed.
  Map<int, int> get held =>
      {for (final e in _heldAyat.entries) e.key: e.value.length};

  Set<int> heldIndices(int surahNumber) =>
      _heldAyat[surahNumber] ?? const <int>{};

  bool isBookmarked(int surah, int ayah) =>
      bookmarks.containsKey('$surah:$ayah');

  int get ayatHeld => held.values.fold(0, (a, b) => a + b);

  int get totalAyat => surahs.fold(0, (a, s) => a + s.length);

  int get level => 1 + (totalXp ~/ 150);

  int get xpIntoLevel => totalXp % 150;

  double get levelProgress => xpIntoLevel / 150;

  double get dailyProgress =>
      dailyGoalMinutes == 0 ? 0 : (minutesToday / dailyGoalMinutes).clamp(0, 1);

  bool isUnlocked(int index) {
    if (index == 0) return true;
    return sealed.contains(surahs[index - 1].number);
  }

  Surah? get nextSurah {
    for (var i = 0; i < surahs.length; i++) {
      if (!sealed.contains(surahs[i].number) && isUnlocked(i)) {
        return surahs[i];
      }
    }
    return null;
  }

  // -------------------------------------------------------------- session

  /// Called once at app boot. Restores whatever was saved on this device
  /// instantly, then — if Supabase answers — reconciles with the
  /// authoritative copy there. Never blocks: the splash screen has a
  /// timeout regardless of how this resolves.
  Future<void> restoreSession() async {
    darkMode = LocalStore.get('dark_mode') == '1';

    final raw = LocalStore.get('session');
    if (raw != null) {
      try {
        _applySnapshot(jsonDecode(raw) as Map<String, dynamic>);
        _reconcileStreakIfBroken();
        signedIn = true;
      } on Object {
        // Corrupt local snapshot — ignore and fall through to login.
      }
    }
    // This runs from SplashPage's initState, i.e. mid-build — notifying
    // synchronously here would ask an ancestor to rebuild while the
    // framework is still building it. Deferring one microtask is enough;
    // SplashPage itself reads the fields directly rather than waiting for
    // a rebuild, so nothing here is actually blocked on the notification.
    scheduleMicrotask(notifyListeners);

    final refreshToken = _refreshToken;
    if (refreshToken == null) return;
    try {
      final session = await Backend.refresh(refreshToken);
      await _adoptSession(session);
      _reconcileStreakIfBroken();
      await _pullSurahProgress();
      await _pullBookmarks();
      syncNotice = null;
    } on NetException catch (e) {
      syncNotice = 'آفلاین — نمایش آنچه روی این دستگاه ذخیره شده است.';
      AppLog.warn('Session restore could not reach the backend', error: e);
    }
    notifyListeners();
  }

  /// [password] is optional so widget tests / callers that only want the
  /// local-only behaviour of the original build can still use this. This
  /// is regular sign-in only — account *creation* goes through
  /// [beginSignup]/[confirmSignup] instead, since it needs the emailed
  /// code.
  void signIn(String name, String mail, {String? password, String? captchaToken}) {
    displayName = name.trim().isEmpty ? 'دانش‌آموز' : name.trim();
    email = mail.trim();
    signedIn = true;
    notifyListeners();
    _persistSnapshot();

    if (password != null && password.isNotEmpty) {
      unawaited(_syncAuth(email, password, captchaToken));
    }
  }

  Future<void> _syncAuth(String mail, String password, String? captchaToken) async {
    syncing = true;
    syncNotice = null;
    notifyListeners();
    try {
      final session = await Backend.signIn(
        email: mail,
        password: password,
        captchaToken: captchaToken,
      );
      await _adoptSession(session);
      _reconcileStreakIfBroken();
      await _pullSurahProgress();
      await _pullBookmarks();
      syncNotice = null;
    } on NetException catch (e) {
      syncNotice =
          'کار به‌صورت آفلاین — پیشرفت روی این دستگاه ذخیره می‌شود و پس از '
          'در دسترس بودن سرور همگام‌سازی خواهد شد.';
      AppLog.warn('Auth sync failed', error: e);
    }
    syncing = false;
    notifyListeners();
  }

  /// Common tail of every path that ends with a fresh [AuthSession]:
  /// stores the tokens, pulls the profile row Supabase's `handle_new_user`
  /// trigger guarantees exists, and applies it.
  Future<void> _adoptSession(AuthSession session) async {
    _authToken = session.accessToken;
    _refreshToken = session.refreshToken;
    _userId = session.userId;
    if (session.email.isNotEmpty) email = session.email;
    final profile = await Backend.getProfile(session.accessToken, session.userId);
    _applyRemoteProfile(profile);
  }

  // ------------------------------------------------- email-verified signup

  String? _pendingEmail;

  /// Step 1 of real signup: creates the account on Supabase, which in the
  /// same call emails it a 6-digit confirmation code (built-in — see
  /// backend/README.md's "Real email-verified signup" section for the one
  /// dashboard template edit it needs). Unlike the rest of this class this
  /// genuinely needs the network and throws [NetException] on failure —
  /// "verified" only means something if the server confirms it, so there
  /// is no local-only fallback here.
  Future<void> beginSignup(
    String name,
    String mail,
    String password, {
    String? captchaToken,
  }) async {
    await Backend.signUp(
      name: name,
      email: mail,
      password: password,
      captchaToken: captchaToken,
    );
    _pendingEmail = mail.trim();
  }

  /// Re-sends the code for an in-progress signup (e.g. the first one
  /// expired or never arrived).
  Future<void> resendSignupCode() {
    final pending = _pendingEmail;
    if (pending == null) {
      throw StateError('resendSignupCode called with no signup in progress');
    }
    return Backend.resendSignupCode(pending);
  }

  /// Step 2: confirms the emailed code. Throws [NetException] if it's
  /// wrong or expired — the caller should let the user retry rather than
  /// silently continuing, since this is the one gate that's supposed to be
  /// real.
  Future<void> confirmSignup(String code) async {
    final pending = _pendingEmail;
    if (pending == null) {
      throw StateError('confirmSignup called with no signup in progress');
    }
    final session = await Backend.confirmSignup(pending, code);
    _pendingEmail = null;
    await _adoptSession(session);
    signedIn = true;
    notifyListeners();
    _persistSnapshot();
  }

  // -------------------------------------------------------- Google sign-in

  /// Redirects the browser to Google's consent screen — Supabase itself
  /// brokers the whole OAuth2 exchange (state, PKCE, talking to Google),
  /// so there's nothing to store beforehand. [redirectUrl] must be on the
  /// project's Auth > URL Configuration allow-list. Throws [NetException]
  /// if Google isn't configured yet, so the caller can show a friendly
  /// message instead of redirecting into a raw JSON error page.
  Future<void> startGoogleSignIn(String redirectUrl) async {
    if (!await Backend.isGoogleSignInEnabled()) {
      throw const NetException(
          'ورود با گوگل هنوز روی سرور تنظیم نشده است.');
    }
    WebNav.redirectTo(Backend.googleAuthUrl(redirectUrl));
  }

  /// Called once at boot (see SplashPage._go). A no-op unless the URL
  /// fragment is Supabase's redirect back from [startGoogleSignIn]
  /// (`#access_token=...&refresh_token=...`). Returns true if it signed
  /// someone in.
  Future<bool> completeOAuthRedirectIfPresent() async {
    if (!WebNav.hasOAuthCallback) return false;
    final accessToken = WebNav.fragmentParam('access_token');
    final refreshTokenValue = WebNav.fragmentParam('refresh_token');
    WebNav.clearQuery();
    if (accessToken == null || refreshTokenValue == null) {
      AppLog.warn('OAuth redirect ignored: fragment missing tokens');
      return false;
    }
    try {
      // The fragment carries the tokens directly but not the user id/email
      // — refreshing immediately gets us those plus a clean, verified pair.
      final session = await Backend.refresh(refreshTokenValue);
      await _adoptSession(session);
      // The `handle_new_user` trigger only knows about `display_name`
      // (what password signup sends) — Google's own name lands in
      // metadata under a different key, so pull it in here and persist it
      // as this account's real display name.
      final googleName = (session.metadata['full_name'] ??
              session.metadata['name']) as String?;
      if (googleName != null && googleName.isNotEmpty) {
        displayName = googleName;
        _pushProfileFields({'display_name': googleName});
      }
      _reconcileStreakIfBroken();
      signedIn = true;
      await _pullSurahProgress();
      await _pullBookmarks();
      notifyListeners();
      _persistSnapshot();
      return true;
    } on NetException catch (e) {
      AppLog.error('Google sign-in failed to complete', error: e);
      return false;
    }
  }

  void signOut() {
    signedIn = false;
    _authToken = null;
    _refreshToken = null;
    _userId = null;
    LocalStore.remove('session');
    notifyListeners();
  }

  void setGoal(String goal, int minutes) {
    learningGoal = goal;
    dailyGoalMinutes = minutes;
    notifyListeners();
    _persistSnapshot();
    _pushProfileFields({'learning_goal': goal, 'daily_goal_minutes': minutes});
  }

  void toggleDark(bool v) {
    darkMode = v;
    LocalStore.set('dark_mode', v ? '1' : '0');
    notifyListeners();
    _persistSnapshot();
    _pushProfileFields({'dark_mode': v});
  }

  /// Syncs the "even with every tab closed" reminder config to the
  /// server, so the `send-daily-reminders` Edge Function (run on a
  /// schedule, see the Supabase migrations) knows whether/when to push to
  /// this account. A no-op (silently) if not signed in — push reminders
  /// are the one tier of this feature that genuinely needs an account,
  /// since there's no way to address an anonymous local user server-side.
  void syncPushReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required String? timezone,
  }) {
    _pushProfileFields({
      'push_reminder_enabled': enabled,
      'reminder_hour': hour,
      'reminder_minute': minute,
      if (timezone != null) 'timezone': timezone,
    });
  }

  /// Best-effort — a subscription failing to save just means push won't
  /// reach this browser; the foreground (tab-open) reminder tier still
  /// works regardless, and this never blocks the UI on the network.
  Future<void> savePushSubscription({
    required String endpoint,
    required String p256dh,
    required String authKey,
  }) async {
    if (_authToken == null || _userId == null) return;
    try {
      await Backend.upsertPushSubscription(
        _authToken!,
        _userId!,
        endpoint: endpoint,
        p256dh: p256dh,
        authKey: authKey,
      );
    } on Object catch (e) {
      AppLog.warn('Push subscription save failed', error: e);
    }
  }

  Future<void> removePushSubscription(String endpoint) async {
    if (_authToken == null) return;
    try {
      await Backend.deletePushSubscription(_authToken!, endpoint);
    } on Object catch (e) {
      AppLog.warn('Push subscription remove failed', error: e);
    }
  }

  /// Called when a session ends. XP is only awarded for ayat actually held,
  /// a level-clear bonus for each level (chunk) sealed, and a bigger bonus
  /// once every level in the surah is sealed — there is no XP for merely
  /// spending time in a lesson.
  void recordSession({
    required int surahNumber,
    required Set<int> heldIndicesNow,
    required bool didSeal,
    int? sealedChunk,
    bool hadMistakes = false,
    required int minutes,
  }) {
    final previous = _heldAyat[surahNumber] ?? const <int>{};
    if (heldIndicesNow.length > previous.length) {
      totalXp += (heldIndicesNow.length - previous.length) * 12;
    }
    _heldAyat[surahNumber] = heldIndicesNow;
    if (sealedChunk != null) {
      final key = levelKey(surahNumber, sealedChunk);
      final firstTime = sealedLevels.add(key);
      if (firstTime) totalXp += 15;
      // A review cleared with no lapse pushes the next one further out; a
      // level sealed for the first time, or a review with a lapse in it,
      // starts the schedule back from zero — a shaky recall shouldn't earn
      // the same widened gap as a clean one.
      final recalls =
          (firstTime || hadMistakes) ? 0 : (reviewCleanRecalls[key] ?? 0) + 1;
      reviewCleanRecalls[key] = recalls;
      reviewDue[key] = ReviewSchedule.nextDue(DateTime.now(), recalls);
    }
    if (didSeal) {
      sealed.add(surahNumber);
      totalXp += 50;
      quizzesPassed++;
    }
    quizzesTaken++;
    minutesToday += minutes;
    _touchStreakForToday();
    notifyListeners();
    _persistSnapshot();

    _pushProfileFields({
      'total_xp': totalXp,
      'minutes_today': minutesToday,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_active_date': lastActiveDate,
    });
    if (_authToken != null && _userId != null) {
      unawaited(Backend.upsertSurahProgress(
        _authToken!,
        _userId!,
        surah: surahNumber,
        heldCount: heldIndicesNow.length,
        sealed: sealed.contains(surahNumber),
      ).catchError((e) => AppLog.warn('Progress sync failed for surah $surahNumber', error: e)));
    }
  }

  // -------------------------------------------------------------- bookmarks

  Future<void> toggleBookmark(int surah, int ayah) async {
    final key = '$surah:$ayah';
    if (bookmarks.containsKey(key)) {
      final id = bookmarks[key];
      bookmarks.remove(key);
      notifyListeners();
      _persistSnapshot();
      if (id != null && _authToken != null) {
        try {
          await Backend.removeBookmark(_authToken!, id);
        } on NetException catch (e) {
          // Kept removed locally; will simply re-appear from the server on
          // next successful pull if the delete never landed.
          AppLog.warn('Bookmark remove failed for $key', error: e);
        }
      }
      return;
    }

    bookmarks[key] = null;
    notifyListeners();
    _persistSnapshot();
    if (_authToken != null && _userId != null) {
      try {
        final id = await Backend.addBookmark(_authToken!, _userId!,
            surah: surah, ayah: ayah);
        bookmarks[key] = id;
        notifyListeners();
        _persistSnapshot();
      } on NetException catch (e) {
        // Stays bookmarked locally with a null id; a later sync reconciles.
        AppLog.warn('Bookmark add failed for $key', error: e);
      }
    }
  }

  // -------------------------------------------------------------- backend

  Future<void> _pullSurahProgress() async {
    if (_authToken == null) return;
    final rows = await Backend.listSurahProgress(_authToken!);
    for (final r in rows) {
      final surah = (r['surah'] as num).toInt();
      final heldCount = (r['held_count'] as num?)?.toInt() ?? 0;
      // The server only stores how many ayat are held, not which ones —
      // approximate with the first N until a real session on this device
      // supplies the exact set again.
      _heldAyat[surah] = Set<int>.from(List<int>.generate(heldCount, (i) => i));
      if (r['sealed'] == true) sealed.add(surah);
    }
    _persistSnapshot();
  }

  Future<void> _pullBookmarks() async {
    if (_authToken == null) return;
    final rows = await Backend.listBookmarks(_authToken!);
    bookmarks.clear();
    for (final r in rows) {
      bookmarks['${r['surah']}:${r['ayah']}'] = r['id'] as String;
    }
    _persistSnapshot();
  }

  void _pushProfileFields(Map<String, dynamic> fields) {
    if (_authToken == null || _userId == null) return;
    unawaited(
      Backend.updateProfile(_authToken!, _userId!, fields).catchError(
          (e) => AppLog.warn('Profile field push failed', error: e, context: {
                'fields': fields.keys.join(','),
              })),
    );
  }

  void _applyRemoteProfile(Map<String, dynamic> record) {
    final name = record['display_name'] as String?;
    if (name != null && name.isNotEmpty) displayName = name;
    totalXp = (record['total_xp'] as num?)?.toInt() ?? totalXp;
    currentStreak = (record['current_streak'] as num?)?.toInt() ?? currentStreak;
    longestStreak = (record['longest_streak'] as num?)?.toInt() ?? longestStreak;
    final remoteActiveDate = record['last_active_date'] as String?;
    if (remoteActiveDate != null && remoteActiveDate.isNotEmpty) {
      lastActiveDate = remoteActiveDate;
    }
    dailyGoalMinutes =
        (record['daily_goal_minutes'] as num?)?.toInt() ?? dailyGoalMinutes;
    minutesToday = (record['minutes_today'] as num?)?.toInt() ?? minutesToday;
    final goal = record['learning_goal'] as String?;
    if (goal != null && goal.isNotEmpty) learningGoal = goal;
    _persistSnapshot();
  }

  // ------------------------------------------------------------ local save

  void _persistSnapshot() {
    final snap = <String, dynamic>{
      'displayName': displayName,
      'email': email,
      'totalXp': totalXp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate,
      'dailyGoalMinutes': dailyGoalMinutes,
      'minutesToday': minutesToday,
      'learningGoal': learningGoal,
      'quizzesTaken': quizzesTaken,
      'quizzesPassed': quizzesPassed,
      'held': _heldAyat.map((k, v) => MapEntry('$k', v.toList())),
      'sealed': sealed.toList(),
      'sealedLevels': sealedLevels.toList(),
      'reviewDue': reviewDue.map((k, v) => MapEntry('$k', v.toIso8601String())),
      'reviewCleanRecalls': reviewCleanRecalls.map((k, v) => MapEntry('$k', v)),
      'bookmarks': bookmarks,
      'userId': _userId,
      'authToken': _authToken,
      'refreshToken': _refreshToken,
    };
    LocalStore.set('session', jsonEncode(snap));
  }

  void _applySnapshot(Map<String, dynamic> snap) {
    displayName = snap['displayName'] as String? ?? displayName;
    email = snap['email'] as String? ?? email;
    totalXp = (snap['totalXp'] as num?)?.toInt() ?? totalXp;
    currentStreak = (snap['currentStreak'] as num?)?.toInt() ?? currentStreak;
    longestStreak = (snap['longestStreak'] as num?)?.toInt() ?? longestStreak;
    lastActiveDate = snap['lastActiveDate'] as String? ?? lastActiveDate;
    dailyGoalMinutes =
        (snap['dailyGoalMinutes'] as num?)?.toInt() ?? dailyGoalMinutes;
    minutesToday = (snap['minutesToday'] as num?)?.toInt() ?? minutesToday;
    learningGoal = snap['learningGoal'] as String? ?? learningGoal;
    quizzesTaken = (snap['quizzesTaken'] as num?)?.toInt() ?? quizzesTaken;
    quizzesPassed = (snap['quizzesPassed'] as num?)?.toInt() ?? quizzesPassed;

    final heldRaw = snap['held'] as Map<String, dynamic>?;
    if (heldRaw != null) {
      _heldAyat.clear();
      heldRaw.forEach((k, v) {
        _heldAyat[int.parse(k)] = Set<int>.from((v as List).map((e) => e as int));
      });
    }
    final sealedRaw = snap['sealed'] as List?;
    if (sealedRaw != null) {
      sealed
        ..clear()
        ..addAll(sealedRaw.map((e) => e as int));
    }
    final sealedLevelsRaw = snap['sealedLevels'] as List?;
    if (sealedLevelsRaw != null) {
      sealedLevels
        ..clear()
        ..addAll(sealedLevelsRaw.map((e) => e as int));
    }
    final reviewDueRaw = snap['reviewDue'] as Map<String, dynamic>?;
    if (reviewDueRaw != null) {
      reviewDue.clear();
      reviewDueRaw.forEach((k, v) {
        reviewDue[int.parse(k)] = DateTime.parse(v as String);
      });
    }
    final reviewRecallsRaw = snap['reviewCleanRecalls'] as Map<String, dynamic>?;
    if (reviewRecallsRaw != null) {
      reviewCleanRecalls.clear();
      reviewRecallsRaw.forEach((k, v) {
        reviewCleanRecalls[int.parse(k)] = (v as num).toInt();
      });
    }
    final bookmarksRaw = snap['bookmarks'] as Map<String, dynamic>?;
    if (bookmarksRaw != null) {
      bookmarks
        ..clear()
        ..addAll(bookmarksRaw.map((k, v) => MapEntry(k, v as String?)));
    }
    _userId = snap['userId'] as String?;
    _authToken = snap['authToken'] as String?;
    _refreshToken = snap['refreshToken'] as String?;
  }
}

final appState = AppState.instance;
