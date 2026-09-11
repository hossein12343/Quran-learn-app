import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import '../share.dart';

ShareService makeShareService() => WebShareService();

/// Backed by `navigator.share`/`navigator.clipboard.writeText` — neither
/// has a typed `dart:html` binding, so this is the same small hand-
/// installed JS engine + `dart:js` `JsFunction.withThis` callback pattern
/// as `offline_audio_factory_web.dart`'s Cache Storage wrapper.
class WebShareService implements ShareService {
  bool _installed = false;

  void _ensureInstalled() {
    if (_installed) return;
    final script = html.ScriptElement()..text = _engineJs;
    html.document.head!.append(script);
    _installed = true;
  }

  @override
  bool get canShare {
    _ensureInstalled();
    try {
      return js.context.callMethod('__qlCanShare') == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> share({required String text, String? title}) {
    _ensureInstalled();
    final completer = Completer<bool>();
    try {
      js.context.callMethod('__qlShare', [
        title ?? '',
        text,
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
  Future<bool> copyToClipboard(String text) {
    _ensureInstalled();
    final completer = Completer<bool>();
    try {
      js.context.callMethod('__qlCopyToClipboard', [
        text,
        js.JsFunction.withThis((Object? _, bool ok) {
          if (!completer.isCompleted) completer.complete(ok);
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }
}

const String _engineJs = r'''
(function () {
  if (window.__qlCanShare) return;

  window.__qlCanShare = function () {
    return !!(navigator.share);
  };

  window.__qlShare = function (title, text, onDone) {
    if (!navigator.share) { onDone(false); return; }
    navigator.share({ title: title, text: text })
      .then(function () { onDone(true); })
      // Includes the user simply cancelling the share sheet (AbortError)
      // — not worth distinguishing from a real failure here, since
      // either way the caller's only fallback action is the same.
      .catch(function () { onDone(false); });
  };

  window.__qlCopyToClipboard = function (text, onDone) {
    if (!(navigator.clipboard && navigator.clipboard.writeText)) {
      onDone(false);
      return;
    }
    navigator.clipboard.writeText(text)
      .then(function () { onDone(true); })
      .catch(function () { onDone(false); });
  };
})();
''';
