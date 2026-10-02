import '../app_install.dart';

// Off the web there is nothing to install from a browser.

InstallWay currentWay() => InstallWay.none;

Future<bool> prompt() async => false;

void onChange(void Function() changed) {}
