import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

bool _reduced(BuildContext c) =>
    MediaQuery.maybeOf(c)?.disableAnimations ?? false;

/// The app's shared timing. Short, front-loaded motion that settles softly,
/// the way current iOS reads, rather than long uniform ease-outs.
abstract final class Motion {
  static const press = Duration(milliseconds: 70);
  static const release = Duration(milliseconds: 260);
  static const enter = Duration(milliseconds: 340);

  /// Apple's standard easing: moves most of the way almost at once, then
  /// takes its time on the last few pixels.
  static const smooth = Cubic(0.32, 0.72, 0, 1);

  /// Settles with a small overshoot, like a stiff spring. Only for values
  /// that can safely overshoot (scale), never for padding or sizes.
  static const spring = Cubic(0.34, 1.45, 0.64, 1);
}

/// Content fades, rises and firms up as a screen opens.
///
/// Only when the screen opens: a row built because the user is scrolling
/// shows up immediately, like a native list. Lazily-built list rows used to
/// each float in over half a second while you scrolled.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double distance;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.distance = 12,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.enter);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Motion.smooth);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final scrolling = context
            .findAncestorStateOfType<ScrollableState>()
            ?.position
            .isScrollingNotifier
            .value ??
        false;
    if (scrolling) {
      _c.value = 1;
      return;
    }
    _delay = Timer(
      Duration(milliseconds: 30 * math.min(widget.index, 6)),
      () {
        if (mounted) _c.forward();
      },
    );
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) {
          final t = 1 - _a.value;
          return Transform.translate(
            offset: Offset(0, widget.distance * t),
            child: Transform.scale(scale: 1 - 0.03 * t, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Tracks press and hover for any tappable surface and hands them to
/// [builder].
///
/// The pressed state comes from raw pointer events, so it shows the instant
/// a finger lands. `GestureDetector.onTapDown` holds that back for up to
/// 100ms inside anything scrollable, in case the touch becomes a scroll,
/// and on a quick tap it fires down and up in the same frame, so the press
/// never visibly happened. The tap action itself still goes through
/// [GestureDetector.onTap], so a drag that turns into a scroll never
/// triggers it.
class PressDetector extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool pressed, bool hovered)
      builder;

  const PressDetector({super.key, required this.onTap, required this.builder});

  @override
  State<PressDetector> createState() => _PressDetectorState();
}

class _PressDetectorState extends State<PressDetector> {
  /// Long enough that even a very quick tap visibly presses in.
  static const _minPress = Duration(milliseconds: 90);

  bool _pressed = false;
  bool _hovered = false;
  Offset? _origin;
  final _held = Stopwatch();
  Timer? _release;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  void _down(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryMouseButton) {
      return;
    }
    _release?.cancel();
    _origin = e.position;
    _held
      ..reset()
      ..start();
    _setPressed(true);
  }

  void _move(PointerMoveEvent e) {
    final origin = _origin;
    if (origin != null && (e.position - origin).distance > kTouchSlop) _up();
  }

  void _up([PointerEvent? _]) {
    if (_origin == null) return;
    _origin = null;
    final remaining = _minPress - _held.elapsed;
    if (remaining > Duration.zero) {
      _release = Timer(remaining, () => _setPressed(false));
    } else {
      _setPressed(false);
    }
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: on ? (_) => setState(() => _hovered = true) : null,
      onExit: on ? (_) => setState(() => _hovered = false) : null,
      child: Listener(
        onPointerDown: on ? _down : null,
        onPointerMove: on ? _move : null,
        onPointerUp: on ? _up : null,
        onPointerCancel: on ? _up : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: widget.builder(context, on && _pressed, on && _hovered),
        ),
      ),
    );
  }
}

/// Every tappable surface compresses the moment it's touched, springs back
/// on release, and lifts a touch under a mouse cursor. One tactile
/// signature, defined once, applied everywhere.
class Pressable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// An accessible name for a screen reader, for the common case where
  /// [child] is a bare icon with no readable text of its own (unlike
  /// `IconButton`, which gets this for free from its own `tooltip`
  /// param, `Pressable` has no such built-in — every icon-only call
  /// site needs to pass this explicitly). Leave null when [child]
  /// already contains real text (a labeled button, a card with a
  /// title) — wrapping that in another label would just duplicate
  /// what a screen reader already announces from the text itself.
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = PressDetector(
      onTap: onTap,
      builder: (context, pressed, hovered) => AnimatedScale(
        scale: pressed ? scale : (hovered ? 1.012 : 1.0),
        duration: pressed ? Motion.press : Motion.release,
        curve: pressed ? Curves.easeOut : Motion.spring,
        child: child,
      ),
    );
    if (semanticLabel != null) {
      result = Semantics(
        button: true,
        label: semanticLabel,
        child: ExcludeSemantics(child: result),
      );
    }
    return result;
  }
}

/// Shake. Reserved for a rejected answer.
class Shaker extends StatefulWidget {
  final Widget child;
  final int trigger;

  const Shaker({super.key, required this.child, required this.trigger});

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(covariant Shaker old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger > 0) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Numerals roll rather than snap.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const CountUp({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Motion.smooth,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// Circular progress used on the daily goal and on each surah node.
class ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 56,
    this.stroke = 5,
    this.color = AppColors.primary,
    this.track,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    // Defaults to a theme-aware neutral rather than the old hardcoded
    // `AppColors.grey200` — that stayed near-white even in dark mode,
    // showing as a stark pale ring on a dark card. Callers that sit on a
    // saturated background (e.g. the hero level card) still pass their
    // own `track` (`Colors.white24`) and are unaffected.
    final resolvedTrack =
        track ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Motion.smooth,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, stroke, color, resolvedTrack),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Color color;
  final Color track;

  _RingPainter(this.progress, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// A gold sweep across text. The single celebratory moment in the app —
/// it fires when an ayah is committed to memory and nowhere else.
class GoldSweep extends StatefulWidget {
  final Widget child;
  final bool active;

  const GoldSweep({super.key, required this.child, required this.active});

  @override
  State<GoldSweep> createState() => _GoldSweepState();
}

class _GoldSweepState extends State<GoldSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void didUpdateWidget(covariant GoldSweep old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (_c.value == 0 || _c.value == 1) return child!;
        final t = _c.value * 2 - 0.5;
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: const [
              AppColors.primary,
              AppColors.secondary,
              AppColors.primary,
            ],
            stops: [
              (t - 0.25).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Header that drifts and fades as content scrolls over it.
class Parallax extends StatelessWidget {
  final double offset;
  final Widget child;

  const Parallax({super.key, required this.offset, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = (offset / 150).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -offset * 0.32),
      child: Opacity(opacity: 1 - t * 0.9, child: child),
    );
  }
}
