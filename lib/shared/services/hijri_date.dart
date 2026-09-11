import 'dart:convert';
import 'net/net.dart';

/// Today's Hijri (Islamic lunar calendar) date, shown alongside the
/// Gregorian one on Home — the app is Persian-first, and the Hijri
/// calendar is part of everyday religious life for its audience the
/// same way it's absent from a purely secular app.
class HijriToday {
  final int day;
  final int monthNumber;
  final int year;

  const HijriToday({
    required this.day,
    required this.monthNumber,
    required this.year,
  });

  /// The 12 Hijri month names in Persian — a fixed, universally-known
  /// list (same certainty as weekday names), not sourced from the API
  /// itself: aladhan.com's own endpoint only returns English/Arabic
  /// month names, and Persian commonly uses its own established forms
  /// rather than the bare Arabic ones.
  static const List<String> _monthNamesFa = [
    'محرم',
    'صفر',
    'ربیع‌الاول',
    'ربیع‌الثانی',
    'جمادی‌الاول',
    'جمادی‌الثانی',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذی‌القعده',
    'ذی‌الحجه',
  ];

  String get monthNameFa => _monthNamesFa[monthNumber - 1];

  static const List<String> _digitsFa = [
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹'
  ];

  static String _faDigits(int n) =>
      n.toString().split('').map((c) => _digitsFa[int.parse(c)]).join();

  /// e.g. "۲۹ ربیع‌الاول ۱۴۴۸".
  String get label => '${_faDigits(day)} $monthNameFa ${_faDigits(year)}';
}

/// Fetched fresh each call (a day boundary can pass while the app
/// stays open) — the caller is expected to cache it for the session,
/// same as `prayer_times.dart`'s own caller-side caching.
Future<HijriToday?> fetchHijriToday() async {
  final now = DateTime.now();
  final date =
      '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  try {
    final res = await Net.request(
      'GET',
      'https://api.aladhan.com/v1/gToH?date=$date',
    );
    if (!res.ok) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final hijri =
        (data['data'] as Map<String, dynamic>)['hijri'] as Map<String, dynamic>;
    return HijriToday(
      day: int.parse(hijri['day'] as String),
      monthNumber: (hijri['month'] as Map<String, dynamic>)['number'] as int,
      year: int.parse(hijri['year'] as String),
    );
  } on Object {
    return null;
  }
}
