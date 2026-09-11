import '../compass.dart';
import 'compass_factory_stub.dart'
    if (dart.library.html) 'compass_factory_web.dart' as impl;

/// Real device-orientation compass on web (best-effort — see
/// `compass.dart`); the unavailable stub everywhere else.
DeviceCompass createDeviceCompass() => impl.makeCompass();
