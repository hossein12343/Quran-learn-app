import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/juz_data.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/khatm_tracker.dart';

/// A simple 30-juz reading checklist for khatm — most useful during
/// Ramadan, but not calendar-gated: some people run a khatm outside it
/// too, and hard-coding "only during Ramadan" would just be a wall
/// someone hits for no real reason.
class KhatmPage extends StatelessWidget {
  const KhatmPage({super.key});

  String _surahRef(int surahNumber, int ayah) {
    final s = surahs.where((s) => s.number == surahNumber);
    final name = s.isEmpty ? 'سورهٔ $surahNumber' : s.first.englishName;
    return 'از $name، آیهٔ $ayah';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: khatmTracker,
      builder: (context, _) {
        final completed = khatmTracker.completed;
        final pct = completed.length / 30;
        final pace = khatmTracker.suggestedDailyPace;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ختم رمضان'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'شروع ختم جدید',
                onPressed: () => _confirmReset(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
            children: [
              Reveal(index: 0, child: _progressCard(context, pct, pace)),
              const SizedBox(height: AppSpacing.xl),
              ...List.generate(juzStarts.length, (i) {
                final js = juzStarts[i];
                final done = completed.contains(js.juz);
                return Reveal(
                  index: i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _juzRow(context, js, done),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _progressCard(BuildContext context, double pct, int? pace) {
    final done = (pct * 30).round();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 5,
                  backgroundColor: AppColors.white,
                  color: AppColors.primary,
                ),
                Text('$done/30', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              pace == null
                  ? 'برای شروع، یکی از جزءها را که خواندی علامت بزن.'
                  : pace == 0
                      ? 'تبریک! ختم کامل شد. 🎉'
                      : 'برای تمام‌کردن در ۳۰ روز، روزی حدود $pace جزء لازم است.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _juzRow(BuildContext context, JuzStart js, bool done) {
    return Pressable(
      burst: false,
      onTap: () => khatmTracker.toggle(js.juz),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: done
              ? AppColors.primaryLight
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: done ? AppColors.primary : context.borderColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: done ? AppColors.primary : context.borderColor,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جزء ${js.juz}',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(_surahRef(js.surah, js.ayah),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('شروع ختم جدید؟'),
        content: const Text(
            'همهٔ جزءهای علامت‌خورده پاک می‌شوند و شمارش روز از امروز '
            'دوباره شروع می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              khatmTracker.reset();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('شروع دوباره'),
          ),
        ],
      ),
    );
  }
}
