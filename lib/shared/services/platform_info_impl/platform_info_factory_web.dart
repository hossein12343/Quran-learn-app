import 'dart:html' as html;

/// iPad reports as "Macintosh" in its user agent since iPadOS 13 (it
/// requests desktop sites by default), so this deliberately only
/// catches "iPhone" — matching the user's own "on iPhone mostly" ask
/// rather than guessing iPad should be included too.
bool detectIPhone() => html.window.navigator.userAgent.contains('iPhone');
