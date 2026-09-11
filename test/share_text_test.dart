import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/features/quran/quran_page.dart';

void main() {
  test(
      'composes Arabic, then translation, then a plain surah:ayah '
      'reference, with no app link', () {
    final text = composeShareText(
      englishName: 'Al-Fatiha',
      arabicName: 'ٱلْفَاتِحَة',
      ayahNumber: 1,
      arabic: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      translation: 'به نام خداوند بخشندۀ مهربان',
    );

    expect(text, contains('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'));
    expect(text, contains('به نام خداوند بخشندۀ مهربان'));
    expect(text, contains('Al-Fatiha'));
    expect(text, contains('ٱلْفَاتِحَة'));
    expect(text, contains('1'));
    expect(text, isNot(contains('http')));

    // Arabic text must come first, ahead of the translation and the
    // reference line — it's the actual content being shared.
    final arabicIndex = text.indexOf('بِسْمِ');
    final translationIndex = text.indexOf('به نام');
    final referenceIndex = text.indexOf('Al-Fatiha');
    expect(arabicIndex, lessThan(translationIndex));
    expect(translationIndex, lessThan(referenceIndex));
  });
}
