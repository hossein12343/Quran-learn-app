import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Offline checks on the bundled Quran text. The character-for-character
/// comparison against the source needs network access and lives in
/// tools/verify_quran_text.py — run that before shipping any text change.

/// The standard ayah count of each surah, 1 to 114 (Hafs, Kufan counting),
/// as printed in the Madinah Mushaf.
const _ayahCounts = <int>[
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, //
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, //
  54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, //
  49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, //
  44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, //
  26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, //
  6, 3, 5, 4, 5, 6,
];

void main() {
  final surahs = (jsonDecode(File('assets/quran_full.json').readAsStringSync())
      as Map<String, dynamic>)['surahs'] as List<dynamic>;

  test('the reference counts themselves add up to 6,236 ayat in 114 surahs',
      () {
    expect(_ayahCounts.length, 114);
    expect(_ayahCounts.fold<int>(0, (a, b) => a + b), 6236);
  });

  test('all 114 surahs are present, in order', () {
    expect(surahs.length, 114);
    for (var i = 0; i < surahs.length; i++) {
      expect((surahs[i] as Map)['number'], i + 1);
    }
  });

  test('every surah has its standard number of ayat, numbered 1..n', () {
    for (var i = 0; i < surahs.length; i++) {
      final ayat = (surahs[i] as Map)['ayat'] as List<dynamic>;
      expect(ayat.length, _ayahCounts[i], reason: 'surah ${i + 1}');
      for (var j = 0; j < ayat.length; j++) {
        expect((ayat[j] as Map)['number'], j + 1,
            reason: 'surah ${i + 1}, position ${j + 1}');
      }
    }
  });

  test('no ayah is empty or carries leftover markup', () {
    final markup = RegExp(r'[<>]|&[a-z]+;');
    for (final s in surahs) {
      for (final a in (s as Map)['ayat'] as List<dynamic>) {
        final text = (a as Map)['arabic'] as String;
        final ref = '${s['number']}:${a['number']}';
        expect(text.trim(), isNotEmpty, reason: ref);
        expect(markup.hasMatch(text), isFalse, reason: ref);
      }
    }
  });
}
