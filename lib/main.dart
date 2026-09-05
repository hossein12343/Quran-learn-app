import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_pages.dart';
import 'features/main/main_shell.dart';
import 'features/splash/splash_page.dart';
import 'shared/services/app_log.dart';
import 'shared/services/app_state.dart';
import 'shared/services/audio.dart';
import 'shared/services/audio_impl/audio_factory.dart';
import 'shared/services/oauth/web_nav.dart';
import 'shared/services/reminder_impl/reminder_factory.dart';
import 'shared/services/reminders.dart';
import 'shared/services/settings.dart';
import 'shared/services/sfx.dart';
import 'shared/services/sfx_impl/sfx_factory.dart';

/// A lightweight, permanent early-warning net for real UI freezes — logs
/// (via `AppLog`, to Supabase, no DevTools needed) any single frame whose
/// actual GPU rasterization takes a genuinely user-visible amount of time.
/// This is what caught the real root cause of a user-reported freeze right
/// after a correct quiz answer: Dart-side logic measured under 1ms every
/// time, but one frame's *rasterization* — invisible to any Dart-level
/// timing, `addPostFrameCallback` included — took over 14 seconds, traced
/// to `canvas.drawShadow` in `Mascot`'s star painter (fixed: see
/// `mascot.dart`). Kept at a high threshold specifically so it stays quiet
/// during normal use and only fires on something worth investigating.
void _installFrameTimingWatch() {
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final t in timings) {
      final buildMs = t.buildDuration.inMilliseconds;
      final rasterMs = t.rasterDuration.inMilliseconds;
      if (rasterMs > 800 || buildMs > 800) {
        AppLog.info('perf: slow frame', context: {
          'build_ms': buildMs,
          'raster_ms': rasterMs,
          'route': AppLog.currentRoute,
        });
      }
    }
  });
}

/// The "یادآور روزانه" toggle in Settings used to be pure decoration — it
/// persisted a bool and did nothing else, no notification system existed
/// behind it (flagged as issue #2 in this app's own "what should I improve"
/// review). This is the real implementation of its **foreground** tier:
/// checked once a minute, fires exactly once per day, only once the user
/// has both turned the toggle on *and* granted browser notification
/// permission (that handshake happens in `settings_page.dart`, not here).
/// Works with no account at all, but only while some tab has the app open
/// — see `reminders.dart`'s doc comment for the **background** tier (real
/// Web Push, needs a signed-in account) this complements, wired below in
/// [_maybeResubscribePush].
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void _checkDailyReminder() {
  if (!settings.dailyReminder || !reminders.available) return;
  final now = DateTime.now();
  final today = _dateKey(now);
  // Already practiced today — nothing to remind about.
  if (appState.lastActiveDate == today) return;
  final target = settings.reminderTime;
  final reached = now.hour > target.hour ||
      (now.hour == target.hour && now.minute >= target.minute);
  if (!reached) return;
  if (reminders.alreadyFiredToday(today)) return;
  reminders.fire(
    title: 'وقت تمرین قرآنه! 🌙',
    body: 'چند دقیقه وقت بذار — استریکت رو امروز هم زنده نگه دار.',
    dateKey: today,
  );
}

void _installDailyReminderWatch() {
  _checkDailyReminder();
  Timer.periodic(const Duration(minutes: 1), (_) => _checkDailyReminder());
}

/// Re-registers the push subscription once per sign-in, for the case the
/// toggle-driven subscribe flow in `settings_page.dart` never ran this
/// session — e.g. a returning user who enabled the reminder before, then
/// closed the tab and reopened it (or signed in on a fresh browser that
/// already restored `settings.dailyReminder = true` from local storage).
/// `subscribeToPush` reuses an existing subscription if the browser
/// already has one, so calling it again here is cheap and idempotent, not
/// a duplicate registration.
bool _pushResubscribeAttempted = false;
Future<void> _maybeResubscribePush() async {
  if (_pushResubscribeAttempted) return;
  if (!appState.signedIn) return;
  if (!settings.dailyReminder || !reminders.permissionGranted) return;
  if (!reminders.pushSupported) return;
  _pushResubscribeAttempted = true;
  final sub = await reminders.subscribeToPush(vapidPublicKey);
  if (sub != null) {
    await appState.savePushSubscription(
      endpoint: sub.endpoint,
      p256dh: sub.p256dh,
      authKey: sub.auth,
    );
    appState.syncPushReminder(
      enabled: true,
      hour: settings.reminderTime.hour,
      minute: settings.reminderTime.minute,
      timezone: reminders.timezone,
    );
  }
}

