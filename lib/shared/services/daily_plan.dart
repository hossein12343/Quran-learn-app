import 'dart:math' as math;

/// The parts of a hifz day, in the order a teacher sets them: the new
/// lesson (sabaq) while the mind is fresh, then revision of what was
/// learned recently (sabqi), then of what was learned long ago (manzil),
/// and finally the words the learner keeps getting wrong.
enum PlanStepKind { newLesson, recentRevision, oldRevision, weakWords }

class PlanStep {
  final PlanStepKind kind;
  final int done;
  final int target;

  const PlanStep(this.kind, {required this.done, required this.target});

  bool get isDone => done >= target;
}

/// What has been done toward today's plan. Counts belong to one calendar
/// day ([day], 'yyyy-MM-dd') and read as zero on any other, so a new day
/// starts clean without a midnight timer.
class DailyPlanLog {
  String? day;
  final Map<PlanStepKind, int> _counts = {};

  int count(PlanStepKind kind, String today) =>
      day == today ? (_counts[kind] ?? 0) : 0;

  void note(PlanStepKind kind, String today) {
    if (day != today) {
      day = today;
      _counts.clear();
    }
    _counts[kind] = (_counts[kind] ?? 0) + 1;
  }

  void clear() {
    day = null;
    _counts.clear();
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        for (final e in _counts.entries) e.key.name: e.value,
      };

  void loadJson(Object? raw) {
    clear();
    if (raw is! Map || raw['day'] is! String) return;
    day = raw['day'] as String;
    for (final kind in PlanStepKind.values) {
      final v = raw[kind.name];
      if (v is num) _counts[kind] = v.toInt();
    }
  }
}

class DailyPlan {
  /// A level reviewed less than this many days apart is still "recent" —
  /// held, but not yet settled.
  static const recentUnderDays = 7;

  /// Old revision a day at most; the rest stays due for the days after, so
  /// a long break doesn't come back as one enormous day.
  static const oldPerDay = 3;

  static bool isRecent(int intervalDays) => intervalDays < recentUnderDays;

  /// Today's steps, done ones included (so they show as ticked rather than
  /// vanishing). A step with nothing to do and nothing done is left out.
  static List<PlanStep> build({
    required bool hasNewLesson,
    required int recentDue,
    required int oldDue,
    required bool hasWeakWords,
    required DailyPlanLog log,
    required String today,
  }) {
    int done(PlanStepKind k) => log.count(k, today);
    final steps = <PlanStep>[];

    final newDone = done(PlanStepKind.newLesson);
    if (hasNewLesson || newDone > 0) {
      steps.add(PlanStep(PlanStepKind.newLesson,
          done: newDone.clamp(0, 1), target: 1));
    }

    final recentDone = done(PlanStepKind.recentRevision);
    if (recentDue + recentDone > 0) {
      steps.add(PlanStep(PlanStepKind.recentRevision,
          done: recentDone, target: recentDue + recentDone));
    }

    final oldDone = done(PlanStepKind.oldRevision);
    // Capped at [oldPerDay], unless the learner chose to do more.
    final oldTarget = math.max(oldDone, math.min(oldPerDay, oldDue + oldDone));
    if (oldTarget > 0) {
      steps.add(
          PlanStep(PlanStepKind.oldRevision, done: oldDone, target: oldTarget));
    }

    final weakDone = done(PlanStepKind.weakWords);
    if (hasWeakWords || weakDone > 0) {
      steps.add(PlanStep(PlanStepKind.weakWords,
          done: weakDone.clamp(0, 1), target: 1));
    }
    return steps;
  }
}
