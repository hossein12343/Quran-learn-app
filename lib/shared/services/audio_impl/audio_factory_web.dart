import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../app_log.dart';
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

  /// Bumped on every `play()` call, and checked after every `await` inside
  /// it, so a call superseded by a newer one (the user tapped play again,
  /// or the quiz auto-advanced to the next ayah, before the first clip
  /// actually started) quietly gives up instead of fighting the newer
  /// call for the shared `<audio>` element or logging a spurious error.
  /// Without this, changing `_el.src` mid-flight reliably throws
  /// `AbortError` from the *first* call's `.play()` — on mobile browsers
  /// in particular, this is the single most common reason "the sound
  /// doesn't work" even though playback itself is fine: a teach step's
  /// auto-play race with the mascot/UI settling, or a double-tap on the
  /// play button, aborted the very first attempt and nothing retried it.
  int _playToken = 0;

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
    final token = ++_playToken;
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
        if (token == _playToken) _el.currentTime = skip;
      }));
    }
    try {
      await _el.play();
    } on Object catch (e) {
      if (token != _playToken) {
        // Superseded by a newer play() while this one was still starting
        // — expected, not a real failure. Silent on purpose.
        return;
      }
      // A genuine failure (blocked by the browser's autoplay policy,
      // network error, unsupported format, ...). This used to be a bare
      // debugPrint, invisible outside a locally-attached DevTools console
      // — exactly the case where "it just doesn't make a sound" would
      // never surface without one. AppLog.warn is still local-only for
      // now (see app_log.dart), but this is the seam a rate-limited Edge
      // Function should hang off of if remote diagnostics come back.
      AppLog.warn('Recitation playback failed', error: e, context: {
        'surah': surah,
        'ayah': ayah,
        'qari': qariId,
        'url': url,
      });
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
