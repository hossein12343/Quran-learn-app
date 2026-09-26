import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/weak_spots.dart';

void main() {
  const ayah = ['a', 'b', 'c', 'd', 'e', 'f'];

  group('missedWordPositions', () {
    test('a perfect answer misses nothing', () {
      expect(missedWordPositions(ayah, ayah), isEmpty);
    });

    test('one forgotten word blames only that word, not everything after', () {
      // "c" left out, so everything after it sits one place early.
      expect(missedWordPositions(ayah, ['a', 'b', 'd', 'e', 'f', 'x']), [2]);
    });

    test('two swapped words blame one of them', () {
      expect(missedWordPositions(ayah, ['a', 'c', 'b', 'd', 'e', 'f']),
          hasLength(1));
    });

    test('a distractor tile in place of a word blames that word', () {
      expect(missedWordPositions(ayah, ['a', 'b', 'x', 'd', 'e', 'f']), [2]);
    });

    test('an empty answer misses every word', () {
      expect(missedWordPositions(ayah, const []), [0, 1, 2, 3, 4, 5]);
    });
  });

  group('weakSpotsFromWordBank', () {
    test('a right answer proves every word and the whole ayah', () {
      final r = weakSpotsFromWordBank(ayah, ayah, true);
      expect(r.missed, isEmpty);
      expect(r.right, [WeakSpot.wholeAyah, 0, 1, 2, 3, 4, 5]);
    });

    test('a slip on a couple of words blames just those words', () {
      final r =
          weakSpotsFromWordBank(ayah, ['a', 'x', 'c', 'd', 'e', 'f'], false);
      expect(r.missed, [1]);
      expect(r.right, isEmpty);
    });

    test('missing most of the ayah blames the ayah, not a word list', () {
      final r = weakSpotsFromWordBank(ayah, ['a', 'b'], false);
      expect(r.missed, [WeakSpot.wholeAyah]);
    });
  });

  group('WeakSpots', () {
    test('a spot leaves the list after two right answers in a row', () {
      final spots = WeakSpots()..missed(1, 2, 3);
      expect(spots.answeredRight(1, 2, 3), isFalse);
      expect(spots.length, 1);
      expect(spots.answeredRight(1, 2, 3), isTrue);
      expect(spots.isEmpty, isTrue);
    });

    test('a new miss resets the run of right answers', () {
      final spots = WeakSpots()..missed(1, 2, 3);
      spots.answeredRight(1, 2, 3);
      spots.missed(1, 2, 3);
      spots.answeredRight(1, 2, 3);
      expect(spots.length, 1);
      expect(spots[WeakSpot.keyOf(1, 2, 3)]!.misses, 2);
    });

    test('a right answer on a word never missed changes nothing', () {
      final spots = WeakSpots();
      expect(spots.answeredRight(1, 2, 3), isFalse);
      expect(spots.isEmpty, isTrue);
    });

    test('ranks most-missed first, then most recent', () {
      final t = DateTime(2026, 9, 1);
      final spots = WeakSpots()
        ..missed(1, 0, 0, at: t)
        ..missed(1, 0, 1, at: t)
        ..missed(1, 0, 1, at: t)
        ..missed(1, 0, 2, at: t.add(const Duration(days: 1)));
      expect(spots.ranked().map((s) => s.word), [1, 2, 0]);
      expect(spots.ranked(limit: 1).single.word, 1);
    });

    test('keeps only the most recent spots beyond the cap', () {
      final t = DateTime(2026, 9, 1);
      final spots = WeakSpots();
      for (var i = 0; i <= WeakSpots.maxSpots; i++) {
        spots.missed(1, i, 0, at: t.add(Duration(minutes: i)));
      }
      expect(spots.length, WeakSpots.maxSpots);
      expect(spots[WeakSpot.keyOf(1, 0, 0)], isNull);
    });

    test('survives saving and loading', () {
      final spots = WeakSpots()
        ..missed(2, 5, WeakSpot.wholeAyah)
        ..missed(2, 5, 1);
      spots.answeredRight(2, 5, 1);
      final restored = WeakSpots()..loadJson(spots.toJson());
      expect(restored.length, 2);
      expect(restored[WeakSpot.keyOf(2, 5, 1)]!.rightInARow, 1);
      expect(restored[WeakSpot.keyOf(2, 5, -1)]!.isWholeAyah, isTrue);
    });

    test('ignores damaged saved data instead of crashing', () {
      final spots = WeakSpots()
        ..loadJson([
          {'s': 1},
          'junk',
          {'s': 1, 'a': 0, 'w': 0, 'm': 1, 't': '2026-09-01T00:00:00.000'},
        ]);
      expect(spots.length, 1);
    });
  });
}
