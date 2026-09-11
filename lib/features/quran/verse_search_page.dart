import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/verse_search.dart';
import 'quran_page.dart';

/// Full-text search across every loaded ayah's Arabic text and Persian
/// translation — distinct from the plain surah-name/number search
/// already on the Quran tab's list, which can't find "the verse with
/// 'ای کسانی که ایمان آورده‌اید' in it." See `shared/data/verse_search.dart`
/// for the actual matching logic.
class VerseSearchPage extends StatefulWidget {
  const VerseSearchPage({super.key});

  @override
  State<VerseSearchPage> createState() => _VerseSearchPageState();
}

class _VerseSearchPageState extends State<VerseSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final results = q.isEmpty ? const <VerseMatch>[] : searchVerses(q);
    return Scaffold(
      appBar: AppBar(title: const Text('جستجوی آیات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'بخشی از آیه یا ترجمه را بنویس…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? _hint(
                    context,
                    'بخشی از متن آیه یا ترجمه‌اش را بنویس تا '
                    'پیدایش کنیم.')
                : results.isEmpty
                    ? _hint(context, 'چیزی پیدا نشد.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl),
                        itemCount: results.length,
                        itemBuilder: (context, i) => Reveal(
                          index: i,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _resultCard(context, results[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      );

  Widget _resultCard(BuildContext context, VerseMatch m) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SurahReaderPage(
            surah: m.surah,
            scrollToAyah: m.ayah.number,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                '${m.surah.englishName} · ${m.ayah.number}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                m.ayah.arabic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ArabicType.ayah(size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              m.ayah.translation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
