import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// One word of an ayah, with its own Uthmani form and Persian meaning
/// (see `tools/fetch_word_by_word.py`). `arabic` is this view's own
/// source of truth for per-word text — it is not guaranteed to
/// whitespace-align with `Ayah.arabic` (a pause mark like "ۚ" rides
/// along with the preceding word here), so the two are never mixed in
/// the same render.
class WbwWord {
  final String arabic;
  final String translation;

  const WbwWord({required this.arabic, required this.translation});
}

Map<int, Map<int, List<WbwWord>>> _wordByWord = {};

bool wordByWordLoaded = false;

List<WbwWord>? wordByWordFor(int surahNumber, int ayahNumber) =>
    _wordByWord[surahNumber]?[ayahNumber];

/// Loaded lazily on first toggle use, same reasoning as
/// `translation2.dart`: a per-word study aid, not core reading data
/// everyone needs to pay the fetch/parse cost for at splash.
Future<void> loadWordByWord() async {
  if (wordByWordLoaded) return;
  try {
    final raw = await rootBundle.loadString('assets/quran_wbw.json');
    _wordByWord = await compute(_parseWordByWordJson, raw);
    wordByWordLoaded = true;
  } on Object {
    // Asset missing or malformed — the toggle just finds nothing and
    // the reader falls back to its normal single-block Arabic text.
  }
}

Map<int, Map<int, List<WbwWord>>> _parseWordByWordJson(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final result = <int, Map<int, List<WbwWord>>>{};
  for (final s in data['surahs'] as List) {
    final sm = s as Map<String, dynamic>;
    final ayat = <int, List<WbwWord>>{};
    for (final a in sm['ayat'] as List) {
      final am = a as Map<String, dynamic>;
      ayat[am['number'] as int] = [
        for (final w in am['words'] as List)
          WbwWord(
            arabic: (w as Map<String, dynamic>)['arabic'] as String,
            translation: w['translation'] as String,
          ),
      ];
    }
    result[sm['number'] as int] = ayat;
  }
  return result;
}
