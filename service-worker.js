self.addEventListener('install', event => {
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', event => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch {
    payload = { title: 'Архив Юристов', body: event.data?.text() || 'Новый материал опубликован.' };
  }

  const title = payload.title || 'Архив Юристов';
  const options = {
    body: payload.body || 'Опубликован новый материал.',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: payload.tag || `lecture-${payload.lectureId || Date.now()}`,
    renotify: true,
    data: { lectureId: payload.lectureId || null }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const lectureId = event.notification.data?.lectureId;
  const targetUrl = lectureId ? `/?lecture=${encodeURIComponent(lectureId)}` : '/';

  event.waitUntil((async () => {
    const clientList = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clientList) {
      if ('focus' in client) {
        await client.focus();
        if (lectureId) client.navigate(targetUrl);
        return;
      }
    }
    if (clients.openWindow) await clients.openWindow(targetUrl);
  })());
});
