import 'package:flutter/material.dart';
import 'app_state.dart';
import 'prayer_times.dart';
import 'reminders.dart';
import 'settings.dart';

/// Keeps `settings.reminderTime` pointed at today's actual prayer time when
/// [Settings.reminderAnchor] is [ReminderAnchor.afterPrayer], instead of
/// whatever it resolved to yesterday (prayer times drift a few minutes day
/// to day). Every existing consumer of `reminderTime` — the per-minute
/// foreground check in main.dart, the background-push sync — needs no
/// changes: this just keeps that one field current.
String? _resolvedForDate;

enum PrayerLookupStatus { idle, loading, ok, failed }

/// Lets the Settings page show live "در حال یافتن ساعت اذان…" /
/// "ساعت اذان یافت نشد" state without needing its own polling — the
/// resolver below is the only writer.
final ValueNotifier<PrayerLookupStatus> prayerLookupStatus =
    ValueNotifier(PrayerLookupStatus.idle);

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

TimeOfDay _addMinutes(TimeOfDay t, int minutes) {
  final total = (t.hour * 60 + t.minute + minutes) % (24 * 60);
  return TimeOfDay(hour: total ~/ 60, minute: total % 60);
}

/// Call once at boot and thereafter on every tick of the existing daily-
/// reminder timer (see main.dart) — the date guard below makes every call
/// after the first one on a given day a cheap no-op, so polling it every
/// minute is fine. Pass `force: true` right after the user changes the
/// prayer/offset settings, so the screen reflects the new choice
/// immediately instead of waiting for the next date change.
Future<void> resolvePrayerAnchoredReminderTime({bool force = false}) async {
  if (settings.reminderAnchor != ReminderAnchor.afterPrayer) return;
  final today = _todayKey();
  if (!force && _resolvedForDate == today) return;
  prayerLookupStatus.value = PrayerLookupStatus.loading;
  final times = await prayerTimesService.fetchToday();
  if (times == null) {
    // Location denied, offline, or the API is unreachable — leave
    // reminderTime exactly as it was (either yesterday's resolved time or
    // the untouched default) rather than block the reminder entirely.
    prayerLookupStatus.value = PrayerLookupStatus.failed;
    return;
  }
  prayerLookupStatus.value = PrayerLookupStatus.ok;
  _resolvedForDate = today;
  final resolved =
      _addMinutes(times[settings.reminderPrayer], settings.reminderOffsetMinutes);
  settings.setResolvedReminderTime(resolved);
  if (settings.dailyReminder && appState.signedIn) {
    // hour/minute still go along as the fallback the server-side cron
    // uses if *it* can't reach Aladhan at send time; anchor/prayer/offset/
    // lat/lon are what let it look the real azan time up itself instead,
    // fresh, every day, with no dependency on this tab ever being open
    // again (see send-daily-reminders' doc comment).
    appState.syncPushReminder(
      enabled: true,
      hour: resolved.hour,
      minute: resolved.minute,
      timezone: reminders.timezone,
      anchor: 'prayer',
      prayer: settings.reminderPrayer.name,
      offsetMinutes: settings.reminderOffsetMinutes,
      lat: times.latitude,
      lon: times.longitude,
    );
  }
}
