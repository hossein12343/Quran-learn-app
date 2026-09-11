import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/settings.dart';

/// Where the app's Qur'anic text, translation, and recitation audio
/// actually come from, and a couple of standing commitments about how
/// this app handles that content — not a settings screen, a trust one.
/// For a religious text, "who verified this and where did it come from"
/// matters as much as any feature; this page exists to answer that
/// plainly instead of leaving it implicit or, worse, unanswered.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: settings.direction,
      child: Scaffold(
        appBar: AppBar(title: const Text('دربارهٔ منابع')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
          children: [
            Reveal(index: 0, child: Icon(Icons.menu_book_rounded,
                size: 40, color: AppColors.primary)),
            const SizedBox(height: AppSpacing.md),
            Reveal(
              index: 1,
              child: Text(
                'یادگیری قرآن روی متن و صوتی ساخته شده که منبعش مشخص و '
                'قابل استناد است — نه چیزی که از جایی نامعلوم جمع شده '
                'باشد.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Reveal(
              index: 2,
              child: _card(
                context,
                icon: Icons.text_fields_rounded,
                title: 'متن قرآن',
                body: 'رسم‌الخط عثمانی، به روایت حفص از عاصم — همان '
                    'روایتی که در اکثر قریب به‌اتفاق مصحف‌های چاپی و '
                    'برنامه‌های قرآنی استفاده می‌شود. متن از Quran.com '
                    '(api.quran.com) دریافت شده است.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Reveal(
              index: 3,
              child: _card(
                context,
                icon: Icons.translate_rounded,
                title: 'ترجمه',
                body: 'ترجمهٔ فارسی: حسین تاجی کل‌دری. برای بخش‌هایی که '
                    'ترجمهٔ فارسی در دسترس نبود، از ترجمهٔ انگلیسی '
                    'Saheeh International به‌عنوان منبع کمکی استفاده '
                    'شده — هر دو از طریق Quran.com.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Reveal(
              index: 4,
              child: _card(
                context,
                icon: Icons.record_voice_over_rounded,
                title: 'قاریان',
                body: 'صوت تلاوت از everyayah.com دریافت می‌شود:\n'
                    '${knownQaris.map((q) => '• ${q.nativeName}').join('\n')}',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Reveal(
              index: 5,
              child: _card(
                context,
                icon: Icons.block_flipped,
                title: 'تعهد ما دربارهٔ تبلیغات',
                body: 'حتی اگر در آینده تبلیغاتی به نسخهٔ رایگان اضافه '
                    'شود، هیچ‌وقت کنار متن قرآن، ترجمه، یا صوت تلاوت '
                    'نمایش داده نخواهد شد. این یک قول محصولی نیست — یک '
                    'خط قرمز است.',
                accent: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    Color accent = AppColors.primary,
  }) {
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
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
