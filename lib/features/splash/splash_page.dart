import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/data/tajweed_data.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/oauth/web_nav.dart';
import '../auth/auth_pages.dart';

/// Restores whatever session was saved on this device before deciding
/// which screen to show. Without this, every reload flashed the login
/// screen even for someone who was already signed in — the exact problem
/// BACKEND.md flags: "await the current session... or users see the login
/// screen flash on every cold start."
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Set once we know this boot came back from the Google OAuth redirect,
  /// so the screen reads as "signing you in…" rather than a bare logo.
  bool _finishingSignIn = false;

  @override
  void initState() {
    super.initState();
    _finishingSignIn =
        WebNav.startedOnOAuthRedirect || appState.hasStoredSession;
    _go();
  }

  Future<void> _go() async {
    // Handle a Google OAuth redirect landing back here before anything
    // else — it's a no-op unless the URL fragment actually carries
    // Supabase's session tokens (see AppState.startGoogleSignIn).
    final signedInByGoogle = await appState.completeOAuthRedirectIfPresent();
    // Skip if OAuth already signed someone in this boot — completeOAuth-
    // RedirectIfPresent already persisted the session, so restoreSession()
    // would just redundantly re-fetch the same profile a second time via
    // a fresh token refresh, adding extra concurrent notifyListeners()
    // calls right as SplashPage is trying to navigate away (this is what
    // caused a real `_elements.contains(element)` Navigator crash — see
    // the note on `_routeLogger` in main.dart).
    if (!signedInByGoogle) {
      if (appState.hasStoredSession) {
        // A persisted login is on this device — wait for the token refresh
        // (bounded) before deciding where to go, so a returning user lands
        // straight on Home instead of flashing the login screen every cold
        // start. restoreSession() still applies the local snapshot
        // synchronously first, so the wait only covers the network round
        // trip.
        await appState
            .restoreSession()
            .timeout(const Duration(seconds: 6), onTimeout: () => false);
      } else {
        // No stored session — nothing to wait on.
        // ignore: unawaited_futures
        appState.restoreSession();
      }
    }
    // The full 114-surah parse no longer gates startup — kick it off and
    // let the shell rebuild against `quranRevision` when it lands (see
    // quran_seed.dart). The app opens on the 4-surah fallback immediately.
    // ignore: unawaited_futures
    loadFullQuran();
    // Same "don't block the splash on it" reasoning as loadFullQuran —
    // tajweed coloring is an opt-in reading aid (see Settings), not
    // something the app needs before it can open.
    // ignore: unawaited_futures
    loadTajweedData();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (signedInByGoogle) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    // Came back from the Google redirect but the session isn't confirmed
    // yet. Never drop the user on the login form here — that reads as
    // "sign-in failed" when it's usually just a slow network settling
    // after the redirect. Hold on this loading screen and keep checking
    // until the background restore flips `signedIn`, then continue home.
    if (WebNav.startedOnOAuthRedirect && !appState.signedIn) {
      final ok = await _waitForSignIn(const Duration(seconds: 8));
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }
    }
    Navigator.of(context).pushReplacementNamed(
      appState.signedIn ? '/home' : '/login',
    );
  }

  /// Polls `appState.signedIn` until it turns true or [budget] runs out.
  Future<bool> _waitForSignIn(Duration budget) async {
    final deadline = DateTime.now().add(budget);
    while (!appState.signedIn && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return appState.signedIn;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Wordmark(size: 84),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (_finishingSignIn) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'در حال ورود…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
