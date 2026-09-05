import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';

/// Opens [SurahPickerSheet] as a bottom sheet and returns the surah picked,
/// or null if dismissed. Shared between Home's "Continue memorising" card
/// and the top of the Learn path — both just need "let me start/jump to
/// any surah," they differ only in what they do with the result.
Future<Surah?> pickSurah(BuildContext context) {
  return showModalBottomSheet<Surah>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => const SurahPickerSheet(),
  );
}

/// Picks any surah — independent of the strict sequential unlock order the
/// Learn path itself still enforces; see `AppState.currentFocusSurah`'s doc
/// comment for why that's safe to do without touching the lock system.
class SurahPickerSheet extends StatefulWidget {
  const SurahPickerSheet({super.key});

  @override
  State<SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<SurahPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Strip hyphens/spaces/apostrophes from both sides so "Yasin" still
    // finds "Ya-Sin", "Anam" finds "Al-An'am", etc. — noticed live that a
    // literal substring match missed these.
    String normalize(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"[-'\s]"), '');
    final q = normalize(_query);
    final results = q.isEmpty
        ? surahs
        : surahs
            .where((s) =>
                normalize(s.englishName).contains(q) ||
                s.number.toString() == _query.trim())
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(AppRadius.circular),
                ),
              ),
            ),
            Text('انتخاب سوره', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'شروع (یا ادامه) هر سوره، حتی خارج از ترتیب معمول.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'جستجو بر اساس نام یا شماره',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = results[i];
                  final sealed = appState.sealed.contains(s.number);
                  final held = appState.held[s.number] ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: sealed
                          ? AppColors.secondaryLight
                          : AppColors.primaryLight,
                      foregroundColor: sealed
                          ? AppColors.secondaryDark
                          : AppColors.primaryDeep,
                      child: Text('${s.number}'),
                    ),
                    title: Text(s.englishName,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      sealed ? 'مهر و موم شده' : '$held از ${s.length} آیه حفظ شده',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(s.arabicName,
                          style: ArabicType.ayah(
                              size: 20, color: context.mutedColor)),
                    ),
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
