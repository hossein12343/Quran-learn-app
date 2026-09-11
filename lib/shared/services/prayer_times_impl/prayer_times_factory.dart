import '../prayer_times.dart';
import 'prayer_times_factory_stub.dart'
    if (dart.library.html) 'prayer_times_factory_web.dart' as impl;

/// Real geolocation + Aladhan lookup on web, the no-op stub everywhere else.
PrayerTimesService createPrayerTimesService() => impl.makeService();
