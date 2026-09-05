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
  int? _playingAyah;

  Future<void> _play(int ayahNumber) async {
    setState(() => _playingAyah = ayahNumber);
    await recitation.play(
      surah: widget.surah.number,
      ayah: ayahNumber,
      qariId: settings.qariId,
      speed: settings.speed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(widget.surah.englishName)),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl),
          itemCount: widget.surah.ayat.length,
          itemBuilder: (context, i) {
            final a = widget.surah.ayat[i];
            final bookmarked = appState.isBookmarked(widget.surah.number, a.number);
            return Reveal(
              index: i,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: context.borderColor, width: 2),
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
                            onTap: () => _play(a.number),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _playingAyah == a.number
                                    ? Icons.volume_up_rounded
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
                              bookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 22,
                              color: bookmarked
                                  ? AppColors.secondary
                                  : context.mutedColor,
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
              ),
            );
          },
        ),
      ),
    );
  }
}
