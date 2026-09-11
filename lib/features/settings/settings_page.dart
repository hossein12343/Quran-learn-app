import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/audio.dart';
import '../../shared/services/prayer_reminder.dart';
import '../../shared/services/prayer_times.dart';
import '../../shared/services/recite_check.dart';
import '../../shared/services/reminders.dart';
import '../../shared/services/settings.dart';
import '../profile/pro_page.dart';
import 'about_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Merged with `appState` too, not just `settings` — the reminder
      // section's copy/behavior depends on `appState.signedIn` (push
      // needs an account), so a sign-in/out while this page is open needs
      // to be able to repaint it, not just a settings change.
      animation: Listenable.merge([settings, appState]),
      builder: (context, _) => Directionality(
        textDirection: settings.direction,
        child: Scaffold(
          appBar: AppBar(title: Text(L10n.t('settings'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl),
            children: [
              Reveal(index: 0, child: _reciterSection(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 1, child: _speedSection(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 2, child: _modeSection(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 3, child: _languageSection(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 4, child: _fontSizeSection(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 5, child: _reminderSection(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 6, child: _capabilityNotice(context)),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 7, child: _aboutLink(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context,
      {required String title, String? subtitle, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.borderColor, width: 2),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _reciterSection(BuildContext context) {
    return _panel(
      context,
      title: L10n.t('reciter'),
      subtitle: 'صدای کسی که در طول جلسه می‌شنوید.',
      child: Column(
        children: [
          for (final q in knownQaris)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Pressable(
                // Locked reciters open the Pro upsell instead of selecting
                // — see plan.dart. This is the only place `qariId` is ever
                // set, so it's also the only gate real playback needs.
                onTap: (q.isPro && !appState.isPro)
                    ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const ProPage()))
                    : () => settings.setQari(q.id),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: settings.qariId == q.id
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: settings.qariId == q.id
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (q.isPro && !appState.isPro) ...[
                        Icon(Icons.lock_rounded,
                            size: 18, color: AppColors.gold),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(q.style,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(q.nativeName,
                            style: ArabicType.tile(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _speedSection(BuildContext context) {
    return _panel(
      context,
      title: L10n.t('speed'),
      subtitle: 'پخش کندتر تقلید دقیق را آسان‌تر می‌کند.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final s in playbackSpeeds) ...[
                Expanded(
                  child: Pressable(
                    onTap: () => settings.setSpeed(s),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: settings.speed == s
                            ? AppColors.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: settings.speed == s
                              ? AppColors.white
                              : context.mutedColor,
                        ),
                      ),
                    ),
                  ),
                ),
                if (s != playbackSpeeds.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(L10n.t('repeat'),
              style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: settings.repeatCount.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.primary,
            label: '${settings.repeatCount}',
            onChanged: (v) => settings.setRepeat(v.round()),
          ),
          Text(
            'هر آیه ${settings.repeatCount} بار پخش می‌شود پیش از آنکه از '
            'شما خواسته شود آن را تکرار کنید.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _modeSection(BuildContext context) {
    return _panel(
      context,
      title: L10n.t('mode'),
      subtitle: 'در هر جلسه چقدر یاد می‌گیرید.',
      child: Column(
        children: [
          for (final m in LearnMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Pressable(
                onTap: () => settings.setMode(m),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: settings.mode == m
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: settings.mode == m
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(m.blurb,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _languageSection(BuildContext context) {
    return _panel(
      context,
      title: L10n.t('language'),
      child: Row(
        children: [
          Expanded(child: _langChip(context, 'en', 'English')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _langChip(context, 'fa', 'فارسی')),
        ],
      ),
    );
  }

  Widget _langChip(BuildContext context, String code, String label) {
    final on = settings.language == code;
    return Pressable(
      onTap: () => settings.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on
              ? AppColors.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: on ? AppColors.white : context.mutedColor,
          ),
        ),
      ),
    );
  }

  Widget _fontSizeSection(BuildContext context) {
    return _panel(
      context,
      title: L10n.t('fontSize'),
      subtitle: 'روی خواندن قرآن و تمرین‌ها اعمال می‌شود.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'بِسْمِ ٱللَّهِ',
              style: ArabicType.ayah(size: 27 * settings.arabicScale),
            ),
          ),
          Slider(
            value: settings.arabicScale,
            min: 0.85,
            max: 1.35,
            divisions: 10,
            activeColor: AppColors.primary,
            label: '${(settings.arabicScale * 100).round()}%',
            onChanged: (v) => settings.setArabicScale(v),
          ),
          const Divider(height: AppSpacing.xxl),
          Text('اندازهٔ متن رابط کاربری',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'اندازهٔ همهٔ متن‌های فارسیِ برنامه — دکمه‌ها، منوها، متن '
            'تنظیمات — را تغییر می‌دهد.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('نمونه: دکمه، منو، متن تنظیمات',
              style: Theme.of(context).textTheme.bodyLarge),
          Slider(
            value: settings.uiTextScale,
            min: 0.85,
            max: 1.35,
            divisions: 10,
            activeColor: AppColors.primary,
            label: '${(settings.uiTextScale * 100).round()}%',
            onChanged: (v) => settings.setUiTextScale(v),
          ),
        ],
      ),
    );
  }

  Widget _reminderSection(BuildContext context) {
    final blocked = settings.dailyReminder &&
        reminders.available &&
        !reminders.permissionGranted;
    final canBackground = reminders.pushSupported && appState.signedIn;
    String subtitle;
    if (!reminders.available) {
      subtitle = 'اعلان مرورگر در این دستگاه در دسترس نیست.';
    } else if (canBackground) {
      subtitle = 'چون وارد حساب شده‌اید، حتی وقتی برنامه بسته باشد هم '
          'یادآوری می‌شوید.';
    } else {
      subtitle = 'وقتی این تب باز باشد با یک اعلان مرورگر یادآوری می‌کند. '
          'برای یادآوری حتی وقتی برنامه بسته است، وارد حساب کاربری شوید.';
    }
    return _panel(
      context,
      title: L10n.t('reminder'),
      subtitle: subtitle,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.dailyReminder,
              activeColor: AppColors.primary,
              onChanged: reminders.available
                  ? (v) => _onReminderToggle(context, v)
                  : null,
              title: Text('یادآوری روزانه',
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            if (settings.dailyReminder) ...[
              const SizedBox(height: AppSpacing.sm),
              _anchorChoice(context),
              const SizedBox(height: AppSpacing.md),
              settings.reminderAnchor == ReminderAnchor.fixedTime
                  ? _fixedTimeControl(context)
                  : _prayerAnchorControl(context),
            ],
            if (blocked)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'اجازهٔ اعلان داده نشده — یادآور کار نمی‌کند تا از تنظیمات '
                  'مرورگر اجازه بدهید.',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "ساعت مشخص" vs "بعد از نماز" — a two-way choice, same visual language
  /// as `_modeSection`'s learning-mode picker.
  Widget _anchorChoice(BuildContext context) {
    Widget chip(String label, ReminderAnchor value) {
      final on = settings.reminderAnchor == value;
      return Expanded(
        child: Pressable(
          onTap: () {
            settings.setReminderAnchor(value);
            if (value == ReminderAnchor.afterPrayer) {
              unawaited(resolvePrayerAnchoredReminderTime(force: true));
            } else if (settings.dailyReminder && appState.signedIn) {
              // Switching back to a fixed time: tell the server right
              // away rather than waiting for some other sync — otherwise
              // it would keep computing against the just-abandoned prayer
              // setting until the next unrelated reminder change.
              _syncPushReminder(
                enabled: true,
                hour: settings.reminderTime.hour,
                minute: settings.reminderTime.minute,
              );
            }
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: on ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                  color: on ? AppColors.primary : context.borderColor),
            ),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: on ? AppColors.primaryDeep : null),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('ساعت مشخص', ReminderAnchor.fixedTime),
        const SizedBox(width: AppSpacing.sm),
        chip('بعد از نماز', ReminderAnchor.afterPrayer),
      ],
    );
  }

  Widget _fixedTimeControl(BuildContext context) {
    final h = settings.reminderTime.hour.toString().padLeft(2, '0');
    final m = settings.reminderTime.minute.toString().padLeft(2, '0');
    return Row(
      children: [
        Text('یادآوری در ساعت $h:$m',
            style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        Pressable(
          onTap: () => _pickReminderTime(context),
          child: Text('تغییر ساعت',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.blue)),
        ),
      ],
    );
  }

  /// Prayer picker + a "N minutes after" offset stepper, plus the live
  /// resolved-time status (calculating / found / couldn't find — see
  /// `prayer_reminder.dart`'s `prayerLookupStatus`).
  Widget _prayerAnchorControl(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final p in Prayer.values)
              Pressable(
                onTap: () {
                  settings.setReminderPrayer(p);
                  unawaited(resolvePrayerAnchoredReminderTime(force: true));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: settings.reminderPrayer == p
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.circular),
                    border: Border.all(
                        color: settings.reminderPrayer == p
                            ? AppColors.primary
                            : context.borderColor),
                  ),
                  child: Text(
                    p.labelFa,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: settings.reminderPrayer == p
                            ? AppColors.primaryDeep
                            : null),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text('${settings.reminderOffsetMinutes} دقیقه بعد از اذان',
                style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            IconButton(
              tooltip: 'کم‌کردن ۵ دقیقه',
              onPressed: settings.reminderOffsetMinutes <= 0
                  ? null
                  : () {
                      settings.setReminderOffsetMinutes(
                          settings.reminderOffsetMinutes - 5);
                      unawaited(resolvePrayerAnchoredReminderTime(force: true));
                    },
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: AppColors.primary,
            ),
            IconButton(
              tooltip: 'افزودن ۵ دقیقه',
              onPressed: settings.reminderOffsetMinutes >= 90
                  ? null
                  : () {
                      settings.setReminderOffsetMinutes(
                          settings.reminderOffsetMinutes + 5);
                      unawaited(resolvePrayerAnchoredReminderTime(force: true));
                    },
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ValueListenableBuilder<PrayerLookupStatus>(
          valueListenable: prayerLookupStatus,
          builder: (context, status, _) {
            final h = settings.reminderTime.hour.toString().padLeft(2, '0');
            final m = settings.reminderTime.minute.toString().padLeft(2, '0');
            final (text, color) = switch (status) {
              PrayerLookupStatus.loading => (
                  'در حال یافتن ساعت اذان…',
                  context.mutedColor
                ),
              PrayerLookupStatus.failed => (
                  'ساعت اذان پیدا نشد — اجازهٔ موقعیت مکانی لازم است. '
                      'فعلاً طبق آخرین ساعت شناخته‌شده ($h:$m) یادآوری می‌شود.',
                  AppColors.red
                ),
              PrayerLookupStatus.ok || PrayerLookupStatus.idle => (
                  'یادآوری حدود ساعت $h:$m',
                  AppColors.primaryDeep
                ),
            };
            return Row(
              children: [
                Expanded(
                  child: Text(text,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: color)),
                ),
                if (status == PrayerLookupStatus.failed)
                  Pressable(
                    onTap: () => unawaited(
                        resolvePrayerAnchoredReminderTime(force: true)),
                    child: Text('تلاش دوباره',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.blue)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Wraps `AppState.syncPushReminder` with whatever anchor/prayer/offset
  /// the user currently has picked, so every call site here — the master
  /// toggle, the manual time picker — keeps the server's copy consistent
  /// with Settings, not just the hour/minute. Doesn't carry lat/lon:
  /// those come from an actual Aladhan fetch, which
  /// `resolvePrayerAnchoredReminderTime` (already running at boot and on
  /// every prayer/offset change) supplies on its own next successful run.
  void _syncPushReminder(
      {required bool enabled, required int hour, required int minute}) {
    final anchored = settings.reminderAnchor == ReminderAnchor.afterPrayer;
    appState.syncPushReminder(
      enabled: enabled,
      hour: hour,
      minute: minute,
      timezone: reminders.timezone,
      anchor: anchored ? 'prayer' : 'fixed',
      prayer: anchored ? settings.reminderPrayer.name : null,
      offsetMinutes: anchored ? settings.reminderOffsetMinutes : null,
    );
  }

  Future<void> _onReminderToggle(BuildContext context, bool v) async {
    if (!v) {
      settings.setReminder(false);
      if (appState.signedIn) {
        _syncPushReminder(
          enabled: false,
          hour: settings.reminderTime.hour,
          minute: settings.reminderTime.minute,
        );
      }
      return;
    }
    // Ask for real browser permission before claiming the reminder is on —
    // a granted toggle with no permission behind it would just be the old
    // "does nothing" bug wearing a permission-aware disguise.
    final granted = await reminders.requestPermission();
    settings.setReminder(true);
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'اجازهٔ اعلان داده نشد — بدون آن، یادآور نمی‌تواند اعلانی نشان دهد.'),
        ),
      );
      return;
    }
    // Signed-in accounts additionally get real background push — the
    // subscription is what lets the server-side reminder reach this
    // browser even with every tab closed.
    if (appState.signedIn && reminders.pushSupported) {
      final sub = await reminders.subscribeToPush(vapidPublicKey);
      if (sub != null) {
        await appState.savePushSubscription(
          endpoint: sub.endpoint,
          p256dh: sub.p256dh,
          authKey: sub.auth,
        );
      }
    }
    if (appState.signedIn) {
      _syncPushReminder(
        enabled: true,
        hour: settings.reminderTime.hour,
        minute: settings.reminderTime.minute,
      );
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (picked == null) return;
    settings.setReminder(true, picked);
    if (appState.signedIn) {
      _syncPushReminder(
          enabled: true, hour: picked.hour, minute: picked.minute);
    }
  }

  Widget _capabilityNotice(BuildContext context) {
    final audioOn = recitation.available;
    final micOn = reciteGrader.available;
    if (audioOn && micOn) return const SizedBox.shrink();

    final missing = <String>[
      if (!audioOn) 'پخش تلاوت',
      if (!micOn) 'ارزیابی تلاوت با صدا',
    ].join(' و ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('هنوز فعال نشده',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.secondaryDark)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$missing به پکیج‌هایی نیاز دارند که تا زمانی که pub.dev این '
            'دستگاه را رد می‌کند، قابل نصب نیستند. انتخاب‌های بالای شما ذخیره '
            'شده و به‌محض نصب آن‌ها فعال می‌شوند.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _aboutLink(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AboutPage()),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: context.mutedColor),
          const SizedBox(width: AppSpacing.sm),
          Text('دربارهٔ متن، ترجمه و قاریان',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: context.mutedColor)),
          const Spacer(),
          Icon(Icons.chevron_left_rounded, size: 20, color: context.mutedColor),
        ],
      ),
    );
  }
}
