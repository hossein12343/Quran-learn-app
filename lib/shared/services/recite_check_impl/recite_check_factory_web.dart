import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../recite_check.dart';

ReciteGrader makeReciteGrader() => WebReciteGrader();

/// Real recite-aloud grading on web via two browser APIs, neither of which
/// needs a pub.dev package: the Web Speech API (`SpeechRecognition`) for
/// the transcript, and Web Audio (`AnalyserNode`) on the same microphone
/// stream for the live input-level meter. Same footing as
/// `sfx_factory_web.dart`/`reminder_factory_web.dart` — a small hand-
/// installed JS engine reached via `dart:js`, results returned through
/// `JsFunction.withThis` callbacks rather than `dart:js_util`'s
/// `promiseToFuture` (unresolvable under this SDK's `flutter analyze`,
/// see `sfx_factory_web.dart`'s doc comment).
///
/// `available` deliberately does *not* depend on the JS engine being
/// installed — it only asks whether `window.SpeechRecognition` (or the
/// still-current `webkit`-prefixed name) exists at all, the same
/// "ask the platform directly" shape as `WebReminderService.available`
/// checking `html.Notification.supported`. Chrome/Edge ship it
/// unprefixed-adjacent (`webkitSpeechRecognition`); Firefox and Safari, as
/// of this writing, ship neither — on those browsers this correctly stays
/// `false` and the app falls back to the ungraded "I repeated it" flow,
/// same as it always has.
class WebReciteGrader implements ReciteGrader {
  bool _installed = false;
  final ValueNotifier<bool> _rec = ValueNotifier<bool>(false);
  final ValueNotifier<double> _lvl = ValueNotifier<double>(0);

  void _ensureInstalled() {
    if (_installed) return;
    final script = html.ScriptElement()..text = _engineJs;
    html.document.head!.append(script);
    _installed = true;
  }

  @override
  bool get available {
    try {
      return js.context.hasProperty('SpeechRecognition') ||
          js.context.hasProperty('webkitSpeechRecognition');
    } on Object {
      return false;
    }
  }

  @override
  ValueListenable<bool> get isRecording => _rec;

  @override
  ValueListenable<double> get level => _lvl;

  @override
  Future<void> start() async {
    if (!available) {
      throw StateError('Microphone capture is not set up in this build.');
    }
    _ensureInstalled();
    final completer = Completer<void>();
    try {
      js.context.callMethod('__qlReciteStart', [
        js.JsFunction.withThis((Object? _, num v) => _lvl.value = v.toDouble()),
        // Recognition can end on its own (a silence timeout, or the tab
        // losing the mic) before the user ever taps stop — this keeps
        // `isRecording` truthful instead of it reading "still recording"
        // forever after that.
        js.JsFunction.withThis((Object? _) => _rec.value = false),
        js.JsFunction.withThis((Object? _, String err) {
          _rec.value = false;
          _lvl.value = 0;
          if (!completer.isCompleted) {
            completer.completeError(StateError(err));
          }
        }),
      ]);
    } on Object catch (e) {
      throw StateError('Microphone capture failed to start: $e');
    }
    _rec.value = true;
    if (!completer.isCompleted) completer.complete();
    return completer.future;
  }

  @override
  Future<ReciteResult> stopAndGrade(String expected) async {
    _rec.value = false;
    final completer = Completer<String>();
    try {
      js.context.callMethod('__qlReciteStop', [
        js.JsFunction.withThis((Object? _, String transcript) {
          if (!completer.isCompleted) completer.complete(transcript);
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete('');
    }
    _lvl.value = 0;
    final transcript = await completer.future;
    return RecitationScorer.grade(expected, transcript);
  }

  @override
  Future<void> cancel() async {
    _rec.value = false;
    _lvl.value = 0;
    try {
      js.context.callMethod('__qlReciteCancel');
    } on Object {
      // Nothing was capturing, or the engine was never installed — fine.
    }
  }
}

/// One shared `SpeechRecognition` instance plus a `getUserMedia` +
/// `AnalyserNode` level meter running alongside it on the same
/// microphone. Both ask for mic permission; browsers only ever prompt
/// once per origin and silently reuse that grant for the second ask, so
/// this doesn't double-prompt in practice.
const String _engineJs = r'''
(function () {
  if (window.__qlReciteStart) return; // already installed

  var Rec = window.SpeechRecognition || window.webkitSpeechRecognition;
  var recognition = null;
  var stream = null;
  var audioCtx = null;
  var analyser = null;
  var rafId = null;
  var finalTranscript = '';

  function stopMeter() {
    if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
    if (stream) {
      stream.getTracks().forEach(function (t) { t.stop(); });
      stream = null;
    }
    analyser = null;
  }

  function meterLoop(onLevel) {
    if (!analyser) return;
    var data = new Uint8Array(analyser.frequencyBinCount);
    analyser.getByteTimeDomainData(data);
    var sum = 0;
    for (var i = 0; i < data.length; i++) {
      var v = (data[i] - 128) / 128;
      sum += v * v;
    }
    var rms = Math.sqrt(sum / data.length);
    onLevel(Math.min(1, rms * 4));
    rafId = requestAnimationFrame(function () { meterLoop(onLevel); });
  }

  window.__qlReciteStart = function (onLevel, onEnded, onError) {
    if (!Rec) { onError('Speech recognition is not supported here.'); return; }
    finalTranscript = '';
    try {
      recognition = new Rec();
      recognition.lang = 'ar-SA';
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.onresult = function (event) {
        for (var i = event.resultIndex; i < event.results.length; i++) {
          if (event.results[i].isFinal) {
            finalTranscript += event.results[i][0].transcript + ' ';
          }
        }
      };
      recognition.onerror = function (event) {
        onError(String(event.error || 'recognition error'));
      };
      recognition.onend = function () { onEnded(); };
      recognition.start();
    } catch (e) {
      onError(String(e));
      return;
    }
    // Level metering rides on its own getUserMedia stream, independent of
    // recognition's internal one — a nice-to-have, so its failure is
    // swallowed rather than surfaced through onError, which is reserved
    // for recognition itself failing to start.
    navigator.mediaDevices.getUserMedia({ audio: true }).then(function (s) {
      stream = s;
      audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
      var source = audioCtx.createMediaStreamSource(stream);
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 512;
      source.connect(analyser);
      meterLoop(onLevel);
    }).catch(function () {});
  };

  window.__qlReciteStop = function (onResult) {
    stopMeter();
    if (recognition) {
      recognition.onend = null; // this stop is intentional, not a timeout
      try { recognition.stop(); } catch (e) {}
    }
    // A final onresult for the tail end of speech can still arrive just
    // after stop() — this grace delay lets it land before grading reads
    // finalTranscript.
    setTimeout(function () {
      onResult(finalTranscript.trim());
      recognition = null;
    }, 300);
  };

  window.__qlReciteCancel = function () {
    stopMeter();
    if (recognition) {
      recognition.onend = null;
      recognition.onresult = null;
      recognition.onerror = null;
      try { recognition.abort(); } catch (e) {}
      recognition = null;
    }
    finalTranscript = '';
  };
})();
''';
