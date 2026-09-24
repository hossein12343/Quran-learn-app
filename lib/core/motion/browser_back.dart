import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The app's one navigator, so the browser's back can reach it.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Makes Safari's own back — its back button, or its swipe in from the
/// left screen edge — feel like a normal browser back.
///
/// Safari's swipe has already slid the page away (over an old snapshot)
/// by the time the app hears about it. Letting the navigator pop normally
/// then played a second, half-second slide after it, while Safari kept
/// showing its snapshot — and on the main screen, where nothing pops,
/// nothing redrew at all, so the snapshot could sit there. That was the
/// "swiping back takes forever to load, sometimes never" report.
///
/// So: close the top page at once, then force a fresh frame so Safari
/// swaps its snapshot for the real screen immediately. Anything that
/// guards its own back (the quiz's "leave?" dialog, the main screen
/// switching to Home) still gets the normal handling.
///
/// Registered in `main()` before `runApp`, so it runs before the
/// navigator's own back handling.
class BrowserBackHandler with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;

  BrowserBackHandler(this.navigatorKey);

  @override
  Future<bool> didPopRoute() async {
    final nav = navigatorKey.currentState;
    if (nav == null) return false;
    Route<dynamic>? top;
    nav.popUntil((route) {
      top = route;
      return true; // Stops at the top route without popping anything.
    });
    final route = top;
    if (route == null ||
        route.isFirst ||
        route.willHandlePopInternally ||
        route.popDisposition == RoutePopDisposition.doNotPop) {
      await nav.maybePop();
    } else {
      nav.removeRoute(route);
    }
    SchedulerBinding.instance.scheduleForcedFrame();
    // Always handled: never let a back leave the app for whatever site
    // was open before it (after Google sign-in, that's Google's own page).
    return true;
  }
}
