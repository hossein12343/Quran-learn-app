import 'package:flutter/widgets.dart';

class GlassDockItem {
  final IconData icon;
  final String label;
  const GlassDockItem(this.icon, this.label);
}

/// The iPhone tab bar, drawn by the browser as a real HTML element layered
/// over the Flutter canvas instead of by Flutter itself.
///
/// Real Liquid Glass needs a live blur of whatever is behind the bar. Done
/// inside Flutter (`BackdropFilter`), CanvasKit has to re-read and re-blur
/// its own framebuffer on every frame the content moves — shipped twice,
/// reported as real lag on a real iPhone both times. CSS `backdrop-filter`
/// on a separate element is composited by Safari itself, through the same
/// Core Animation backdrop layers native iOS blur uses, so Flutter pays
/// nothing for it at all.
///
/// Real on web: `glass_dock_impl/glass_dock_factory_web.dart`. Off-web,
/// [NoGlassDock] makes every call a no-op.
abstract class GlassDock {
  /// Pushes the dock's whole current state. Implementations diff against
  /// the previous call and only touch what changed, so this is safe to
  /// call from every rebuild.
  void update({
    required List<GlassDockItem> items,
    required int selected,
    required bool visible,
    required bool compact,
    required bool dark,
    required bool rtl,
    required ValueChanged<int> onTap,
  });

  /// Hides it outright — for when the screen that owns it goes away
  /// entirely (e.g. signing out), not just when something covers it.
  void hide();
}

class NoGlassDock implements GlassDock {
  @override
  void update({
    required List<GlassDockItem> items,
    required int selected,
    required bool visible,
    required bool compact,
    required bool dark,
    required bool rtl,
    required ValueChanged<int> onTap,
  }) {}

  @override
  void hide() {}
}

GlassDock glassDock = NoGlassDock();
