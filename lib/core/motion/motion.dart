import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

bool _reduced(BuildContext c) =>
    MediaQuery.maybeOf(c)?.disableAnimations ?? false;

/// Content fades and rises as it enters the viewport. Lists build their
/// children lazily, so placing this inside a builder fires it on scroll.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double distance;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.distance = 26,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(
      Duration(milliseconds: 60 * (widget.index % 7)),
      () {
        if (mounted) _c.forward();
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, widget.distance * (1 - a.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Every tappable surface compresses slightly. One tactile signature,
/// defined once, applied everywhere.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.965,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
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
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
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
    final resolvedTrack = track ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
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
