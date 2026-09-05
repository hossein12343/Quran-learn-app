import 'package:flutter/material.dart';
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
  bool _down = false;
  static const double _depth = 7;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
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
              duration: const Duration(milliseconds: 80),
              top: _down ? _depth : 0,
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
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 * _c.value),
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
