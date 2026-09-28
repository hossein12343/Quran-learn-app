// Custom bootstrap template (flutter build web substitutes this file
// in place of its own generated default whenever one exists at
// web/flutter_bootstrap.js — see docs.flutter.dev/platform-integration
// /web/initialization). Kept as close to Flutter's own default as
// possible: the only real change is omitting `serviceWorkerSettings`
// (Flutter's own service worker is a no-op cleanup stub in current
// Flutter versions anyway — see app_cache_sw.js's doc comment) and
// registering a real caching one separately below instead, so the two
// never compete over the same scope.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    // The graphics engine from this site rather than Google's CDN (the
    // default): one fewer outside service seeing every visitor, and no
    // dependence on gstatic.com being reachable (it isn't everywhere).
    canvasKitBaseUrl: "canvaskit/",
  },
});

if ('serviceWorker' in navigator) {
  // The app's files come from the saved copy of the build that was current
  // when it was saved (see app_cache_sw.js). When a newer build's worker
  // takes over during the first seconds of opening — still on the splash or
  // sign-in screen — reload once so the new release shows now rather than
  // on the next open. Not on a first visit (nothing was in control yet),
  // and never mid-use.
  const openedAt = Date.now();
  const hadWorker = !!navigator.serviceWorker.controller;
  let reloading = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!hadWorker || reloading || Date.now() - openedAt > 10000) return;
    reloading = true;
    window.location.reload();
  });
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('app_cache_sw.js').catch(() => {});
  });
}
