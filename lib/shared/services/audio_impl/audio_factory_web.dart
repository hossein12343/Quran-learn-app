import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../audio.dart';
import '../settings.dart';

RecitationPlayer makePlayer() => WebAudioPlayer();

/// Streams per-ayah recitation straight from everyayah.com using the
/// browser's native `<audio>` element — no audio package, so it works
/// while pub.dev is unreachable. Nothing is downloaded ahead of time;
/// each ayah is a small clip fetched on demand.
class WebAudioPlayer implements RecitationPlayer {
  final html.AudioElement _el = html.AudioElement()..preload = 'auto';
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);

  WebAudioPlayer() {
    _el.onPlay.listen((_) => _playing.value = true);
    _el.onPause.listen((_) => _playing.value = false);
    _el.onEnded.listen((_) => _playing.value = false);
  }

  @override
  bool get available => true;

  @override
  ValueListenable<bool> get isPlaying => _playing;

  @override
  Future<void> play({
    required int surah,
    required int ayah,
    required String qariId,
    double speed = 1.0,
  }) async {
    final qari =
        knownQaris.firstWhere((q) => q.id == qariId, orElse: () => knownQaris.first);
    final url =
        'https://everyayah.com/data/${ayahClipPath(qari.folder, surah, ayah)}';
    _el
      ..src = url
      ..playbackRate = speed;
    final skip = _bismillahSkipSeconds(surah, ayah);
    if (skip > 0) {
      // everyayah.com's ayah-1 clip for every surah except Al-Fatihah (whose
      // own ayah 1 genuinely *is* the basmala) and At-Tawbah (recited with
      // no basmala at all) has the reciter's spoken "Bismillah..." baked
      // into the start of the file — heard fresh on every single surah,
      // which is exactly what got flagged as repetitive. There's no
      // per-reciter timestamp data to cut it precisely, so this seeks past
      // an approximate, reciter-average duration instead of playing the
      // whole clip; wait for metadata so the seek actually takes (setting
      // currentTime before the browser knows the clip's duration is
      // unreliable across browsers).
      unawaited(_el.onLoadedMetadata.first.then((_) {
        _el.currentTime = skip;
      }));
    }
    try {
      await _el.play();
    } on Object catch (e) {
      debugPrint('audio: could not play $url ($e)');
    }
  }

  /// Seconds to skip into ayah 1's clip to land past the spoken basmala.
  /// 0 for every other ayah, and for the two surahs where ayah 1 isn't
  /// preceded by one at all.
  double _bismillahSkipSeconds(int surah, int ayah) {
    if (ayah != 1 || surah == 1 || surah == 9) return 0;
    return 3.6;
  }

  @override
  Future<void> stop() async {
    _el.pause();
    _el.currentTime = 0;
  }

  @override
  Future<void> setSpeed(double speed) async {
    _el.playbackRate = speed;
  }
}
