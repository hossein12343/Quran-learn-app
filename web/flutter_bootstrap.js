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
  config: {},
});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('app_cache_sw.js').catch(() => {});
  });
}
