/// Tiny abstraction over "read the current URL, redirect the browser
/// somewhere, strip query params" — the three things a redirect-based
/// OAuth2 flow needs from the platform. Only meaningful on web, where
/// Google Sign-In actually redirects a real browser tab; other platforms
/// get a no-op/throwing stub (see [WebNav]'s doc comment there).
library web_nav;

export 'web_nav_stub.dart'
    if (dart.library.html) 'web_nav_web.dart';
