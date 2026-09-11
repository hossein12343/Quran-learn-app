import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mascot.dart';
import '../../shared/data/duas.dart';
import '../../shared/services/audio.dart';
import '../../shared/services/settings.dart';

/// The full Hisnul Muslim ("Fortress of the Muslim") collection —
/// everyday duas and adhkar, outside the Quran text itself. English
/// only (see `duas.dart`'s doc comment for why); this list page and
/// its chapter detail are deliberately plain — the content itself,
/// not any reading-mode chrome, is the point here.
class DuasPage extends StatefulWidget {
  const DuasPage({super.key});

  @override
  State<DuasPage> createState() => _DuasPageState();
}

class _DuasPageState extends State<DuasPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadDuas().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: settings.direction,
      child: Scaffold(
        appBar: AppBar(title: const Text('دعاها و اذکار')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : duaChapters.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Mascot(mood: MascotMood.idle, size: 64),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'در حال حاضر این مجموعه در دسترس نیست.',
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
                    itemCount: duaChapters.length,
                    itemBuilder: (context, i) {
                      final chapter = duaChapters[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Pressable(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DuaChapterPage(chapter: chapter),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                  color: context.borderColor, width: 2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _titleCase(chapter.title),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text('${chapter.duas.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: context.mutedColor)),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(Icons.chevron_left_rounded,
                                    color: context.mutedColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

String _titleCase(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class DuaChapterPage extends StatelessWidget {
  final DuaChapter chapter;

  const DuaChapterPage({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: settings.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(_titleCase(chapter.title))),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxl),
          itemCount: chapter.duas.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _duaCard(context, chapter.duas[i]),
          ),
        ),
      ),
    );
  }

  Widget _duaCard(BuildContext context, Dua dua) {
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
              if (dua.repeat > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text('${dua.repeat}× تکرار',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryDark)),
                ),
              const Spacer(),
              if (recitation.available && dua.audio.isNotEmpty)
                Pressable(
                  onTap: () => recitation.playClip(dua.audio),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.play_circle_outline_rounded,
                        size: 22, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              dua.arabic,
              style: ArabicType.ayah(
                size: 24,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              dua.transliteration,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: context.mutedColor,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              dua.translation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
