import 'dart:math';
import '../../shared/data/quran_seed.dart';

/// Every ayah is taught before it is ever tested: first heard, then read
/// aloud along with the recitation, and only then drilled. An ayah counts
/// as held only after it has been produced correctly under three different
/// drill types — recognising a verse is not the same as being able to
/// recall it, so recognition alone never clears an ayah.
enum Drill { order, blank, next, blind }

/// Presentation steps happen once per ayah, before its first drill.
enum ExerciseKind { listen, repeat, drill }

enum Stage { build, gate, sealed, failed }

const int kHearts = 4;
const int kDrillsToHold = 3;

class MemoryItem {
  final int index;
  final Set<Drill> cleared = <Drill>{};
  int lapses = 0;

  /// Presentation state. Unlike [cleared], a mistake never resets these —
  /// once you've been taught an ayah you don't get re-taught it just for
  /// slipping on a drill.
  bool listened = false;
  bool repeated = false;

  MemoryItem(this.index);

  bool get held => cleared.length >= kDrillsToHold;
  void reset() => cleared.clear();
}

class Exercise {
  final ExerciseKind kind;
  final Drill? drill;
  final int ayahIndex;
  final bool isGate;
  final List<String> tiles;
  final List<String> answer;
  final List<String> options;
  final String correctOption;
  final String? maskedText;
  final String? contextText;
  final String? translation;
  final String? arabic;
  final int? seconds;

  const Exercise({
    this.kind = ExerciseKind.drill,
    this.drill,
    required this.ayahIndex,
    required this.isGate,
    this.tiles = const [],
    this.answer = const [],
    this.options = const [],
    this.correctOption = '',
    this.maskedText,
    this.contextText,
    this.translation,
    this.arabic,
    this.seconds,
  });

  bool get isWordBank => drill == Drill.order || drill == Drill.blind;
}

/// A memorisation session for one surah, a chunk at a time.
///
/// The rule this class exists to enforce: there is no route from "started"
/// to "held" for an ayah that skips actually hearing and reading it first,
/// and no route from "held" to "sealed" for a chunk that skips producing
/// every ayah in it correctly three ways, then producing them all again, in
/// order, unaided, with zero mistakes.
class Session {
  final Surah surah;
  final List<MemoryItem> items;
  final Random _rng = Random();
  final List<String> _pool;

  int hearts = kHearts;
  Stage stage = Stage.build;
  int gateIndex = 0;
  int mistakes = 0;
  int currentChunk;

  /// When true, this Session plays exactly one level (chunk) and seals
  /// after its gate clears instead of rolling on into the next chunk —
  /// how every session is launched now, from a specific level on the
  /// surah's own path, rather than one long uninterrupted run through the
  /// whole surah.
  final bool singleLevel;

  Session(
    this.surah, {
    Set<int> alreadyHeld = const <int>{},
    int? startChunk,
    this.singleLevel = false,
  })  : items = List<MemoryItem>.generate(surah.ayat.length, (i) {
          final item = MemoryItem(i);
          if (alreadyHeld.contains(i) || isKnownIntro(surah, i)) {
            item.listened = true;
            item.repeated = true;
            item.cleared.addAll(Drill.values);
          }
          return item;
        }),
        _pool = _buildPool(surah),
        currentChunk = startChunk ?? 0 {
    if (startChunk == null) {
      // Resuming a surah already partly held: skip straight past any chunk
      // that's entirely complete rather than re-gating content already held.
      while (currentChunk < chunkCount &&
          items.sublist(chunkStart, chunkEnd).every((i) => i.held)) {
        currentChunk++;
      }
      if (currentChunk >= chunkCount) stage = Stage.sealed;
    }
  }

  /// Al-Fatihah's own ayah 1 *is* the basmala every surah opens with
  /// (except At-Tawbah) — everyone already knows it verbatim, so it's
  /// played rather than taught: auto-held from the start (never listened/
  /// repeated/drilled as its own step) and skipped in the final gate too
  /// (see [next]'s `Stage.gate` transition). It still exists as a real
  /// [MemoryItem] so `Drill.next` can use it as "the previous ayah"
  /// context for the first ayah actually taught.
  static bool isKnownIntro(Surah surah, int index) =>
      surah.number == 1 && index == 0;

