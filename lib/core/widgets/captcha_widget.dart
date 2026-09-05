/// Renders a Cloudflare Turnstile challenge and reports the resulting
/// token — real widget on web, an invisible no-op stub everywhere else
/// (same conditional-export shape as `sfx`/`reminders`).
library captcha_widget;

export 'captcha_widget_stub.dart' if (dart.library.html) 'captcha_widget_web.dart';
