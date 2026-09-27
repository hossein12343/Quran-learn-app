import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/daily_plan.dart';
import 'package:quran_learn_app/shared/services/learning_sync.dart';
import 'package:quran_learn_app/shared/services/weak_spots.dart';

LevelReview review(DateTime due, {int reps = 1}) =>
    LevelReview(due: due, reps: reps, ease: 2.5, gapDays: 3);

void main() {
  final monday = DateTime(2026, 9, 28);
  final friday = DateTime(2026, 10, 2);

  group('merge', () {
    test('keeps every sealed level and held ayah from both sides', () {
      final merged = LearningState.merge(
        LearningState(sealedLevels: {
          1000
        }, held: {
          1: {0, 1}
        }),
        LearningState(sealedLevels: {
          112000
        }, held: {
          1: {2},
          112: {0}
        }),
      );
      expect(merged.sealedLevels, {1000, 112000});
      expect(merged.held, {
        1: {0, 1, 2},
        112: {0}
      });
    });

    test("a level's review follows whichever side reviewed it last", () {
      final merged = LearningState.merge(
        LearningState(reviews: {1000: review(monday), 2000: review(friday)}),
        LearningState(
            reviews: {1000: review(friday, reps: 3), 3000: review(monday)}),
      );
      expect(merged.reviews[1000]!.due, friday);
      expect(merged.reviews[1000]!.reps, 3);
      expect(merged.reviews[2000]!.due, friday);
      expect(merged.reviews.keys, containsAll([1000, 2000, 3000]));
    });

    test('a device wiped by Safari gets the whole history back', () {
      final account = LearningState(
        sealedLevels: {1000},
        reviews: {1000: review(friday, reps: 4)},
        held: {
          1: {0, 1, 2, 3, 4, 5, 6}
        },
      );
      final merged = LearningState.merge(LearningState(), account);
      expect(merged.toJson(), account.toJson());
    });

    test('hard words come from whichever side changed them last', () {
      final phone = (WeakSpots()..missed(1, 1, 1)).toJson();
      final laptop = (WeakSpots()..missed(1, 3, 2)).toJson();
      LearningState withWeak(List<Map<String, dynamic>> w, DateTime? at) =>
          LearningState(weakSpots: w, weakSpotsAt: at);

      // The laptop cleared a word more recently: it must not come back.
      expect(
          LearningState.merge(withWeak(phone, monday), withWeak(laptop, friday))
              .weakSpots,
          laptop);
      expect(
          LearningState.merge(withWeak(phone, friday), withWeak(laptop, monday))
              .weakSpots,
          phone);
      // Never saved on the account: this device's list stands.
      expect(
          LearningState.merge(withWeak(phone, null), LearningState()).weakSpots,
          phone);
    });

    test("today's plan keeps the most done on either device", () {
      const today = '2026-09-27';
      final a = DailyPlanLog()..note(PlanStepKind.newLesson, today);
      final b = DailyPlanLog()
        ..note(PlanStepKind.oldRevision, today)
        ..note(PlanStepKind.oldRevision, today);
      final merged = LearningState.merge(
              LearningState(planLog: a), LearningState(planLog: b))
          .planLog;
      expect(merged.count(PlanStepKind.newLesson, today), 1);
      expect(merged.count(PlanStepKind.oldRevision, today), 2);
    });
  });

  group('DailyPlanLog.mergeFrom', () {
    test('a later day replaces an earlier one', () {
      final log = DailyPlanLog()..note(PlanStepKind.newLesson, '2026-09-26');
      log.mergeFrom(DailyPlanLog()..note(PlanStepKind.weakWords, '2026-09-27'));
      expect(log.day, '2026-09-27');
      expect(log.count(PlanStepKind.newLesson, '2026-09-27'), 0);
      expect(log.count(PlanStepKind.weakWords, '2026-09-27'), 1);
    });

    test('an earlier day changes nothing', () {
      final log = DailyPlanLog()..note(PlanStepKind.newLesson, '2026-09-27');
      log.mergeFrom(DailyPlanLog()..note(PlanStepKind.weakWords, '2026-09-26'));
      expect(log.count(PlanStepKind.newLesson, '2026-09-27'), 1);
      expect(log.count(PlanStepKind.weakWords, '2026-09-27'), 0);
    });
  });

  test('survives saving and loading', () {
    final state = LearningState(
      sealedLevels: {1000, 112000},
      reviews: {1000: review(friday, reps: 2)},
      held: {
        1: {0, 1, 2}
      },
      weakSpots: (WeakSpots()..missed(1, 1, 1)).toJson(),
      weakSpotsAt: monday,
      planLog: DailyPlanLog()..note(PlanStepKind.newLesson, '2026-09-27'),
    );
    final restored = LearningState.fromJson(state.toJson());
    expect(restored.toJson(), state.toJson());
    expect(restored.reviews[1000]!.due, friday);
    expect(restored.weakSpotsAt, monday);
  });

  test('damaged saved data loads what it can instead of failing', () {
    final state = LearningState.fromJson({
      'sealed': [1000, 'x'],
      'levels': {
        '1000': {'due': 'not a date'},
        'abc': {'due': '2026-10-02T00:00:00Z', 'reps': 1, 'ease': 2, 'gap': 1},
        '2000': {'due': '2026-10-02T00:00:00Z', 'reps': 1, 'ease': 2, 'gap': 1},
      },
      'held': {
        '1': 'junk',
        '2': [0, 1]
      },
      'weak': 'junk',
    });
    expect(state.sealedLevels, {1000});
    expect(state.reviews.keys, [2000]);
    expect(state.held, {
      2: {0, 1}
    });
    expect(state.weakSpots, isEmpty);
    expect(LearningState.fromJson(null).isEmpty, isTrue);
  });
}
