import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/glass_dock.dart';
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
/// On iPhone the bar is instead a floating Liquid Glass dock drawn by the
/// browser, not by Flutter — see [GlassDock] for why.
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

  /// True while the iPhone dock is minimised. iOS 26 tab bars fold into a
  /// single bubble holding just the current tab while you scroll down,
  /// and expand again when you scroll back up or tap the bubble. Driven by
  /// [UserScrollNotification], which only fires on an actual direction
  /// change, not every scroll frame.
  bool _navCollapsed = false;

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

  static final _dockItems = [
    for (final item in _items) GlassDockItem(item.active, item.label),
  ];

  /// The dock's height plus its gap above the screen edge. Must match
  /// `.ql-dock`'s `height` and `bottom` in `glass_dock_factory_web.dart`.
  static const _dockFootprint = 64.0 + 21.0;

  @override
  void dispose() {
    glassDock.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (isIPhone) _syncDock(context);
        return Scaffold(
          // Lets the pages run all the way down behind the floating dock,
          // which is what its glass then blurs.
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
          bottomNavigationBar: isIPhone
              // Paints nothing — only reserves the dock's footprint so
              // SnackBars and FABs still land above it.
              ? const SafeArea(
                  top: false,
                  child: SizedBox(height: _dockFootprint),
                )
              : _flatNavBar(context),
        );
      },
    );
  }

  void _syncDock(BuildContext context) {
    glassDock.update(
      items: _dockItems,
      selected: _index,
      // The dock sits above the entire Flutter canvas, so left alone it
      // would cover dialogs, sheets, popup menus and every pushed page.
      // All of those are routes, so "this route is the top one" is exactly
      // when it should be showing.
      visible: ModalRoute.of(context)?.isCurrent ?? true,
      compact: _navCollapsed,
      dark: appState.darkMode,
      rtl: Directionality.of(context) == TextDirection.rtl,
      onTap: _goTo,
    );
  }

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
                  Expanded(child: _tab(i, _items[i])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _goTo(int i) {
    setState(() {
      _index = i;
      _opened.add(i);
      // Tapping the minimised bubble is how you get the full dock back.
      _navCollapsed = false;
    });
  }

  Widget _tab(int i, _NavItem item) {
    final on = _index == i;
    final color = on ? AppColors.primary : context.mutedColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTo(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: 4),
          child: AnimatedScale(
            scale: on ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(on ? item.active : item.inactive, size: 25, color: color),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
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
