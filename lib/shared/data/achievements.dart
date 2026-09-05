import 'package:flutter/material.dart';
import '../services/app_state.dart';

/// Purely derived from AppState — nothing is stored, so there is no table
/// to seed and no way to unlock one by editing local data, since the
/// criteria are recomputed from the same numbers the rest of the app
/// already trusts (XP, streak, seals).
class Achievement {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(AppState s) unlocked;

  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}

final List<Achievement> achievements = <Achievement>[
  Achievement(
    key: 'first_ayah',
    title: 'اولین آیه',
    description: 'اولین آیه خود را در حافظه نگه دارید.',
    icon: Icons.auto_stories_rounded,
    unlocked: (s) => s.ayatHeld >= 1,
  ),
  Achievement(
    key: 'first_seal',
    title: 'اولین مهر',
    description: 'دروازه پایانی یک سوره را رد کنید.',
    icon: Icons.auto_awesome,
    unlocked: (s) => s.sealed.isNotEmpty,
  ),
  Achievement(
    key: 'ten_ayat',
    title: 'ده آیه',
    description: 'ده آیه از هر سوره‌ای را حفظ کنید.',
    icon: Icons.stacked_line_chart_rounded,
    unlocked: (s) => s.ayatHeld >= 10,
  ),
  Achievement(
    key: 'level_5',
    title: 'سطح ۵',
    description: 'به سطح ۵ برسید.',
    icon: Icons.bolt_rounded,
    unlocked: (s) => s.level >= 5,
  ),
  Achievement(
    key: 'streak_3',
    title: 'روند سه‌روزه',
    description: 'یک روند سه‌روزه را زنده نگه دارید.',
    icon: Icons.local_fire_department_rounded,
    unlocked: (s) => s.currentStreak >= 3,
  ),
  Achievement(
    key: 'streak_7',
    title: 'یک هفته کامل',
    description: 'یک روند هفت‌روزه را زنده نگه دارید.',
    icon: Icons.local_fire_department_rounded,
    unlocked: (s) => s.currentStreak >= 7,
  ),
  Achievement(
    key: 'all_seeded',
    title: 'همه سوره‌های اولیه',
    description: 'سوره‌های الفاتحه، الإخلاص، الفلق و الناس را مهر و موم کنید.',
    icon: Icons.workspace_premium_rounded,
    unlocked: (s) => s.sealed.length >= 4,
  ),
  Achievement(
    key: 'bookworm',
    title: 'خواننده نشان‌گذار',
    description: 'پنج آیه را برای مراجعه بعدی ذخیره کنید.',
    icon: Icons.bookmark_rounded,
    unlocked: (s) => s.bookmarks.length >= 5,
  ),
];
