import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/data/quran_seed.dart';
import 'package:quran_learn_app/shared/services/app_state.dart';

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  setUp(() {
    // AppState is a singleton; reset the fields each test touches so tests
    // don't leak into one another.
    appState
      ..displayName = 'Learner'
      ..email = ''
      ..signedIn = false
      ..totalXp = 0
      ..currentStreak = 0
      ..longestStreak = 0
      ..lastCelebratedStreakMilestone = 0
      ..lastActiveDate = null
      ..dailyGoalMinutes = 10
      ..quizzesTaken = 0
      ..quizzesPassed = 0;
    appState.sealed.clear();
    appState.sealedLevels.clear();
    appState.bookmarks.clear();
    appState.reviewDue.clear();
    appState.reviewCleanRecalls.clear();
    appState.reviewEase.clear();
    appState.reviewInterval.clear();
    appState.activeDates.clear();
  });

  test('recordSession awards 12 XP per newly held ayah', () {
    appState.recordSession(
      surahNumber: 112,
      heldIndicesNow: {0, 1},
      didSeal: false,
      minutes: 3,
    );
    expect(appState.totalXp, 24);
    expect(appState.held[112], 2);
    expect(appState.heldIndices(112), {0, 1});
  });

  test('recordSession only awards XP for the increase, not the whole set',
      () {
    // A surah untouched by any other test — _heldAyat is private state that
    // persists on the AppState singleton across tests, so reusing a surah
    // number another test already wrote to would carry over its count.
    appState.recordSession(
        surahNumber: 113, heldIndicesNow: {0}, didSeal: false, minutes: 1);
    appState.recordSession(
        surahNumber: 113, heldIndicesNow: {0, 1, 2}, didSeal: false, minutes: 1);
    // 1 ayah then +2 more = 3 total newly-held increments, 12 XP each.
    expect(appState.totalXp, 3 * 12);
  });

  test('sealing a surah adds the 50 XP bonus and marks it sealed', () {
    appState.recordSession(
      surahNumber: 114,
      heldIndicesNow: {0, 1, 2, 3, 4, 5},
      didSeal: true,
      minutes: 5,
    );
    expect(appState.sealed.contains(114), isTrue);
    expect(appState.totalXp, 6 * 12 + 50);
    expect(appState.quizzesPassed, 1);
  });

  test('toggleBookmark adds and then removes locally with no backend', () async {
    expect(appState.isBookmarked(1, 1), isFalse);
    await appState.toggleBookmark(1, 1);
    expect(appState.isBookmarked(1, 1), isTrue);
    await appState.toggleBookmark(1, 1);
    expect(appState.isBookmarked(1, 1), isFalse);
  });

  test('isUnlocked only opens a surah once the previous one is sealed', () {
    expect(appState.isUnlocked(0), isTrue);
    expect(appState.isUnlocked(1), isFalse);
    appState.sealed.add(1); // Al-Fatiha's surah number
    expect(appState.isUnlocked(1), isTrue);
  });

  test('a level chains through the levels of one surah, independent of the '
      'main path, once the surah itself is unlocked', () {
    final fake = Surah(
      number: 9050,
      arabicName: 'اختبار',
      englishName: 'Fake',
      meaning: 'Test',
      revelation: 'Meccan',
      ayat: List<Ayah>.generate(20, (i) => Ayah(i + 1, 'a b', 'ayah')),
    );
    // Not part of `surahs` at all, so its first level reads as locked —
    // same as any surah the main path hasn't unlocked yet.
    expect(appState.isLevelUnlocked(fake, 0), isFalse);
    expect(appState.isLevelUnlocked(fake, 1), isFalse);

    appState.sealedLevels.add(appState.levelKey(9050, 0));
    expect(appState.isLevelUnlocked(fake, 1), isTrue);
    expect(appState.isLevelUnlocked(fake, 2), isFalse);
    expect(appState.nextChunkFor(fake), 1);
  });

  test('recordSession seals a level, awards its bonus once, and unlocks the next',
      () {
    final fake = Surah(
      number: 9051,
      arabicName: 'اختبار',
      englishName: 'Fake',
      meaning: 'Test',
      revelation: 'Meccan',
      ayat: List<Ayah>.generate(10, (i) => Ayah(i + 1, 'a b', 'ayah')),
    );
    expect(appState.isLevelSealed(9051, 0), isFalse);

    appState.recordSession(
      surahNumber: 9051,
      heldIndicesNow: {0, 1, 2, 3, 4, 5, 6, 7},
      didSeal: false,
      sealedChunk: 0,
      minutes: 4,
    );
    expect(appState.isLevelSealed(9051, 0), isTrue);
    expect(appState.isLevelUnlocked(fake, 1), isTrue);
    expect(appState.totalXp, 8 * 12 + 15); // 8 ayat held + one level bonus
    expect(appState.sealed.contains(9051), isFalse); // level, not the surah

    // Sealing the same level again must not pay the bonus twice.
    final xpBefore = appState.totalXp;
    appState.recordSession(
      surahNumber: 9051,
      heldIndicesNow: {0, 1, 2, 3, 4, 5, 6, 7},
      didSeal: false,
      sealedChunk: 0,
      minutes: 1,
    );
    expect(appState.totalXp, xpBefore);
  });

  test('first seal schedules review for tomorrow', () {
    appState.recordSession(
      surahNumber: 1,
      heldIndicesNow: {0, 1, 2, 3, 4, 5, 6},
      didSeal: true,
      sealedChunk: 0,
      minutes: 3,
    );
    final key = appState.levelKey(1, 0);
    expect(appState.reviewInterval[key], 1);
    expect(appState.reviewCleanRecalls[key], 1);
    expect(appState.dueForReview, isEmpty); // not due until tomorrow
  });

  test('SM-2: clean reviews grow the gap and the ease; a lapse trims both '
      'without a full reset', () {
    appState.recordSession(
      surahNumber: 112,
      heldIndicesNow: {0, 1, 2, 3},
      didSeal: true,
      sealedChunk: 0,
      minutes: 2,
    );
    final key = appState.levelKey(112, 0);

    void reviewClean() {
      appState.reviewDue[key] =
          DateTime.now().subtract(const Duration(minutes: 1));
      appState.recordSession(
        surahNumber: 112,
        heldIndicesNow: {0, 1, 2, 3},
        didSeal: true,
        sealedChunk: 0,
        hadMistakes: false,
        minutes: 1,
      );
    }

    reviewClean(); // reps 2 -> interval 3
    expect(appState.reviewCleanRecalls[key], 2);
    expect(appState.reviewInterval[key], 3);

    reviewClean(); // reps 3 -> interval round(3 * ease)
    expect(appState.reviewCleanRecalls[key], 3);
    final grownInterval = appState.reviewInterval[key]!;
    expect(grownInterval, greaterThan(3));
    final grownEase = appState.reviewEase[key]!;
    expect(grownEase, greaterThan(ReviewSchedule.startEase));

    // A lapse: interval and ease shrink, but reps only steps back by one
    // (the old ladder would have reset to zero).
    appState.reviewDue[key] =
        DateTime.now().subtract(const Duration(minutes: 1));
    appState.recordSession(
      surahNumber: 112,
      heldIndicesNow: {0, 1, 2, 3},
      didSeal: true,
      sealedChunk: 0,
      hadMistakes: true,
      minutes: 1,
    );
    expect(appState.reviewCleanRecalls[key], 2); // not 0
    expect(appState.reviewInterval[key], lessThan(grownInterval));
    expect(appState.reviewEase[key], lessThan(grownEase));
  });

  test('a pre-SM-2 sealed level (rep count only) migrates onto the new '
      'scheduler without losing its place', () {
    final key = appState.levelKey(113, 0);
    // Simulate a snapshot from before reviewEase/reviewInterval existed.
    appState.sealedLevels.add(key);
    appState.reviewCleanRecalls[key] = 2; // old ladder day-14 tier
    appState.reviewDue[key] =
        DateTime.now().subtract(const Duration(minutes: 1));

    appState.recordSession(
      surahNumber: 113,
      heldIndicesNow: {0, 1, 2, 3, 4},
      didSeal: true,
      sealedChunk: 0,
      hadMistakes: false,
      minutes: 1,
    );
    // Started from the legacy 14-day interval, grown by the default ease.
    expect(appState.reviewInterval[key], greaterThan(14));
    expect(appState.reviewCleanRecalls[key], 3);
  });

  group('today counters and quests', () {
    test('minutesToday is 0 when the last session was not today', () {
      appState.currentStreak = 5;
      appState.lastActiveDate =
          ymd(DateTime.now().subtract(const Duration(days: 2)));
      // Simulate a stale value carried in from a previous day's snapshot.
      appState.recordSession(
          surahNumber: 401, heldIndicesNow: {0}, didSeal: false, minutes: 7);
      // recordSession set lastActiveDate to today and reset the counters
      // first, so only this session's 7 minutes count.
      expect(appState.minutesToday, 7);
    });

    test('a new calendar day resets minutes / ayat / lessons', () {
      appState.lastActiveDate =
          ymd(DateTime.now().subtract(const Duration(days: 1)));
      appState.recordSession(
          surahNumber: 402,
          heldIndicesNow: {0, 1},
          didSeal: false,
          minutes: 4);
      expect(appState.minutesToday, 4);
      expect(appState.ayatLearnedToday, 2);
      expect(appState.lessonsToday, 1);
    });

    test('daily quests reflect live progress and completion', () {
      appState.dailyGoalMinutes = 10;
      appState.recordSession(
          surahNumber: 403,
          heldIndicesNow: {0, 1, 2, 3},
          didSeal: false,
          minutes: 12);
      final byId = {for (final q in appState.dailyQuests) q.id: q};
      expect(byId['minutes']!.done, isTrue); // 12 >= 10
      expect(byId['learn']!.done, isTrue); // 4 >= 3
      expect(byId['lesson']!.done, isTrue); // 1 >= 1
      expect(appState.questsDoneToday, 3);
    });

    test('this week: Saturday-first, today flagged, session marked active', () {
      appState.activeDates.add(ymd(DateTime.now()));
      final week = appState.thisWeek;
      expect(week.length, 7);
      expect(week.first.day.weekday, DateTime.saturday);
      final todayCell = week.firstWhere((d) => d.isToday);
      expect(todayCell.active, isTrue);
      expect(todayCell.future, isFalse);
      expect(week.where((d) => d.isToday).length, 1);
    });
  });

  group('streak milestone celebration', () {
    test('a milestone the streak just reached still celebrates', () {
      appState.currentStreak = 3;
      appState.seedStreakMilestoneBaseline();
      expect(appState.pendingStreakMilestone, 3);
    });

    test('a fresh device does not throw a stale party for a passed milestone',
        () {
      // currentStreak restored as 40, but lastCelebrated is still 0 (new
      // device). Without seeding, pendingStreakMilestone would be 30.
      appState.currentStreak = 40;
      appState.seedStreakMilestoneBaseline();
      expect(appState.pendingStreakMilestone, isNull);
      expect(appState.lastCelebratedStreakMilestone, 30);
    });

    test('seeding never lowers an already-higher baseline', () {
      appState.currentStreak = 8;
      appState.lastCelebratedStreakMilestone = 7;
      appState.seedStreakMilestoneBaseline();
      expect(appState.lastCelebratedStreakMilestone, 7);
      expect(appState.pendingStreakMilestone, isNull);
    });
  });

  group('streak', () {
    test('first session ever starts the streak at 1', () {
      appState.recordSession(
          surahNumber: 201, heldIndicesNow: {0}, didSeal: false, minutes: 1);
      expect(appState.currentStreak, 1);
      expect(appState.longestStreak, 1);
    });

    test('a second session the same day does not double-count', () {
      appState.recordSession(
          surahNumber: 202, heldIndicesNow: {0}, didSeal: false, minutes: 1);
      appState.recordSession(
          surahNumber: 202,
          heldIndicesNow: {0, 1},
          didSeal: false,
          minutes: 1);
      expect(appState.currentStreak, 1);
    });

    test('a session the day after yesterday extends the streak', () {
      appState.currentStreak = 3;
      appState.longestStreak = 3;
      appState.lastActiveDate =
          ymd(DateTime.now().subtract(const Duration(days: 1)));
      appState.recordSession(
          surahNumber: 203, heldIndicesNow: {0}, didSeal: false, minutes: 1);
      expect(appState.currentStreak, 4);
      expect(appState.longestStreak, 4);
    });

    test('a session after a gap of 2+ days restarts the streak at 1', () {
      appState.currentStreak = 5;
      appState.longestStreak = 5;
      appState.lastActiveDate =
          ymd(DateTime.now().subtract(const Duration(days: 3)));
      appState.recordSession(
          surahNumber: 204, heldIndicesNow: {0}, didSeal: false, minutes: 1);
      expect(appState.currentStreak, 1);
      expect(appState.longestStreak, 5); // longest survives a reset
    });
  });
}
