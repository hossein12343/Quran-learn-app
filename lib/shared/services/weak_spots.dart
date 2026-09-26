import 'dart:math' as math;

/// A word, or a whole ayah, the learner has gotten wrong in a drill and
/// hasn't yet shown they know again.
class WeakSpot {
  /// [word] value meaning the whole ayah rather than one word in it — for
  /// mistakes like picking the wrong "next ayah", or missing most of one.
  static const wholeAyah = -1;

  final int surah;

  /// Index into the surah's ayat (0-based), as the quiz uses.
  final int ayah;

  /// Index into that ayah's words (0-based), or [wholeAyah].
  final int word;

  int misses;

  /// Correct answers in a row since the last miss.
  int rightInARow;
  DateTime lastMissed;

  WeakSpot({
    required this.surah,
    required this.ayah,
    required this.word,
    this.misses = 0,
    this.rightInARow = 0,
    required this.lastMissed,
  });

  bool get isWholeAyah => word == wholeAyah;

  String get key => keyOf(surah, ayah, word);

  static String keyOf(int surah, int ayah, int word) => '$surah:$ayah:$word';

  Map<String, dynamic> toJson() => {
        's': surah,
        'a': ayah,
        'w': word,
        'm': misses,
        'r': rightInARow,
        't': lastMissed.toIso8601String(),
      };

  static WeakSpot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final s = raw['s'], a = raw['a'], w = raw['w'], m = raw['m'];
    final t = DateTime.tryParse('${raw['t']}');
    if (s is! num || a is! num || w is! num || m is! num || t == null) {
      return null;
    }
    return WeakSpot(
      surah: s.toInt(),
      ayah: a.toInt(),
      word: w.toInt(),
      misses: m.toInt(),
      rightInARow: (raw['r'] as num?)?.toInt() ?? 0,
      lastMissed: t,
    );
  }
}

/// Remembers exactly which words trip the learner up, so they can be
/// practised on their own instead of redoing whole levels. A spot leaves
/// the list once it's answered right [recoverAfter] times in a row.
class WeakSpots {
  static const recoverAfter = 2;

  /// Keeps the list about what's hard right now: the oldest spots drop
  /// off beyond this many.
  static const maxSpots = 60;

  final Map<String, WeakSpot> _spots = {};

  int get length => _spots.length;
  bool get isEmpty => _spots.isEmpty;

  WeakSpot? operator [](String key) => _spots[key];

  void missed(int surah, int ayah, int word, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final key = WeakSpot.keyOf(surah, ayah, word);
    final spot = _spots.putIfAbsent(
      key,
      () => WeakSpot(surah: surah, ayah: ayah, word: word, lastMissed: now),
    );
    spot
      ..misses += 1
      ..rightInARow = 0
      ..lastMissed = now;
    if (_spots.length > maxSpots) {
      final oldest = _spots.values
          .reduce((a, b) => a.lastMissed.isBefore(b.lastMissed) ? a : b);
      _spots.remove(oldest.key);
    }
  }

  /// Returns true if this answer took the spot off the list.
  bool answeredRight(int surah, int ayah, int word) {
    final key = WeakSpot.keyOf(surah, ayah, word);
    final spot = _spots[key];
    if (spot == null) return false;
    spot.rightInARow += 1;
    if (spot.rightInARow >= recoverAfter) {
      _spots.remove(key);
      return true;
    }
    return false;
  }

  /// Most-missed first; among equals, the most recently missed.
  List<WeakSpot> ranked({int? limit}) {
    final list = _spots.values.toList()
      ..sort((a, b) {
        final byMisses = b.misses.compareTo(a.misses);
        return byMisses != 0 ? byMisses : b.lastMissed.compareTo(a.lastMissed);
      });
    return limit == null ? list : list.take(limit).toList();
  }

  void clear() => _spots.clear();

  List<Map<String, dynamic>> toJson() =>
      [for (final s in _spots.values) s.toJson()];

  void loadJson(Object? raw) {
    _spots.clear();
    if (raw is! List) return;
    for (final item in raw) {
      final spot = WeakSpot.fromJson(item);
      if (spot != null) _spots[spot.key] = spot;
    }
  }
}

/// Positions in [answer] the learner didn't get right. Their attempt is
/// lined up with the ayah (longest common subsequence), so one forgotten
/// word doesn't also blame every word after it just for having shifted.
List<int> missedWordPositions(List<String> answer, List<String> given) {
  final n = answer.length, m = given.length;
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = answer[i] == given[j]
          ? lcs[i + 1][j + 1] + 1
          : math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  final missed = <int>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (answer[i] == given[j]) {
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      missed.add(i++);
    } else {
      j++;
    }
  }
  while (i < n) {
    missed.add(i++);
  }
  return missed;
}

/// What one word-tile answer (build the ayah from tiles) says about weak
/// spots. A right answer proves every word and the ayah as a whole. A wrong
/// one blames the words that weren't in place — or, when most of the ayah
/// was missing, the whole ayah rather than a long list of its words.
({List<int> missed, List<int> right}) weakSpotsFromWordBank(
    List<String> answer, List<String> given, bool correct) {
  if (correct) {
    return (
      missed: const <int>[],
      right: [WeakSpot.wholeAyah, for (var i = 0; i < answer.length; i++) i],
    );
  }
  final missed = missedWordPositions(answer, given);
  if (missed.isEmpty || missed.length * 2 > answer.length) {
    return (missed: const [WeakSpot.wholeAyah], right: const <int>[]);
  }
  return (missed: missed, right: const <int>[]);
}
