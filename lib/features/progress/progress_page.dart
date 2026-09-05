import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/achievements.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../review/review_page.dart';
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
          Reveal(index: 0, child: _heroCard(context)),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  child: _stat(context, '${appState.sealed.length}',
                      'سوره مهر و موم شده', Icons.auto_awesome, AppColors.secondary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _stat(context, '${appState.totalXp}', 'مجموع امتیاز',
                      Icons.bolt_rounded, AppColors.xpGolden),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Reveal(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: _stat(context, '$accuracy%', 'جلسات موفق',
                      Icons.verified_rounded, AppColors.success),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _stat(context, '${appState.longestStreak}',
                      'طولانی‌ترین روند', Icons.local_fire_department_rounded,
                      AppColors.streakFire),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 3,
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
          const SizedBox(height: AppSpacing.md),
          Reveal(
            index: 4,
            child: Pressable(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReviewPage()),
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
                    const Icon(Icons.refresh_rounded,
                        color: AppColors.gold, size: 22),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        appState.dueForReview.isEmpty
                            ? 'مرور دوره‌ای'
                            : '${appState.dueForReview.length} سطح آماده مرور',
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
            index: 5,
            child: Text('بر اساس سوره',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < surahs.length; i++)
            Reveal(
              index: i + 6,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _bar(context, surahs[i]),
              ),
            ),
        ],
      ),
    );
  }

  /// The motivational centrepiece of this page: how much of the *whole*
  /// Qur'an — not just one surah — is actually held, framed as a
  /// percentage rather than a raw ayah count. 6236 ayat makes any single
  /// surah's progress look small in isolation; a running "X% of the whole
  /// Qur'an" figure is the number worth watching climb over months.
  Widget _heroCard(BuildContext context) {
    final held = appState.ayatHeld;
    final total = appState.totalAyat;
    final pct = total == 0 ? 0.0 : held / total;
    final pctValue = pct * 100;
    final pctText = pctValue <= 0
        ? '0'
        : pctValue < 1
            ? pctValue.toStringAsFixed(2)
            : pctValue < 10
                ? pctValue.toStringAsFixed(1)
                : pctValue.round().toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حافظه شما',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.white)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUp(
                value: held,
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: AppColors.white),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 6),
                child: Text('آیه از $total',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.white)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('$pctText% کل قرآن',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.circular),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _milestoneMessage(pct, appState.sealed.length),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }

  String _milestoneMessage(double pct, int sealedCount) {
    if (pct >= 1) return 'ماشاءالله! کل قرآن را حفظ کرده‌ای! 🎉';
    if (pct >= 0.5) return 'بیش از نصف قرآن در حافظه‌ات است — محشری!';
    if (pct >= 0.1) return 'بیش از ده درصد قرآن را حفظ کرده‌ای!';
    if (sealedCount >= 3) return '$sealedCount سوره را کامل مهر و موم کرده‌ای!';
    if (sealedCount >= 1) return 'اولین سوره‌ات را کامل کردی — همینطور ادامه بده!';
    if (pct > 0) return 'شروع خوبی بود! یک سوره را تمام کن.';
    return 'اولین آیه‌ات را همین امروز حفظ کن!';
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
