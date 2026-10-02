import 'package:flutter/material.dart';
import '../../shared/services/app_install.dart';
import '../../shared/services/store/local_store.dart';
import '../motion/motion.dart';
import '../theme/app_theme.dart';

const _dismissedKey = 'install_hint_dismissed';

/// Suggests putting the app on the Home Screen, on phones where it isn't
/// yet. On an iPhone it explains Safari's Add to Home Screen (there's no
/// App Store version); on Android Chrome its Install button opens the
/// browser's own dialog. Closing it hides it for good on this device;
/// Profile keeps a way back to the steps.
class InstallHint extends StatefulWidget {
  /// Space around the card; none at all while it's hidden.
  final EdgeInsetsGeometry padding;

  const InstallHint({super.key, this.padding = EdgeInsets.zero});

  @override
  State<InstallHint> createState() => _InstallHintState();
}

class _InstallHintState extends State<InstallHint> {
  bool _dismissed = LocalStore.get(_dismissedKey) != null;

  void _dismiss() {
    LocalStore.set(_dismissedKey, '1');
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InstallWay>(
      valueListenable: installWay,
      builder: (context, way, _) {
        if (_dismissed || way == InstallWay.none) {
          return const SizedBox(width: double.infinity);
        }
        final t = Theme.of(context).textTheme;
        final card = Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.add_to_home_screen_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('برنامه را روی گوشی نصب کنید',
                        style: t.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      way == InstallWay.iphoneSteps
                          ? 'اول آن را به صفحهٔ اصلی آیفون اضافه کنید و از '
                              'همان‌جا باز کنید؛ سریع‌تر است و بدون اینترنت هم '
                              'کار می‌کند.'
                          : 'مثل یک برنامهٔ معمولی از صفحهٔ اصلی گوشی باز '
                              'می‌شود؛ سریع‌تر است و بدون اینترنت هم کار می‌کند.',
                      style: t.bodySmall?.copyWith(color: context.mutedColor),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Pressable(
                      onTap: () => _act(context, way),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppRadius.circular),
                        ),
                        child: Text(
                          way == InstallWay.browserPrompt ? 'نصب' : 'چطور؟',
                          style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'بستن',
                onPressed: _dismiss,
                icon: Icon(Icons.close_rounded,
                    size: 20, color: context.mutedColor),
              ),
            ],
          ),
        );
        return Padding(padding: widget.padding, child: card);
      },
    );
  }

  Future<void> _act(BuildContext context, InstallWay way) async {
    if (way == InstallWay.browserPrompt) {
      await promptInstall();
    } else {
      await showInstallSteps(context, way);
    }
  }
}

/// The steps for putting the app on the Home Screen, for [way].
Future<void> showInstallSteps(BuildContext context, InstallWay way) {
  final iphone = way == InstallWay.iphoneSteps;
  final steps = iphone
      ? const [
          (
            Icons.ios_share_rounded,
            'در Safari، دکمهٔ اشتراک‌گذاری را بزنید: مربعی با فلش رو به بالا. '
                'اگر آن را نمی‌بینید، اول «⋯» را بزنید.'
          ),
          (
            Icons.add_box_outlined,
            'گزینهٔ «افزودن به صفحهٔ اصلی» (Add to Home Screen) را بزنید. '
                'شاید لازم باشد کمی پایین بروید.'
          ),
          (
            Icons.check_circle_outline_rounded,
            '«افزودن» (Add) را بزنید و برنامه را از آیکون آن روی صفحهٔ اصلی '
                'باز کنید.'
          ),
        ]
      : const [
          (
            Icons.more_vert_rounded,
            'منوی مرورگر را باز کنید: سه نقطه در گوشهٔ بالای صفحه.'
          ),
          (
            Icons.install_mobile_rounded,
            '«نصب برنامه» (Install app) یا «افزودن به صفحهٔ اصلی» '
                '(Add to Home screen) را بزنید.'
          ),
          (
            Icons.check_circle_outline_rounded,
            'تأیید کنید. آیکون یادگیری قرآن روی صفحهٔ اصلی گوشی می‌آید.'
          ),
        ];
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) {
      final t = Theme.of(context).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  iphone
                      ? 'افزودن به صفحهٔ اصلی آیفون'
                      : 'نصب روی گوشی اندروید',
                  style: t.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.14),
                      child: Text('${i + 1}',
                          style:
                              t.labelLarge?.copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(steps[i].$1, color: context.mutedColor, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(steps[i].$2, style: t.bodyMedium)),
                  ],
                ),
              ],
              if (iphone) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'آیفون ورود به برنامهٔ نصب‌شده را جدا از Safari نگه می‌دارد؛ '
                  'پس یک بار دیگر در خود برنامه وارد شوید. پیشرفت شما در '
                  'حسابتان ذخیره است.',
                  style: t.bodySmall?.copyWith(color: context.mutedColor),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
