import 'package:flutter/material.dart';

/// The five daily prayers a reminder can be anchored to instead of a fixed
/// clock time — see [Settings.reminderAnchor] in `settings.dart`.
enum Prayer { fajr, dhuhr, asr, maghrib, isha }

extension PrayerLabel on Prayer {
  String get labelFa => switch (this) {
        Prayer.fajr => 'فجر',
        Prayer.dhuhr => 'ظهر',
        Prayer.asr => 'عصر',
        Prayer.maghrib => 'مغرب',
        Prayer.isha => 'عشاء',
      };
}

/// One day's five prayer times, in the device's local time, plus the
/// coordinates they were calculated for — carried along so a caller that
/// wants to sync a server-side reminder (see `prayer_reminder.dart`) has
/// them without a separate lookup; the location service that produced
/// this already resolved them to fetch the times themselves.
class PrayerTimes {
  final TimeOfDay fajr;
  final TimeOfDay dhuhr;
  final TimeOfDay asr;
  final TimeOfDay maghrib;
  final TimeOfDay isha;
  final double latitude;
  final double longitude;

  const PrayerTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.latitude,
    required this.longitude,
  });

  TimeOfDay operator [](Prayer p) => switch (p) {
        Prayer.fajr => fajr,
        Prayer.dhuhr => dhuhr,
        Prayer.asr => asr,
        Prayer.maghrib => maghrib,
        Prayer.isha => isha,
      };
}

/// Resolves "today's prayer times for wherever this device is" so a
/// reminder can be anchored to a prayer ("۱۵ دقیقه بعد از اذان مغرب")
/// instead of a fixed clock time — the far more natural framing for this
/// app's audience than an arbitrary hour. Real implementation on web only
/// (needs the browser's Geolocation API); a no-op stub elsewhere.
abstract class PrayerTimesService {
  /// Best-effort: null if geolocation is denied/unsupported, the network
  /// call fails, or (off-web) this is the stub. Callers should fall back to
  /// whatever reminder time was last resolved (or the fixed-time default)
  /// rather than block the reminder entirely on this.
  Future<PrayerTimes?> fetchToday();
}

class NoPrayerTimesService implements PrayerTimesService {
  const NoPrayerTimesService();

  @override
  Future<PrayerTimes?> fetchToday() async => null;
}

/// Real geolocation + Aladhan API lookup on web, the stub everywhere else.
/// Set once in main().
PrayerTimesService prayerTimesService = const NoPrayerTimesService();
