import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/pattern_overlay.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/plan.dart';

/// The Free-vs-Pro comparison and upgrade screen.
///
/// **No payment processor is wired up yet — deliberately.** Real charging
/// needs a payment provider account (Stripe or similar) that only the
/// app's owner can create, plus a webhook that flips `profiles.is_pro`
/// server-side once a charge actually succeeds; neither exists yet. The
/// call to action below says so honestly rather than pretending to take a
/// payment it can't actually process. Every *gate* in the app (hearts,
/// reciters — see `plan.dart`) is already written against `isPro` alone,
/// so wiring a real provider later is exactly one webhook, no changes to
/// anything that reads the flag.
class ProPage extends StatelessWidget {
  const ProPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final isPro = appState.isPro;
    return Scaffold(
      appBar: AppBar(title: const Text('یادگیری قرآن Pro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          Reveal(
            index: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.hero,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.gold, AppColors.goldDark],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(child: StarField()),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.workspace_premium_rounded,
                              color: AppColors.white, size: 36),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            isPro ? 'شما Pro هستید' : 'یادگیری قرآن Pro',
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            isPro
                                ? 'همهٔ مزایای زیر برای شما فعال است.'
                                : 'یادگیری بدون محدودیت.',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final perk in proPerks) ...[
                  _perkRow(context, perk, isPro),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Reveal(
            index: 2,
            child: isPro
                ? Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.successWash,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text('اشتراک Pro شما فعال است.'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DuoButton(
                        label: 'شروع Pro',
                        onTap: () => _showComingSoon(context),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'پرداخت هنوز راه‌اندازی نشده — این دکمه فعلاً فقط '
                        'نمایشی است.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _perkRow(BuildContext context, ProPerk perk, bool isPro) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.borderColor, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPro ? Icons.check_circle_rounded : Icons.lock_rounded,
            color: isPro ? AppColors.success : context.mutedColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perk.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(perk.description,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('به‌زودی'),
        content: const Text(
          'راه‌اندازی پرداخت هنوز کامل نشده — به محض آماده شدن، از همینجا '
          'می‌توانید Pro را فعال کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }
}
