/// Tiny persistent key-value store, zero pub.dev dependencies.
///
/// Without this, every setting and the signed-in session reset on every
/// reload — the single biggest everyday annoyance in the previous build.
/// web uses `window.localStorage` (built into the browser); desktop uses a
/// JSON file next to the executable. Both are part of the SDK already.
library local_store;

export 'local_store_stub.dart' if (dart.library.io) 'local_store_io.dart' if (dart.library.html) 'local_store_web.dart';
