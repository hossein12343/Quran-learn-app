import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import '../offline_audio.dart';

OfflineAudio makeService() => WebOfflineAudio();

/// Backed by the browser's Cache Storage API — `caches.open`/`match`/
/// `put`/`delete` — which `dart:html` has no typed bindings for (same gap,
/// same fix, as `reminder_factory_web.dart`'s Push API wrapper: a small
/// hand-installed JS engine, `dart:js` + `JsFunction.withThis` callbacks
/// rather than `dart:js_util`'s `promiseToFuture`, which this SDK's
/// `flutter analyze` can't resolve).
///
/// One shared cache (`quran-audio-v1`), keyed by the clip's own URL — an
/// ayah is cached at most once no matter how many surahs/sessions touch
/// it, and `resolve()` below is what makes that transparent to the
/// player: it never needs to know whether a clip came from disk or the
/// network, only which URL to ask Cache Storage for.
class WebOfflineAudio implements OfflineAudio {
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
      return js.context.callMethod('__qlAudioAvailable') == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> isCached(String url) {
    if (!available) return Future.value(false);
    final completer = Completer<bool>();
    try {
      js.context.callMethod('__qlAudioHas', [
        url,
        js.JsFunction.withThis((Object? _, bool has) {
          if (!completer.isCompleted) completer.complete(has);
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  @override
  Future<bool> cache(String url) {
    if (!available) return Future.value(false);
    final completer = Completer<bool>();
    try {
      js.context.callMethod('__qlAudioStore', [
        url,
        js.JsFunction.withThis((Object? _, bool ok) {
          if (!completer.isCompleted) completer.complete(ok);
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  @override
  Future<void> uncache(String url) {
    if (!available) return Future.value();
    final completer = Completer<void>();
    try {
      js.context.callMethod('__qlAudioDelete', [
        url,
        js.JsFunction.withThis((Object? _) {
          if (!completer.isCompleted) completer.complete();
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  @override
  Future<String> resolve(String url) {
    if (!available) return Future.value(url);
    final completer = Completer<String>();
    try {
      js.context.callMethod('__qlAudioObjectUrl', [
        url,
        js.JsFunction.withThis((Object? _, String? objectUrl) {
          if (!completer.isCompleted) {
            completer.complete(objectUrl ?? url);
          }
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete(url);
    }
    return completer.future;
  }
}

const String _engineJs = r'''
(function () {
  if (window.__qlAudioAvailable) return;

  window.__qlAudioAvailable = function () {
    return 'caches' in window;
  };

  function qlCache() {
    return caches.open('quran-audio-v1');
  }

  window.__qlAudioHas = function (url, onDone) {
    qlCache()
      .then(function (c) { return c.match(url); })
      .then(function (resp) { onDone(!!resp); })
      .catch(function () { onDone(false); });
  };

  // `fetch` (not the cached clip itself) still needs everyayah.com
  // reachable, same as any uncached play always did — this only removes
  // *future* plays from needing the network again.
  window.__qlAudioStore = function (url, onDone) {
    qlCache()
      .then(function (c) {
        return fetch(url, { mode: 'cors' }).then(function (resp) {
          if (!resp.ok) throw new Error('bad status ' + resp.status);
          return c.put(url, resp);
        });
      })
      .then(function () { onDone(true); })
      .catch(function () { onDone(false); });
  };

  window.__qlAudioDelete = function (url, onDone) {
    qlCache()
      .then(function (c) { return c.delete(url); })
      .then(function () { onDone(); })
      .catch(function () { onDone(); });
  };

  window.__qlAudioObjectUrl = function (url, onDone) {
    qlCache()
      .then(function (c) { return c.match(url); })
      .then(function (resp) {
        if (!resp) { onDone(null); return; }
        return resp.blob().then(function (blob) {
          onDone(URL.createObjectURL(blob));
        });
      })
      .catch(function () { onDone(null); });
  };
})();
''';
