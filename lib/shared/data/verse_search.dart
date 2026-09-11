import 'quran_seed.dart';

class VerseMatch {
  final Surah surah;
  final Ayah ayah;
  const VerseMatch(this.surah, this.ayah);
}

/// Same diacritics range as `RecitationScorer.normalise` in
/// `recite_check.dart` (that one is tuned for matching a speech-
/// recognition transcript, this one for whatever a person happens to
/// type — kept independent rather than shared, so a future tweak to one
/// doesn't silently change the other). Built from explicit code points
/// rather than typed as literal combining-mark characters or `\uXXXX`
/// escapes in source — both are easy to silently mistransform when
/// copied through several tools, and a wrong diacritic range would fail
/// silently (searches would just under- or over-match, nothing would
/// throw), so this is the one part of the file worth being fully
/// unambiguous about. Arabic combining marks U+064B–0652, madd (0670),
/// superscript alef/small high marks (0653–0655), and tatweel (0640).
String _charRange(int from, int to) {
  final buf = StringBuffer();
  for (var c = from; c <= to; c++) {
    buf.writeCharCode(c);
  }
  return buf.toString();
}

final RegExp _diacritics = RegExp(
  '[${_charRange(0x064B, 0x0652)}'
  '${_charRange(0x0670, 0x0670)}'
  '${_charRange(0x0653, 0x0655)}'
  '${_charRange(0x0640, 0x0640)}]',
);

/// Folds diacritics and common Arabic/Persian letter-shape variants
/// (hamza forms, taa marbuta, yaa/kaf) so "typed it slightly differently
/// than the source text" doesn't defeat a search.
String _normalize(String s) => s
    .replaceAll(_diacritics, '')
    .replaceAll(String.fromCharCode(0x0671), 'ا') // alif wasla -> alif
    .replaceAll(String.fromCharCode(0x0622), 'ا') // alif madda -> alif
    .replaceAll(String.fromCharCode(0x0623), 'ا') // alif hamza above
    .replaceAll(String.fromCharCode(0x0625), 'ا') // alif hamza below
    .replaceAll(String.fromCharCode(0x0629), 'ه') // taa marbuta -> haa
    .replaceAll(String.fromCharCode(0x06C0), 'ه') // persian heh+hamza
    .replaceAll(String.fromCharCode(0x0649), 'ي') // alif maqsura -> yaa
    .replaceAll(String.fromCharCode(0x064A), 'ی') // arabic yaa -> persian
    .replaceAll(String.fromCharCode(0x0643), 'ک') // arabic kaf -> persian
    .toLowerCase();

/// Searches every loaded ayah's Arabic text and Persian translation for
/// [query] as a plain substring after normalization — no ranking, no
/// fuzzy matching. That's deliberately all "I half-remember a verse and
/// want to find it" actually needs; ranking would be solving a problem
/// nobody has here. Returns at most [limit] matches, in Quran order.
List<VerseMatch> searchVerses(String query, {int limit = 50}) {
  final q = _normalize(query.trim());
  if (q.isEmpty) return const [];
  final results = <VerseMatch>[];
  for (final s in surahs) {
    for (final a in s.ayat) {
      if (results.length >= limit) return results;
      if (_normalize(a.translation).contains(q) ||
          _normalize(a.arabic).contains(q)) {
        results.add(VerseMatch(s, a));
      }
    }
  }
  return results;
}
