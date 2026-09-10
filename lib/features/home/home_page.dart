import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/mascot.dart';
import '../../core/widgets/pattern_overlay.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../profile/pro_page.dart';
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

  bool _celebratingMilestone = false;

  /// Fires at most once per newly-reached milestone (see
  /// `AppState.pendingStreakMilestone`) — `build` re-runs on every
  /// `appState` change (a whole quiz session's worth of XP/streak
  /// updates, not just this one), so the `_celebratingMilestone` guard is
  /// what keeps a single crossed milestone from queuing a dialog on every
  /// one of those rebuilds while the first one is still open.
  void _maybeCelebrateStreak() {
    final milestone = appState.pendingStreakMilestone;
    if (milestone == null || _celebratingMilestone) return;
    _celebratingMilestone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _StreakMilestoneDialog(days: milestone),
      );
      appState.acknowledgeStreakMilestone(milestone);
      _celebratingMilestone = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeCelebrateStreak();
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
            const SizedBox(height: AppSpacing.lg),
            Reveal(index: 0, child: _weekStrip()),
            const SizedBox(height: AppSpacing.xl),
            if (appState.dueForReview.isNotEmpty) ...[
              Reveal(index: 1, child: _reviewBanner()),
              const SizedBox(height: AppSpacing.xl),
            ],
            Reveal(index: 2, child: _continueCard(next)),
            const SizedBox(height: AppSpacing.xl),
            Reveal(index: 3, child: _questsCard()),
            const SizedBox(height: AppSpacing.xl),
            Reveal(index: 4, child: RepaintBoundary(child: _levelCard())),
            if (!appState.isPro) ...[
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 5, child: _proCard()),
            ],
            const SizedBox(height: AppSpacing.xl),
            Reveal(
              index: 6,
              child: Text('حافظه شما',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.md),
            Reveal(index: 7, child: _memoryCard()),
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

  /// This calendar week, Saturday \u2192 Friday. A day a session landed on
  /// shows the streak fire; today is ringed; days still ahead are faint.
  /// Rendered RTL so Saturday sits on the right.
  Widget _weekStrip() {
    // Persian weekday initials, Saturday first \u2014 matches AppState.thisWeek.
    const labels = ['\u0634', '\u06cc', '\u062f', '\u0633', '\u0686', '\u067e', '\u062c'];
    final week = appState.thisWeek;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.streakFire, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                appState.currentStreak > 0
                    ? '${appState.currentStreak} \u0631\u0648\u0632 \u067e\u0634\u062a\u200c\u0633\u0631\u0647\u0645'
                    : '\u0627\u06cc\u0646 \u0647\u0641\u062a\u0647 \u0631\u0627 \u0634\u0631\u0648\u0639 \u06a9\u0646',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    Column(
                      children: [
                        Text(
                          labels[i],
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: week[i].isToday ? AppColors.primary : null,
                                fontWeight: week[i].isToday
                                    ? FontWeight.w800
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: week[i].active
                                ? AppColors.goldLight
                                : (week[i].future
                                    ? Colors.transparent
                                    : surface),
                            border: week[i].isToday
                                ? Border.all(
                                    color: AppColors.primary, width: 2)
                                : (week[i].future
                                    ? Border.all(color: surface, width: 1.5)
                                    : null),
                          ),
                          child: week[i].active
                              ? const Icon(Icons.local_fire_department_rounded,
                                  size: 19, color: AppColors.streakFire)
                              : Icon(Icons.circle,
                                  size: 5,
                                  color: week[i].future
                                      ? Colors.transparent
                                      : context.mutedColor),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _questIcons = <String, IconData>{
    'minutes': Icons.timer_rounded,
    'learn': Icons.auto_stories_rounded,
    'lesson': Icons.check_circle_rounded,
  };

  Widget _questsCard() {
    final quests = appState.dailyQuests;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('\u0645\u0623\u0645\u0648\u0631\u06cc\u062a\u200c\u0647\u0627\u06cc \u0627\u0645\u0631\u0648\u0632',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Text(
                '${appState.questsDoneToday}/${quests.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < quests.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _questRow(quests[i]),
          ],
        ],
      ),
    );
  }

  Widget _questRow(DailyQuest q) {
    final done = q.done;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.primaryLight : context.borderColor,
          ),
          child: Icon(
            done
                ? Icons.check_rounded
                : (_questIcons[q.id] ?? Icons.flag_rounded),
            size: 20,
            color: done ? AppColors.primary : context.mutedColor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: done ? context.mutedColor : null,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.circular),
                child: LinearProgressIndicator(
                  value: q.fraction,
                  minHeight: 6,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      done ? AppColors.primary : AppColors.gold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '${q.progress.clamp(0, q.target)}/${q.target}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }

  Widget _proCard() {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProPage()),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.gold,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.gilt)),
              ),
              const Positioned.fill(child: StarField()),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.white, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\u06cc\u0627\u062f\u06af\u06cc\u0631\u06cc \u0642\u0631\u0622\u0646 Pro',
                              style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('\u0642\u0644\u0628 \u0646\u0627\u0645\u062d\u062f\u0648\u062f\u060c \u0645\u062d\u0627\u0641\u0638 \u0631\u0648\u0646\u062f\u060c \u0647\u0645\u0647\u0654 \u0642\u0627\u0631\u06cc\u0627\u0646',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded,
                        color: AppColors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
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

/// A full, one-time celebration for reaching a round streak number
/// (`AppState.streakMilestones`) — the "bigger celebration moments" the
/// regular right/wrong tones and small mascot never covered. Reuses
/// `Confetti`, otherwise reserved for sealing a level/surah, since a
/// streak milestone is exactly that kind of rare, meaningful moment.
class _StreakMilestoneDialog extends StatelessWidget {
  final int days;
  const _StreakMilestoneDialog({required this.days});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: Confetti(play: true)),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.hero,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 56, color: AppColors.streakFire),
                const SizedBox(height: AppSpacing.md),
                Text('$days روز پشت‌سرهم!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'همینطور ادامه بده — این روند نتیجهٔ تلاش واقعی توست.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                DuoButton(
                  label: 'ادامه',
                  fullWidth: false,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

