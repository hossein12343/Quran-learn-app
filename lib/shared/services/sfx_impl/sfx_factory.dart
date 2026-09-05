import '../sfx.dart';
import 'sfx_factory_stub.dart'
    if (dart.library.html) 'sfx_factory_web.dart' as impl;

/// Real synthesized tones on web via `dart:web_audio` (zero packages
/// needed, see sfx.dart); the silent stub everywhere else.
SoundEffects createSoundEffects() => impl.makeSoundEffects();
