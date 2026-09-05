import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

/// Cloudflare Turnstile embedded via a real DOM `<div>` (through
/// `HtmlElementView`/`dart:ui_web`'s platform-view registry, the
/// standard way to put real HTML inside a CanvasKit-rendered Flutter web
/// page) plus a small hand-installed JS engine — same proven pattern as
/// `sfx_factory_web.dart`/`reminder_factory_web.dart`: a script-tag-
/// installed global, flat top-level function calls with primitive args,
/// results returned via `JsFunction.withThis` rather than `allowInterop`
/// (this SDK's `flutter analyze` can't resolve `allowInterop` — it's a
/// re-export from the same `dart:js_util` this project already found
/// unresolvable; `withThis` is declared natively in `dart:js` instead —
/// see `sfx_factory_web.dart`'s doc comment for the original discovery).
class CaptchaWidget extends StatefulWidget {
  final String siteKey;
  final ValueChanged<String> onToken;
  final ValueChanged<String>? onError;

  const CaptchaWidget({
    super.key,
    required this.siteKey,
    required this.onToken,
    this.onError,
  });

  @override
  State<CaptchaWidget> createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  static int _instanceCounter = 0;
  late final String _viewType;
  late final String _containerId;

  @override
  void initState() {
    super.initState();
    _ensureEngineInstalled();
    final n = _instanceCounter++;
    _viewType = 'ql-captcha-$n';
    _containerId = 'ql-captcha-container-$n';
    // Registered once here (initState runs exactly once per State, even
    // across parent rebuilds) — registering the same viewType twice
    // throws, which is exactly why this lives in initState and not
    // build().
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) => html.DivElement()
        ..id = _containerId
        ..style.width = '300px'
        ..style.height = '65px',
    );
    // Deferred one turn so the <div> is actually attached to the DOM
    // (HtmlElementView's factory runs synchronously during layout, but
    // Turnstile needs the element to be a real, attached DOM node before
    // it can measure/render into it).
    Timer.run(_render);
  }

  void _render() {
    try {
      js.context.callMethod('__qlCaptchaRender', [
        _containerId,
        widget.siteKey,
        js.JsFunction.withThis((Object? _, String token) => widget.onToken(token)),
        js.JsFunction.withThis((Object? _, String err) => widget.onError?.call(err)),
      ]);
    } on Object catch (e) {
      widget.onError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Turnstile's normal widget is a fixed 300x65 checkbox card.
    return SizedBox(
      width: 300,
      height: 65,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

bool _engineInstalled = false;

void _ensureEngineInstalled() {
  if (_engineInstalled) return;
  final script = html.ScriptElement()..text = _engineJs;
  html.document.head!.append(script);
  _engineInstalled = true;
}

/// Installs the real Turnstile script (Cloudflare's CDN, loaded async
/// with `render=explicit` so it never auto-renders anything on its own —
/// every widget instance calls `__qlCaptchaRender` explicitly instead)
/// plus a small queue so a render requested before Turnstile's own
/// script has finished loading waits instead of silently failing.
const String _engineJs = r'''
(function () {
  if (window.__qlCaptchaRender) return;
  window.__qlCaptchaReady = false;
  window.__qlCaptchaQueue = [];
  window.__qlCaptchaOnLoad = function () {
    window.__qlCaptchaReady = true;
    var queued = window.__qlCaptchaQueue;
    window.__qlCaptchaQueue = [];
    queued.forEach(function (fn) { fn(); });
  };

  var script = document.createElement('script');
  script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?onload=__qlCaptchaOnLoad&render=explicit';
  script.async = true;
  document.head.appendChild(script);

  window.__qlCaptchaRender = function (containerId, sitekey, onToken, onError) {
    function doRender() {
      var el = document.getElementById(containerId);
      if (!el) { onError('captcha container not found'); return; }
      if (el.dataset.qlRendered === '1') return; // don't double-render on a rebuild
      try {
        window.turnstile.render(el, {
          sitekey: sitekey,
          callback: function (token) { onToken(token); },
          'error-callback': function () { onError('challenge error'); },
          'expired-callback': function () { onError('expired'); },
        });
        el.dataset.qlRendered = '1';
      } catch (e) {
        onError(String(e));
      }
    }
    if (window.__qlCaptchaReady) { doRender(); } else { window.__qlCaptchaQueue.push(doRender); }
  };
})();
''';
