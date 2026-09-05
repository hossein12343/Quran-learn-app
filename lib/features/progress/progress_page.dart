import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/achievements.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import 'achievements_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final accuracy = appState.quizzesTaken == 0
        ? 0
        : ((appState.quizzesPassed / appState.quizzesTaken) * 100).round();
    final unlockedAchievements =
        achievements.where((a) => a.unlocked(appState)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('پیشرفت')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          Reveal(
            index: 0,
            child: Row(
              children: [
                Expanded(
                  child: _stat(context, '${appState.ayatHeld}', 'آیه حفظ شده',
                      Icons.auto_stories_rounded, AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _stat(context, '${appState.sealed.length}',
                      'سوره مهر و موم شده', Icons.auto_awesome, AppColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Reveal(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  child: _stat(context, '${appState.totalXp}', 'مجموع امتیاز',
                      Icons.bolt_rounded, AppColors.xpGolden),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _stat(context, '$accuracy%', 'جلسات موفق',
                      Icons.verified_rounded, AppColors.success),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 2,
            child: Pressable(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AchievementsPage()),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: context.borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.secondaryDark, size: 22),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '$unlockedAchievements از ${achievements.length} دستاورد',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded,
                        color: context.mutedColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 3,
            child: Text('بر اساس سوره',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < surahs.length; i++)
            Reveal(
              index: i + 4,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _bar(context, surahs[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.md),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(fontSize: 26)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, Surah s) {
    final held = appState.held[s.number] ?? 0;
    final p = s.length == 0 ? 0.0 : held / s.length;
    final sealed = appState.sealed.contains(s.number);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.borderColor, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.englishName,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('$held/${s.length}',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.circular),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: p),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                    sealed ? AppColors.secondary : AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
