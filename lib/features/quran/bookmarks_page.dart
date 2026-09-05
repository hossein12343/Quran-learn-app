import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  @override
  Widget build(BuildContext context) {
    final entries = appState.bookmarks.keys.toList()
      ..sort((a, b) {
        final pa = a.split(':').map(int.parse).toList();
        final pb = b.split(':').map(int.parse).toList();
        return pa[0] != pb[0] ? pa[0].compareTo(pb[0]) : pa[1].compareTo(pb[1]);
      });

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('نشان‌شده‌ها')),
        body: entries.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Mascot(mood: MascotMood.idle, size: 64),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'هنوز نشانی وجود ندارد — هنگام خواندن روی ستاره هر آیه '
                        'بزنید تا اینجا ذخیره شود.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                    AppSpacing.sm, AppSpacing.xl, AppSpacing.xxxl),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final parts = entries[i].split(':');
                  final surahNumber = int.parse(parts[0]);
                  final ayahNumber = int.parse(parts[1]);
                  final surah = surahs.firstWhere((s) => s.number == surahNumber,
                      orElse: () => surahs.first);
                  final ayah = surah.ayat.firstWhere(
                      (a) => a.number == ayahNumber,
                      orElse: () => surah.ayat.first);
                  return Reveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _card(context, surah, ayah),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _card(BuildContext context, Surah surah, Ayah ayah) {
    return Container(
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
              Expanded(
                child: Text('${surah.englishName} · آیه ${ayah.number}',
                    style: Theme.of(context).textTheme.labelMedium),
              ),
              Pressable(
                onTap: () => appState.toggleBookmark(surah.number, ayah.number),
                child: const Icon(Icons.star_rounded,
                    size: 20, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(ayah.arabic,
                style: ArabicType.ayah(
                    size: 24, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(ayah.translation, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
