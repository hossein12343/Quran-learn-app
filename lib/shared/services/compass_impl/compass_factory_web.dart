import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../compass.dart';

DeviceCompass makeCompass() => WebDeviceCompass();

/// Backed by the browser's `deviceorientationabsolute` (Android/Chrome) or
/// `deviceorientation` + the WebKit-only `webkitCompassHeading` (iOS
/// Safari) events — neither is covered by a typed `dart:html` binding, so
/// this is a small hand-installed JS engine, same `dart:js` +
/// `JsFunction.withThis` pattern as `offline_audio_factory_web.dart`'s
/// Cache Storage wrapper.
///
/// Deliberately conservative about what counts as a real heading: a plain
/// `deviceorientation` event with neither `webkitCompassHeading` nor
/// `absolute: true` is *relative* rotation only, not locked to true
/// north — reporting that as "the heading" would silently point users the
/// wrong way, worse than not showing a live needle at all. Those cases
/// are dropped rather than guessed at; [heading] simply never updates,
/// and the Qibla page falls back to its static bearing display.
class WebDeviceCompass implements DeviceCompass {
  final ValueNotifier<double?> _heading = ValueNotifier<double?>(null);
  bool _installed = false;
  bool _started = false;

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
      return js.context.callMethod('__qlCompassAvailable') == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() {
    _ensureInstalled();
    final completer = Completer<bool>();
    try {
      js.context.callMethod('__qlCompassRequestPermission', [
        js.JsFunction.withThis((Object? _, bool granted) {
          if (granted) _startListening();
          if (!completer.isCompleted) completer.complete(granted);
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  void _startListening() {
    if (_started) return;
    _started = true;
    try {
      js.context.callMethod('__qlCompassStart', [
        js.JsFunction.withThis((Object? _, num heading) {
          _heading.value = heading.toDouble();
        }),
      ]);
    } on Object {
      // Nothing sensible to do here — heading just stays null, same as
      // if the sensor never existed.
    }
  }

  @override
  ValueListenable<double?> get heading => _heading;
}

const String _engineJs = r'''
(function () {
  if (window.__qlCompassAvailable) return;

  window.__qlCompassAvailable = function () {
    return typeof DeviceOrientationEvent !== 'undefined';
  };

  window.__qlCompassRequestPermission = function (onDone) {
    if (typeof DeviceOrientationEvent === 'undefined') { onDone(false); return; }
    if (typeof DeviceOrientationEvent.requestPermission === 'function') {
      DeviceOrientationEvent.requestPermission()
        .then(function (state) { onDone(state === 'granted'); })
        .catch(function () { onDone(false); });
    } else {
      // Most browsers (Android Chrome, desktop) have no gate at all.
      onDone(true);
    }
  };

  var started = false;
  window.__qlCompassStart = function (onHeading) {
    if (started) return;
    started = true;
    function handle(e) {
      var heading = null;
      if (typeof e.webkitCompassHeading === 'number' && !isNaN(e.webkitCompassHeading)) {
        // iOS Safari: already a true-north heading, no conversion needed.
        heading = e.webkitCompassHeading;
      } else if (e.absolute === true && typeof e.alpha === 'number') {
        // Standard absolute-orientation-to-compass-heading conversion.
        heading = (360 - e.alpha) % 360;
      }
      // A plain relative deviceorientation event (neither branch above)
      // is deliberately ignored — see the class doc comment.
      if (heading !== null) onHeading(heading);
    }
    window.addEventListener('deviceorientationabsolute', handle, true);
    window.addEventListener('deviceorientation', handle, true);
  };
})();
''';
