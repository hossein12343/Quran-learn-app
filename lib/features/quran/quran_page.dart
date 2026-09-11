import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/data/tajweed_data.dart';
import '../../shared/data/tajweed_parser.dart';
import '../../shared/data/translation2.dart';
import '../../shared/data/word_by_word.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/audio.dart';
import '../../shared/services/offline_audio.dart';
import '../../shared/services/settings.dart';
import '../../shared/services/share.dart';
import '../../shared/services/store/local_store.dart';
import '../../shared/services/tafsir.dart';
import 'bookmarks_page.dart';
import 'khatm_page.dart';
import 'mushaf_page_view.dart';
import 'verse_search_page.dart';

/// The text put on the clipboard / into the native share sheet for one
/// ayah — pure and standalone so it's unit-testable without a widget
/// tree. Arabic first (the actual content), translation, then a plain
/// reference line; deliberately no link back to the app (it has no
/// public per-ayah deep link to share yet), so the shared text still
/// stands alone and means something to whoever receives it.
String composeShareText({
  required String englishName,
  required String arabicName,
  required int ayahNumber,
  required String arabic,
  required String translation,
}) =>
    '$arabic\n\n$translation\n\n— سورهٔ $englishName ($arabicName)، آیهٔ '
    '$ayahNumber';

/// Which (reciter, surah) pairs have been downloaded for offline playback
/// — a flat set persisted locally, `"qariId:surahNumber"` per entry.
/// Deliberately app-state-free and tiny: nothing outside the reader needs
/// this, and `offline_audio.dart`'s cache itself is the actual source of
/// truth for playback (see its `resolve()`) — this set only drives the
/// reader's own "دانلود شده" indicator, so it being slightly stale (e.g.
/// after clearing browser storage) is harmless, not a correctness bug.
abstract class _OfflineSurahs {
  static const _key = 'offline_surahs';

