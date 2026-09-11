import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/word_by_word.dart';

void main() {
  test('pads surah, ayah, and word position to 3 digits each', () {
    expect(wordAudioUrl(1, 1, 1),
        'https://audio.qurancdn.com/wbw/001_001_001.mp3');
  });

  test('handles double-digit surah/ayah/position without breaking the width',
      () {
    expect(wordAudioUrl(12, 5, 3),
        'https://audio.qurancdn.com/wbw/012_005_003.mp3');
  });

  test('handles a triple-digit ayah number (a long surah)', () {
    expect(wordAudioUrl(2, 255, 7),
        'https://audio.qurancdn.com/wbw/002_255_007.mp3');
  });
}
