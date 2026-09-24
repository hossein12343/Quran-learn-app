import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../motion/motion.dart';
import '../theme/app_theme.dart';

/// A single circular node on a winding lesson trail.
class PathNode extends StatefulWidget {
  final double size;
  final Color face;
  final Color shadow;
  final Widget icon;
  final VoidCallback onTap;

  const PathNode({
    super.key,
    required this.size,
    required this.face,
    required this.shadow,
    required this.icon,
    required this.onTap,
  });

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode> {
  static const double _depth = 7;

  @override
  Widget build(BuildContext context) =>
      PressDetector(onTap: widget.onTap, builder: _build);

  Widget _build(BuildContext context, bool down, bool hover) {
    final hovering = hover && !down;
    return AnimatedContainer(
      duration: Motion.release,
      curve: Motion.spring,
      transform: Matrix4.translationValues(0, hovering ? -2 : 0, 0),
      transformAlignment: Alignment.center,
      child: SizedBox(
        width: widget.size,
        height: widget.size + _depth,
        child: Stack(
          children: [
            Positioned(
              top: _depth,
              left: 0,
              right: 0,
              height: widget.size,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: widget.shadow),
              ),
            ),
            AnimatedPositioned(
              duration: down ? Motion.press : const Duration(milliseconds: 180),
              curve: down ? Curves.easeOut : Motion.smooth,
              top: down ? _depth : 0,
              left: 0,
              right: 0,
              height: widget.size,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: widget.face),
                child: Center(child: widget.icon),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bouncing "START" pill Duolingo shows above the next lesson.
class StartBadge extends StatefulWidget {
  const StartBadge({super.key});

  @override
  State<StartBadge> createState() => _StartBadgeState();
}

class _StartBadgeState extends State<StartBadge>
    with SingleTickerProviderStateMixin {
  /// Two quick hops every few seconds rather than bouncing nonstop: any
  /// running animation makes Flutter on the web redraw the whole screen
  /// every frame, so a badge bouncing forever kept the Learn tab redrawing
  /// continuously, which is what made it stutter on a phone.
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _hop();
  }

  void _hop() {
    _c.forward(from: 0);
    _next = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) _hop();
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        // Two hops per run: |sin| over two half-periods.
        offset: Offset(0, -5 * math.sin(_c.value * 2 * math.pi).abs()),
        child: child,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          border: Border.all(color: context.borderColor, width: 2),
        ),
        child: const Text(
          'شروع',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
