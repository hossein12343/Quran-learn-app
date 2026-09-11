import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// A second Persian translation (IslamHouse.com — see
/// `tools/fetch_translation2.py`), alongside the Hussein Taji Kal Dari
/// one `quran_seed.dart` uses by default. Loaded lazily on first actual
/// use (not at splash like the main Quran text) — this is an opt-in
/// toggle for comparing phrasing, not something every session needs, so
/// there's no reason to make everyone pay for the fetch/parse.
Map<int, Map<int, String>> _translation2 = {};

bool translation2Loaded = false;

String? translation2For(int surahNumber, int ayahNumber) =>
    _translation2[surahNumber]?[ayahNumber];

Future<void> loadTranslation2() async {
  if (translation2Loaded) return;
  try {
    final raw = await rootBundle.loadString('assets/quran_translation2.json');
    _translation2 = await compute(_parseTranslation2Json, raw);
    translation2Loaded = true;
  } on Object {
    // Asset missing or malformed — the toggle just falls back to the
    // default translation for every ayah (see quran_page.dart), same
    // as if the user had never switched at all.
  }
}

Map<int, Map<int, String>> _parseTranslation2Json(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final result = <int, Map<int, String>>{};
  for (final s in data['surahs'] as List) {
    final sm = s as Map<String, dynamic>;
    final ayat = <int, String>{};
    for (final a in sm['ayat'] as List) {
      final am = a as Map<String, dynamic>;
      ayat[am['number'] as int] = am['text'] as String;
    }
    result[sm['number'] as int] = ayat;
  }
  return result;
}
