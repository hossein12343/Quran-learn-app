import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/features/quiz/quiz_engine.dart';
import 'package:quran_learn_app/shared/data/quran_seed.dart';

Surah _fakeSurah(int ayatCount) {
  return Surah(
    number: 9001,
    arabicName: 'اختبار',
    englishName: 'Test Surah',
    meaning: 'Test',
    revelation: 'Meccan',
    ayat: List<Ayah>.generate(
      ayatCount,
      (i) => Ayah(i + 1, 'كلمة واحد ${i + 1} ثلاثة أربعة', 'Ayah ${i + 1}'),
    ),
  );
}

void main() {
  test('a fresh ayah is taught (listen, then repeat) before any drill', () {
    final s = Session(_fakeSurah(3));

    final first = s.next()!;
    expect(first.kind, ExerciseKind.listen);
    expect(first.ayahIndex, 0);
    s.acknowledgeTeach(first);

    final second = s.next()!;
    expect(second.kind, ExerciseKind.repeat);
    expect(second.ayahIndex, 0);
    s.acknowledgeTeach(second);

    final third = s.next()!;
    expect(third.kind, ExerciseKind.drill);
  });

  test('ayat are taught strictly in order, one fully learned before the next starts', () {
    final s = Session(_fakeSurah(5));
    final introducedOrder = <int>[];
    for (var i = 0; i < 200; i++) {
      final ex = s.next();
      if (ex == null) break;
      if (ex.kind == ExerciseKind.listen && !introducedOrder.contains(ex.ayahIndex)) {
        introducedOrder.add(ex.ayahIndex);
        // Every ayah before this one must already be fully held — nothing
        // new starts until the previous one is finished.
        for (var j = 0; j < ex.ayahIndex; j++) {
          expect(s.items[j].held, isTrue,
              reason: 'ayah $j should be held before ayah ${ex.ayahIndex} starts');
        }
      }
      // Drill.next always looks backward at an already-mastered ayah, never
      // forward into untaught content.
      if (ex.kind == ExerciseKind.drill && ex.drill == Drill.next) {
        expect(ex.ayahIndex, greaterThan(0));
        expect(s.items[ex.ayahIndex - 1].held, isTrue);
      }
      if (ex.kind != ExerciseKind.drill) {
        s.acknowledgeTeach(ex);
      } else {
        s.submit(ex, true);
      }
      if (s.stage == Stage.sealed) break;
    }
    expect(s.stage, Stage.sealed);
    expect(introducedOrder, [0, 1, 2, 3, 4]);
  });

  test('a long surah gates one chunk at a time, not the whole surah', () {
    final s = Session(_fakeSurah(kChunkSize + 3));
    expect(s.chunkCount, 2);

    // Drive chunk 0's build phase (listen/repeat/drills) to completion.
    // next() transitions build -> gate internally and, in the same call,
    // returns the first gate exercise rather than null — so once the stage
    // has flipped, stop without submitting that exercise; the test drives
    // the gate itself below, starting cleanly from gateIndex 0.
    while (s.stage == Stage.build && s.currentChunk == 0) {
      final ex = s.next()!;
      if (s.stage != Stage.build) break;
      if (ex.kind != ExerciseKind.drill) {
        s.acknowledgeTeach(ex);
      } else {
        s.submit(ex, true);
      }
    }

    expect(s.stage, Stage.gate);
    expect(s.gateIndex, 0);
    // The gate for chunk 0 only walks ayat 0..kChunkSize-1, not the whole
    // (kChunkSize + 3)-ayah surah.
    for (var i = 0; i < kChunkSize; i++) {
      final ex = s.next()!;
      expect(ex.isGate, isTrue);
      expect(ex.ayahIndex, i);
      s.submit(ex, true);
    }
    // Chunk 0 sealed, chunk 1 begins — not sealed yet, since 3 ayat remain.
    expect(s.stage, Stage.build);
    expect(s.currentChunk, 1);
  });

  test('resuming with alreadyHeld skips chunks already fully held', () {
    final surah = _fakeSurah(kChunkSize + 2);
    final allOfChunkZero = Set<int>.from(List.generate(kChunkSize, (i) => i));
    final s = Session(surah, alreadyHeld: allOfChunkZero);

    expect(s.currentChunk, 1);
    expect(s.heldCount, kChunkSize);
    final ex = s.next()!;
    // Straight into chunk 1's content, not re-teaching chunk 0.
    expect(ex.ayahIndex, greaterThanOrEqualTo(kChunkSize));
  });

  test('singleLevel seals after one chunk instead of rolling into the next', () {
    final s = Session(_fakeSurah(kChunkSize + 3), singleLevel: true);
    while (s.stage == Stage.build || s.stage == Stage.gate) {
      final ex = s.next()!;
      if (s.stage != Stage.build && s.stage != Stage.gate) break;
      if (ex.kind != ExerciseKind.drill) {
        s.acknowledgeTeach(ex);
      } else {
        s.submit(ex, true);
      }
    }
    expect(s.stage, Stage.sealed);
    // Only chunk 0's 8 ayat were ever touched — the 3 remaining ayat were
    // never introduced, because this Session stops after one level.
    expect(s.heldCount, kChunkSize);
    expect(s.sealedWholeSurah, isFalse);
  });

  test('startChunk jumps straight into a specific level, and sealedWholeSurah '
      'is true only when that level was the surah\'s last', () {
    final surah = _fakeSurah(kChunkSize + 3);
    final s = Session(surah, startChunk: 1, singleLevel: true);
    expect(s.currentChunk, 1);

    final first = s.next()!;
    expect(first.ayahIndex, greaterThanOrEqualTo(kChunkSize));

    while (s.stage == Stage.build || s.stage == Stage.gate) {
      final ex = s.next()!;
      if (s.stage != Stage.build && s.stage != Stage.gate) break;
      if (ex.kind != ExerciseKind.drill) {
        s.acknowledgeTeach(ex);
      } else {
        s.submit(ex, true);
      }
    }
    expect(s.stage, Stage.sealed);
    expect(s.sealedWholeSurah, isTrue); // chunk 1 was the last chunk
  });

  test('a mistake during the gate restarts only the current chunk\'s gate', () {
    final s = Session(_fakeSurah(kChunkSize + 2));
    // Fast-forward chunk 0 to the gate, without consuming the transition
    // exercise next() returns in the same call that flips the stage.
    while (s.stage == Stage.build) {
      final ex = s.next()!;
      if (s.stage != Stage.build) break;
      if (ex.kind != ExerciseKind.drill) {
        s.acknowledgeTeach(ex);
      } else {
        s.submit(ex, true);
      }
    }
    expect(s.stage, Stage.gate);
    final ex = s.next()!;
    expect(ex.ayahIndex, 0);
    s.submit(ex, false); // miss the very first gate item
    expect(s.gateIndex, 0); // back to the start of THIS chunk, not ayah 0 of nothing else
    expect(s.currentChunk, 0);
    expect(s.hearts, kHearts - 1);
  });

  test(
      "Al-Fatihah's own ayah 1 (the basmala) is played, never taught or "
      'drilled', () {
    final fatihah = Surah(
      number: 1,
      arabicName: 'الفاتحة',
      englishName: 'Test Fatihah',
      meaning: 'Test',
      revelation: 'Meccan',
      ayat: List<Ayah>.generate(
        4,
        (i) => Ayah(i + 1, 'كلمة ${i + 1} اثنان ثلاثة', 'Ayah ${i + 1}'),
      ),
    );
    final s = Session(fatihah);

    // Pre-held from the start — never appears as its own teach/drill step.
    expect(s.items[0].held, isTrue);

    final first = s.next()!;
    expect(first.kind, ExerciseKind.listen);
    expect(first.ayahIndex, 1); // teaching starts at the 2nd ayah, not the basmala

    // Drive the whole session to the gate and confirm it never re-tests
    // ayah 0 either.
    var ex = first;
    for (var i = 0; i < 200 && s.stage == Stage.build; i++) {
      if (ex.kind != ExerciseKind.drill) {
        s.acknowledgeTeach(ex);
      } else {
        s.submit(ex, true);
      }
      final next = s.next();
      if (next == null) break;
      ex = next;
    }
    expect(s.stage, Stage.gate);
    expect(s.gateIndex, 1); // gate starts at ayah 1, skipping the basmala
  });
}
