import '../audio.dart';
import 'audio_factory_stub.dart'
    if (dart.library.html) 'audio_factory_web.dart' as impl;

/// Real playback on web via the browser's own `<audio>` element (zero
/// packages needed); the silent stub everywhere else, exactly as
/// documented in BACKEND.md's audio section.
RecitationPlayer createRecitationPlayer() => impl.makePlayer();
