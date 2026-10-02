import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import '../app_install.dart';

// The browser side lives in web/flutter_bootstrap.js (__qlStandalone,
// __qlCanInstall, __qlPromptInstall), because Chrome's install offer can
// arrive before the app starts.

bool _call(String fn) {
  try {
    return js.context.callMethod(fn) == true;
  } on Object {
    return false;
  }
}

InstallWay currentWay() {
  if (_call('__qlStandalone')) return InstallWay.none;
  final agent = html.window.navigator.userAgent;
  if (agent.contains('iPhone')) return InstallWay.iphoneSteps;
  if (_call('__qlCanInstall')) return InstallWay.browserPrompt;
  if (agent.contains('Android')) return InstallWay.androidSteps;
  return InstallWay.none;
}

Future<bool> prompt() {
  final done = Completer<bool>();
  try {
    js.context.callMethod('__qlPromptInstall', [
      js.JsFunction.withThis((Object? _, Object? installed) {
        if (!done.isCompleted) done.complete(installed == true);
      }),
    ]);
  } on Object {
    if (!done.isCompleted) done.complete(false);
  }
  return done.future;
}

void onChange(void Function() changed) {
  html.window.addEventListener('ql-installable', (_) => changed());
}
