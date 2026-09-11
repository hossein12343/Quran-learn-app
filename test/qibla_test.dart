import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/qibla.dart';

void main() {
  // Reference values computed independently in Python (standard great-
  // circle bearing / haversine formulas against the Kaaba's coordinates),
  // not hand-derived from the same Dart code under test — so a bug in the
  // implementation can't accidentally agree with its own reference value.
  // Also cross-checked against commonly-published facts (London's Qibla
  // is widely cited as ~119°, Jakarta's as ~295° — both matched).
  const cases = [
    // name, lat, lon, expectedBearing, expectedDistanceKm
    ('Tehran', 35.6892, 51.3890, 218.4010, 1943.8),
    ('London', 51.5074, -0.1278, 118.9872, 4793.8),
    ('Jakarta', -6.2088, 106.8456, 295.1517, 7920.1),
    ('New York', 40.7128, -74.0060, 58.4817, 10306.3),
  ];

  for (final (name, lat, lon, expectedBearing, expectedDistance) in cases) {
    test('$name: bearing and distance to the Kaaba', () {
      expect(Qibla.bearingFrom(lat, lon), closeTo(expectedBearing, 0.01));
      expect(Qibla.distanceKmFrom(lat, lon), closeTo(expectedDistance, 0.1));
    });
  }

  test('bearing is always normalised into [0, 360)', () {
    for (final (_, lat, lon, _, _) in cases) {
      final b = Qibla.bearingFrom(lat, lon);
      expect(b, greaterThanOrEqualTo(0));
      expect(b, lessThan(360));
    }
  });
}
