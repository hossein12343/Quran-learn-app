import '../glass_dock.dart';
import 'glass_dock_factory_stub.dart'
    if (dart.library.html) 'glass_dock_factory_web.dart' as impl;

/// Real HTML/CSS glass dock on web (see `glass_dock.dart`); the no-op stub
/// everywhere else.
GlassDock createGlassDock() => impl.makeGlassDock();
