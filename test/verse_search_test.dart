import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/verse_search.dart';

void main() {
  // These rely on quran_seed.dart's 4-surah fallback (Al-Fatihah,
  // Al-Ikhlas, Al-Falaq, An-Nas) — the only data available without
  // loading the full-Quran asset, which a plain unit test doesn't do.

  test(
      'finds a verse by a plain-text (no diacritics) substring of its '
      'Persian translation', () {
    final results = searchVerses('بخشنده');
    expect(results, isNotEmpty);
    expect(
      results.any((m) => m.surah.number == 1 && m.ayah.number == 1),
      isTrue,
      reason: 'Al-Fatihah 1:1 translation contains "بخشندۀ"',
    );
  });

  test('finds a verse by a substring unique to one ayah, not others', () {
    final results = searchVerses('جزا');
    expect(results, hasLength(1));
    expect(results.single.surah.number, 1);
    expect(results.single.ayah.number, 4); // "مالک روز جزاء است."
  });

  test('an empty or whitespace-only query returns no results', () {
    expect(searchVerses(''), isEmpty);
    expect(searchVerses('   '), isEmpty);
  });

  test('results respect the limit parameter', () {
    // "الله" appears in more than one ayah across the fallback surahs.
    final unlimited = searchVerses('الله');
    expect(unlimited.length, greaterThan(1));
    final limited = searchVerses('الله', limit: 1);
    expect(limited, hasLength(1));
    expect(limited.first.surah.number, unlimited.first.surah.number);
    expect(limited.first.ayah.number, unlimited.first.ayah.number);
  });

  test('results come back in Quran order (surah, then ayah)', () {
    final results = searchVerses('الله');
    for (var i = 1; i < results.length; i++) {
      final prev = results[i - 1];
      final cur = results[i];
      final prevKey = prev.surah.number * 1000 + prev.ayah.number;
      final curKey = cur.surah.number * 1000 + cur.ayah.number;
      expect(curKey, greaterThan(prevKey));
    }
  });
}
