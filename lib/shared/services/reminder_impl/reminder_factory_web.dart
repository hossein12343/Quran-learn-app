import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import '../reminders.dart';

ReminderService makeReminderService() => WebReminderService();

/// Backed by the browser's `Notification` API (`dart:html`, typed and
/// analyzer-clean) for permission/foreground notifications, and a small
/// hand-installed JS engine (same pattern as `sfx_factory_web.dart` —
/// `dart:js`, flat top-level functions, results returned via
/// `js.allowInterop` callbacks rather than needing `dart:js_util`'s
/// `promiseToFuture`, which this SDK's `flutter analyze` doesn't
/// recognise) for the Push API and timezone lookup, neither of which
/// `dart:html` exposes typed bindings for.
class WebReminderService implements ReminderService {
  static const _storageKey = 'reminder_fired_date';
  bool _installed = false;

  void _ensureInstalled() {
    if (_installed) return;
    final script = html.ScriptElement()..text = _engineJs;
    html.document.head!.append(script);
    _installed = true;
  }

  @override
  bool get available {
    try {
      return html.Notification.supported;
    } on Object {
      return false;
    }
  }

  @override
  bool get permissionGranted {
    if (!available) return false;
    try {
      return html.Notification.permission == 'granted';
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!available) return false;
    try {
      final result = await html.Notification.requestPermission();
      return result == 'granted';
    } on Object {
      return false;
    }
  }

  @override
  bool alreadyFiredToday(String dateKey) {
    try {
      return html.window.localStorage[_storageKey] == dateKey;
    } on Object {
      return false;
    }
  }

  @override
  void fire({required String title, required String body, required String dateKey}) {
    if (!available || !permissionGranted) return;
    try {
      html.Notification(title, body: body);
      html.window.localStorage[_storageKey] = dateKey;
    } on Object {
      // A notification failing to show is a nice-to-have gap, not
      // something that should ever disrupt the app.
    }
  }

  @override
  String? get timezone {
    _ensureInstalled();
    try {
      final tz = js.context.callMethod('__qlTimezone');
      return tz is String && tz.isNotEmpty ? tz : null;
    } on Object {
      return null;
    }
  }

  @override
  bool get pushSupported {
    _ensureInstalled();
    try {
      return js.context.callMethod('__qlPushSupported') == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<PushSubscriptionData?> subscribeToPush(String vapidPublicKey) async {
    if (!pushSupported) return null;
    _ensureInstalled();
    final completer = Completer<PushSubscriptionData?>();
    try {
      js.context.callMethod('__qlPushSubscribe', [
        vapidPublicKey,
        // `JsFunction.withThis`, not `allowInterop` — this SDK's
        // `flutter analyze` can't resolve `allowInterop` (it's merely a
        // re-export from `dart:js_util`, the same library `dart:js_util`
        // itself was already found unresolvable under, in
        // `sfx_factory_web.dart`'s doc comment). `withThis` is declared
        // natively in `dart:js` and does the same job — JS calls it as a
        // normal function, and the interop bridge supplies the JS `this`
        // as this callback's own leading (here, ignored) argument.
        js.JsFunction.withThis((Object? _, String subscriptionJson) {
          if (completer.isCompleted) return;
          try {
            final map = jsonDecode(subscriptionJson) as Map<String, dynamic>;
            final keys = map['keys'] as Map<String, dynamic>;
            completer.complete(PushSubscriptionData(
              endpoint: map['endpoint'] as String,
              p256dh: keys['p256dh'] as String,
              auth: keys['auth'] as String,
            ));
          } on Object {
            completer.complete(null);
          }
        }),
        js.JsFunction.withThis((Object? _, String __) {
          if (!completer.isCompleted) completer.complete(null);
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  @override
  Future<void> unsubscribeFromPush() async {
    if (!pushSupported) return;
    _ensureInstalled();
    final completer = Completer<void>();
    try {
      js.context.callMethod('__qlPushUnsubscribe', [
        js.JsFunction.withThis((Object? _) {
          if (!completer.isCompleted) completer.complete();
        }),
      ]);
    } on Object {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }
}

/// `/push/` is a deliberately narrow, never-actually-navigated-to scope —
/// see `web/push_sw.js`'s doc comment for why this avoids ever competing
/// with Flutter's own `/`-scoped service worker.
const String _engineJs = r'''
(function () {
  if (window.__qlPushSupported) return;

  window.__qlTimezone = function () {
    try { return Intl.DateTimeFormat().resolvedOptions().timeZone || ''; }
    catch (e) { return ''; }
  };

  window.__qlPushSupported = function () {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  };

  function urlBase64ToUint8Array(base64String) {
    var padding = '='.repeat((4 - base64String.length % 4) % 4);
    var base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    var rawData = atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; ++i) outputArray[i] = rawData.charCodeAt(i);
    return outputArray;
  }

  window.__qlPushSubscribe = function (vapidPublicKey, onSuccess, onError) {
    if (!window.__qlPushSupported()) { onError('unsupported'); return; }
    navigator.serviceWorker.register('/push_sw.js', { scope: '/push/' })
      .then(function (reg) {
        return reg.pushManager.getSubscription().then(function (existing) {
          if (existing) return existing;
          return reg.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
          });
        });
      })
      .then(function (sub) { onSuccess(JSON.stringify(sub)); })
      .catch(function (err) { onError(String(err)); });
  };

  window.__qlPushUnsubscribe = function (onDone) {
    if (!('serviceWorker' in navigator)) { onDone(); return; }
    navigator.serviceWorker.getRegistration('/push/')
      .then(function (reg) {
        if (!reg) { onDone(); return; }
        return reg.pushManager.getSubscription().then(function (sub) {
          return sub ? sub.unsubscribe() : null;
        }).then(function () { onDone(); });
      })
      .catch(function () { onDone(); });
  };
})();
''';
