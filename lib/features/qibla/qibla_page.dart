import 'dart:math' as math;
import 'dart:ui' as ui;

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

  static const _unsupportedMessage =
      'قطب‌نمای زنده روی این دستگاه در دسترس نیست — با قطب‌نمای '
      'گوشی یا نقشه، رو به همین زاویه از شمال بایست.';

  Widget _compassBody(BuildContext context, (double, double) loc) {
    final bearing = Qibla.bearingFrom(loc.$1, loc.$2);
    final distance = Qibla.distanceKmFrom(loc.$1, loc.$2);
    return ValueListenableBuilder<double?>(
      valueListenable: deviceCompass.heading,
      builder: (context, heading, _) => ValueListenableBuilder<bool>(
        valueListenable: deviceCompass.timedOut,
        // `LayoutBuilder` here (outside the scroll view) reads the
        // Scaffold body's real available height, so the `ConstrainedBox`
        // below can force the scrollable content to be at least that
        // tall — without it, the Column just started at the top and
        // left the rest of a tall phone screen empty below it, which
        // read as "not even centred" because it genuinely wasn't.
        // `Center` then does the actual centring on any screen tall
        // enough for the content to fit; a short/landscape screen still
        // scrolls normally once content exceeds that minimum height.
        builder: (context, timedOut, _) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.xl * 2,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    else if (timedOut || !deviceCompass.available)
                      Text(
                        _unsupportedMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      DuoButton(
                        label: _requestingCompass
                            ? 'در حال فعال‌سازی…'
                            : 'فعال‌سازی قطب‌نمای زنده',
                        onTap: _requestingCompass ? null : _activateCompass,
                      ),
                  ],
                ),
              ),
            ),
          ),
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

    // A soft radial glow behind the dial — a flat stroked circle on a
    // plain background was the single biggest reason this read as
    // "plain": nothing gave the disc any sense of depth or material.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          AppColors.gold.withValues(alpha: 0.16),
          AppColors.gold.withValues(alpha: 0.0),
        ]),
    );

    // Two rings instead of one — an outer gold-tinted edge and an
    // inset inner ring — reads as a layered instrument face rather
    // than a single bare outline.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      center,
      radius - 9,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (var deg = 0; deg < 360; deg += 30) {
      final isCardinal = deg % 90 == 0;
      final outer = _point(center, radius - 4, deg.toDouble());
      final inner =
          _point(center, radius - (isCardinal ? 20 : 11), deg.toDouble());
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = deg == 0
              ? AppColors.primary
              : (isCardinal ? mutedColor : borderColor)
          ..strokeWidth = isCardinal ? 3 : 1.4
          ..strokeCap = StrokeCap.round,
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
      final pos = _point(center, radius - 36, entry.key.toDouble());
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // The needle itself: a classic two-toned compass needle — a
    // tapered gold lens pointing at the Kaaba, balanced by a shorter,
    // muted tail on the opposite side — rather than a plain line with
    // a triangular arrowhead, which read as a generic hiking-compass
    // needle rather than something built for this one purpose.
    final tip = _point(center, radius - 30, bearing);
    final tail = _point(center, radius * 0.4, bearing + 180);
    final dir = tip - center;
    final len = dir.distance;
    if (len > 0) {
      final unit = dir / len;
      final perp = Offset(-unit.dy, unit.dx);

      const headWidth = 7.0;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
              (center + perp * headWidth).dx, (center + perp * headWidth).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(
              (center - perp * headWidth).dx, (center - perp * headWidth).dy)
          ..close(),
        Paint()..color = AppColors.gold,
      );

      const tailWidth = 5.0;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
              (center + perp * tailWidth).dx, (center + perp * tailWidth).dy)
          ..lineTo(tail.dx, tail.dy)
          ..lineTo(
              (center - perp * tailWidth).dx, (center - perp * tailWidth).dy)
          ..close(),
        Paint()..color = mutedColor.withValues(alpha: 0.55),
      );

      _drawKaaba(canvas, tip, unit);
    }

    // A two-tone pivot instead of one flat dot, echoing the needle's
    // own gold/primary pairing.
    canvas.drawCircle(center, 7, Paint()..color = AppColors.gold);
    canvas.drawCircle(center, 4.5, Paint()..color = AppColors.primary);
    canvas.drawCircle(
        center, 1.6, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  /// A small stylised Kaaba — a plain dark cube with a gold band —
  /// marking the needle's tip. This is a Qibla compass, not a hiking
  /// one; a generic arrowhead never said what the needle actually
  /// points at.
  void _drawKaaba(Canvas canvas, Offset tip, Offset unit) {
    const side = 13.0;
    final rect = Rect.fromCenter(
        center: tip - unit * (side * 0.2), width: side, height: side);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF15130F));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top + rect.height * 0.34, rect.width,
          rect.height * 0.15),
      Paint()..color = AppColors.gold,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.bearing != bearing ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.mutedColor != mutedColor;
}
