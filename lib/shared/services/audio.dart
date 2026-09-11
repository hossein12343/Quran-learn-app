import 'package:flutter/foundation.dart';
import 'settings.dart';

/// Per-ayah recitation playback.
///
/// This is an interface plus a no-op implementation, on purpose. Flutter has
/// no audio in the SDK, so real playback needs a package (just_audio or
/// audioplayers) which cannot be fetched while pub.dev is refusing your
/// machine. Every screen talks to `recitation` only, so switching to the real
/// implementation is one new file and one line in main().
abstract class RecitationPlayer {
  /// Whether real audio is wired up. The UI uses this to decide between
  /// showing a play button and showing "audio not set up yet".
  bool get available;

  Future<void> play({
    required int surah,
    required int ayah,
    required String qariId,
    double speed,
  });

  Future<void> stop();
  Future<void> setSpeed(double speed);

  /// Plays an arbitrary short clip by URL — used for a single word's
  /// own audio (see `shared/data/word_by_word.dart`'s `wordAudioUrl`),
  /// not a full ayah. Bypasses [play]'s surah/ayah/qari-specific
  /// logic entirely (no bismillah-skip, no offline-cache resolution).
  /// Shares the same underlying audio channel as [play] — starting
  /// this supersedes any in-progress ayah playback and vice versa,
  /// same one-audio-channel behavior as everywhere else in this app.
  Future<void> playClip(String url);

  /// Emits true while a clip is playing.
  ValueListenable<bool> get isPlaying;

  /// Bumped once each time a clip plays through to its natural end — not
  /// when playback is stopped or superseded by a newer `play()`. The Qur'an
  /// reader's continuous / repeat playback advances off this.
  ValueListenable<int> get clipEndCount;

  /// Unlocks the underlying `<audio>` element for the rest of the page's
  /// lifetime. Mobile Safari in particular refuses to play *any* media —
  /// not just the first attempt — unless a `.play()` call happens
  /// synchronously inside a real user gesture at least once; a session's
  /// very first recitation is triggered from `QuizPage.initState`
  /// (reached after a route push settles, not inside the tap that started
  /// it), which misses that window. No-op off-web. Call once, from a real
  /// early user gesture — see `main.dart`, same pattern as `sfx.warmUp()`.
  void warmUp();
}

class SilentPlayer implements RecitationPlayer {
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);
  final ValueNotifier<int> _clipEnds = ValueNotifier<int>(0);

  @override
  bool get available => false;

  @override
  ValueListenable<bool> get isPlaying => _playing;

  @override
  ValueListenable<int> get clipEndCount => _clipEnds;

  @override
  Future<void> play({
    required int surah,
    required int ayah,
    required String qariId,
    double speed = 1.0,
  }) async {
    // Deliberately does nothing. See BACKEND.md → Audio.
    debugPrint('audio stub: $surah:$ayah by $qariId at ${speed}x');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> playClip(String url) async {
    debugPrint('audio stub: clip $url');
  }

  @override
  void warmUp() {}
}

/// Real playback on web (via the browser's own `<audio>` element — no
/// package needed) or the silent stub elsewhere. See
/// `audio_impl/audio_web.dart`. Set once in main().
RecitationPlayer recitation = SilentPlayer();

/// Builds the per-ayah clip URL.
///
/// The everyayah.com layout is `{base}/{reciterFolder}/{surah}{ayah}.mp3`
/// with both numbers zero-padded to three digits. The folder name per
/// reciter is NOT guessable — read it off the source before relying on it.
String ayahClipPath(String reciterFolder, int surah, int ayah) {
  final s = surah.toString().padLeft(3, '0');
  final a = ayah.toString().padLeft(3, '0');
  return '$reciterFolder/$s$a.mp3';
}

/// Convenience wrapper that reads the user's current settings.
Future<void> playCurrent(int surah, int ayah) => recitation.play(
      surah: surah,
      ayah: ayah,
      qariId: settings.qariId,
      speed: settings.speed,
    );
