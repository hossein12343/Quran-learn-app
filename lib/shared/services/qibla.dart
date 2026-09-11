import 'dart:math' as math;

/// Pure geodesy — no platform dependency, so it's fully unit-testable
/// without a browser. Formulas are the standard great-circle initial
/// bearing / haversine distance (the same ones effectively every Qibla-
/// compass app uses), cross-checked against independently-computed
/// reference values for real cities before trusting them — see
/// `test/qibla_test.dart`.
abstract class Qibla {
  /// The Kaaba, Mecca — a fixed, well-documented coordinate, not something
  /// that needs a runtime lookup.
  static const double kaabaLat = 21.4225;
  static const double kaabaLon = 39.8262;

  static double _deg2rad(double d) => d * math.pi / 180;
  static double _rad2deg(double r) => r * 180 / math.pi;

  /// Compass bearing from (lat, lon) toward the Kaaba, in degrees from true
  /// north, normalised to [0, 360).
  static double bearingFrom(double lat, double lon) {
    final lat1 = _deg2rad(lat);
    final lat2 = _deg2rad(kaabaLat);
    final dLon = _deg2rad(kaabaLon - lon);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final theta = _rad2deg(math.atan2(y, x));
    return (theta + 360) % 360;
  }

  /// Great-circle distance to the Kaaba, in kilometers.
  static double distanceKmFrom(double lat, double lon) {
    const earthRadiusKm = 6371.0;
    final lat1 = _deg2rad(lat);
    final lat2 = _deg2rad(kaabaLat);
    final dLat = _deg2rad(kaabaLat - lat);
    final dLon = _deg2rad(kaabaLon - lon);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
}
