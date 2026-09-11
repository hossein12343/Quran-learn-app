import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../shared/services/compass.dart';
import '../../shared/services/prayer_times.dart';
import '../../shared/services/qibla.dart';

/// Which way to face for prayer — a static bearing (works everywhere,
/// needs no sensor) plus a live-rotating needle when the device actually
/// has a usable compass (see `compass.dart` for what counts as "usable" —
/// a browser that only exposes relative rotation, not true-north-locked,
/// deliberately never reports a heading here rather than showing a
/// needle that would silently point the wrong way).
class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  (double, double)? _location;
  bool _loading = true;
  bool _requestingCompass = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    setState(() => _loading = true);
    // Shares its cache with the prayer-reminder feature (see
    // `prayer_times.dart`) — someone who already granted location there
    // gets Qibla for free, no second prompt.
    final loc = await prayerTimesService.resolveLocation();
    if (!mounted) return;
    setState(() {
      _location = loc;
      _loading = false;
    });
  }

  Future<void> _activateCompass() async {
    setState(() => _requestingCompass = true);
    await deviceCompass.requestPermission();
    if (!mounted) return;
    setState(() => _requestingCompass = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قبله')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _location == null
              ? _locationMissing(context)
              : _compassBody(context, _location!),
    );
  }

  Widget _locationMissing(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded,
                size: 48, color: context.mutedColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              'برای نشان‌دادن جهت قبله، به موقعیت مکانی‌ات نیاز داریم.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            DuoButton(
                label: 'تلاش دوباره',
                fullWidth: false,
                onTap: _resolveLocation),
          ],
        ),
      ),
    );
  }

  Widget _compassBody(BuildContext context, (double, double) loc) {
    final bearing = Qibla.bearingFrom(loc.$1, loc.$2);
    final distance = Qibla.distanceKmFrom(loc.$1, loc.$2);
    return ValueListenableBuilder<double?>(
      valueListenable: deviceCompass.heading,
      builder: (context, heading, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            _dial(context, bearing, heading),
            const SizedBox(height: AppSpacing.xl),
            Text('${bearing.round()}° از شمال',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('${distance.round()} کیلومتر تا کعبه',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            if (heading != null)
              Text(
                'قطب‌نما فعال است — بچرخ تا فلش طلایی درست رو به بالا بایستد.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.primary),
              )
            else if (deviceCompass.available)
              DuoButton(
                label: _requestingCompass
                    ? 'در حال فعال‌سازی…'
                    : 'فعال‌سازی قطب‌نمای زنده',
                fullWidth: false,
                onTap: _requestingCompass ? null : _activateCompass,
              )
            else
              Text(
                'قطب‌نمای زنده روی این دستگاه در دسترس نیست — با قطب‌نمای '
                'گوشی یا نقشه، رو به همین زاویه از شمال بایست.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _dial(BuildContext context, double bearing, double? heading) {
    return SizedBox(
      width: 260,
      height: 280,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 20,
            child: Transform.rotate(
              angle: heading == null ? 0 : -heading * math.pi / 180,
              child: CustomPaint(
                size: const Size(260, 260),
                painter: _CompassPainter(
                  bearing: bearing,
                  borderColor: context.borderColor,
                  mutedColor: context.mutedColor,
                ),
              ),
            ),
          ),
          Icon(Icons.arrow_drop_down_rounded,
              size: 32, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double bearing;
  final Color borderColor;
  final Color mutedColor;

  const _CompassPainter({
    required this.bearing,
    required this.borderColor,
    required this.mutedColor,
  });

  static const Map<int, String> _cardinals = {
    0: 'N',
    90: 'E',
    180: 'S',
    270: 'W'
  };

  Offset _point(Offset center, double radius, double degrees) {
    final rad = degrees * math.pi / 180;
    return center + Offset(math.sin(rad), -math.cos(rad)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var deg = 0; deg < 360; deg += 30) {
      final isCardinal = deg % 90 == 0;
      final outer = _point(center, radius, deg.toDouble());
      final inner =
          _point(center, radius - (isCardinal ? 12 : 6), deg.toDouble());
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = deg == 0
              ? AppColors.primary
              : (isCardinal ? mutedColor : borderColor)
          ..strokeWidth = isCardinal ? 2 : 1,
      );
    }

    for (final entry in _cardinals.entries) {
      final color = entry.key == 0 ? AppColors.primary : mutedColor;
      final tp = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = _point(center, radius - 28, entry.key.toDouble());
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // The Qibla needle: a line from center to the bearing angle, capped
    // with a small triangular arrowhead.
    final tip = _point(center, radius - 22, bearing);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final dir = tip - center;
    final len = dir.distance;
    if (len > 0) {
      final unit = dir / len;
      final perp = Offset(-unit.dy, unit.dx);
      const headLen = 14.0, headWidth = 9.0;
      final base = tip - unit * headLen;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((base + perp * headWidth).dx, (base + perp * headWidth).dy)
        ..lineTo((base - perp * headWidth).dx, (base - perp * headWidth).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = AppColors.gold);
    }

    canvas.drawCircle(center, 5, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.bearing != bearing ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.mutedColor != mutedColor;
}
