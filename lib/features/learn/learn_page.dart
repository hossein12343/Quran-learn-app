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
///
/// The whole path is ~900 rows (114 surahs, one row per level), so it is
/// built through a [ListView.builder] — only the handful of rows actually
/// on screen are ever constructed. Each level row draws its own dashed
/// connector down to the next level's node, so the zigzag trail needs no
/// separate full-height painter.
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
  static const double _topPad = 40;
  // Repeating horizontal offsets from centre — the classic Duolingo zigzag.
  static const List<double> _offsets = [0, 60, 85, 60, 0, -60, -85, -60];

  final ScrollController _sc = ScrollController();
  List<_PathItem> _items = const [];
  List<double> _tops = const []; // this item's top, in path-local coords
  List<int> _levelOffset = const []; // offset-array index, keyed by item index
  List<int> _nextLevel = const []; // index of the next level row, or -1

  @override
  void initState() {
    super.initState();
    _layout();
    // The full mushaf may still be parsing when this tab is first opened
    // (see quran_seed.dart) — relay out the path once it lands.
    quranRevision.addListener(_onQuranLoaded);
    _scrollToNextSoon();
  }

  void _onQuranLoaded() {
    if (!mounted) return;
    setState(_layout);
    _scrollToNextSoon();
  }

  void _scrollToNextSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      final nextIndex = _nextItemIndex();
      if (nextIndex == null || nextIndex == 0) return;
      final target = (_topPad + _tops[nextIndex] - 220)
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
    _nextLevel = List<int>.filled(_items.length, -1);
    var y = 0.0;
    var levelCounter = 0;
    var lastLevel = -1;
    for (var i = 0; i < _items.length; i++) {
      _tops[i] = y;
      if (_items[i].chunkIndex != null) {
        _levelOffset[i] = levelCounter % _offsets.length;
        levelCounter++;
        if (lastLevel != -1) _nextLevel[lastLevel] = i;
        lastLevel = i;
      }
      y += _items[i].height;
    }
  }

  int? _nextItemIndex() {
    for (var i = 0; i < _items.length; i++) {
      final chunk = _items[i].chunkIndex;
      if (chunk != null &&
          !appState.isLevelSealed(_items[i].surah.number, chunk)) {
        return i;
      }
    }
    return null;
  }

  @override
  void dispose() {
    quranRevision.removeListener(_onQuranLoaded);
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
    return Scaffold(
      appBar: AppBar(title: const Text('یادگیری')),
      body: ListView.builder(
        controller: _sc,
        padding: const EdgeInsets.only(top: _topPad, bottom: 80),
        itemCount: _items.length,
        // Each row's connector paints down into the next row, so per-row
        // repaint boundaries (which would clip it) are off; the rows are
        // cheap and static enough not to need them.
        addRepaintBoundaries: false,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, i) => _row(i, nextIndex),
      ),
    );
  }

  Widget _row(int i, int? nextIndex) {
    final item = _items[i];
    if (item.chunkIndex == null) {
      return SizedBox(
        height: item.height,
        child: Center(child: _header(item.surah)),
      );
    }

    final x = _offsets[_levelOffset[i]];
    final next = _nextLevel[i];
    final isNext = i == nextIndex;
    // The first dozen rows animate in; past that the path is off-screen on
    // first paint and a Reveal per row would just be ~900 idle controllers.
    final animate = i < 12;

    final node = Transform.translate(
      offset: Offset(x, 0),
      child: _levelNode(item.surah, item.chunkIndex!, isNext: isNext),
    );

    return SizedBox(
      height: item.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (next != -1)
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectorPainter(
                  fromX: x,
                  toX: _offsets[_levelOffset[next]],
                  drop: _tops[next] - _tops[i],
                  color: context.borderColor,
                ),
              ),
            ),
          animate ? Reveal(index: i, child: node) : node,
          if (isNext)
            Positioned(
              top: -28,
              child: Transform.translate(
                offset: Offset(x, 0),
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
        ],
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
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
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
                    const SnackBar(
                        content: Text('ابتدا سطح قبلی را تمام کنید.')),
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

/// The dashed segment from one level node down to the next. Drawn per-row
/// (the connector for row i lives in row i's stack and is allowed to
/// overflow downward into the next row) so the path needs no separate
/// full-height painter over the whole ~900-row list.
class _ConnectorPainter extends CustomPainter {
  final double fromX;
  final double toX;
  final double drop; // vertical distance to the next node's row top
  final Color color;

  _ConnectorPainter({
    required this.fromX,
    required this.toX,
    required this.drop,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final a = Offset(cx + fromX, size.height / 2);
    final b = Offset(cx + toX, size.height / 2 + drop);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dash = 10.0;
    const gap = 10.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = (drawn + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * drawn, a + dir * segEnd, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.fromX != fromX ||
      old.toX != toX ||
      old.drop != drop ||
      old.color != color;
}