  static Set<String> _read() {
    final raw = LocalStore.get(_key);
    if (raw == null) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  static void _write(Set<String> ids) => LocalStore.set(_key, ids.join(','));

  static bool has(String qariId, int surah) =>
      _read().contains('$qariId:$surah');

  static void add(String qariId, int surah) {
    final ids = _read()..add('$qariId:$surah');
    _write(ids);
  }

  static void remove(String qariId, int surah) {
    final ids = _read()..remove('$qariId:$surah');
    _write(ids);
  }
}

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
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'مصحف — صفحه به صفحه',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MushafPageView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_search_rounded),
            tooltip: 'جستجوی آیات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const VerseSearchPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.checklist_rounded),
            tooltip: 'ختم رمضان',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const KhatmPage()),
            ),
          ),
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
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl),
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

  /// Scrolls to (and briefly highlights) this ayah on open — set when
  /// arriving from verse search rather than the plain surah list.
  final int? scrollToAyah;

  const SurahReaderPage({super.key, required this.surah, this.scrollToAyah});

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

  /// Only the in-flight download's own progress needs to live in State —
  /// "is it downloaded" is read straight from `_OfflineSurahs` on every
  /// build instead, so it's never stale after the user changes reciters
  /// on a different screen (Settings) and comes back to this one.
  bool _downloading = false;
  int _downloadDone = 0;
  int _downloadTotal = 0;

  /// Set only when arriving via [SurahReaderPage.scrollToAyah] — a brief
  /// highlight so the ayah search actually landed you on is obvious, not
  /// just "somewhere near the top of a long scroll."
  int? _highlighted;

  /// Which single word (by ayah number + position within that ayah's
  /// word-by-word list) currently has its meaning expanded, in
  /// word-by-word mode — at most one at a time, across the whole
  /// reader, so tapping a new word closes whichever was open before.
  int? _tappedWordAyah;
  int? _tappedWordIndex;

  GlobalKey _keyFor(int n) => _ayahKeys.putIfAbsent(n, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    recitation.clipEndCount.addListener(_onClipEnd);
    final target = widget.scrollToAyah;
    if (target != null) {
      _highlighted = target;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToAyah(target));
    }
  }

  /// `ListView.builder` only gives an ayah a `BuildContext` once it's
  /// been laid out — for a long surah, the target of a search jump is
  /// almost never already built. Nudges the scroll position toward a
  /// rough estimate of where it should be (bringing it into the lazy
  /// build window), then retries; once the real context exists,
  /// `Scrollable.ensureVisible` does the precise correction.
  Future<void> _scrollToAyah(int ayahNumber, {int attemptsLeft = 25}) async {
    if (!mounted) return;
    final ctx = _keyFor(ayahNumber).currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
      // A permanent highlight would just read as "this ayah is special"
      // forever — fades after landing so it reads as "you arrived here."
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted && _highlighted == ayahNumber) {
        setState(() => _highlighted = null);
      }
      return;
    }
    if (attemptsLeft <= 0 || !_sc.hasClients) return;
    final index = widget.surah.ayat.indexWhere((a) => a.number == ayahNumber);
    if (index < 0) return;
    final estimate = (index * 200.0).clamp(0.0, _sc.position.maxScrollExtent);
    _sc.jumpTo(estimate);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await _scrollToAyah(ayahNumber, attemptsLeft: attemptsLeft - 1);
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

  String _clipUrl(int ayahNumber) {
    final qari = settings.qari;
    return 'https://everyayah.com/data/'
        '${ayahClipPath(qari.folder, widget.surah.number, ayahNumber)}';
  }

  Future<void> _download() async {
    if (!offlineAudio.available || _downloading) return;
    setState(() {
      _downloading = true;
      _downloadDone = 0;
      _downloadTotal = widget.surah.ayat.length;
    });
    var succeeded = 0;
    for (final a in widget.surah.ayat) {
      if (!mounted) return;
      if (await offlineAudio.cache(_clipUrl(a.number))) succeeded++;
      if (!mounted) return;
      setState(() => _downloadDone++);
    }
    if (!mounted) return;
    // Marked downloaded even on a partial failure (a flaky ayah or two) —
    // resolve() falls back to the live URL per-clip regardless, so a few
    // misses just mean those specific ayat still need the network, not
    // that the whole download is worthless. Only an *empty* run (every
    // single clip failed — no connectivity at all) stays unmarked, since
    // re-tapping "دانلود" is the obvious recovery there.
    if (succeeded > 0) {
      _OfflineSurahs.add(settings.qariId, widget.surah.number);
    }
    setState(() => _downloading = false);
  }

  Future<void> _removeDownload() async {
    setState(() => _downloading = true);
    for (final a in widget.surah.ayat) {
      await offlineAudio.uncache(_clipUrl(a.number));
    }
    _OfflineSurahs.remove(settings.qariId, widget.surah.number);
    if (!mounted) return;
    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appState, settings, tajweedRevision]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.surah.englishName),
          actions: [
            _wordByWordToggle(context),
            _translation2Toggle(context),
            if (tajweedLoaded) _tajweedToggle(context),
            if (offlineAudio.available) _downloadAction(context),
          ],
        ),
        body: ListView.builder(
          controller: _sc,
          padding: EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, _running ? 96 : AppSpacing.xxxl),
          itemCount: widget.surah.ayat.length,
          itemBuilder: (context, i) => _ayahCard(widget.surah.ayat[i], i),
        ),
        bottomNavigationBar: _running ? _playbackBar(context) : null,
      ),
    );
  }

  /// One icon, three states: download (nothing cached for this reciter
  /// yet), a small progress ring while it runs, or a filled "cached" mark
  /// that removes the download on tap — freeing whatever room it used is
  /// just as real a need as making it in the first place.
  Widget _downloadAction(BuildContext context) {
    if (_downloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: _downloadTotal == 0
                      ? null
                      : _downloadDone / _downloadTotal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('$_downloadDone/$_downloadTotal',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      );
    }
    final downloaded = _OfflineSurahs.has(settings.qariId, widget.surah.number);
    return IconButton(
      tooltip:
          downloaded ? 'حذف نسخهٔ آفلاین' : 'دانلود این سوره برای پخش آفلاین',
      onPressed: downloaded ? _removeDownload : _download,
      icon: Icon(
        downloaded
            ? Icons.offline_pin_rounded
            : Icons.download_for_offline_outlined,
        color: downloaded ? AppColors.primary : null,
      ),
    );
  }

  bool _loadingWbw = false;

  /// Lazily loads word-by-word data on first use, same pattern as
  /// [_toggleTranslation2] — a study aid most sessions won't touch.
  /// Turning word-by-word on closes whatever word-meaning bubble was
  /// already open (stale index into a now-different rendering mode).
  Future<void> _toggleWordByWord() async {
    if (!settings.wordByWordEnabled && !wordByWordLoaded) {
      setState(() => _loadingWbw = true);
      await loadWordByWord();
      if (!mounted) return;
      setState(() => _loadingWbw = false);
    }
    setState(() {
      _tappedWordAyah = null;
      _tappedWordIndex = null;
    });
    settings.setWordByWordEnabled(!settings.wordByWordEnabled);
  }

  Widget _wordByWordToggle(BuildContext context) {
    final on = settings.wordByWordEnabled;
    return IconButton(
      tooltip: on ? 'خاموش‌کردن معنای واژه‌به‌واژه' : 'معنای واژه‌به‌واژه',
      onPressed: _loadingWbw ? null : _toggleWordByWord,
      icon: _loadingWbw
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.touch_app_rounded,
              color: on ? AppColors.primary : null,
            ),
    );
  }

  bool _loadingTranslation2 = false;

  /// Switches between the default translation and the second one (see
  /// `shared/data/translation2.dart`), lazily loading it on the very
  /// first tap rather than at startup — this is an opt-in comparison
  /// toggle, not something every session needs to pay the fetch for.
  Future<void> _toggleTranslation2() async {
    if (!settings.useTranslation2 && !translation2Loaded) {
      setState(() => _loadingTranslation2 = true);
      await loadTranslation2();
      if (!mounted) return;
      setState(() => _loadingTranslation2 = false);
    }
    settings.setUseTranslation2(!settings.useTranslation2);
  }

  Widget _translation2Toggle(BuildContext context) {
    final on = settings.useTranslation2;
    return IconButton(
      tooltip: on ? 'بازگشت به ترجمهٔ پیش‌فرض' : 'ترجمهٔ دیگر',
      onPressed: _loadingTranslation2 ? null : _toggleTranslation2,
      icon: _loadingTranslation2
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.swap_horiz_rounded,
              color: on ? AppColors.primary : null,
            ),
    );
  }

  /// Toggles rule-colored tajweed rendering for the whole reader — a
  /// per-user preference (`settings.tajweedEnabled`), not per-surah state,
  /// so it stays on/off consistently as someone moves between surahs.
  Widget _tajweedToggle(BuildContext context) {
    final on = settings.tajweedEnabled;
    return IconButton(
      tooltip: on ? 'خاموش‌کردن رنگ‌آمیزی تجوید' : 'رنگ‌آمیزی تجوید',
      onPressed: () => settings.setTajweedEnabled(!on),
      icon: Icon(
        Icons.format_color_text_rounded,
        color: on ? AppColors.primary : null,
      ),
    );
  }

  /// Plain ayah text, unless the tajweed toggle is on *and* rule data
  /// actually loaded for this ayah — falls back to the ordinary `Text`
  /// rather than routing through the parser at all when either is false,
  /// so turning the toggle off is guaranteed to look exactly like it did
  /// before this feature existed.
  Widget _ayahText(BuildContext context, Ayah a) {
    final style = ArabicType.ayah(
      size: 27 * settings.arabicScale,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
    if (settings.wordByWordEnabled) {
      final words = wordByWordFor(widget.surah.number, a.number);
      if (words != null)
        return _wordByWordText(context, a.number, words, style);
    }
    final raw = settings.tajweedEnabled
        ? tajweedTextFor(widget.surah.number, a.number)
        : null;
    if (raw == null) return Text(a.arabic, style: style);
    return Text.rich(TextSpan(children: parseTajweed(raw, style)));
  }

  /// Word-by-word mode's own renderer — a `Wrap` of individually
  /// tappable words instead of one `Text` block, each with room to
  /// expand its own meaning underneath. Deliberately not combined with
  /// tajweed coloring (see `settings.wordByWordEnabled`'s doc comment):
  /// the ayah's tajweed markup is a per-character span list, not
  /// segmented by word, so reconciling the two rendering paths isn't
  /// worth it for what's already a secondary study mode.
  Widget _wordByWordText(
    BuildContext context,
    int ayahNumber,
    List<WbwWord> words,
    TextStyle style,
  ) {
    final translationStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        );
    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.start,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < words.length; i++)
          GestureDetector(
            onTap: () => setState(() {
              final closing =
                  _tappedWordAyah == ayahNumber && _tappedWordIndex == i;
              _tappedWordAyah = closing ? null : ayahNumber;
              _tappedWordIndex = closing ? null : i;
            }),
            child: Column(
              children: [
                Text(words[i].arabic, style: style),
                if (_tappedWordAyah == ayahNumber && _tappedWordIndex == i)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(words[i].translation, style: translationStyle),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Native share sheet where the browser has one; otherwise a clipboard
  /// copy with a snackbar, since silently doing nothing on a tap would
  /// be worse than either.
  Future<void> _shareAyah(Ayah a) async {
    final text = composeShareText(
      englishName: widget.surah.englishName,
      arabicName: widget.surah.arabicName,
      ayahNumber: a.number,
      arabic: a.arabic,
      translation: a.translation,
    );
    final shared = shareService.canShare
        ? await shareService.share(text: text, title: 'یادگیری قرآن')
        : false;
    if (shared || !mounted) return;
    final copied = await shareService.copyToClipboard(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied ? 'متن آیه کپی شد.' : 'اشتراک‌گذاری انجام نشد.'),
      ),
    );
  }

  Widget _ayahCard(Ayah a, int i) {
    final bookmarked = appState.isBookmarked(widget.surah.number, a.number);
    final sounding = _running && _current == a.number;
    final highlighted = _highlighted == a.number;
    return Container(
      key: _keyFor(a.number),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.goldLight
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: sounding
              ? AppColors.primary
              : (highlighted ? AppColors.gold : context.borderColor),
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
                  onTap: () => sounding ? _stop() : _startFrom(a.number),
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
              if (shareService is! UnavailableShare) ...[
                const SizedBox(width: AppSpacing.md),
                Pressable(
                  onTap: () => _shareAyah(a),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.share_rounded,
                        size: 22, color: context.mutedColor),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Pressable(
                onTap: () => _toggleTafsir(a),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 22,
                    color: _tafsirOpenAyah == a.number
                        ? AppColors.primary
                        : context.mutedColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.rtl,
            child: _ayahText(context, a),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            (settings.useTranslation2
                    ? translation2For(widget.surah.number, a.number)
                    : null) ??
                a.translation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_tafsirOpenAyah == a.number) ...[
            const SizedBox(height: AppSpacing.md),
            _tafsirPanel(context),
          ],
        ],
      ),
    );
  }

  /// Which ayah's tafsir panel is expanded, if any — one at a time,
  /// same reasoning as [_tappedWordAyah]. `_tafsirText` is cleared
  /// whenever a *different* ayah is opened so a stale answer never
  /// flashes under the wrong ayah while the real fetch is in flight.
  int? _tafsirOpenAyah;
  bool _tafsirLoading = false;
  String? _tafsirText;

  Future<void> _toggleTafsir(Ayah a) async {
    if (_tafsirOpenAyah == a.number) {
      setState(() => _tafsirOpenAyah = null);
      return;
    }
    setState(() {
      _tafsirOpenAyah = a.number;
      _tafsirText = null;
      _tafsirLoading = true;
    });
    final text = await tafsirService.fetch(widget.surah.number, a.number);
    // The user may have closed this panel or opened a different ayah's
    // while the fetch was in flight — don't let a slow, now-irrelevant
    // response overwrite whatever's actually showing.
    if (!mounted || _tafsirOpenAyah != a.number) return;
    setState(() {
      _tafsirLoading = false;
      _tafsirText = text;
    });
  }

  Widget _tafsirPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفسیر ابن‌کثیر (به انگلیسی)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_tafsirLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_tafsirText == null)
            Text('در حال حاضر تفسیری برای این آیه در دسترس نیست.',
                style: Theme.of(context).textTheme.bodySmall)
          else
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _tafsirText!,
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
