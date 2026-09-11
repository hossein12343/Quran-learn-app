import 'dart:convert';
import 'store/local_store.dart';

/// A memorization goal — a scope (a set of surah numbers) and a
/// target date. "Finish X by Y," with the pace that implies computed
/// from what's already held (see `features/learn/hifz_plan_page.dart`
/// — this class only stores the goal itself, not the math). Device-
/// local only, same reasoning as `ayah_notes.dart`: a second synced
/// table wasn't worth it for a feature this small.
class HifzPlan {
  final List<int> surahNumbers;
  final String scopeLabel;
  final DateTime targetDate;

  const HifzPlan({
    required this.surahNumbers,
    required this.scopeLabel,
    required this.targetDate,
  });
}

const _key = 'hifz_plan';

HifzPlan? loadHifzPlan() {
  final raw = LocalStore.get(_key);
  if (raw == null) return null;
  try {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return HifzPlan(
      surahNumbers: (m['surahNumbers'] as List).map((e) => e as int).toList(),
      scopeLabel: m['scopeLabel'] as String,
      targetDate: DateTime.parse(m['targetDate'] as String),
    );
  } on Object {
    return null;
  }
}

void saveHifzPlan(HifzPlan plan) {
  LocalStore.set(
    _key,
    jsonEncode({
      'surahNumbers': plan.surahNumbers,
      'scopeLabel': plan.scopeLabel,
      'targetDate': plan.targetDate.toIso8601String(),
    }),
  );
}

void clearHifzPlan() => LocalStore.remove(_key);

/// The actual "planner" math — pure and standalone so it's directly
/// unit-testable without a widget tree, same reasoning as
/// `quiz_engine.dart`'s split from its own UI.
class HifzPace {
  final int totalAyat;
  final int heldAyat;
  final int remainingAyat;
  final int daysRemaining;
  final double ayatPerDay;
  final bool alreadyComplete;
  final bool overdue;

  const HifzPace({
    required this.totalAyat,
    required this.heldAyat,
    required this.remainingAyat,
    required this.daysRemaining,
    required this.ayatPerDay,
    required this.alreadyComplete,
    required this.overdue,
  });
}

/// [now] is a parameter (not read internally) so this stays testable
/// against a fixed date instead of whatever day the test happens to
/// run on.
HifzPace computeHifzPace({
  required int totalAyat,
  required int heldAyat,
  required DateTime targetDate,
  required DateTime now,
}) {
  final held = heldAyat < 0 ? 0 : (heldAyat > totalAyat ? totalAyat : heldAyat);
  final remaining = totalAyat - held;
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
  final daysRemaining = target.difference(today).inDays;
  final overdue = daysRemaining < 0 && remaining > 0;
  // A same-day or already-past target still needs a pace number to
  // show ("do it all today") rather than dividing by zero or a
  // negative count.
  final effectiveDays = daysRemaining < 1 ? 1 : daysRemaining;
  return HifzPace(
    totalAyat: totalAyat,
    heldAyat: held,
    remainingAyat: remaining,
    daysRemaining: daysRemaining,
    ayatPerDay: remaining <= 0 ? 0 : remaining / effectiveDays,
    alreadyComplete: remaining <= 0,
    overdue: overdue,
  );
}
