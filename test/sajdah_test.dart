import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/sajdah.dart';

void main() {
  test('recognises a known sajdah ayah (As-Sajdah 15)', () {
    expect(isSajdahAyah(32, 15), isTrue);
  });

  test('recognises the first and last sajdah ayat in Quran order', () {
    expect(isSajdahAyah(7, 206), isTrue);
    expect(isSajdahAyah(96, 19), isTrue);
  });

  test('does not flag a neighbouring, non-sajdah ayah', () {
    expect(isSajdahAyah(32, 14), isFalse);
    expect(isSajdahAyah(32, 16), isFalse);
  });

  test('does not flag an unrelated surah/ayah pair', () {
    expect(isSajdahAyah(1, 1), isFalse);
  });

  test('there are exactly 14 sajdah verses', () {
    expect(sajdahVerseKeys.length, 14);
  });
}
