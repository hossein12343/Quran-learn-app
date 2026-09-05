import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Duolingo's signature button: a flat coloured face sitting on top of a
/// darker "shadow" face of the same shape. At rest the shadow peeks out
/// [depth] pixels below; on press the face slides down to cover it, so the
/// button visibly sinks instead of using a blurred elevation shadow.
class DuoButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color? shadowColor;
  final Color textColor;
  final IconData? icon;
  final bool fullWidth;
  final double height;
  final double depth;
  final EdgeInsets? padding;

  const DuoButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.primary,
    this.shadowColor,
    this.textColor = AppColors.white,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
    this.depth = AppDepth.button,
    this.padding,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    // Disabled state used to fall back to hardcoded `AppColors.grey300`/
    // `grey400`/`grey500` — light-mode-only tones that stayed pale cream
    // even in dark mode, clashing with the dark surface around them. The
    // context-based `border`/`mutedColor` getters flip with the theme.
    final face = enabled ? widget.color : context.borderColor;
    final shadow = enabled
        ? (widget.shadowColor ?? _darken(widget.color))
        : context.mutedColor;
    final labelColor = enabled ? widget.textColor : context.mutedColor;

    final content = Padding(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: labelColor, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: labelColor,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      // `Stack`+`Positioned` was the original layout here, sized via
      // `IntrinsicWidth` for the non-fullWidth case — but a `Stack` never
      // contributes intrinsic width from children wrapped in `Positioned`
      // (regardless of which edges are set), so it always measured 0 and
      // `IntrinsicWidth` collapsed the whole button to nothing: invisible
      // and untappable. Confirmed live — this made the quiz page's
      // non-fullWidth "CHECK" button disappear on every drill exercise,
      // a real dead end with no way to submit an answer and proceed.
      // Fixed by dropping `Positioned` for plain `Padding`, which *does*
      // size the `Stack` correctly: the shadow layer carries an invisible
      // copy of the real content so both layers report the same natural
      // width, and the press animation moves via `AnimatedPadding`
      // instead of `AnimatedPositioned`.
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: EdgeInsets.only(top: widget.depth),
            child: SizedBox(
              width: widget.fullWidth ? double.infinity : null,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: shadow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child:
                    widget.fullWidth ? null : Opacity(opacity: 0, child: content),
              ),
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(top: _down ? widget.depth : 0),
            child: SizedBox(
              width: widget.fullWidth ? double.infinity : null,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }
}

/// A flat, thick-bordered tile used for answer choices and word-bank tiles.
/// Selection/correctness state is expressed with border + fill colour, in
/// keeping with Duolingo's answer tiles (depth is reserved for the primary
/// action button so it stays meaningful).
class DuoTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? fillColor;
  final EdgeInsetsGeometry padding;
  final bool stretch;

  const DuoTile({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.fillColor,
    this.padding = const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    this.stretch = false,
  });

  @override
  State<DuoTile> createState() => _DuoTileState();
}

class _DuoTileState extends State<DuoTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    // Both default to theme-aware colors rather than the old hardcoded
    // `AppColors.grey300`/`white` — those never adapted to dark mode, so
    // every plain tile stayed a stark white box with a pale-cream border
    // even on a dark surface. Callers can still force a specific colour
    // (e.g. sealed/selected states) by passing one explicitly.
    final fill = widget.fillColor ?? Theme.of(context).colorScheme.surface;
    final border = widget.borderColor ?? context.borderColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: widget.stretch ? double.infinity : null,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: border.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A pill badge — streak counters, XP, hearts. Bold fill, no border.
class DuoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const DuoBadge({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.streakFire,
    this.background = AppColors.goldLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.circular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
