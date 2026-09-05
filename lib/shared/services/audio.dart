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

  /// Emits true while a clip is playing.
  ValueListenable<bool> get isPlaying;
}

class SilentPlayer implements RecitationPlayer {
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);

  @override
  bool get available => false;

  @override
  ValueListenable<bool> get isPlaying => _playing;

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
