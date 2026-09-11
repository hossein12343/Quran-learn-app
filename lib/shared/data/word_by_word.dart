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
  final String transliteration;

  const WbwWord({
    required this.arabic,
    required this.translation,
    required this.transliteration,
  });
}

/// Builds a single word's own audio clip URL — a separate, much
/// smaller per-word clip set from the Quran.com word-by-word CDN, not
/// the everyayah.com reciter audio the rest of this app plays.
/// Deterministic from (surah, ayah, 1-based word position): confirmed
/// against the live API's own `audio_url` field for several
/// surah/ayah pairs (including a double-digit surah/ayah, to rule out
/// a padding-width fluke) before trusting the pattern, so nothing
/// here needs to be stored in assets/quran_wbw.json — `position` is
/// just `wordByWordFor(...)`'s list index + 1, since the one filtered-
/// out "end" marker per ayah (see fetch_word_by_word.py) always comes
/// after every real word, never between them.
String wordAudioUrl(int surahNumber, int ayahNumber, int position) {
  String pad3(int n) => n.toString().padLeft(3, '0');
  return 'https://audio.qurancdn.com/wbw/'
      '${pad3(surahNumber)}_${pad3(ayahNumber)}_${pad3(position)}.mp3';
}

Map<int, Map<int, List<WbwWord>>> _wordByWord = {};

bool wordByWordLoaded = false;

List<WbwWord>? wordByWordFor(int surahNumber, int ayahNumber) =>
    _wordByWord[surahNumber]?[ayahNumber];

/// The whole ayah's Latin-script reading guide — just this same
/// per-word data's own `transliteration` fields, joined with spaces.
/// No separate fetch or asset: it rides along with the word-by-word
/// data, so turning this feature on lazy-loads the exact same file.
String? transliterationFor(int surahNumber, int ayahNumber) {
  final words = wordByWordFor(surahNumber, ayahNumber);
  if (words == null) return null;
  return words
      .map((w) => w.transliteration)
      .where((t) => t.isNotEmpty)
      .join(' ');
}

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
            transliteration: w['transliteration'] as String? ?? '',
          ),
      ];
    }
    result[sm['number'] as int] = ayat;
  }
  return result;
}
