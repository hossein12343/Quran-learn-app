import '../share.dart';
import 'share_factory_stub.dart' if (dart.library.html) 'share_factory_web.dart'
    as impl;

/// Real Web Share API + clipboard on web (see `share.dart`); the
/// unavailable stub everywhere else.
ShareService createShareService() => impl.makeShareService();
