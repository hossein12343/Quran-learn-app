import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// This app's answer to Duolingo's owl — deliberately a **star with a
/// small crescent moon companion**, not an animal or human character. A
/// religious-content app is the wrong place for an anthropomorphic
/// mascot with a personality of its own (a prior design pass explicitly
/// left one out for that reason); star-and-crescent is about as close as
/// a mascot gets to "in touch with" Islamic visual culture without
/// personifying anything religious itself — it's the same pairing on the
/// flags of most Muslim-majority countries, and the star half already
/// ties into the achievement/sealed-level star used throughout the app
/// (see `pattern_overlay.dart`'s `StarField`). Everything below is
/// hand-drawn (`CustomPaint` + `AnimationController`s) — no image/SVG
/// assets, matching how `Confetti`/`StarField` are already built in this
/// zero-pub.dev app.
///
/// Reaction cadence, matching Duolingo's actual rhythm: [happy] fires
/// after every correct exercise inside a lesson (small, frequent,
/// `core/widgets` callers should treat it as disposable — a fresh
/// `Mascot` per exercise is exactly right, see `quiz_page.dart._footer`),
/// while [cheering] is reserved for finishing a whole level/surah — it
/// plays a bigger spin-and-burst entrance so it actually reads as the
/// larger moment. Keeping that escalation is the point; don't fire
/// [cheering] for routine per-exercise feedback or it stops meaning
/// anything.
enum MascotMood { idle, happy, cheering, sad }

class Mascot extends StatefulWidget {
  final MascotMood mood;
  final double size;

