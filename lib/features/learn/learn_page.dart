import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../core/widgets/path_trail.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../quiz/quiz_page.dart';

/// One continuous winding path for the whole mushaf — Duolingo's actual
/// structure: a surah is a "unit" banner, and its levels sit inline on the
/// SAME path right after it, not behind a separate tap-through page. A long
/// surah's levels (Level 1: Ayat 1–8, Level 2: Ayat 9–16, ...) run one after
/// another; finishing one reveals the next, still on this one screen,
/// before the path moves on to the next surah's banner.
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

/// A row on the path: either a surah's unit banner, or one playable level
/// within it (`chunkIndex != null`).
class _PathItem {
  final Surah surah;
  final int? chunkIndex;
  final double height;

  _PathItem.header(this.surah)
      : chunkIndex = null,
        height = _LearnPageState._headerHeight;

  _PathItem.level(this.surah, int chunk)
      : chunkIndex = chunk,
        height = _LearnPageState._rowHeight;
}

class _LearnPageState extends State<LearnPage> {
  static const double _nodeSize = 68;
  static const double _rowHeight = 116;
  static const double _headerHeight = 84;
  // Repeating horizontal offsets from centre — the classic Duolingo zigzag.
  static const List<double> _offsets = [0, 60, 85, 60, 0, -60, -85, -60];

  final ScrollController _sc = ScrollController();
  late final List<_PathItem> _items;
  late final List<double> _tops; // this item's top, in path-local coords
  late final List<int> _levelOffset; // offset-array index, keyed by item index
  late final double _totalHeight;

  @override
  void initState() {
    super.initState();
    _layout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      final nextIndex = _nextItemIndex();
      if (nextIndex == null || nextIndex == 0) return;
      final target = (40 + _tops[nextIndex] - 220)
          .clamp(0.0, _sc.position.maxScrollExtent);
      _sc.jumpTo(target);
    });
  }

  void _layout() {
    _items = <_PathItem>[];
    for (final s in surahs) {
      _items.add(_PathItem.header(s));
      final count = chunkCountFor(s);
      for (var c = 0; c < count; c++) {
        _items.add(_PathItem.level(s, c));
      }
    }

    _tops = List<double>.filled(_items.length, 0);
    _levelOffset = List<int>.filled(_items.length, 0);
    var y = 40.0;
    var levelCounter = 0;
    for (var i = 0; i < _items.length; i++) {
      _tops[i] = y;
      if (_items[i].chunkIndex != null) {
        _levelOffset[i] = levelCounter % _offsets.length;
        levelCounter++;
      }
      y += _items[i].height;
    }
    _totalHeight = y + 80;
  }

  int? _nextItemIndex() {
    for (var i = 0; i < _items.length; i++) {
      final chunk = _items[i].chunkIndex;
      if (chunk != null && !appState.isLevelSealed(_items[i].surah.number, chunk)) {
        return i;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _open(Surah s, int chunkIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(surah: s, chunkIndex: chunkIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = _nextItemIndex();
    final levelPositions = <int, Offset>{};
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].chunkIndex == null) continue;
      levelPositions[i] = Offset(
        _offsets[_levelOffset[i]],
        _tops[i] + _rowHeight / 2 - 2,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('یادگیری')),
      body: SingleChildScrollView(
        controller: _sc,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: SizedBox(
          height: _totalHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CustomPaint(
                size: Size(double.infinity, _totalHeight),
                painter: _LevelTrailPainter(
                  points: levelPositions.values.toList(),
                  color: context.borderColor,
                ),
              ),
              for (var i = 0; i < _items.length; i++)
                Positioned(
                  top: _tops[i],
                  left: 0,
                  right: 0,
                  height: _items[i].height,
                  child: Center(
                    child: _items[i].chunkIndex == null
                        ? _header(_items[i].surah)
                        : Transform.translate(
                            offset: Offset(_offsets[_levelOffset[i]], 0),
                            child: Reveal(
                              index: i,
                              child: _levelNode(
                                _items[i].surah,
                                _items[i].chunkIndex!,
                                isNext: i == nextIndex,
                              ),
                            ),
                          ),
                  ),
                ),
              // The START badge floats above its node rather than living
              // inside the row's own fixed-height column — the row height
              // is sized for a plain node, and this badge is the one thing
              // that would otherwise overflow it.
              if (nextIndex != null)
                Positioned(
                  top: _tops[nextIndex] - 34,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(_offsets[_levelOffset[nextIndex]], 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Mascot(
                            mood: appState.currentStreak > 0
                                ? MascotMood.happy
                                : MascotMood.idle,
                            size: 40,
                          ),
                          const SizedBox(width: 6),
                          const StartBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Surah s) {
    final si = surahs.indexWhere((x) => x.number == s.number);
    final unlocked = appState.isUnlocked(si);
    final sealed = appState.sealed.contains(s.number);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: sealed
            ? AppColors.secondary
            : unlocked
                ? AppColors.primary
                : context.borderColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.englishName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${s.meaning} · ${s.length} آیه',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              s.arabicName,
              style: ArabicType.ayah(size: 22, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelNode(Surah s, int chunkIndex, {required bool isNext}) {
    final unlocked = appState.isLevelUnlocked(s, chunkIndex);
    final sealed = appState.isLevelSealed(s.number, chunkIndex);
    final start = chunkIndex * kChunkSize;
    final end = (start + kChunkSize).clamp(0, s.length);

    final Color face;
    final Color shadow;
    final Widget icon;
    if (sealed) {
      face = AppColors.secondary;
      shadow = AppColors.secondaryDark;
      icon = const Icon(Icons.star_rounded, color: AppColors.white, size: 30);
    } else if (unlocked) {
      face = AppColors.primary;
      shadow = AppColors.primaryDark;
      icon = Icon(
        isNext ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
        color: AppColors.white,
        size: isNext ? 30 : 24,
      );
    } else {
      face = context.borderColor;
      shadow = context.mutedColor;
      icon = const Icon(Icons.lock_rounded, color: AppColors.white, size: 22);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PathNode(
          size: _nodeSize,
          face: face,
          shadow: shadow,
          icon: icon,
          onTap: unlocked
              ? () => _open(s, chunkIndex)
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ابتدا سطح قبلی را تمام کنید.')),
                  );
                },
        ),
        const SizedBox(height: 6),
        Text(
          chunkCountFor(s) > 1 ? 'سطح ${chunkIndex + 1}' : s.englishName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: unlocked
                    ? Theme.of(context).colorScheme.onSurface
                    : context.mutedColor,
              ),
        ),
        if (chunkCountFor(s) > 1)
          Text(
            'آیات ${start + 1}–$end',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}

/// Dashed connector strung through every level node in order, straight over
/// unit banners the same way Duolingo's own path runs behind them.
class _LevelTrailPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _LevelTrailPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    for (var i = 0; i < points.length - 1; i++) {
      final a = Offset(cx + points[i].dx, points[i].dy);
      final b = Offset(cx + points[i + 1].dx, points[i + 1].dy);
      _dashedLine(canvas, a, b, paint);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 10.0;
    const gapLength = 10.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final direction = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = (drawn + dashLength).clamp(0.0, total);
      canvas.drawLine(a + direction * drawn, a + direction * segEnd, paint);
      drawn += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _LevelTrailPainter old) =>
      old.points != points || old.color != color;
}
