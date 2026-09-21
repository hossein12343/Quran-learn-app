/// True once [main] has checked whether this session is running on an
/// iPhone (via the browser's own user agent) — used to gate iOS-styled
/// visual treatments, like the bottom nav's frosted-glass look (see
/// `features/main/main_shell.dart`), that are meant to feel native
/// there specifically. Staying false on every other platform isn't
/// just cosmetic: `BackdropFilter` blur is real paint work every
/// frame, not something to spend on a device that wouldn't recognise
/// the look anyway. False everywhere off-web too.
bool isIPhone = false;
