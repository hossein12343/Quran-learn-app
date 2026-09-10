import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/audio.dart';
import '../../shared/services/settings.dart';
import 'bookmarks_page.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? surahs
        : surahs
            .where((s) =>
                s.englishName.toLowerCase().contains(q) ||
                s.meaning.toLowerCase().contains(q) ||
                '${s.number}' == q)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('قرآن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded),
            tooltip: 'نشان‌شده‌ها',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BookmarksPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'جستجوی سوره‌ها',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('هیچ سوره‌ای مطابقت ندارد.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0,
                        AppSpacing.xl, AppSpacing.xxxl),
                    itemCount: list.length,
                    itemBuilder: (context, i) => Reveal(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _row(list[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(Surah s) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SurahReaderPage(surah: s)),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('${s.number}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDeep)),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.englishName,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('${s.meaning} \u00b7 ${s.length} \u0622\u06cc\u0647',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(s.arabicName,
                  style: ArabicType.ayah(size: 21, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class SurahReaderPage extends StatefulWidget {
  final Surah surah;
  const SurahReaderPage({super.key, required this.surah});

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  final ScrollController _sc = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  /// The ayah currently sounding (or about to), or null when idle.
  int? _current;

  /// True while a continuous run is in progress — each ayah plays
  /// [Settings.repeatCount] times, then playback rolls to the next ayah,
  /// scrolling it into view, until the surah ends or the user stops.
  bool _running = false;
  int _playsThisAyah = 0;

  GlobalKey _keyFor(int n) => _ayahKeys.putIfAbsent(n, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    recitation.clipEndCount.addListener(_onClipEnd);
  }

  @override
  void dispose() {
    recitation.clipEndCount.removeListener(_onClipEnd);
    recitation.stop();
    _sc.dispose();
    super.dispose();
  }

  void _startFrom(int ayahNumber) {
    setState(() {
      _running = true;
      _current = ayahNumber;
      _playsThisAyah = 0;
    });
    _playCurrent();
  }

  void _stop() {
    recitation.stop();
    setState(() {
      _running = false;
      _current = null;
      _playsThisAyah = 0;
    });
  }

  void _playCurrent() {
    final n = _current;
    if (n == null) return;
    _playsThisAyah++;
    recitation.play(
      surah: widget.surah.number,
      ayah: n,
      qariId: settings.qariId,
      speed: settings.speed,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyFor(n).currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.15);
      }
    });
  }

  void _onClipEnd() {
    if (!_running || _current == null) return;
    // repeatCount 1..N are literal; the settings slider tops out at a
    // finite value, so there's no "infinite" case to guard.
    if (_playsThisAyah < settings.repeatCount) {
      _playCurrent();
      return;
    }
    final next = _current! + 1;
    if (next > widget.surah.ayat.length) {
      _stop();
      return;
    }
    setState(() {
      _current = next;
      _playsThisAyah = 0;
    });
    _playCurrent();
  }

  void _cycleSpeed() {
    final i = playbackSpeeds.indexOf(settings.speed);
    settings.setSpeed(playbackSpeeds[(i + 1) % playbackSpeeds.length]);
    recitation.setSpeed(settings.speed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appState, settings]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(widget.surah.englishName)),
        body: ListView.builder(
          controller: _sc,
          padding: EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl,
              _running ? 96 : AppSpacing.xxxl),
          itemCount: widget.surah.ayat.length,
          itemBuilder: (context, i) => _ayahCard(widget.surah.ayat[i], i),
        ),
        bottomNavigationBar: _running ? _playbackBar(context) : null,
      ),
    );
  }

  Widget _ayahCard(Ayah a, int i) {
    final bookmarked = appState.isBookmarked(widget.surah.number, a.number);
    final sounding = _running && _current == a.number;
    return Container(
      key: _keyFor(a.number),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: sounding ? AppColors.primary : context.borderColor,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text('${a.number}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark)),
              ),
              const Spacer(),
              if (recitation.available)
                Pressable(
                  onTap: () =>
                      sounding ? _stop() : _startFrom(a.number),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      sounding
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.md),
              Pressable(
                onTap: () =>
                    appState.toggleBookmark(widget.surah.number, a.number),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    bookmarked
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 22,
                    color:
                        bookmarked ? AppColors.secondary : context.mutedColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              a.arabic,
              style: ArabicType.ayah(
                size: 27 * settings.arabicScale,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(a.translation,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _playbackBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: context.borderColor, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: _stop,
                icon: const Icon(Icons.stop_rounded),
                color: AppColors.primary,
                tooltip: 'توقف',
              ),
              Expanded(
                child: Text(
                  'آیهٔ $_current · پخش ${_playsThisAyah.clamp(1, settings.repeatCount)} از ${settings.repeatCount}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              _pill(
                label: '${settings.repeatCount}×',
                icon: Icons.repeat_rounded,
                onTap: () => settings.setRepeat(
                    settings.repeatCount >= 5 ? 1 : settings.repeatCount + 1),
              ),
              const SizedBox(width: AppSpacing.sm),
              _pill(
                label: '${settings.speed}×',
                icon: Icons.speed_rounded,
                onTap: _cycleSpeed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.circular),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primaryDeep),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDeep)),
          ],
        ),
      ),
    );
  }
}
