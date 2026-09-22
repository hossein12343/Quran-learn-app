import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/platform_info.dart';
import '../home/home_page.dart';
import '../learn/learn_page.dart';
import '../practice/practice_page.dart';
import '../quran/quran_page.dart';
import '../progress/progress_page.dart';
import '../profile/profile_page.dart';

/// Six tabs. IndexedStack keeps each tab's scroll position, which a plain
/// switch would throw away. Icon + small label nav with a coloured top
/// indicator bar. (Was icon-only for a while, matching Duolingo's bar —
/// reverted back to labelled: six lookalike outline icons (compass,
/// insights, school cap, ...) aren't self-explanatory on their own, and
/// the label was already being computed and simply not shown.)
///
/// Learn vs Practice is a deliberate split, not a naming quirk: Learn stays
/// the strict locked/sequential path; Practice is "any surah, any level,
/// no order, no locks" — see practice_page.dart's doc comment.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  /// True while the glass nav bar is shrunk to its compact, icon-only
  /// state — real iOS 26 tab bars "shrink to bring focus to the
  /// content while keeping navigation instantly accessible" while
  /// scrolling down, then "fluidly expand" back on scrolling up (both
  /// quoted from Apple's own Liquid Glass announcement). Driven by
  /// [UserScrollNotification], which only fires on an actual direction
  /// change, not every scroll frame — cheap to listen to, unlike the
  /// live blur this whole nav bar deliberately avoids elsewhere.
  bool _navCollapsed = false;

  /// True while a mouse cursor is over the floating glass dock — desktop
  /// browsers only (touch has no hover), gives the dock a real lift/scale
  /// response the way a cursor approaching the macOS/iPadOS Dock does,
  /// reinforcing that it's a separate floating layer and not part of the
  /// page underneath it.
  bool _dockHovering = false;

  /// Every tab keeps its place in the `IndexedStack` once opened — that's
  /// what actually preserves scroll position, matching the class doc
  /// comment above — but a tab never opened this app-open is built as a
  /// cheap placeholder instead of the real page. Without this, reaching
  /// MainShell for the first time (every sign-in) built all six tabs —
  /// Learn, Practice, Quran, Progress, and Profile included — before a
  /// single frame ever showed anything but Home.
  final Set<int> _opened = {0};

  static const _items = <_NavItem>[
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'خانه'),
    _NavItem(Icons.school_rounded, Icons.school_outlined, 'یادگیری'),
    _NavItem(Icons.explore_rounded, Icons.explore_outlined, 'تمرین'),
    _NavItem(Icons.menu_book_rounded, Icons.menu_book_outlined, 'قرآن'),
    _NavItem(Icons.insights_rounded, Icons.insights_outlined, 'پیشرفت'),
    _NavItem(Icons.person_rounded, Icons.person_outline, 'پروفایل'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          // On iPhone the dock is its own floating layer over the content,
          // not a strip the content stops short of — extendBody is
          // Scaffold's own mechanism for letting body draw underneath
          // bottomNavigationBar instead of reserving space for it. That's
          // what actually lets real content scroll behind the dock and
          // show through its glass, instead of the blur just sampling a
          // flat edge. The flat (non-iPhone) bar keeps the old, simpler
          // layout — it was never meant to float.
          extendBody: isIPhone,
          body: NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              if (!isIPhone) return false;
              final collapse = n.direction == ScrollDirection.reverse;
              final expand = n.direction == ScrollDirection.forward;
              if (collapse && !_navCollapsed) {
                setState(() => _navCollapsed = true);
              } else if (expand && _navCollapsed) {
                setState(() => _navCollapsed = false);
              }
              return false;
            },
            child: IndexedStack(
              index: _index,
              children: [
                _opened.contains(0)
                    ? HomePage(onGoToLearn: () => _goTo(1))
                    : const SizedBox.shrink(),
                _opened.contains(1)
                    ? const LearnPage()
                    : const SizedBox.shrink(),
                _opened.contains(2)
                    ? const PracticePage()
                    : const SizedBox.shrink(),
                _opened.contains(3)
                    ? const QuranPage()
                    : const SizedBox.shrink(),
                _opened.contains(4)
                    ? const ProgressPage()
                    : const SizedBox.shrink(),
                _opened.contains(5)
                    ? const ProfilePage()
                    : const SizedBox.shrink(),
              ],
            ),
          ),
          bottomNavigationBar:
              isIPhone ? _glassNavBar(context) : _flatNavBar(context),
        );
      },
    );
  }

  /// The plain bar's indicator used to be static — each tab flipping its
  /// own top stripe on and off — replaced here with the same sliding,
  /// single-indicator approach as the glass bar below, just styled as a
  /// thin coloured bar instead of a translucent pill, matching this
  /// variant's existing flat look.
  Widget _flatNavBar(BuildContext context) {
    final lastIndex = _items.length - 1;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: context.borderColor, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              // `AlignmentDirectional`, not `Alignment` — this bar sits
              // inside the app's ambient `Directionality` (RTL for
              // Persian, the app's default), and `Row` below already
              // reorders its children for RTL on its own. `Alignment`'s
              // x is always *physical* left/right regardless of text
              // direction, so it would put this indicator on the
              // opposite side from the tab it's meant to sit under the
              // moment the app runs RTL — `AlignmentDirectional`'s
              // start/end follow the same reordering `Row` uses,
              // keeping the two in sync in either direction.
              alignment: AlignmentDirectional(_index / lastIndex * 2 - 1, -1),
              child: FractionallySizedBox(
                widthFactor: 1 / _items.length,
                child: Container(height: 3, color: AppColors.primary),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(child: _tab(i, _items[i], showBar: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Real "Liquid Glass" this time, not the gradient-only stand-in —
  /// but scoped specifically to dodge the reason that stand-in existed
  /// in the first place: a full-bleed `BackdropFilter` re-blurring every
  /// frame the content behind it changed was genuine, reported lag on
  /// Safari/CanvasKit. The blur here only ever runs while [_navCollapsed]
  /// is false — i.e. while the page *isn't* mid-scroll — because Flutter
  /// only re-renders a frame (blur included) when something on screen
  /// actually changes, and the one thing that changes constantly is the
  /// content scrolling behind this bar. The instant a scroll starts,
  /// [_navCollapsed] flips true and this swaps to the cheap tinted
  /// gradient below instead — same trick the rest of this bar already
  /// used, just now reserved for exactly the moment it's needed. A tab
  /// switch's own ~0.3s animation still repaints under real blur, but
  /// that's a short burst, not sustained scroll-driven cost.
  Widget _glassLayer(Color base) {
    if (_navCollapsed) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              base.withValues(alpha: 0.94),
              base.withValues(alpha: 0.78),
            ],
          ),
        ),
      );
    }
    return BackdropFilter(
      filter: ui.ImageFilter.compose(
        outer: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        // A standard saturation-boost color matrix (factor 1.35) — real
        // Liquid Glass doesn't just blur, it visibly *saturates* the
        // content showing through it. Without this the blur alone reads
        // as frosted plastic, not glass.
        inner: const ColorFilter.matrix(<double>[
          1.27545,
          -0.25025,
          -0.02520,
          0,
          0,
          -0.07455,
          1.09975,
          -0.02520,
          0,
          0,
          -0.07455,
          -0.25025,
          1.32480,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              base.withValues(alpha: 0.55),
              base.withValues(alpha: 0.30),
            ],
          ),
        ),
      ),
    );
  }

  /// The flat bar's static per-tab top stripe is replaced here with one
  /// glass "pill" that slides and morphs to the newly-selected tab —
  /// closer to how Apple's own tab bars (Music included) actually
  /// animate selection, rather than each tab independently flipping its
  /// own indicator on and off.
  ///
  /// Sized and spaced to read as a dock actually floating above the
  /// content — larger, more rounded, and held well clear of every
  /// screen edge — rather than a bar stuck flush to the bottom.
  Widget _glassNavBar(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    const radius = 36.0;
    final lastIndex = _items.length - 1;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(26, 0, 26, 30),
      child: MouseRegion(
        onEnter: (_) => setState(() => _dockHovering = true),
        onExit: (_) => setState(() => _dockHovering = false),
        child: AnimatedScale(
          // The lift itself: a cursor resting over the dock nudges it
          // very slightly toward the viewer, on top of the deeper shadow
          // below — the same "it's floating above you" cue a real macOS
          // Dock gives on approach, just subtler since this one holds
          // still rather than magnifying individual icons.
          scale: _dockHovering ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: _navCollapsed ? 54 : 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: _dockHovering ? 0.30 : 0.22),
                  blurRadius: _dockHovering ? 40 : 32,
                  offset: Offset(0, _dockHovering ? 20 : 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                children: [
                  Positioned.fill(child: _glassLayer(base)),
                  // A thin specular streak near the top edge — a cheap,
                  // static gradient, not a filter — is what actually sells
                  // "glass" over "tinted plastic": real glass catches a
                  // highlight along the edge nearest the light.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 1.4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    // `AlignmentDirectional`, not `Alignment` — see the flat
                    // bar's matching comment above; this pill has the exact
                    // same RTL bug fixed the same way.
                    alignment:
                        AlignmentDirectional(_index / lastIndex * 2 - 1, 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / _items.length,
                      heightFactor: 0.8,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius - 8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.30),
                                AppColors.primary.withValues(alpha: 0.12),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: _tab(i, _items[i],
                              showBar: false,
                              compact: _navCollapsed,
                              iconSize: 28),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goTo(int i) {
    setState(() {
      _index = i;
      _opened.add(i);
    });
  }

  Widget _tab(int i, _NavItem item,
      {bool showBar = true, bool compact = false, double iconSize = 25}) {
    final on = _index == i;
    final color = on ? AppColors.primary : context.mutedColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTo(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBar)
              Container(
                height: 3,
                color: on ? AppColors.primary : Colors.transparent,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: 4),
              child: AnimatedScale(
                scale: on ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(on ? item.active : item.inactive,
                        size: iconSize, color: color),
                    // Collapsed = icon-only, matching real iOS 26 tab
                    // bars shrinking to "keep navigation instantly
                    // accessible" while giving scrolled content more
                    // room — AnimatedSize keeps the label's own
                    // collapse smooth instead of an abrupt cut.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: compact
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        on ? FontWeight.w800 : FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData active;
  final IconData inactive;
  final String label;
  const _NavItem(this.active, this.inactive, this.label);
}