  static List<String> _buildPool(Surah s) {
    final set = <String>{};
    for (final a in s.ayat) {
      set.addAll(a.words);
    }
    // Short surahs do not contain enough material to make guessing hard,
    // so widen the pool with real words from elsewhere in the mushaf.
    if (set.length < 26) {
      for (final other in surahs) {
        if (other.number == s.number) continue;
        for (final a in other.ayat) {
          set.addAll(a.words);
        }
        if (set.length >= 45) break;
      }
    }
    return set.toList();
  }

  int get total => items.length;
  int get heldCount => items.where((i) => i.held).length;
  int get chunkCount => (total / kChunkSize).ceil();
  int get chunkStart => currentChunk * kChunkSize;
  int get chunkEnd => min(chunkStart + kChunkSize, total);

  /// True once the chunk that just sealed was the surah's last one — the
  /// whole surah is complete, not just this one level.
  bool get sealedWholeSurah =>
      stage == Stage.sealed && (currentChunk + 1) * kChunkSize >= total;

  /// Scoped to the level being played, not the whole surah — each session
  /// is one level now, so the bar should fill over that level alone.
  double get progress {
    if (stage == Stage.sealed) return 1;
    final chunkItems = items.sublist(chunkStart, chunkEnd);
    final chunkSize = chunkItems.length;
    final built = chunkItems.fold<int>(0, (s, i) => s + i.cleared.length);
    final buildPart = built / (chunkSize * kDrillsToHold);
    if (stage == Stage.build) return buildPart * 0.7;
    final gated = (gateIndex - chunkStart).clamp(0, chunkSize);
    return 0.7 + (gated / chunkSize) * 0.3;
  }

  Exercise? next() {
    if (stage == Stage.failed || stage == Stage.sealed) return null;

    if (stage == Stage.build) {
      final pending =
          items.sublist(chunkStart, chunkEnd).where((i) => !i.held).toList();
      if (pending.isEmpty) {
        stage = Stage.gate;
        // Skip the known intro in the final recall too — it was never
        // taught as a step, so it's never tested as one either.
        gateIndex =
            chunkStart + (isKnownIntro(surah, chunkStart) ? 1 : 0);
        return next();
      }

      // One ayah at a time: whichever ayah is already started (heard, or
      // heard-and-repeated but still short of its three drills) is finished
      // — taught, then drilled — before a new one is ever introduced. This
      // is the whole point: you are never asked to build something you
      // were never taught.
      final inProgress = pending.where((i) => i.listened).toList();
      if (inProgress.isNotEmpty) {
        final item = inProgress.first;
        if (!item.repeated) return _teach(item.index, ExerciseKind.repeat);
        return _build(item.index, _pickDrill(item), false);
      }

      pending.sort((a, b) => a.index.compareTo(b.index));
      final item = pending.first;
      return _teach(item.index, ExerciseKind.listen);
    }

    return _build(gateIndex, Drill.blind, true);
  }

  Exercise _teach(int index, ExerciseKind kind) {
    final ayah = surah.ayat[index];
    return Exercise(
      kind: kind,
      ayahIndex: index,
      isGate: false,
      arabic: ayah.arabic,
      translation: ayah.translation,
    );
  }

  Drill _pickDrill(MemoryItem item) {
    // Ayat are taught strictly in order, so by the time item i is being
    // drilled, item i-1 is already held — never i+1. "What comes next"
    // therefore tests forward from the *previous* ayah (already mastered)
    // into this one, not from this ayah into content never taught.
    final hasPrevious = item.index > 0;
    final available = <Drill>[
      if (!item.cleared.contains(Drill.order)) Drill.order,
      if (!item.cleared.contains(Drill.blank)) Drill.blank,
      if (hasPrevious && !item.cleared.contains(Drill.next)) Drill.next,
      if (!item.cleared.contains(Drill.blind)) Drill.blind,
    ];
    if (available.isEmpty) return Drill.blind;
    available.sort((a, b) => a.index.compareTo(b.index));
    // First drill after teaching is the gentlest; after that it is mixed.
    if (item.cleared.isEmpty) return available.first;
    return available[_rng.nextInt(available.length)];
  }

