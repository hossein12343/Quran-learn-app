import 'platform_info_factory_stub.dart'
    if (dart.library.html) 'platform_info_factory_web.dart' as impl;

/// True on web when the browser's own user agent says iPhone; false on
/// every other platform. See `platform_info.dart` for why this exists.
bool detectIPhone() => impl.detectIPhone();
