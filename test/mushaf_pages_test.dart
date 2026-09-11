import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/mushaf_pages.dart';

void main() {
  test('there are exactly 604 pages, the standard Uthmani mushaf count', () {
    expect(pageStarts.length, 604);
    expect(mushafTotalPages, 604);
  });

  test('page numbers are sequential 1..604 with no gaps or duplicates', () {
    for (var i = 0; i < pageStarts.length; i++) {
      expect(pageStarts[i].page, i + 1);
    }
  });

  test('page 1 starts at 1:1, matching every printed mushaf', () {
    expect(pageStarts.first.surah, 1);
    expect(pageStarts.first.ayah, 1);
  });

  test(
      'page 604 (the last) starts at 112:1 — Al-Ikhlas, matching the '
      'standard mushaf', () {
    expect(pageStarts.last.page, 604);
    expect(pageStarts.last.surah, 112);
  });

  test('surah numbers never decrease across consecutive pages', () {
    for (var i = 1; i < pageStarts.length; i++) {
      expect(
          pageStarts[i].surah, greaterThanOrEqualTo(pageStarts[i - 1].surah));
    }
  });

  // These rely on quran_seed.dart's 4-surah fallback (Al-Fatihah,
  // Al-Ikhlas, Al-Falaq, An-Nas) — the only data available without
  // loading the full-Quran asset, which a plain unit test doesn't do.

  test(
      'contentForPage(1) returns all of Al-Fatihah, since page 2 starts '
      'a surah not in the fallback (gracefully skipped, not a crash)', () {
    final content = contentForPage(1);
    expect(content.page, 1);
    expect(content.segments, hasLength(1));
    expect(content.segments.single.surah.number, 1);
    expect(content.segments.single.ayat, hasLength(7));
  });

  test(
      'contentForPage(604), the last page, has no exclusive upper bound '
      'and correctly spans three short surahs on the fallback data', () {
    final content = contentForPage(604);
    expect(content.segments, hasLength(3));
    expect(content.segments[0].surah.number, 112);
    expect(content.segments[0].ayat, hasLength(4));
    expect(content.segments[1].surah.number, 113);
    expect(content.segments[1].ayat, hasLength(5));
    expect(content.segments[2].surah.number, 114);
    expect(content.segments[2].ayat, hasLength(6));
  });
}
