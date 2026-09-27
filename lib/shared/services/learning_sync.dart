import 'daily_plan.dart';

/// One sealed level's place in the review schedule.
class LevelReview {
  final DateTime due;
  final int reps;
  final double ease;
  final int gapDays;

  const LevelReview({
    required this.due,
    required this.reps,
    required this.ease,
    required this.gapDays,
  });

  Map<String, dynamic> toJson() => {
        'due': due.toUtc().toIso8601String(),
        'reps': reps,
        'ease': ease,
        'gap': gapDays,
      };

  static LevelReview? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final due = DateTime.tryParse('${raw['due']}');
    final reps = raw['reps'], ease = raw['ease'], gap = raw['gap'];
    if (due == null || reps is! num || ease is! num || gap is! num) {
      return null;
    }
    return LevelReview(
      due: due.toLocal(),
      reps: reps.toInt(),
      ease: ease.toDouble(),
      gapDays: gap.toInt(),
    );
  }
}

/// The memorisation progress that has to outlive a device: which levels
/// are sealed and when each is next due, exactly which ayat are held, the
/// hard words, today's plan, and which days were practised. Safari deletes a site's saved data after
/// about a week unused, so on a phone this copy on the account is what
/// keeps months of review history from vanishing.
class LearningState {
  final Set<int> sealedLevels;
  final Map<int, LevelReview> reviews;
  final Map<int, Set<int>> held;
  final List<Map<String, dynamic>> weakSpots;

  /// When [weakSpots] last changed; null if never.
  final DateTime? weakSpotsAt;
  final DailyPlanLog planLog;

  /// Days a session was done ('yyyy-MM-dd'): Home's week strip, and how
  /// the private stats tell whether people come back.
  final Set<String> activeDays;

  /// Enough history for the stats; older days are dropped.
  static const keepDays = 120;

  LearningState({
    Set<int>? sealedLevels,
    Map<int, LevelReview>? reviews,
    Map<int, Set<int>>? held,
    List<Map<String, dynamic>>? weakSpots,
    this.weakSpotsAt,
    DailyPlanLog? planLog,
    Set<String>? activeDays,
  })  : activeDays = _recent(activeDays ?? {}),
        sealedLevels = sealedLevels ?? {},
        reviews = reviews ?? {},
        held = held ?? {},
        weakSpots = weakSpots ?? [],
        planLog = planLog ?? DailyPlanLog();

  bool get isEmpty =>
      sealedLevels.isEmpty &&
      reviews.isEmpty &&
      held.values.every((s) => s.isEmpty) &&
      weakSpots.isEmpty &&
      planLog.day == null &&
      activeDays.isEmpty;

  /// The [keepDays] most recent days. 'yyyy-MM-dd' sorts as dates do.
  static Set<String> _recent(Set<String> days) => days.length <= keepDays
      ? days
      : (days.toList()..sort((a, b) => b.compareTo(a))).take(keepDays).toSet();

  Map<String, dynamic> toJson() => {
        'v': 1,
        'sealed': sealedLevels.toList()..sort(),
        'levels': {
          for (final e in reviews.entries) '${e.key}': e.value.toJson()
        },
        'held': {
          for (final e in held.entries)
            if (e.value.isNotEmpty) '${e.key}': e.value.toList()..sort(),
        },
        'weak': weakSpots,
        if (weakSpotsAt != null)
          'weakAt': weakSpotsAt!.toUtc().toIso8601String(),
        'plan': planLog.toJson(),
        'days': activeDays.toList()..sort(),
      };

  /// Anything unreadable is skipped rather than failing the whole load.
  static LearningState fromJson(Object? raw) {
    if (raw is! Map) return LearningState();
    final sealed = <int>{
      if (raw['sealed'] case final List list)
        for (final k in list)
          if (k is num) k.toInt(),
    };
    final reviews = <int, LevelReview>{};
    if (raw['levels'] case final Map levels) {
      levels.forEach((k, v) {
        final key = int.tryParse('$k');
        final review = LevelReview.fromJson(v);
        if (key != null && review != null) reviews[key] = review;
      });
    }
    final held = <int, Set<int>>{};
    if (raw['held'] case final Map map) {
      map.forEach((k, v) {
        final surah = int.tryParse('$k');
        if (surah == null || v is! List) return;
        held[surah] = {
          for (final i in v)
            if (i is num) i.toInt(),
        };
      });
    }
    return LearningState(
      sealedLevels: sealed,
      reviews: reviews,
      held: held,
      weakSpots: [
        if (raw['weak'] case final List list)
          for (final s in list)
            if (s is Map) s.cast<String, dynamic>(),
      ],
      weakSpotsAt: DateTime.tryParse('${raw['weakAt']}')?.toLocal(),
      planLog: DailyPlanLog()..loadJson(raw['plan']),
      activeDays: {
        if (raw['days'] case final List list)
          for (final d in list)
            if (d is String && _dayPattern.hasMatch(d)) d,
      },
    );
  }

  static final _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// This device's state and the account's, combined so neither loses
  /// anything it learned:
  /// - sealed levels and held ayat: everything either side has;
  /// - a level's review: whichever side reviewed it last — its next due
  ///   date is the later one;
  /// - hard words: the side that changed them last (merging word by word
  ///   would bring back words already cleared on the other device);
  /// - today's plan: see [DailyPlanLog.mergeFrom];
  /// - practice days: every day either side has.
  static LearningState merge(LearningState local, LearningState remote) {
    final reviews = {...local.reviews};
    remote.reviews.forEach((key, theirs) {
      final mine = reviews[key];
      if (mine == null ||
          theirs.due.isAfter(mine.due) ||
          (theirs.due == mine.due && theirs.reps > mine.reps)) {
        reviews[key] = theirs;
      }
    });

    final held = {
      for (final e in local.held.entries) e.key: {...e.value}
    };
    remote.held.forEach((surah, ayat) {
      (held[surah] ??= {}).addAll(ayat);
    });

    final remoteWeakNewer = remote.weakSpotsAt != null &&
        (local.weakSpotsAt == null ||
            remote.weakSpotsAt!.isAfter(local.weakSpotsAt!));

    return LearningState(
      sealedLevels: {...local.sealedLevels, ...remote.sealedLevels},
      reviews: reviews,
      held: held,
      weakSpots: remoteWeakNewer ? remote.weakSpots : local.weakSpots,
      weakSpotsAt: remoteWeakNewer ? remote.weakSpotsAt : local.weakSpotsAt,
      planLog: DailyPlanLog()
        ..mergeFrom(local.planLog)
        ..mergeFrom(remote.planLog),
      activeDays: {...local.activeDays, ...remote.activeDays},
    );
  }
}
