import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A short burst of falling coloured pieces — the one purely celebratory
/// moment in the app, reserved for sealing a level or a surah so it stays
/// meaningful. Plays once when [play] turns true; toggling it back to
/// false and true again replays it.
class Confetti extends StatefulWidget {
  final bool play;
  const Confetti({super.key, required this.play});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));
  late final List<_Particle> _particles =
      List.generate(42, (_) => _Particle(Random()));

  @override
  void initState() {
    super.initState();
    if (widget.play) _c.forward();
  }

  @override
  void didUpdateWidget(covariant Confetti old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_particles, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  final double x0;
  final double vx;
  final double delay;
  final double size;
  final double rotSpeed;
  final Color color;

  _Particle(Random r)
      : x0 = r.nextDouble(),
        vx = (r.nextDouble() - 0.5) * 0.5,
        delay = r.nextDouble() * 0.25,
        size = 6 + r.nextDouble() * 7,
        rotSpeed = (r.nextDouble() - 0.5) * 12,
        color = const [
          AppColors.primary,
          AppColors.blue,
          AppColors.gold,
          AppColors.red,
          AppColors.purple,
        ][r.nextInt(5)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = localT * size.height * 1.05;
      final x = p.x0 * size.width + p.vx * size.width * localT;
      final opacity = (1 - localT * localT).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotSpeed * localT);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
