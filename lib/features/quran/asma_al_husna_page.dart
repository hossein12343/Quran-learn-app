import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/asma_al_husna.dart';
import '../../shared/services/settings.dart';

/// The 99 Names of Allah — a plain reference list, numbered in the
/// traditional order. English meaning only (see `asma_al_husna.dart`'s
/// doc comment).
class AsmaAlHusnaPage extends StatelessWidget {
  const AsmaAlHusnaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: settings.direction,
      child: Scaffold(
        appBar: AppBar(title: const Text('اسماء الحسنی')),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxl),
          itemCount: asmaAlHusna.length,
          itemBuilder: (context, i) {
            final n = asmaAlHusna[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: context.borderColor, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text('${n.number}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppColors.primaryDeep)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.transliteration,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(n.meaning,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: context.mutedColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(n.arabic,
                          style: ArabicType.ayah(
                              size: 22, color: AppColors.primary)),
                    ),
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
