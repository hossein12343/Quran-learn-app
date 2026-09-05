import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/mascot.dart';
import '../../core/widgets/surah_picker_sheet.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../quiz/quiz_page.dart';

/// A deliberately separate feature from the structured "Learn" path — that
/// one stays a strict, locked, sequential progression through the mushaf;
/// this one is "pick literally any surah and any level, no order, no
/// locks," for free practice/review rather than the main memorisation
/// track. Own tab, own simple list UI (not the winding path), so it never
/// gets confused with — or accidentally changes the state of — Learn.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  Surah? _chosen;

  Future<void> _choose() async {
    final s = await pickSurah(context);
    if (s != null) setState(() => _chosen = s);
  }

  void _open(int chunkIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(surah: _chosen!, chunkIndex: chunkIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _chosen;
    return Scaffold(
      appBar: AppBar(title: const Text('تمرین')),
      body: SafeArea(child: s == null ? _empty() : _levelsList(s)),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mascot(mood: MascotMood.happy, size: 72),
          const SizedBox(height: AppSpacing.lg),
          Text('تمرین هر سوره',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'جدا از مسیر یادگیری شما — هر سوره، هر سطح، به هر ترتیب '
            'که بخواهید. اینجا هیچ‌چیز قفل نیست.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          DuoButton(
              label: 'انتخاب سوره', onTap: _choose, color: AppColors.blue),
        ],
      ),
    );
  }

  Widget _levelsList(Surah s) {
    final count = chunkCountFor(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.englishName,
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(
                      '${s.length} آیه · $count سطح',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _choose, child: const Text('تغییر')),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final sealed = appState.isLevelSealed(s.number, i);
              final start = i * kChunkSize;
              final end = (start + kChunkSize).clamp(0, s.length);
              return DuoTile(
                stretch: true,
                fillColor: sealed
                    ? AppColors.secondaryLight
                    : Theme.of(context).colorScheme.surface,
                borderColor: sealed ? AppColors.secondary : context.borderColor,
                onTap: () => _open(i),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          sealed ? AppColors.secondary : AppColors.blueLight,
                      foregroundColor:
                          sealed ? AppColors.white : AppColors.blueDark,
                      child: sealed
                          ? const Icon(Icons.star_rounded, size: 18)
                          : Text('${i + 1}'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سطح ${i + 1}',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('آیات ${start + 1}–$end',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded,
                        color: context.mutedColor),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
