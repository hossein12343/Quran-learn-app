import 'package:flutter/foundation.dart';
import 'app_install_impl/app_install_stub.dart'
    if (dart.library.html) 'app_install_impl/app_install_web.dart' as impl;

/// How this device can put the app on its Home Screen. It's a web app:
/// iPhones get no App Store version (the stores aren't open to developers
/// in Iran), so people add it from the browser instead.
enum InstallWay {
  /// Already installed, or a computer: nothing to offer.
  none,

  /// iPhone: Safari's Share → Add to Home Screen, explained in steps.
  iphoneSteps,

  /// Android Chrome offered its own install dialog; a button can open it.
  browserPrompt,

  /// Another Android browser: the menu's "Install app" / "Add to Home
  /// screen", explained in steps.
  androidSteps,
}

/// What to offer right now. Changes when Chrome makes its offer, which can
/// happen a moment after the app opens, or once the app is installed.
final ValueNotifier<InstallWay> installWay = ValueNotifier(impl.currentWay());

/// Opens the browser's own install dialog ([InstallWay.browserPrompt]).
/// True if the person installed.
Future<bool> promptInstall() async {
  final installed = await impl.prompt();
  installWay.value = impl.currentWay();
  return installed;
}

/// Starts listening for the browser's offer. Call once at startup.
void watchInstallability() =>
    impl.onChange(() => installWay.value = impl.currentWay());
