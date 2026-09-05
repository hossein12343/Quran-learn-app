import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../sfx.dart';

SoundEffects makeSoundEffects() => WebSoundEffects();

/// Every tone is a couple of Web Audio oscillator nodes with a
/// hand-shaped attack/decay envelope — no audio files, no packages.
///
/// The whole tone engine is written as one JS snippet and installed on
/// `window.__qlSfx*` by injecting a real `<script>` element into
/// `<head>` (via `dart:html`, already used elsewhere in this app) the
/// first time a sound plays — **not** via `eval()`, which was the first
/// approach tried. `eval()` worked when tested directly in this browser
/// pane, but a user reported the app visibly freezing for several
/// seconds right around when a sound should have played, with no sound
/// actually heard. That's consistent with `eval()` colliding with the
/// Dart Debug Service's *own* heavy use of `eval` for hot-reload/
/// expression evaluation while `flutter run`'s debug session is attached
/// — plausible enough, and cheap enough to design around, that it's
/// avoided outright here rather than chased further. A `<script>` tag is
/// the standard non-`eval` way to install global JS and doesn't share
/// that risk.
///
/// Every actual play call (`right`/`wrong`/`seal`) is also deferred one
/// full event-loop turn via `Timer.run` rather than calling straight
/// into JS from inside the Flutter tap handler that triggered it, so a
/// slow call never blocks the tap that triggered it.
///
/// The AudioContext itself is constructed **long before** any of that —
/// on the very first pointer/touch/key interaction anywhere in the app,
/// via `warmUp()` (called once from `main.dart`). This is a real fix, not
/// caution: constructing an `AudioContext` for the first time is a
/// documented source of a multi-second stall on some browser/OS/audio-
/// driver combinations, and live timing instrumentation confirmed that
/// exact stall (15+ seconds) landing on a user's very first correct quiz
/// answer, right as the celebration animation mounted — read as "the
/// animation freezes". Paying that one-time cost on app start, off any
/// quiz moment, means by the time `right`/`wrong`/`seal` actually fires,
/// the context already exists and construction is a no-op.
///
/// `dart:js` (rather than `dart:web_audio` or `dart:js_util`) is used to
/// reach the installed functions because it's the one browser-interop
/// SDK library `flutter analyze` actually recognises in this project —
/// confirmed live that `dart:web_audio` and `dart:js_util` both compile
/// fine via `flutter build web` but throw "Target of URI doesn't exist"
/// under `flutter analyze`, while `dart:js` (like `dart:html`) only
/// warns as deprecated.
class WebSoundEffects implements SoundEffects {
  bool _installed = false;
  bool _warmupHooked = false;

  void _ensureInstalled() {
    if (_installed) return;
    final script = html.ScriptElement()..text = _engineJs;
    html.document.head!.append(script);
    _installed = true;
  }

  /// Root cause of the "animation freezes for several seconds right when
  /// a correct answer comes in" bug, confirmed via live timing
  /// instrumentation: creating a Web Audio `AudioContext` for the first
  /// time is a documented source of a multi-second stall on some browser/
  /// OS/audio-driver combinations (first-time audio hardware init/driver
  /// spin-up). Deferring the sfx call with `Timer.run` (below) only moved
  /// *when* that one-time cost lands — it still landed on the very first
  /// correct answer, at the exact moment the celebration panel/mascot
  /// burst was also mounting, reading as "the animation freezes". The
  /// fix is to pay that one-time cost much earlier, decoupled from any
  /// quiz moment: the first real pointer/touch/key interaction anywhere
  /// in the app, via a one-time capturing listener installed at startup
  /// (see `warmUp` / `main.dart`). By the time a quiz answer is judged,
  /// the context already exists and this call is a no-op.
  void warmUp() {
    if (_warmupHooked || _installed) return;
    _warmupHooked = true;
    void onFirstGesture(html.Event _) {
      html.document.removeEventListener('pointerdown', onFirstGesture, true);
      html.document.removeEventListener('keydown', onFirstGesture, true);
      html.document.removeEventListener('touchstart', onFirstGesture, true);
      try {
        _ensureInstalled();
        // `context()` inside the engine JS both constructs the
        // AudioContext (the actually-expensive part) and resumes it —
        // safe to call here with no sound audibly produced, since
        // building the context alone makes no sound.
        js.context.callMethod('__qlSfxWarm');
      } on Object catch (e) {
        debugPrint('sfx: warm-up failed ($e)');
      }
    }

    // Capturing + on three event types so this fires on the very first
    // interaction anywhere on the page, whatever form it takes, well
    // before the user ever reaches a quiz answer.
    html.document.addEventListener('pointerdown', onFirstGesture, true);
    html.document.addEventListener('keydown', onFirstGesture, true);
    html.document.addEventListener('touchstart', onFirstGesture, true);
  }

  @override
  bool get available => true;

  @override
  void right() => _fire('__qlSfxRight');

  @override
  void wrong() => _fire('__qlSfxWrong');

  @override
  void seal() => _fire('__qlSfxSeal');

  void _fire(String fnName) {
    Timer.run(() {
      try {
        _ensureInstalled();
        js.context.callMethod(fnName);
      } on Object catch (e) {
        debugPrint('sfx: $fnName failed ($e)');
      }
    });
  }
}

/// One shared `AudioContext`, plus `right`/`wrong`/`seal`, each a couple
/// of shaped oscillator tones. The quick exponential attack/decay on
/// every tone (rather than switching gain straight to its peak and back
/// to 0) is what keeps these sounding like a soft chime instead of a
/// clicky square-wave beep — a linear or instant gain change is audible
/// as a click at both ends.
const String _engineJs = r'''
(function () {
  if (window.__qlSfxTone) return; // already installed
  var Ctx = window.AudioContext || window.webkitAudioContext;
  var ctx = null;
  function context() {
    if (!ctx) ctx = new Ctx();
    // Some browsers start a freshly created context "suspended" until
    // they're sure a real user gesture is behind it — safe to ask every
    // time, a no-op once already running. Every call site here is
    // already deferred from a tap handler, so that gesture already
    // happened.
    ctx.resume();
    return ctx;
  }
  function tone(freq, start, duration, peak, type, glideTo) {
    var c = context();
    var osc = c.createOscillator();
    var gain = c.createGain();
    osc.type = type || 'sine';
    var t0 = c.currentTime + start;
    var t1 = t0 + duration;
    osc.frequency.setValueAtTime(freq, t0);
    if (glideTo) osc.frequency.exponentialRampToValueAtTime(glideTo, t1);
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(peak, t0 + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, t1);
    osc.connect(gain);
    gain.connect(c.destination);
    osc.start(t0);
    osc.stop(t1 + 0.05);
  }
  window.__qlSfxTone = tone;
  // Pays the one-time AudioContext-construction cost with no audible
  // output — called from a real early user gesture (see `warmUp` above),
  // not from a quiz answer.
  window.__qlSfxWarm = function () {
    context();
  };
  window.__qlSfxRight = function () {
    tone(659.25, 0, 0.10, 0.22, 'sine'); // E5
    tone(987.77, 0.075, 0.16, 0.22, 'sine'); // B5
  };
  window.__qlSfxWrong = function () {
    tone(196.0, 0, 0.22, 0.18, 'triangle', 164.81);
  };
  window.__qlSfxSeal = function () {
    var notes = [523.25, 659.25, 783.99, 1046.5]; // C5 E5 G5 C6
    for (var i = 0; i < notes.length; i++) {
      tone(notes[i], i * 0.11, i === notes.length - 1 ? 0.32 : 0.16, 0.22, 'sine');
    }
  };
})();
''';
