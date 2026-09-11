import 'package:flutter/foundation.dart';

/// The device's own compass heading, degrees clockwise from true north.
///
/// Real on web: `compass_impl/compass_factory_web.dart` backs this with
/// the browser's `deviceorientationabsolute` event (Android/Chrome) or
/// `deviceorientation` + the WebKit-only `webkitCompassHeading` field
/// (iOS Safari) — no typed `dart:html` binding covers either, so it's a
/// hand-installed JS engine string, same reasoning as `reminder_factory
/// _web.dart`'s Push API wrapper. Off-web (and any browser without a
/// working compass sensor) this stays [UnavailableCompass]: the Qibla
/// page still works without it — it just shows the static bearing instead
/// of a live-rotating needle. See `features/qibla/qibla_page.dart`.
abstract class DeviceCompass {
  bool get available;

  /// iOS 13+ requires this to be called from an actual tap (a bare
  /// `deviceorientation` listener silently receives nothing until the
  /// user has explicitly granted it) — every other browser this resolves
  /// true immediately with no prompt at all. Safe to call more than once.
  Future<bool> requestPermission();

  /// Heading in degrees, null until the first real reading arrives (or
  /// forever, if the sensor never reports one — some laptops/desktops
  /// expose the event with no usable data).
  ValueListenable<double?> get heading;
}

class UnavailableCompass implements DeviceCompass {
  final ValueNotifier<double?> _heading = ValueNotifier<double?>(null);

  @override
  bool get available => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  ValueListenable<double?> get heading => _heading;
}

DeviceCompass deviceCompass = UnavailableCompass();
