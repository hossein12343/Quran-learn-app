import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;

/// Raw tajweed-marked-up text (Al Quran Cloud's `quran-tajweed` edition —
/// see `tools/fetch_tajweed.py`), keyed by surah number then by
/// [Ayah.number] (the ayah's position *within* the surah, matching
/// `quran_seed.dart`'s own numbering, not the API's global 1–6236 id).
Map<int, Map<int, String>> _tajweedText = {};

bool tajweedLoaded = false;

/// Bumped once [loadTajweedData] finishes, so a screen already built before
/// the asset loaded can rebuild once it's ready — same pattern as
/// `quran_seed.dart`'s `quranRevision`.
final ValueNotifier<int> tajweedRevision = ValueNotifier<int>(0);

String? tajweedTextFor(int surahNumber, int ayahNumber) =>
    _tajweedText[surahNumber]?[ayahNumber];

/// Loads `assets/quran_tajweed.json` once, off the UI isolate (same reason
/// as `loadFullQuran`: parsing ~6,236 ayat is real work). Safe to call
/// again; leaves tajweed coloring simply unavailable if the asset is
/// missing or malformed rather than throwing — this is an optional reading
/// aid, not something the app depends on to function.
Future<void> loadTajweedData() async {
  if (tajweedLoaded) return;
  try {
    final raw = await rootBundle.loadString('assets/quran_tajweed.json');
    _tajweedText = await compute(_parseTajweedJson, raw);
    tajweedLoaded = true;
    tajweedRevision.value++;
  } on Object {
    // Asset missing or malformed — tajweed coloring stays unavailable.
  }
}

Map<int, Map<int, String>> _parseTajweedJson(String raw) {
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