  const Mascot({super.key, this.mood = MascotMood.idle, this.size = 72});

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat(reverse: true);
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  late final AnimationController _entrance = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: widget.mood == MascotMood.cheering ? 750 : 550));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final List<_Sparkle> _sparkles =
      List.generate(9, (_) => _Sparkle(math.Random()));
  Timer? _blinkTimer;

  bool get _celebratory =>
      widget.mood == MascotMood.cheering || widget.mood == MascotMood.happy;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    if (_celebratory) _burst.forward();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
        Duration(milliseconds: 2200 + math.Random().nextInt(2600)), () {
      if (!mounted) return;
      _blink.forward(from: 0).then((_) {
        if (mounted) _blink.reverse();
      });
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(covariant Mascot old) {
    super.didUpdateWidget(old);
    // A mood change is a little "reaction" — replay the pop-in so a fresh
    // expression actually reads as a response, not a silent swap.
    if (old.mood != widget.mood) {
      _entrance.duration =
          Duration(milliseconds: widget.mood == MascotMood.cheering ? 750 : 550);
      _entrance.forward(from: 0);
      if (_celebratory) _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _blink.dispose();
    _entrance.dispose();
    _burst.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final cheer = widget.mood == MascotMood.cheering;
    final bounce = cheer ? 9.0 : 3.5;
    final burstBox = widget.size * 2.6;
    // The widget's *reported* footprint stays exactly `size` × `size` —
    // every existing call site places this in a tight Row/Column (the
    // badge row, the START badge, ...) sized for the plain star, and
    // those must not silently grow just because a celebratory burst can
    // paint further out. `OverflowBox` lets the burst render past those
    // bounds purely visually, the way `Positioned` overflow would inside
    // a `Stack`, without telling the parent this widget got bigger.
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_celebratory && !reduced)
            OverflowBox(
              maxWidth: burstBox,
              maxHeight: burstBox,
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) => CustomPaint(
                  size: Size(burstBox, burstBox),
                  painter: _SparklePainter(
                      sparkles: _sparkles,
                      t: _burst.value,
                      big: cheer,
                      color: AppColors.gold),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: Listenable.merge([_bob, _entrance]),
            builder: (context, child) {
              final pop = reduced
                  ? 1.0
                  : Curves.elasticOut.transform(_entrance.value.clamp(0.0, 1.0));
              final spin = !reduced && cheer
                  ? (1 - Curves.easeOutCubic.transform(_entrance.value.clamp(0.0, 1.0))) *
                      math.pi *
                      2
                  : 0.0;
              final bob = reduced || widget.mood == MascotMood.sad
                  ? 0.0
                  : math.sin(_bob.value * math.pi) * bounce;
              final tilt = widget.mood == MascotMood.sad ? 0.05 : 0.0;
              return Transform.translate(
                offset: Offset(0, -bob + (widget.mood == MascotMood.sad ? 3 : 0)),
                child: Transform.rotate(
                  angle: tilt + spin,
                  child: Transform.scale(scale: pop, child: child),
                ),
              );
            },
            // `_bob` (the idle up/down float) repeats forever for as long
            // as this widget is mounted — and it stays mounted, animating,
            // even off-screen, since every tab lives inside `MainShell`'s
            // `IndexedStack` (`main_shell.dart`) rather than being torn
            // down. Without a `RepaintBoundary` here, every one of those
            // ticks re-runs `_MascotPainter.paint()` — a `Path.combine`
            // boolean op for the crescent plus a drop shadow, not free —
            // as part of repainting the whole `Transform` subtree above,
            // continuously, in the background, for the entire time a user
            // is elsewhere in the app (mid-quiz, say). `RepaintBoundary`
            // lets Flutter cache this subtree as its own compositor layer
            // that `Transform` can just reposition per frame instead of
            // re-painting — confirmed live this was a real, reproducible
            // cause of the app freezing for several seconds after a user
            // report (traced to accumulated allocation/GC pressure from
            // this exact loop, worse in the unoptimized debug/DDC build
            // `flutter run` serves). **How to apply**: any widget with a
            // perpetual `AnimationController` driving a `Transform` over
            // a non-trivial `CustomPaint` needs a `RepaintBoundary`
            // between them — this is that pattern, not a one-off.
            child: RepaintBoundary(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: AnimatedBuilder(
                  animation: _blink,
                  builder: (context, _) => CustomPaint(
                    painter: _MascotPainter(mood: widget.mood, blink: _blink.value),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A handful of tiny star/crescent bits that pop outward and fade —
/// the "cool animation" flourish behind a happy/cheering reaction.
/// Deliberately not `Confetti` (falling coloured rectangles, reserved for
/// the one big level/surah-seal moment) — this is a tighter, faster burst
/// centred on the mascot itself, sized down for [MascotMood.happy]'s
/// much more frequent per-exercise firing.
class _Sparkle {
  final double angle;
  final double distance;
  final double size;
  final bool star;
  _Sparkle(math.Random r)
      : angle = r.nextDouble() * math.pi * 2,
        distance = 0.7 + r.nextDouble() * 0.35,
        size = 3 + r.nextDouble() * 3,
        star = r.nextDouble() < 0.7;
}

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final double t;
  final bool big;
  final Color color;
  _SparklePainter(
      {required this.sparkles, required this.t, required this.big, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2 * (big ? 1.0 : 0.72);
    // Ease out then fade in the tail of the animation.
    final travel = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final opacity = (1 - t) * (t < 0.15 ? t / 0.15 : 1.0);
    if (opacity <= 0) return;
    for (final s in sparkles) {
      final dist = maxR * s.distance * travel;
      final pos = center +
          Offset(math.cos(s.angle) * dist, math.sin(s.angle) * dist);
      final paint = Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      final sz = s.size * (big ? 1.3 : 1.0);
      if (s.star) {
        _tinyStar(canvas, pos, sz, paint);
      } else {
        canvas.drawCircle(pos, sz * 0.55, paint);
      }
    }
  }

  void _tinyStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? r : r * 0.4;
      final angle = math.pi / 4 * i;
      final p = Offset(c.dx + radius * math.cos(angle), c.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}

class _MascotPainter extends CustomPainter {
  final MascotMood mood;
  final double blink;
  _MascotPainter({required this.mood, required this.blink});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // A small crescent moon tucked behind the star's upper-right point —
    // the star-and-crescent pairing, not a literal figurative character.
    final moonCenter = Offset(center.dx + r * 0.62, center.dy - r * 0.6);
    final moonR = r * 0.34;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonCenter, radius: moonR)),
      Path()
        ..addOval(Rect.fromCircle(
            center: Offset(moonCenter.dx + moonR * 0.55, moonCenter.dy - moonR * 0.32),
            radius: moonR * 0.86)),
    );
    canvas.drawPath(moon, Paint()..color = AppColors.gold);

    final body = _roundedStar(center, r * 0.98, r * 0.46, rounding: 0.30);
    // `canvas.drawShadow` (Skia's real ambient+spot shadow, `SkShadowUtils`)
    // is one of the most expensive single canvas calls there is — confirmed
    // live via frame-timing instrumentation as the actual cause of a user-
    // reported multi-second freeze: a single frame's *rasterization* (not
    // Dart logic — that measured under 1ms) took over 14 seconds right when
    // a fresh `Mascot` painted for the first time. A brand-new `Mascot`
    // mounts on every single quiz answer (`quiz_page.dart._footer`), so
    // this cost was being paid fresh, repeatedly, exactly when the
    // celebration panel appears. A blurred-paint shadow (`MaskFilter.blur`)
    // approximates the same soft drop-shadow look for a shape this small,
    // for a tiny fraction of the cost.
    canvas.drawPath(
      body.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    final bodyPaint = Paint()
      ..shader = AppGradients.gilt
          .createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(body, bodyPaint);

    // Soft highlight so the star reads as a rounded, friendly volume
    // rather than a flat cut-out.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawCircle(Offset(center.dx - r * 0.28, center.dy - r * 0.32),
        r * 0.55, Paint()..color = Colors.white.withValues(alpha: 0.16));
    canvas.restore();

    _face(canvas, center, r);
  }

  void _face(Canvas canvas, Offset center, double r) {
    final eyeY = center.dy - r * 0.05;
    final eyeDx = r * 0.30;
    final ink = AppColors.grey900;
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = r * 0.10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case MascotMood.sad:
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawLine(
            Offset(center.dx + dx - r * 0.09, eyeY - r * 0.04),
            Offset(center.dx + dx + r * 0.09, eyeY + r * 0.08),
            stroke,
          );
        }
        break;
      case MascotMood.happy:
      case MascotMood.cheering:
        for (final dx in [-eyeDx, eyeDx]) {
          final rect = Rect.fromCenter(
              center: Offset(center.dx + dx, eyeY + r * 0.05),
              width: r * 0.34,
              height: r * 0.34);
          canvas.drawArc(rect, math.pi * 0.12, math.pi * 0.76, false, stroke);
        }
        break;
      case MascotMood.idle:
        final h = math.max(1.6, r * 0.22 * (1 - blink));
        final eyePaint = Paint()..color = ink;
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(center.dx + dx, eyeY), width: r * 0.19, height: h),
            eyePaint,
          );
        }
        break;
    }

    final mouthY = center.dy + r * 0.32;
    final mouthStroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case MascotMood.cheering:
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(center.dx, mouthY - r * 0.08),
              width: r * 0.5,
              height: r * 0.4),
          0.2,
          math.pi - 0.4,
          false,
          mouthStroke..strokeWidth = r * 0.11,
        );
        break;
      case MascotMood.happy:
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(center.dx, mouthY - r * 0.1),
              width: r * 0.42,
              height: r * 0.3),
          0.3,
          math.pi - 0.6,
          false,
          mouthStroke..strokeWidth = r * 0.095,
        );
        break;
      case MascotMood.sad:
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(center.dx, mouthY + r * 0.16),
              width: r * 0.36,
              height: r * 0.26),
          math.pi + 0.3,
          math.pi - 0.6,
          false,
          mouthStroke..strokeWidth = r * 0.095,
        );
        break;
      case MascotMood.idle:
        canvas.drawLine(
          Offset(center.dx - r * 0.11, mouthY),
          Offset(center.dx + r * 0.11, mouthY),
          mouthStroke..strokeWidth = r * 0.09,
        );
        break;
    }
  }

  /// A 5-point star with each vertex softened by a quadratic curve — a
  /// plain sharp-pointed star reads as an icon, not a character; rounding
  /// the tips just enough keeps it recognisably a star while feeling soft
  /// and friendly.
  Path _roundedStar(Offset center, double outerR, double innerR,
      {double rounding = 0}) {
    const points = 5;
    final verts = <Offset>[];
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerR : innerR;
      final angle = (math.pi / points) * i - math.pi / 2;
      verts.add(Offset(center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle)));
    }
    final path = Path();
    final n = verts.length;
    for (var i = 0; i < n; i++) {
      final prev = verts[(i - 1 + n) % n];
      final curr = verts[i];
      final next = verts[(i + 1) % n];
      final start = Offset.lerp(curr, prev, rounding)!;
      final end = Offset.lerp(curr, next, rounding)!;
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.mood != mood || old.blink != blink;
}
