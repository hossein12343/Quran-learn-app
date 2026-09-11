import '../media_session.dart';
import 'media_session_factory_stub.dart'
    if (dart.library.html) 'media_session_factory_web.dart' as impl;

/// Real `navigator.mediaSession` wiring on web (see `media_session.dart`);
/// the unavailable stub everywhere else.
MediaSessionController createMediaSession() => impl.makeMediaSession();
