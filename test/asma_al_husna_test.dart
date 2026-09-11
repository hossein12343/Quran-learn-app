import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/asma_al_husna.dart';

void main() {
  test('has exactly 99 names', () {
    expect(asmaAlHusna.length, 99);
  });

  test('numbers are sequential 1..99 with no gaps or duplicates', () {
    final numbers = asmaAlHusna.map((n) => n.number).toList();
    expect(numbers, List.generate(99, (i) => i + 1));
  });

  test('the first name is Ar-Rahman', () {
    expect(asmaAlHusna.first.transliteration, contains('Rahmaan'));
  });

  test('every entry has non-empty Arabic, transliteration, and meaning', () {
    for (final n in asmaAlHusna) {
      expect(n.arabic, isNotEmpty, reason: 'name #${n.number}');
      expect(n.transliteration, isNotEmpty, reason: 'name #${n.number}');
      expect(n.meaning, isNotEmpty, reason: 'name #${n.number}');
    }
  });
}
