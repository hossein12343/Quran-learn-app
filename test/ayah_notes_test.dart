import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/ayah_notes.dart';

void main() {
  // A surah/ayah pair no real Quran content ever uses, so this test
  // can't collide with an actual note a developer running these tests
  // locally might have saved for themselves — LocalStore.io persists
  // to a real file on disk (see local_store_io.dart), not an in-memory
  // fake, so tests still have to clean up after themselves here.
  const surah = 999;
  const ayah = 1;

  tearDown(() => AyahNotes.set(surah, ayah, ''));

  test('has no note by default', () {
    expect(AyahNotes.has(surah, ayah), isFalse);
    expect(AyahNotes.get(surah, ayah), isNull);
  });

  test('saves and reads back a note', () {
    AyahNotes.set(surah, ayah, 'a reflection on this ayah');
    expect(AyahNotes.has(surah, ayah), isTrue);
    expect(AyahNotes.get(surah, ayah), 'a reflection on this ayah');
  });

  test('trims surrounding whitespace', () {
    AyahNotes.set(surah, ayah, '  padded note  ');
    expect(AyahNotes.get(surah, ayah), 'padded note');
  });

  test('an empty or whitespace-only note deletes it instead of saving blank',
      () {
    AyahNotes.set(surah, ayah, 'something');
    expect(AyahNotes.has(surah, ayah), isTrue);

    AyahNotes.set(surah, ayah, '   ');
    expect(AyahNotes.has(surah, ayah), isFalse);
  });
}
