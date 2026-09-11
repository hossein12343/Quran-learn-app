import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/surah_picker_sheet.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/hifz_plan.dart';
import '../../shared/services/settings.dart';

/// "Finish X by Y" — a memorization goal with the daily pace it
/// implies, computed live from what `AppState` already tracks as
/// held. Three scope choices, deliberately not a full custom
/// multi-surah picker: Juz Amma (surahs 78-114, the fixed, universally
/// -known last juz — no juz-boundary data needed for that one) and
/// the whole Quran cover the two most common real goals, and a single
/// surah covers the rest via the existing picker sheet.
class HifzPlanPage extends StatefulWidget {
  const HifzPlanPage({super.key});

  @override
  State<HifzPlanPage> createState() => _HifzPlanPageState();
}

class _HifzPlanPageState extends State<HifzPlanPage> {
  HifzPlan? _plan;

  @override
  void initState() {
    super.initState();
    _plan = loadHifzPlan();
  }

  Future<void> _startPlan(List<int> surahNumbers, String label) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'تاریخ هدف را انتخاب کنید',
    );
    if (picked == null || !mounted) return;
    final plan = HifzPlan(
      surahNumbers: surahNumbers,
      scopeLabel: label,
      targetDate: picked,
    );
    saveHifzPlan(plan);
    setState(() => _plan = plan);
  }

  Future<void> _pickSingleSurah() async {
    final s = await pickSurah(context);
    if (s == null || !mounted) return;
    await _startPlan([s.number], s.englishName);
  }

  void _cancelPlan() {
    clearHifzPlan();
    setState(() => _plan = null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => Directionality(
        textDirection: settings.direction,
        child: Scaffold(
          appBar: AppBar(title: const Text('برنامهٔ حفظ')),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _plan == null
                ? _setupView(context)
                : _progressView(context, _plan!),
          ),
        ),
      ),
    );
  }

  Widget _setupView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'یک هدف حفظ با تاریخ مشخص تعیین کنید تا سرعت لازم روزانه '
            'برایتان محاسبه شود.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        _presetButton(
          context,
          'جزء عمّ (سوره‌های ۷۸ تا ۱۱۴)',
          () => _startPlan([for (var n = 78; n <= 114; n++) n], 'جزء عمّ'),
        ),
        const SizedBox(height: AppSpacing.md),
        _presetButton(
          context,
          'کل قرآن',
          () => _startPlan([for (final s in surahs) s.number], 'کل قرآن'),
        ),
        const SizedBox(height: AppSpacing.md),
        _presetButton(context, 'یک سورهٔ مشخص', _pickSingleSurah),
      ],
    );
  }

  Widget _presetButton(BuildContext context, String label, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.borderColor, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.titleMedium)),
              Icon(Icons.chevron_left_rounded, color: context.mutedColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressView(BuildContext context, HifzPlan plan) {
    final totalAyat = surahs
        .where((s) => plan.surahNumbers.contains(s.number))
        .fold(0, (sum, s) => sum + s.ayat.length);
    final heldAyat =
        plan.surahNumbers.fold(0, (sum, n) => sum + (appState.held[n] ?? 0));
    final pace = computeHifzPace(
      totalAyat: totalAyat,
      heldAyat: heldAyat,
      targetDate: plan.targetDate,
      now: DateTime.now(),
    );
    final progress = totalAyat == 0 ? 0.0 : pace.heldAyat / totalAyat;

    return ListView(
      children: [
        Text(plan.scopeLabel, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'تاریخ هدف: ${plan.targetDate.year}/${plan.targetDate.month}/${plan.targetDate.day}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.mutedColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${pace.heldAyat} از ${pace.totalAyat} آیه حفظ‌شده',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xl),
        if (pace.alreadyComplete)
          _statCard(context, 'تبریک! این هدف را کامل کرده‌اید.',
              accent: AppColors.primary)
        else if (pace.overdue)
          _statCard(context,
              'تاریخ هدف گذشته است — ${pace.remainingAyat} آیه باقی مانده.',
              accent: AppColors.red)
        else ...[
          _statCard(context,
              '${pace.remainingAyat} آیه در ${pace.daysRemaining} روز باقی مانده'),
          const SizedBox(height: AppSpacing.md),
          _statCard(context, 'سرعت لازم: روزی ${pace.ayatPerDay.ceil()} آیه',
              accent: AppColors.gold),
        ],
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: _cancelPlan,
          child: const Text('لغو این برنامه و تعیین هدف جدید'),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String text,
      {Color accent = AppColors.primary}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent, width: 2),
      ),
      child: Text(text,
          style:
              Theme.of(context).textTheme.titleMedium?.copyWith(color: accent)),
    );
  }
}
