import 'dart:html' as html;
import 'dart:js' as js;
import '../media_session.dart';

MediaSessionController makeMediaSession() => WebMediaSession();

/// Backed by `navigator.mediaSession` — no typed `dart:html` binding
/// covers it, so this is the same hand-installed JS engine + `dart:js`
/// `JsFunction.withThis` callback pattern as `share_factory_web.dart`.
class WebMediaSession implements MediaSessionController {
  bool _installed = false;

  void _ensureInstalled() {
    if (_installed) return;
    final script = html.ScriptElement()..text = _engineJs;
    html.document.head!.append(script);
    _installed = true;
  }

  @override
  bool get available {
    _ensureInstalled();
    try {
      return js.context.callMethod('__qlMediaSessionAvailable') == true;
    } on Object {
      return false;
    }
  }

  @override
  void setMetadata({required String title, String? artist}) {
    _ensureInstalled();
    try {
      js.context
          .callMethod('__qlMediaSessionSetMetadata', [title, artist ?? '']);
    } on Object {
      // Best-effort — a lock screen with no metadata is no worse than
      // this feature not existing at all.
    }
  }

  @override
  void setPlaying(bool playing) {
    _ensureInstalled();
    try {
      js.context.callMethod(
          '__qlMediaSessionSetPlaybackState', [playing ? 'playing' : 'paused']);
    } on Object {}
  }

  @override
  void setHandlers({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onStop,
  }) {
    _ensureInstalled();
    try {
      js.context.callMethod('__qlMediaSessionSetHandlers', [
        js.JsFunction.withThis((Object? _) => onPlay()),
        js.JsFunction.withThis((Object? _) => onPause()),
        js.JsFunction.withThis((Object? _) => onStop()),
      ]);
    } on Object {}
  }

  @override
  void clear() {
    _ensureInstalled();
    try {
      js.context.callMethod('__qlMediaSessionClear');
    } on Object {}
  }
}

const String _engineJs = r'''
(function () {
  if (window.__qlMediaSessionAvailable) return;

  window.__qlMediaSessionAvailable = function () {
    return 'mediaSession' in navigator;
  };

  window.__qlMediaSessionSetMetadata = function (title, artist) {
    if (!('mediaSession' in navigator)) return;
    navigator.mediaSession.metadata = new MediaMetadata({
      title: title,
      artist: artist
    });
  };

  window.__qlMediaSessionSetPlaybackState = function (state) {
    if (!('mediaSession' in navigator)) return;
    navigator.mediaSession.playbackState = state;
  };

  window.__qlMediaSessionSetHandlers = function (onPlay, onPause, onStop) {
    if (!('mediaSession' in navigator)) return;
    navigator.mediaSession.setActionHandler('play', function () { onPlay(); });
    navigator.mediaSession.setActionHandler('pause', function () { onPause(); });
    // Not every browser implements the 'stop' action — Safari in
    // particular can throw on an unrecognised action name.
    try {
      navigator.mediaSession.setActionHandler('stop', function () { onStop(); });
    } catch (e) {}
  };

  window.__qlMediaSessionClear = function () {
    if (!('mediaSession' in navigator)) return;
    navigator.mediaSession.metadata = null;
    navigator.mediaSession.playbackState = 'none';
    try { navigator.mediaSession.setActionHandler('play', null); } catch (e) {}
    try { navigator.mediaSession.setActionHandler('pause', null); } catch (e) {}
    try { navigator.mediaSession.setActionHandler('stop', null); } catch (e) {}
  };
})();
''';
