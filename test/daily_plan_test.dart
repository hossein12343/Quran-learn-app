import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/daily_plan.dart';

void main() {
  const today = '2026-09-26';

  List<PlanStep> plan({
    bool newLesson = true,
    int recent = 0,
    int old = 0,
    bool weak = false,
    DailyPlanLog? log,
  }) =>
      DailyPlan.build(
        hasNewLesson: newLesson,
        recentDue: recent,
        oldDue: old,
        hasWeakWords: weak,
        log: log ?? DailyPlanLog(),
        today: today,
      );

  test('a full day runs new lesson, recent, old, then hard words', () {
    expect(plan(recent: 2, old: 1, weak: true).map((s) => s.kind), [
      PlanStepKind.newLesson,
      PlanStepKind.recentRevision,
      PlanStepKind.oldRevision,
      PlanStepKind.weakWords,
    ]);
  });

  test('a day with nothing due is just the new lesson', () {
    final steps = plan();
    expect(steps.single.kind, PlanStepKind.newLesson);
    expect(steps.single.isDone, isFalse);
  });

  test('a finished step stays in the plan, ticked', () {
    final log = DailyPlanLog()
      ..note(PlanStepKind.recentRevision, today)
      ..note(PlanStepKind.recentRevision, today);
    // Both reviews done, so none are due any more.
    final recent = plan(log: log).last;
    expect(recent.kind, PlanStepKind.recentRevision);
    expect((recent.done, recent.target, recent.isDone), (2, 2, true));
  });

  test('old revision is capped per day, but doing more still counts', () {
    final capped = plan(old: 10).last;
    expect(capped.target, DailyPlan.oldPerDay);

    final log = DailyPlanLog();
    for (var i = 0; i < 4; i++) {
      log.note(PlanStepKind.oldRevision, today);
    }
    final extra = plan(old: 6, log: log).last;
    expect((extra.done, extra.target, extra.isDone), (4, 4, true));
  });

  test("yesterday's progress doesn't count today", () {
    final log = DailyPlanLog()..note(PlanStepKind.newLesson, '2026-09-25');
    expect(plan(log: log).single.isDone, isFalse);
    log.note(PlanStepKind.newLesson, today);
    expect(log.count(PlanStepKind.newLesson, today), 1);
  });

  test('once every surah is learned, no new lesson is asked for', () {
    expect(plan(newLesson: false), isEmpty);
    expect(
        plan(newLesson: false, weak: true).single.kind, PlanStepKind.weakWords);
  });

  test('a level is recent until its gap reaches a week', () {
    expect(DailyPlan.isRecent(1), isTrue);
    expect(DailyPlan.isRecent(6), isTrue);
    expect(DailyPlan.isRecent(7), isFalse);
  });

  test('the log survives saving and loading, and shrugs off junk', () {
    final log = DailyPlanLog()
      ..note(PlanStepKind.oldRevision, today)
      ..note(PlanStepKind.weakWords, today);
    final restored = DailyPlanLog()..loadJson(log.toJson());
    expect(restored.count(PlanStepKind.oldRevision, today), 1);
    expect(restored.count(PlanStepKind.weakWords, today), 1);

    final junk = DailyPlanLog()..loadJson({'day': 5, 'newLesson': 'x'});
    expect(junk.count(PlanStepKind.newLesson, today), 0);
    final none = DailyPlanLog()..loadJson(null);
    expect(none.day, isNull);
  });
}
