import 'package:flutter/material.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
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
  @override
  void initState() {
    super.initState();
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
      // restoreSession() applies whatever is cached on this device
      // synchronously (before its first `await`), so appState.signedIn is
      // already correct by the time this line runs; the slower reconcile
      // with the backend keeps going in the background.
      // ignore: unawaited_futures
      appState.restoreSession();
    }
    await Future.wait([
      loadFullQuran(),
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]);
    if (!mounted) return;
    if (signedInByGoogle) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      appState.signedIn ? '/home' : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Wordmark(size: 84)),
    );
  }
}
