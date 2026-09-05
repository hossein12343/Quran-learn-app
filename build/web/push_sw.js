// A small, independent service worker whose only job is Web Push — it
// deliberately does NOT touch Flutter's own asset-caching service worker
// (`flutter_service_worker.js`, auto-generated fresh on every `flutter
// build web` and not something to hand-edit). Registered at the narrow
// `/push/` scope (see `reminder_factory_web.dart`'s `_engineJs`), well
// below Flutter's own `/` scope, specifically so the two never compete
// for the same scope slot — this worker never needs to control page
// navigation or fetches, only receive push events and show notifications,
// which doesn't require scope overlap at all.
self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { title: 'یادآوری', body: event.data ? event.data.text() : '' };
  }
  var title = data.title || 'یادآوری قرآن یادگیری';
  var options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        if ('focus' in list[i]) return list[i].focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});
