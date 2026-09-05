import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';

/// Framed encouragingly, as the original spec asked for: this is what you
/// have, not a bar chart of what's missing.
class MemorizedPage extends StatelessWidget {
  const MemorizedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final withProgress =
        surahs.where((s) => (appState.held[s.number] ?? 0) > 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('آیات حفظ‌شده')),
      body: withProgress.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Mascot(mood: MascotMood.idle, size: 64),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'هنوز چیزی حفظ نشده — هر آیه‌ای که سه تمرین آن را کامل '
                      'کنید، اینجا نمایش داده می‌شود.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                  AppSpacing.sm, AppSpacing.xl, AppSpacing.xxxl),
              children: [
                Reveal(
                  index: 0,
                  child: Text(
                    '${appState.ayatHeld} آیه در '
                    '${withProgress.length} سوره حفظ شده است.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var i = 0; i < withProgress.length; i++)
                  Reveal(
                    index: i + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _surahCard(context, withProgress[i]),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _surahCard(BuildContext context, Surah s) {
    final indices = appState.heldIndices(s.number).toList()..sort();
    final sealed = appState.sealed.contains(s.number);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: sealed ? AppColors.secondary : context.borderColor,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.englishName,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (sealed)
                const Icon(Icons.auto_awesome,
                    size: 18, color: AppColors.secondaryDark),
              const SizedBox(width: 4),
              Text('${indices.length}/${s.length}',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final idx in indices)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.circular),
                  ),
                  child: Text(
                    'آیه ${s.ayat[idx].number}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.primaryDeep),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
