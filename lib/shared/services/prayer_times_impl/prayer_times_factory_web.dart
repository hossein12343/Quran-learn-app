import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../net/net.dart';
import '../prayer_times.dart';
import '../store/local_store.dart';

PrayerTimesService makeService() => WebPrayerTimesService();

/// Browser Geolocation (`dart:html`, no package needed) + the free Aladhan
/// API (api.aladhan.com — no key required) for the actual calculation, so
/// there's no need to hand-roll astronomical prayer-time math.
///
/// Calculation method defaults to **7 ("University of Tehran")** rather
/// than Aladhan's own default (3, Muslim World League) — this app is
/// Persian-first, and that method is the one in common use in Iran. See
/// https://aladhan.com/calculation-methods for the full list; a future
/// pass could make this user-configurable if the audience broadens.
class WebPrayerTimesService implements PrayerTimesService {
  static const _latKey = 'prayer_lat';
  static const _lonKey = 'prayer_lon';
  static const int _calculationMethod = 7;

  @override
  Future<PrayerTimes?> fetchToday() async {
    try {
      final loc = await resolveLocation();
      if (loc == null) return null;
      final now = DateTime.now();
      final date =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final url = 'https://api.aladhan.com/v1/timings/$date'
          '?latitude=${loc.$1}&longitude=${loc.$2}&method=$_calculationMethod';
      final res = await Net.request('GET', url);
      if (!res.ok) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final timings = (body['data'] as Map<String, dynamic>)['timings']
          as Map<String, dynamic>;
      TimeOfDay parse(String key) {
        // Aladhan returns "HH:mm" or "HH:mm (TZ)" depending on tuning
        // params — this app passes none, but strip defensively either way.
        final raw = (timings[key] as String).split(' ').first;
        final parts = raw.split(':');
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }

      return PrayerTimes(
        fajr: parse('Fajr'),
        dhuhr: parse('Dhuhr'),
        asr: parse('Asr'),
        maghrib: parse('Maghrib'),
        isha: parse('Isha'),
        latitude: loc.$1,
        longitude: loc.$2,
      );
    } on Object {
      // Network failure, denied permission, malformed response — best
      // effort throughout; the caller falls back to the last-known time.
      return null;
    }
  }

  /// (latitude, longitude) — from a cached previous lookup if there is one
  /// (avoids re-prompting for location permission every day), else a fresh
  /// `getCurrentPosition()` call, cached on success.
  @override
  Future<(double, double)?> resolveLocation() async {
    final cachedLat = LocalStore.get(_latKey);
    final cachedLon = LocalStore.get(_lonKey);
    if (cachedLat != null && cachedLon != null) {
      return (double.parse(cachedLat), double.parse(cachedLon));
    }
    try {
      final geolocation = html.window.navigator.geolocation;
      final pos = await geolocation.getCurrentPosition(
        enableHighAccuracy: false,
        timeout: const Duration(seconds: 8),
      );
      final lat = pos.coords?.latitude?.toDouble();
      final lon = pos.coords?.longitude?.toDouble();
      if (lat == null || lon == null) return null;
      LocalStore.set(_latKey, lat.toString());
      LocalStore.set(_lonKey, lon.toString());
      return (lat, lon);
    } on Object {
      // Permission denied, unsupported, or blocked by Permissions-Policy.
      return null;
    }
  }
}
