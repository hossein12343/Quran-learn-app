import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/prayer_times.dart';

void main() {
  final times = const PrayerTimes(
    fajr: TimeOfDay(hour: 5, minute: 0),
    dhuhr: TimeOfDay(hour: 12, minute: 30),
    asr: TimeOfDay(hour: 16, minute: 0),
    maghrib: TimeOfDay(hour: 19, minute: 15),
    isha: TimeOfDay(hour: 20, minute: 45),
    latitude: 35.6892,
    longitude: 51.3890,
  );

  test('just after midnight, next prayer is Fajr later today', () {
    final r = nextPrayerFrom(times, const TimeOfDay(hour: 0, minute: 30));
    expect(r.prayer, Prayer.fajr);
    expect(r.minutesUntil, 4 * 60 + 30); // 00:30 -> 05:00
  });

  test('between Dhuhr and Asr, next prayer is Asr', () {
    final r = nextPrayerFrom(times, const TimeOfDay(hour: 14, minute: 0));
    expect(r.prayer, Prayer.asr);
    expect(r.minutesUntil, 2 * 60);
  });

  test(
      'exactly at a prayer time, that prayer no longer counts as "next" '
      '(it has arrived, not still ahead)', () {
    final r = nextPrayerFrom(times, const TimeOfDay(hour: 16, minute: 0));
    expect(r.prayer, Prayer.maghrib);
  });

  test(
      'after Isha, wraps to tomorrow\'s Fajr and counts through '
      'midnight', () {
    final r = nextPrayerFrom(times, const TimeOfDay(hour: 22, minute: 0));
    expect(r.prayer, Prayer.fajr);
    // 22:00 -> midnight (2h) + midnight -> 05:00 (5h) = 7h
    expect(r.minutesUntil, 7 * 60);
  });

  test('minutesUntil is always positive, never zero or negative', () {
    for (var h = 0; h < 24; h++) {
      final r = nextPrayerFrom(times, TimeOfDay(hour: h, minute: 0));
      expect(r.minutesUntil, greaterThan(0), reason: 'hour $h');
    }
  });
}
