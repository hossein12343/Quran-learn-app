import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const _rtlLanguages = {'fa', 'ar', 'he', 'ur', 'ps', 'ckb', 'ku', 'sd', 'yi'};

/// Which way pages slide and swipe back: the phone's own direction, not
/// the app's. The app is Persian (right-to-left), but it runs inside
/// Safari, whose own back swipe follows the phone's language — on an
/// English iPhone, in from the left edge, moving right. When the app slid
/// the other way, the swipe people reached for was Safari's, which goes
/// back through browser history instead of the app.
TextDirection navigationDirection() {
  final lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return _rtlLanguages.contains(lang) ? TextDirection.rtl : TextDirection.ltr;
}

/// Page motion runs in [navigationDirection]; the page itself keeps the
/// app's own layout direction.
Widget _inNavigationDirection(BuildContext context,
    Widget Function(Widget content) motion, Widget content) {
  final appDirection = Directionality.of(context);
  return Directionality(
    textDirection: navigationDirection(),
    child: motion(Directionality(textDirection: appDirection, child: content)),
  );
}

/// The iOS page slide on every platform, plus a swipe-back that works from
/// anywhere on the page (as in iOS 26), not only from a thin strip at the
/// screen edge.
///
/// Flutter's own back swipe only listens within 20px of the edge, which is
/// especially bad on the web: in Safari the left edge belongs to the
/// browser's own back swipe.
class SwipeBackPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const SwipeBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _inNavigationDirection(
      context,
      (content) => super.buildTransitions<T>(route, context, animation,
          secondaryAnimation, _SwipeBack<T>(route: route, child: content)),
      child,
    );
  }
}

/// Switching between top-level screens (splash, sign-in, onboarding, the
/// main tabs): a short cross-fade that settles in from a hair smaller, the
/// way an iPhone app moves from its launch screen to its first screen. A
/// sideways slide says "you went one level deeper", which these aren't —
/// it's what made landing on Home after Google sign-in look off.
///
/// Built on [MaterialPageRoute] on purpose. The first version used a plain
/// `PageRouteBuilder`, and with it the screen underneath a page never got
/// drawn during a swipe-back: dragging a page off Home showed blank white
/// where Home should be (measured: 77% of the uncovered area, against 1%
/// with a MaterialPageRoute). Only this route's own arrival is replaced;
/// everything that happens while a page sits on top of it stays standard.
class RootRoute<T> extends MaterialPageRoute<T> {
  RootRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
        parent: animation, curve: const Cubic(0.32, 0.72, 0, 1));
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
        // The standard transition, with this screen already fully in place:
        // when a page opens on top, this one still drifts aside underneath
        // it the iOS way and follows the finger on swipe-back.
        child: super.buildTransitions(
            context, kAlwaysCompleteAnimation, secondaryAnimation, child),
      ),
    );
  }
}

class _SwipeBack<T> extends StatefulWidget {
  final PageRoute<T> route;
  final Widget child;

  const _SwipeBack({super.key, required this.route, required this.child});

  @override
  State<_SwipeBack<T>> createState() => _SwipeBackState<T>();
}

class _SwipeBackState<T> extends State<_SwipeBack<T>> {
  // Same release behaviour as Flutter's edge swipe (cupertino/route.dart):
  // a flick of at least one screen width per second decides on its own,
  // otherwise it pops if dragged past halfway.
  static const _minFlingVelocity = 1.0;
  static const _settleDuration = Duration(milliseconds: 350);

  late final HorizontalDragGestureRecognizer _drag =
      HorizontalDragGestureRecognizer(
    debugOwner: this,
    // Touch only: on a computer, dragging with the mouse is how you select
    // text, not how you go back.
    supportedDevices: const {PointerDeviceKind.touch},
  )
        ..onUpdate = _update
        ..onEnd = _end
        ..onCancel = _cancel;

  /// Null until the first movement shows which way the finger is going.
  /// Only a drag in the "back" direction takes over the page; a drag the
  /// other way is ignored.
  bool? _backwards;

  // Driving the route's own transition by hand is exactly what Flutter's
  // edge swipe does; that controller just isn't exposed outside a route
  // subclass. Doing it here means every MaterialPageRoute in the app gets
  // the gesture through the theme, instead of swapping 30-odd call sites
  // over to a custom route class.
  // ignore: invalid_use_of_protected_member
  AnimationController get _controller => widget.route.controller!;

  double get _dir =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  void _pointerDown(PointerDownEvent e) {
    if (widget.route.popGestureEnabled) _drag.addPointer(e);
  }

  void _update(DragUpdateDetails d) {
    final delta = d.primaryDelta! * _dir;
    if (_backwards == null) {
      _backwards = delta > 0;
      if (_backwards!) widget.route.navigator!.didStartUserGesture();
    }
    if (!_backwards!) return;
    _controller.value -= delta / context.size!.width;
  }

  void _end(DragEndDetails d) {
    final backwards = _backwards;
    _backwards = null;
    if (backwards != true) return;
    final velocity = d.velocity.pixelsPerSecond.dx * _dir / context.size!.width;
    _settle(velocity);
  }

  void _cancel() {
    final backwards = _backwards;
    _backwards = null;
    if (backwards == true) _settle(0);
  }

  void _settle(double velocity) {
    final navigator = widget.route.navigator!;
    final controller = _controller;
    const curve = Curves.fastEaseInToSlowEaseOut;
    final bool stay;
    if (!widget.route.isCurrent) {
      stay = widget.route.isActive;
    } else if (velocity.abs() >= _minFlingVelocity) {
      stay = velocity <= 0;
    } else {
      stay = controller.value > 0.5;
    }
    if (stay) {
      controller.animateTo(1, duration: _settleDuration, curve: curve);
    } else {
      if (widget.route.isCurrent) navigator.pop();
      if (controller.isAnimating) {
        controller.animateBack(0, duration: _settleDuration, curve: curve);
      }
    }
    if (controller.isAnimating) {
      // The transition stays linear (finger-following) until it lands.
      late AnimationStatusListener done;
      done = (_) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(done);
      };
      controller.addStatusListener(done);
    } else {
      navigator.didStopUserGesture();
    }
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _pointerDown,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
