import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../shared/data/quran_seed.dart';

/// Opens [KnownSurahsSheet]; returns the surahs ticked, or null if closed.
Future<Set<int>?> pickKnownSurahs(BuildContext context, Set<int> initial) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => KnownSurahsSheet(initial: initial),
  );
}

/// "Which surahs do you already know?" — listed short surahs first, since
/// those are what most people already have, with Juz 30 in one tap.
class KnownSurahsSheet extends StatefulWidget {
  final Set<int> initial;
  const KnownSurahsSheet({super.key, this.initial = const {}});

  @override
  State<KnownSurahsSheet> createState() => _KnownSurahsSheetState();
}

class _KnownSurahsSheetState extends State<KnownSurahsSheet> {
  static const _juz30First = 78;

  late final Set<int> _picked = {...widget.initial};

  /// Al-Fatihah, then An-Nas backward — the short surahs first whichever
  /// order the learner chose to learn in.
  late final List<Surah> _list = [
    ...surahs.where((s) => s.number == 1),
    ...surahs.where((s) => s.number != 1).toList().reversed,
  ];

  Iterable<int> get _juz30 =>
      surahs.where((s) => s.number >= _juz30First).map((s) => s.number);

  bool get _allJuz30 => _juz30.every(_picked.contains);

  void _toggleJuz30() => setState(() {
        final all = _allJuz30;
        for (final n in _juz30) {
          all ? _picked.remove(n) : _picked.add(n);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('کدام سوره‌ها را حفظ هستید؟', style: t.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'این‌ها را دوباره درس نمی‌دهیم؛ در روزهای آینده، روزی چند '
                  'سطح، یک مرور کوتاه از هرکدام می‌گیرید.',
                  style: t.bodySmall?.copyWith(color: context.mutedColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _row(
                  title: 'همهٔ جزء ۳۰',
                  detail: 'النبأ تا الناس · ${_juz30.length} سوره',
                  checked: _allJuz30,
                  onTap: _toggleJuz30,
                  strong: true,
                ),
                const Divider(),
                for (final s in _list)
                  _row(
                    title: s.arabicName,
                    detail: 'سورهٔ ${s.number} · ${s.length} آیه',
                    checked: _picked.contains(s.number),
                    arabic: true,
                    onTap: () => setState(() => _picked.contains(s.number)
                        ? _picked.remove(s.number)
                        : _picked.add(s.number)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: DuoButton(
                label: _picked.isEmpty
                    ? 'هیچ‌کدام'
                    : 'تأیید · ${_picked.length} سوره',
                color: AppColors.primary,
                onTap: () => Navigator.of(context).pop(_picked),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String title,
    required String detail,
    required bool checked,
    required VoidCallback onTap,
    bool arabic = false,
    bool strong = false,
  }) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: checked ? AppColors.primary : context.borderColor,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: arabic
                  ? Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(title,
                          style: ArabicType.ayah(size: 20),
                          textAlign: TextAlign.start),
                    )
                  : Text(title, style: strong ? t.titleMedium : t.bodyLarge),
            ),
            Text(detail,
                style: t.labelSmall?.copyWith(color: context.mutedColor)),
          ],
        ),
      ),
    );
  }
}

/// How many levels [picked] adds to revision — shown so the learner sees
/// what ticking a whole juz means before they commit.
int levelsIn(Set<int> picked) => surahs
    .where((s) => picked.contains(s.number))
    .fold(0, (n, s) => n + chunkCountFor(s));