void main() {
  // Absolute first thing, before anything else touches the URL — Supabase's
  // OAuth redirect appends `#access_token=...`, and `usePathUrlStrategy()`
  // right below (or Flutter's Router initializing) silently wipes that
  // fragment from the address bar almost immediately. Verified live: without
  // this capture, by the time SplashPage read `Uri.base.fragment` the token
  // was already gone and sign-in silently no-op'd. Capturing it here first
  // is what actually fixes that.
  WebNav.captureInitialFragment();
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) _installFrameTimingWatch();
  // Flutter web's default hash ('#/route') URL strategy collides head-on
  // with Supabase's OAuth implicit flow, which appends its own
  // `#access_token=...` fragment to the redirect URL — Flutter's router
  // parses that fragment as an (unknown) route on boot, before any of our
  // own code runs, corrupting the Navigator and throwing a real
  // `_elements.contains(element)` crash (hit live testing Google sign-in).
  // Switching to path-based URLs frees `#` entirely for Supabase's tokens.
  if (kIsWeb) usePathUrlStrategy();
  AppLog.captureUncaught();
  recitation = createRecitationPlayer();
  sfx = createSoundEffects();
  sfx.warmUp();
  reminders = createReminderService();
  if (kIsWeb) {
    _installDailyReminderWatch();
    appState.addListener(_maybeResubscribePush);
  }
  settings.restore();
  runApp(const QuranLearnApp());
}

/// Tracks the current top-level route so log entries carry roughly where
/// in the app they happened. Only named routes (the auth/splash/home
/// screens) get a name — the many `Navigator.push(MaterialPageRoute(...))`
/// calls elsewhere don't set one, so this is partial context, not a full
/// breadcrumb trail.
class _RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) AppLog.currentRoute = name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = previousRoute?.settings.name;
    if (name != null) AppLog.currentRoute = name;
  }
}

/// A single stable instance, not one created fresh per build — a *new*
/// NavigatorObserver list on every `AnimatedBuilder` rebuild (which
/// `appState.notifyListeners()` triggers, and several calls can fire in
/// quick succession during sign-in) made the Navigator re-subscribe
/// observers mid-transition, corrupting its internal bookkeeping and
/// throwing a `_elements.contains(element) is not true` assertion —
/// hit live during the Google sign-in redirect. See the project's
/// Claude memory for the full story if this resurfaces.
final _routeLogger = _RouteLogger();

class QuranLearnApp extends StatelessWidget {
  const QuranLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'یادگیری قرآن',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
          navigatorObservers: [_routeLogger],
          // The app defaults to Persian UI text now — wrapping everything
          // in RTL directionality once here, rather than per-screen, is
          // what actually makes the whole chrome (nav bar order, text
          // alignment, icon positions) read right-to-left instead of just
          // the Persian text itself sitting oddly inside an LTR layout.
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          initialRoute: '/splash',
          routes: <String, WidgetBuilder>{
            // Path-based URLs (see usePathUrlStrategy above) mean the
            // browser can genuinely land on the bare root path — every
            // OAuth redirect starts there — so it needs its own entry,
            // not just '/splash'. `initialRoute` only seeds the very
            // first navigation; it does not make '/' itself resolvable.
            '/': (_) => const SplashPage(),
            '/splash': (_) => const SplashPage(),
            '/login': (_) => const LoginPage(),
            '/signup': (_) => const SignupPage(),
            '/onboarding': (_) => const OnboardingPage(),
            '/home': (_) => const MainShell(),
          },
          // Defensive fallback so an unrecognized path (e.g. a stray
          // query string PocketBase/Supabase might append) never leaves
          // the app on a blank/dead screen the way '/' briefly did.
          onUnknownRoute: (_) =>
              MaterialPageRoute(builder: (_) => const SplashPage()),
        );
      },
    );
  }
}
