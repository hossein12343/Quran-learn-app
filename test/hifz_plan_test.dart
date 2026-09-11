import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/hifz_plan.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  test('computes the exact daily pace needed to finish by the target date', () {
    final pace = computeHifzPace(
      totalAyat: 100,
      heldAyat: 0,
      targetDate: DateTime(2026, 1, 11), // 10 days out
      now: now,
    );
    expect(pace.remainingAyat, 100);
    expect(pace.daysRemaining, 10);
    expect(pace.ayatPerDay, 10.0);
    expect(pace.alreadyComplete, isFalse);
    expect(pace.overdue, isFalse);
  });

  test('subtracts already-held ayat from what remains', () {
    final pace = computeHifzPace(
      totalAyat: 100,
      heldAyat: 40,
      targetDate: DateTime(2026, 1, 11),
      now: now,
    );
    expect(pace.remainingAyat, 60);
    expect(pace.ayatPerDay, 6.0);
  });

  test('flags a goal already fully held as complete, zero pace needed', () {
    final pace = computeHifzPace(
      totalAyat: 50,
      heldAyat: 50,
      targetDate: DateTime(2026, 6, 1),
      now: now,
    );
    expect(pace.alreadyComplete, isTrue);
    expect(pace.remainingAyat, 0);
    expect(pace.ayatPerDay, 0.0);
  });

  test(
      'clamps held ayat that somehow exceeds the total instead of going negative',
      () {
    final pace = computeHifzPace(
      totalAyat: 50,
      heldAyat: 80,
      targetDate: DateTime(2026, 6, 1),
      now: now,
    );
    expect(pace.heldAyat, 50);
    expect(pace.remainingAyat, 0);
  });

  test('flags an overdue target date that still has ayat left', () {
    final pace = computeHifzPace(
      totalAyat: 100,
      heldAyat: 10,
      targetDate: DateTime(2025, 12, 1), // in the past relative to `now`
      now: now,
    );
    expect(pace.overdue, isTrue);
    expect(pace.remainingAyat, 90);
  });

  test(
      'a same-day target still returns a finite pace instead of dividing by zero',
      () {
    final pace = computeHifzPace(
      totalAyat: 20,
      heldAyat: 0,
      targetDate: now,
      now: now,
    );
    expect(pace.daysRemaining, 0);
    expect(pace.ayatPerDay, 20.0);
    expect(pace.ayatPerDay.isFinite, isTrue);
  });
}