  Exercise _build(int index, Drill drill, bool isGate) {
    final ayah = surah.ayat[index];
    final words = ayah.words;

    switch (drill) {
      case Drill.order:
        return Exercise(
          drill: drill,
          ayahIndex: index,
          isGate: false,
          answer: words,
          tiles: _tiles(words, extra: 2),
          translation: ayah.translation,
        );

      case Drill.blind:
        return Exercise(
          drill: drill,
          ayahIndex: index,
          isGate: isGate,
          answer: words,
          tiles: _tiles(words, extra: isGate ? 6 : 5),
          seconds: 12 + words.length * 4,
        );

      case Drill.blank:
        final hole =
            words.length == 1 ? 0 : 1 + _rng.nextInt(words.length - 1);
        final masked = List<String>.from(words);
        final missing = masked[hole];
        masked[hole] = '———';
        return Exercise(
          drill: drill,
          ayahIndex: index,
          isGate: false,
          maskedText: masked.join(' '),
          options: _options(missing, words),
          correctOption: missing,
          translation: ayah.translation,
        );

      case Drill.next:
        // Shown the previous ayah (already held), pick this one out of the
        // options — chaining is the actual skill hifz needs.
        final previous = surah.ayat[index - 1].arabic;
        final correct = ayah.arabic;
        final others = surah.ayat
            .where((a) => a.arabic != correct && a.arabic != previous)
            .map((a) => a.arabic)
            .toList()
          ..shuffle(_rng);
        final opts = <String>[correct, ...others.take(3)]..shuffle(_rng);
        return Exercise(
          drill: drill,
          ayahIndex: index,
          isGate: false,
          contextText: previous,
          options: opts,
          correctOption: correct,
        );
    }
  }

  /// Distractors are real words from neighbouring ayat, so a tile that
  /// "looks Qur'anic" tells you nothing. Guessing has to fail.
  List<String> _tiles(List<String> words, {required int extra}) {
    final pool = _pool.where((w) => !words.contains(w)).toList()..shuffle(_rng);
    final tiles = <String>[...words, ...pool.take(extra)];
    tiles.shuffle(_rng);
    return tiles;
  }

  List<String> _options(String correct, List<String> exclude) {
    final pool = _pool
        .where((w) => w != correct && !exclude.contains(w))
        .toSet()
        .toList()
      ..shuffle(_rng);
    final opts = <String>[correct, ...pool.take(3)];
    var filler = 0;
    while (opts.length < 4) {
      opts.add('$correct${'​' * (++filler)}');
    }
    opts.shuffle(_rng);
    return opts;
  }

  /// Marks a presentation step seen. Never gated by hearts — listening and
  /// repeating are exposure, not a test.
  void acknowledgeTeach(Exercise ex) {
    final item = items[ex.ayahIndex];
    if (ex.kind == ExerciseKind.listen) item.listened = true;
    if (ex.kind == ExerciseKind.repeat) item.repeated = true;
  }

  void submit(Exercise ex, bool correct) {
    final item = items[ex.ayahIndex];

    if (ex.isGate) {
      if (correct) {
        gateIndex++;
        if (gateIndex >= chunkEnd) {
          if (singleLevel || chunkEnd >= total) {
            stage = Stage.sealed;
          } else {
            currentChunk++;
            stage = Stage.build;
          }
        }
        return;
      }
      // One slip in the final recall returns that ayah to zero and restarts
      // this chunk's gate. This is the part that cannot be brute-forced.
      mistakes++;
      item.reset();
      item.lapses++;
      _loseHeart();
      if (stage != Stage.failed) {
        stage = Stage.build;
        // Superseded the moment `next()` transitions back to Stage.gate
        // (which re-applies the known-intro skip) — set here too just so
        // `gateIndex` is never briefly wrong if something else reads it
        // in between.
        gateIndex = chunkStart + (isKnownIntro(surah, chunkStart) ? 1 : 0);
      }
      return;
    }

    if (correct) {
      item.cleared.add(ex.drill!);
    } else {
      mistakes++;
      item.reset();
      item.lapses++;
      _loseHeart();
    }
  }

  /// Deliberately expensive: costs a heart and sends the ayah back to zero.
  void takeHint(Exercise ex) {
    items[ex.ayahIndex].reset();
    _loseHeart();
  }

  void _loseHeart() {
    hearts--;
    if (hearts <= 0) {
      hearts = 0;
      stage = Stage.failed;
    }
  }
}
