import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/mascot.dart';
import '../../core/widgets/pattern_overlay.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../quiz/quiz_page.dart';
import '../review/review_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToLearn;
  const HomePage({super.key, required this.onGoToLearn});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _sc = ScrollController();

  /// Scroll offset lives in a notifier, not in State. Calling setState on
  /// every scroll frame rebuilt the whole page — both gradient cards, both
  /// CustomPaint rings and every shadow — 60 times a second. This rebuilds
  /// only the header.
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      _offset.value = _sc.offset;
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    _offset.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'صبح بخیر';
    if (h < 18) return 'ظهر بخیر';
    return 'عصر بخیر';
  }

  void _openNext() {
    final s = appState.nextSurah;
    if (s == null) {
      widget.onGoToLearn();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            QuizPage(surah: s, chunkIndex: appState.nextChunkFor(s)),
      ),
    );
  }

  void _openReview() {
    final due = appState.dueForReview;
    if (due.isEmpty) return;
    final item = due.first;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            QuizPage(surah: item.surah, chunkIndex: item.chunkIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = appState.nextSurah;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _sc,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _offset,
              builder: (context, offset, child) =>
                  Parallax(offset: offset, child: child!),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting,
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text(appState.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Mascot(
                        mood: appState.currentStreak > 0
                            ? MascotMood.happy
                            : MascotMood.idle,
                        size: 36,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      DuoBadge(
                        icon: Icons.local_fire_department_rounded,
                        label: '${appState.currentStreak}',
                        color: AppColors.streakFire,
                        background: AppColors.goldLight,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      DuoBadge(
                        icon: Icons.bolt_rounded,
                        label: '${appState.totalXp}',
                        color: AppColors.blueDark,
                        background: AppColors.blueLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (appState.dueForReview.isNotEmpty) ...[
              Reveal(index: 0, child: _reviewBanner()),
              const SizedBox(height: AppSpacing.xl),
            ],
            Reveal(index: 0, child: RepaintBoundary(child: _levelCard())),
            const SizedBox(height: AppSpacing.xl),
            Reveal(index: 1, child: RepaintBoundary(child: _dailyGoalCard())),
            const SizedBox(height: AppSpacing.xl),
            Reveal(index: 2, child: _continueCard(next)),
            const SizedBox(height: AppSpacing.xl),
            Reveal(
              index: 3,
              child: Text('حافظه شما',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.md),
            Reveal(index: 4, child: _memoryCard()),
          ],
        ),
      ),
    );
  }

  void _openReviewList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReviewPage()),
    );
  }

  Widget _reviewBanner() {
    final due = appState.dueForReview;
    final first = due.first;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold,
            ),
            child: const Icon(Icons.refresh_rounded,
                color: AppColors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Pressable(
              onTap: due.length > 1 ? _openReviewList : _openReview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    due.length == 1
                        ? 'وقت مرور سوره ${first.surah.englishName} است'
                        : '${due.length} سطح برای مرور آماده است',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.secondaryDark),
                  ),
                  Text(
                    due.length > 1
                        ? 'برای دیدن همه ضربه بزن.'
                        : 'یک یادآوری سریع بدون کمک، آن را در حافظه نگه می‌دارد.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Pressable(
            onTap: _openReview,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.circular),
              ),
              child: const Text(
                'مرور',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.hero,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppGradients.hero)),
            ),
            const Positioned.fill(child: StarField()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('سطح ${appState.level}',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                )),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                CountUp(
                                  value: appState.totalXp,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(' امتیاز کل',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 15)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ProgressRing(
                        progress: appState.levelProgress,
                        size: 58,
                        stroke: 6,
                        color: AppColors.white,
                        track: Colors.white24,
                        center: Text(
                          '${(appState.levelProgress * 100).round()}%',
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${150 - appState.xpIntoLevel} امتیاز تا سطح ${appState.level + 1}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyGoalCard() {
    return _panel(
      child: Row(
        children: [
          ProgressRing(
            progress: appState.dailyProgress,
            size: 52,
            center: const Icon(Icons.bolt_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\u0647\u062f\u0641 \u0627\u0645\u0631\u0648\u0632',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '${appState.minutesToday} \u0627\u0632 ${appState.dailyGoalMinutes} \u062f\u0642\u06cc\u0642\u0647',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueCard(Surah? next) {
    if (next == null) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('همه سوره‌های موجود مهر و موم شده‌اند',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'برای ادامه، بقیه مصحف را اضافه کنید.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final held = appState.held[next.number] ?? 0;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ادامه حفظ',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text('سوره ${next.englishName}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('$held از ${next.length} آیه حفظ شده',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  next.arabicName,
                  style: ArabicType.ayah(size: 26, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          DuoButton(
              label: 'شروع جلسه',
              onTap: _openNext,
              color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _memoryCard() {
    final held = appState.ayatHeld;
    final total = appState.totalAyat;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUp(
                value: held,
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('از $total آیه موجود',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.circular),
            child: TweenAnimationBuilder<double>(
              tween:
                  Tween<double>(begin: 0, end: total == 0 ? 0 : held / total),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'یک آیه تنها زمانی اینجا شمرده می‌شود که آن را به‌درستی '
            'به سه روش مختلف بازتولید کرده باشید.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.borderColor, width: 2),
      ),
      child: child,
    );
  }
}

