import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../quiz/quiz_page.dart';

/// One entry in the review schedule, resolved from [AppState.reviewDue] —
/// a surah/level pair plus when it's next due, split by [ReviewSchedule.isDue]
/// into "ready now" and "coming up" so a learner can see the whole spaced-
/// repetition schedule, not just whatever Home's one-line banner has room
/// for. Pushing "شروع مرور" opens the exact same gate-only [QuizPage] the
/// Home banner's "مرور" button does — every ayah in that level is already
/// held, so `Session` skips straight to the final blind recall, exactly the
/// "quick unaided reminder" a spaced-repetition review is supposed to be.
class _ReviewEntry {
  final Surah surah;
  final int chunkIndex;
  final DateTime due;
  const _ReviewEntry(
      {required this.surah, required this.chunkIndex, required this.due});
}

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  List<_ReviewEntry> _allEntries() {
    final entries = <_ReviewEntry>[];
    appState.reviewDue.forEach((key, date) {
      final surahNumber = key ~/ 1000;
      final chunkIndex = key % 1000;
      final surah = surahs.firstWhere(
        (s) => s.number == surahNumber,
        orElse: () => surahs.first,
      );
      // Surah data not loaded yet (matches AppState.dueForReview's own
      // guard) -- skip rather than show the wrong surah.
      if (surah.number != surahNumber) return;
      entries.add(_ReviewEntry(surah: surah, chunkIndex: chunkIndex, due: date));
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final all = _allEntries();
    final due = all.where((e) => ReviewSchedule.isDue(e.due)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    final upcoming = all.where((e) => !ReviewSchedule.isDue(e.due)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));

    return Scaffold(
      appBar: AppBar(title: const Text('مرور')),
      body: all.isEmpty
          ? _emptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
              children: [
                Text(
                  'مرور دوره‌ای، بدون کمک، چیزی را که حفظ کرده‌ای در حافظه '
                  'نگه می‌دارد — هر سطح که مهر و موم می‌شود بعد از ۴ روز '
                  'اولین بار مرور می‌شود، و هر بار که تمیز رد شود این فاصله '
                  'بیشتر می‌شود.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (due.isNotEmpty) ...[
                  Reveal(
                    index: 0,
                    child: Text('آماده مرور (${due.length})',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < due.length; i++)
                    Reveal(
                      index: i + 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _card(context, due[i], ready: true),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (upcoming.isNotEmpty) ...[
                  Reveal(
                    index: due.length + 1,
                    child: Text('مرورهای آینده',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < upcoming.length; i++)
                    Reveal(
                      index: due.length + i + 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _card(context, upcoming[i], ready: false),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded,
                size: 56, color: AppColors.gold),
            const SizedBox(height: AppSpacing.lg),
            Text('هنوز چیزی برای مرور نیست',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'وقتی یک سطح را کامل و مهر و موم کنی، برای یادآوری دوره‌ای '
              'اینجا ظاهر می‌شود تا آنچه حفظ کرده‌ای را فراموش نکنی.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _ReviewEntry e, {required bool ready}) {
    final count = chunkCountFor(e.surah);
    final start = e.chunkIndex * kChunkSize;
    final end = (start + kChunkSize).clamp(0, e.surah.length);
    final label = count > 1 ? 'سطح ${e.chunkIndex + 1}' : e.surah.englishName;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: ready ? AppColors.gold : context.borderColor,
          width: ready ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count > 1 ? '${e.surah.englishName} · $label' : label,
                    style: Theme.of(context).textTheme.titleMedium),
                if (count > 1)
                  Text('آیات ${start + 1}–$end',
                      style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  _relativeLabel(e.due, ready: ready),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ready ? AppColors.secondaryDark : context.mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (ready)
            Pressable(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      QuizPage(surah: e.surah, chunkIndex: e.chunkIndex),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(AppRadius.circular),
                ),
                child: const Text(
                  'شروع مرور',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            )
          else
            Icon(Icons.schedule_rounded, color: context.mutedColor, size: 20),
        ],
      ),
    );
  }

  String _relativeLabel(DateTime due, {required bool ready}) {
    final now = DateTime.now();
    if (ready) {
      final daysLate = now.difference(due).inDays;
      return daysLate <= 0 ? 'امروز آماده است' : '$daysLate روز از موعدش گذشته';
    }
    final hoursLeft = due.difference(now).inHours;
    final daysLeft = (hoursLeft / 24).ceil();
    return daysLeft <= 1 ? 'فردا آماده می‌شود' : 'در $daysLeft روز آماده می‌شود';
  }
}
