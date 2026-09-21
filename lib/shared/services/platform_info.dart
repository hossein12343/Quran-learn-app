/// True once [main] has checked whether this session is running on an
/// iPhone (via the browser's own user agent) — used to gate iOS-styled
/// visual treatments, like the bottom nav's floating glass pill (see
/// `features/main/main_shell.dart`), that are meant to feel native
/// there specifically. False everywhere off-web too.
bool isIPhone = false;
