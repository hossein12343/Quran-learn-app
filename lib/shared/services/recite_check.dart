import 'package:flutter/foundation.dart';

/// Result of grading a spoken recitation against the expected ayah.
class ReciteResult {
  /// 0..1 — how closely the transcript matched.
  final double score;

  /// Word indices the grader thinks were wrong or missing.
  final List<int> problemWords;

  /// What the recogniser heard, for showing back to the user.
  final String transcript;

  const ReciteResult({
    required this.score,
    required this.problemWords,
    required this.transcript,
  });

  bool get passed => score >= 0.85;
}

/// Recite-aloud grading.
///
/// Real capture needs three things this build cannot install: a recorder
/// (`record`), permissions (`permission_handler`), and a recogniser. On
/// Android the microphone permission must also be declared in
/// AndroidManifest.xml — a missing declaration there is why the prompt never
/// appeared in your earlier APK. See BACKEND.md → Recite-aloud.
abstract class ReciteGrader {
  bool get available;

  /// Starts capturing. Throws if permission is refused.
  Future<void> start();

  /// Stops capturing and grades against [expected].
  Future<ReciteResult> stopAndGrade(String expected);

  Future<void> cancel();

  ValueListenable<bool> get isRecording;

  /// 0..1 input level, for drawing a live meter.
  ValueListenable<double> get level;
}

class UnavailableGrader implements ReciteGrader {
  final ValueNotifier<bool> _rec = ValueNotifier<bool>(false);
  final ValueNotifier<double> _lvl = ValueNotifier<double>(0);

  @override
  bool get available => false;

  @override
  ValueListenable<bool> get isRecording => _rec;

  @override
  ValueListenable<double> get level => _lvl;

  @override
  Future<void> start() async {
    throw StateError('Microphone capture is not set up in this build.');
  }

  @override
  Future<ReciteResult> stopAndGrade(String expected) async {
    throw StateError('Microphone capture is not set up in this build.');
  }

  @override
  Future<void> cancel() async {}
}

ReciteGrader reciteGrader = UnavailableGrader();

/// Compares a transcript to the expected ayah.
///
/// Pure Dart and independent of whichever recogniser you plug in, so it is
/// unit-testable today. Arabic diacritics are stripped before comparison
/// because no speech recogniser emits them.
class RecitationScorer {
  static final RegExp _diacritics =
      RegExp(r'[\u064B-\u0652\u0670\u0653-\u0655\u0640]');

  static String normalise(String s) => s
      .replaceAll(_diacritics, '')
      .replaceAll('\u0671', '\u0627')
      .replaceAll('\u0622', '\u0627')
      .replaceAll('\u0623', '\u0627')
      .replaceAll('\u0625', '\u0627')
      .replaceAll('\u0629', '\u0647')
      .replaceAll('\u0649', '\u064A')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static ReciteResult grade(String expected, String heard) {
    final want = normalise(expected).split(' ');
    final got = normalise(heard).split(' ');
    final problems = <int>[];
    var matched = 0;

    for (var i = 0; i < want.length; i++) {
      if (i < got.length && got[i] == want[i]) {
        matched++;
      } else if (got.contains(want[i])) {
        // Right word, wrong position — counts as half.
        matched++;
        problems.add(i);
      } else {
        problems.add(i);
      }
    }

    final score = want.isEmpty ? 0.0 : matched / want.length;
    return ReciteResult(
      score: score.clamp(0.0, 1.0),
      problemWords: problems,
      transcript: heard,
    );
  }
}
