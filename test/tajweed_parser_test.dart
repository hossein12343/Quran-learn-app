import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/tajweed_parser.dart';

void main() {
  const base = TextStyle(fontSize: 20, color: Colors.black);

  test('plain text with no markup comes back as one unstyled span', () {
    final spans = parseTajweed('بِسْمِ اللَّهِ', base);

    expect(spans, hasLength(1));
    final span = spans.single as TextSpan;
    expect(span.text, 'بِسْمِ اللَّهِ');
    expect(span.style!.color, base.color);
  });

  test('a single-character rule span gets its rule color, not the base one',
      () {
    // Al-Fatihah 1:1's hamzat-ul-wasl on the alif of "ٱلرَّحْمَٰنِ".
    final spans = parseTajweed('بِسْمِ [h:1[ٱ]للَّهِ', base);

    final texts = spans.map((s) => (s as TextSpan).text).toList();
    expect(texts, ['بِسْمِ ', 'ٱ', 'للَّهِ']);

    final coloredSpan = spans[1] as TextSpan;
    expect(coloredSpan.style!.color, tajweedRuleColors['h']);
    expect(coloredSpan.style!.fontSize, base.fontSize,
        reason: 'only the color should change, not the rest of the style');

    final plainBefore = spans[0] as TextSpan;
    expect(plainBefore.style!.color, base.color);
  });

  test('a rule span can cover multiple characters across a word boundary', () {
    // From Ayat al-Kursi (2:255): idgham-with-ghunnah merging "ةٌ و".
    final spans = parseTajweed('سِنَ[a:1470[ةٌ و]َلَا', base);

    final texts = spans.map((s) => (s as TextSpan).text).toList();
    expect(texts, ['سِنَ', 'ةٌ و', 'َلَا']);
    expect((spans[1] as TextSpan).style!.color, tajweedRuleColors['a']);
  });

  test(
      'every declared rule letter has a distinct or intentionally-shared '
      'color entry', () {
    const metaChars = 'hslnpmqocfwiaudbg';
    for (final c in metaChars.split('')) {
      expect(tajweedRuleColors, contains(c), reason: 'missing color for $c');
    }
  });
}
