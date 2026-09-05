import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/achievements.dart';
import '../../shared/services/app_state.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.unlocked(appState)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('دستاوردها')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          Reveal(
            index: 0,
            child: Text('$unlocked از ${achievements.length} باز شده',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < achievements.length; i++)
            Reveal(
              index: i + 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _tile(context, achievements[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Achievement a) {
    final on = a.unlocked(appState);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: on ? AppColors.secondary : context.borderColor,
          width: 2.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: on ? AppGradients.gilt : null,
              color: on ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Icon(a.icon,
                size: 22, color: on ? AppColors.white : context.mutedColor),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: on ? null : context.mutedColor,
                        )),
                Text(a.description,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (on)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.secondaryDark, size: 20),
        ],
      ),
    );
  }
}
