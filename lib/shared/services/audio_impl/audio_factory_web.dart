import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../../data/quran_seed.dart';
import '../app_log.dart';
import '../audio.dart';
import '../media_session.dart';
import '../offline_audio.dart';
import '../settings.dart';

RecitationPlayer makePlayer() => WebAudioPlayer();

/// Streams per-ayah recitation straight from everyayah.com using the
/// browser's native `<audio>` element — no audio package, so it works
/// while pub.dev is unreachable. Nothing is downloaded ahead of time;
/// each ayah is a small clip fetched on demand.
class WebAudioPlayer implements RecitationPlayer {
  final html.AudioElement _el = html.AudioElement()..preload = 'auto';
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);
  final ValueNotifier<int> _clipEnds = ValueNotifier<int>(0);

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
    _el.onPlay.listen((_) {
      _playing.value = true;
      mediaSession.setPlaying(true);
    });
    _el.onPause.listen((_) {
      _playing.value = false;
      mediaSession.setPlaying(false);
    });
    _el.onEnded.listen((_) {
      _playing.value = false;
      _clipEnds.value++;
      mediaSession.setPlaying(false);
    });
    // Registered once, for the player's whole lifetime — the system's
    // play/pause controls (lock screen, notification shade, hardware
    // media keys) just drive the same `<audio>` element directly, so
    // the `on*` listeners above are the single source of truth for
    // `_playing`/`mediaSession.setPlaying` either way, whether playback
    // started/stopped from inside the app or from outside it.
    mediaSession.setHandlers(
      onPlay: () => unawaited(_el.play()),
      onPause: _el.pause,
      onStop: () => unawaited(stop()),
    );
  }

  @override
  bool get available => true;

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
    final token = ++_playToken;
    final qari = knownQaris.firstWhere((q) => q.id == qariId,
        orElse: () => knownQaris.first);
    final url =
        'https://everyayah.com/data/${ayahClipPath(qari.folder, surah, ayah)}';
    final surahMatch = surahs.where((s) => s.number == surah);
    final surahName =
        surahMatch.isEmpty ? 'سورهٔ $surah' : surahMatch.first.englishName;
    mediaSession.setMetadata(
      title: '$surahName — آیهٔ $ayah',
      artist: qari.nativeName,
    );
    // Transparent to every caller: plays from the downloaded copy (see
    // offline_audio.dart / the reader's "دانلود برای آفلاین" control) when
    // one exists, the live network URL otherwise — nothing here needs to
    // know or care which.
    final playUrl = await offlineAudio.resolve(url);
    if (token != _playToken) return; // superseded while resolving
    _el
      ..src = playUrl
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

  @override
  Future<void> playClip(String url) async {
    final token = ++_playToken;
    _el
      ..src = url
      ..playbackRate = 1.0;
    try {
      await _el.play();
    } on Object catch (e) {
      if (token != _playToken) return; // superseded — see play()'s own note
      AppLog.warn('Word clip playback failed', error: e, context: {'url': url});
    }
  }

  bool _warmupHooked = false;

  @override
  void warmUp() {
    // Same shape as `sfx.warmUp()`: called once from `main()`, long before
    // any real interaction, so it only *registers* for the first genuine
    // gesture anywhere in the app — capturing, so it fires before that
    // gesture is spent on whatever widget it actually landed on.
    if (_warmupHooked) return;
    _warmupHooked = true;
    void onFirstGesture(html.Event _) {
      html.document.removeEventListener('pointerdown', onFirstGesture, true);
      html.document.removeEventListener('keydown', onFirstGesture, true);
      html.document.removeEventListener('touchstart', onFirstGesture, true);
      // The standard "silent unlock" trick: play a near-zero-length
      // silent clip (a 1-sample WAV, inlined as a data: URI so there's no
      // network round trip to race the gesture against) synchronously
      // inside this real gesture, then immediately stop and clear it. On
      // browsers that gate media playback behind user activation (mobile
      // Safari above all), this unlocks *every later* `.play()` call on
      // this element for the rest of the page's lifetime — including
      // ones triggered programmatically, like a teach step auto-playing
      // right after `QuizPage` finishes pushing onto the Navigator, which
      // is otherwise too far removed from the tap that started it to
      // count as a user gesture on its own.
      try {
        _el.src =
            'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=';
        final playFuture = _el.play();
        // A rejected promise here (still possible) shouldn't surface as
        // an app error — this is a best-effort unlock, and a genuine
        // playback failure later still goes through `play()`'s own
        // AppLog.warn.
        unawaited(playFuture.catchError((_) {}).whenComplete(() {
          _el.pause();
          _el.currentTime = 0;
          _el.removeAttribute('src');
        }));
      } on Object {
        // Nothing sensible to do with a synchronous failure here either.
      }
    }

    html.document.addEventListener('pointerdown', onFirstGesture, true);
    html.document.addEventListener('keydown', onFirstGesture, true);
    html.document.addEventListener('touchstart', onFirstGesture, true);
  }
}
