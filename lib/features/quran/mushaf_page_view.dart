import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/mushaf_pages.dart';
import '../../shared/services/settings.dart';

/// A continuous, page-by-page reading mode following the standard
/// 604-page Uthmani mushaf's own pagination (see
/// `shared/data/mushaf_pages.dart`) — swipe through pages the way you'd
/// flip a physical mushaf, crossing surah boundaries seamlessly, instead
/// of the surah-by-surah reader everywhere else in the app. Arabic-only
/// by design (a real mushaf page has no translation on it); the
/// translation toggle is a concession for someone who still wants to
/// follow along with meaning while in this mode.
class MushafPageView extends StatefulWidget {
  final int initialPage;
  const MushafPageView({super.key, this.initialPage = 1});

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  late final PageController _pc;
  late int _page;
  bool _showTranslation = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, mushafTotalPages);
    _pc = PageController(initialPage: _page - 1);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('صفحه $_page از $mushafTotalPages'),
        actions: [
          IconButton(
            tooltip: _showTranslation ? 'فقط متن عربی' : 'نمایش ترجمه',
            icon: Icon(
              Icons.translate_rounded,
              color: _showTranslation ? AppColors.primary : null,
            ),
            onPressed: () =>
                setState(() => _showTranslation = !_showTranslation),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: mushafTotalPages,
        onPageChanged: (i) => setState(() => _page = i + 1),
        itemBuilder: (context, i) => _pageBody(context, i + 1),
      ),
    );
  }

  Widget _pageBody(BuildContext context, int page) {
    final content = contentForPage(page);
    if (content.segments.isEmpty) {
      // Only reachable before loadFullQuran() replaces the 4-surah
      // fallback — most pages reference surahs not in it yet.
      return Center(
        child: Text('در حال بارگذاری متن قرآن…',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final segment in content.segments) ...[
              if (segment.ayat.first.number == 1) ...[
                _surahHeader(context, segment.surah.arabicName),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text.rich(
                TextSpan(
                  children: [
                    for (final a in segment.ayat) ...[
                      TextSpan(
                        text: '${a.arabic} ',
                        style: ArabicType.ayah(size: 24 * settings.arabicScale),
                      ),
                      TextSpan(
                        text: '۝${_ayahMarker(a.number)} ',
                        style: TextStyle(
                          fontSize: 15 * settings.arabicScale,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                textAlign: TextAlign.justify,
              ),
              if (_showTranslation) ...[
                const SizedBox(height: AppSpacing.md),
                ...segment.ayat.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text('${a.number}. ${a.translation}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        ),
      ),
    );
  }

  /// Arabic-Indic digits for the little end-of-ayah marker, matching how
  /// a printed mushaf numbers its ayat — the app's UI chrome stays Latin
  /// numerals everywhere else, but this one spot is meant to look like
  /// the actual page, not the app around it.
  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  String _ayahMarker(int n) =>
      n.toString().split('').map((d) => _digits[int.parse(d)]).join();

  Widget _surahHeader(BuildContext context, String arabicName) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Text(arabicName,
          style: ArabicType.ayah(size: 26, color: AppColors.primaryDeep)),
    );
  }
}
