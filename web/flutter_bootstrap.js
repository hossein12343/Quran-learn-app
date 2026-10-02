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

// Chrome on Android offers "Install app" through this event, often before
// the app has started; keep it so the app's own Install button can show
// the browser's dialog later (see app_install_web.dart).
window.__qlInstall = null;
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  window.__qlInstall = event;
  window.dispatchEvent(new Event('ql-installable'));
});
window.addEventListener('appinstalled', () => {
  window.__qlInstall = null;
  window.dispatchEvent(new Event('ql-installable'));
});
window.__qlStandalone = () =>
  (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
  navigator.standalone === true;
window.__qlCanInstall = () => !!window.__qlInstall;
window.__qlPromptInstall = (done) => {
  const offer = window.__qlInstall;
  if (!offer) return done(false);
  offer.prompt();
  offer.userChoice.then(
    (choice) => {
      window.__qlInstall = null;
      done(!!choice && choice.outcome === 'accepted');
    },
    () => done(false),
  );
};

if ('serviceWorker' in navigator) {
  // The app's files come from the saved copy of the build that was current
  // when this open started (see app_cache_sw.js); a newer build is picked
  // up in the background and used from the next open. The browser only
  // finds the update seconds after the app is on screen, so reloading then
  // would flash the app — or throw away a lesson in progress. Instead, if
  // the app sits in the background for a while (a new session, not a pause
  // mid-lesson), it switches to the new release on coming back.
  const hadWorker = !!navigator.serviceWorker.controller;
  let updateReady = false;
  let hiddenAt = 0;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (hadWorker) updateReady = true;
  });
  // The browser looks for a new release when the app is opened. A Home
  // Screen app can instead be resumed for days without being opened again,
  // so it also looks when brought back after an hour or more.
  let lastUpdateCheck = Date.now();
  const checkForUpdate = () => {
    lastUpdateCheck = Date.now();
    navigator.serviceWorker
      .getRegistration()
      .then((reg) => reg && reg.update())
      .catch(() => {});
  };
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      hiddenAt = Date.now();
    } else if (updateReady && hiddenAt && Date.now() - hiddenAt > 15 * 60 * 1000) {
      window.location.reload();
    } else if (Date.now() - lastUpdateCheck > 60 * 60 * 1000) {
      checkForUpdate();
    }
  });
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('app_cache_sw.js').catch(() => {});
  });
}
