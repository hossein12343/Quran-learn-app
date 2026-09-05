import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_state.dart';
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
          body: IndexedStack(
            index: _index,
            children: [
              HomePage(onGoToLearn: () => setState(() => _index = 1)),
              const LearnPage(),
              const PracticePage(),
              const QuranPage(),
              const ProgressPage(),
              const ProfilePage(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: context.borderColor, width: 2),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(child: _tab(i, _items[i])),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tab(int i, _NavItem item) {
    final on = _index == i;
    final color = on ? AppColors.primary : context.mutedColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
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
