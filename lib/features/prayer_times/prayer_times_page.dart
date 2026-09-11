import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../shared/services/prayer_times.dart';

const Map<Prayer, IconData> _prayerIcons = {
  Prayer.fajr: Icons.nightlight_round,
  Prayer.dhuhr: Icons.wb_sunny_rounded,
  Prayer.asr: Icons.wb_cloudy_rounded,
  Prayer.maghrib: Icons.wb_twilight,
  Prayer.isha: Icons.dark_mode_rounded,
};

/// Today's five prayer times for wherever the device is — reuses the
/// same `PrayerTimesService` (geolocation + Aladhan) the prayer-reminder
/// feature already resolves times through, just surfaced as a screen
/// someone can actually check, not only used internally to anchor a
/// reminder.
class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  PrayerTimes? _times;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps the "X hours Y minutes until ..." countdown roughly live
    // while the page stays open, without needing a per-second timer.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await prayerTimesService.fetchToday();
    if (!mounted) return;
    setState(() {
      _times = t;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اوقات شرعی')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _times == null
              ? _error(context)
              : _body(context, _times!),
    );
  }

  Widget _error(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 48, color: context.mutedColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              'اوقات شرعی در دسترس نیست — به موقعیت مکانی یا اتصال '
              'اینترنت نیاز داریم.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            DuoButton(label: 'تلاش دوباره', fullWidth: false, onTap: _load),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PrayerTimes times) {
    final next = nextPrayerFrom(times, TimeOfDay.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
      children: [
        Reveal(index: 0, child: _nextCard(context, next)),
        const SizedBox(height: AppSpacing.xl),
        ...Prayer.values.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Reveal(
                index: entry.key + 1,
                child: _prayerRow(
                  context,
                  entry.value,
                  times[entry.value],
                  isNext: next.prayer == entry.value,
                ),
              ),
            )),
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _nextCard(
      BuildContext context, ({Prayer prayer, int minutesUntil}) next) {
    final hours = next.minutesUntil ~/ 60;
    final minutes = next.minutesUntil % 60;
    final remaining =
        hours > 0 ? '$hours ساعت و $minutes دقیقه' : '$minutes دقیقه';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اذان بعدی',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(next.prayer.labelFa,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$remaining دیگر',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _prayerRow(BuildContext context, Prayer p, TimeOfDay time,
      {required bool isNext}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.primaryLight
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isNext ? AppColors.primary : context.borderColor,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _prayerIcons[p] ?? Icons.access_time_rounded,
            color: isNext ? AppColors.primary : context.mutedColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Text(p.labelFa, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            _fmt(time),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isNext ? AppColors.primary : null,
                ),
          ),
        ],
      ),
    );
  }
}
