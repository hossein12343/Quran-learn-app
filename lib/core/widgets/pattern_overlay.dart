import 'dart:math';
import 'package:flutter/material.dart';

/// A faint scatter of small stars over a gradient surface — texture for
/// the hero cards (level, profile header) that would otherwise be a flat
/// wash of one colour. Deterministic (fixed seed) so it doesn't shift
/// between rebuilds.
class StarField extends StatelessWidget {
  final double opacity;
  const StarField({super.key, this.opacity = 0.14});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _StarFieldPainter(opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final double opacity;
  _StarFieldPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    for (var i = 0; i < 22; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 1.5 + rng.nextDouble() * 2.5;
      _star(canvas, Offset(cx, cy), r, paint);
    }
  }

  void _star(Canvas canvas, Offset center, double r, Paint paint) {
    const points = 4;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = (pi / points) * i;
      final radius = i.isEven ? r : r * 0.4;
      final p = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
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
  bool shouldRepaint(covariant _StarFieldPainter old) => false;
}
