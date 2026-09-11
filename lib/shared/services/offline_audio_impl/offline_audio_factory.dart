import '../offline_audio.dart';
import 'offline_audio_factory_stub.dart'
    if (dart.library.html) 'offline_audio_factory_web.dart' as impl;

/// Real Cache Storage on web, the no-op stub everywhere else.
OfflineAudio createOfflineAudio() => impl.makeService();
