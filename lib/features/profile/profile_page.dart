import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pattern_overlay.dart';
import '../../shared/services/app_state.dart';
import '../learn/memorized_page.dart';
import '../progress/achievements_page.dart';
import '../quran/bookmarks_page.dart';
import '../settings/settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final initials = appState.displayName.isEmpty
        ? '?'
        : appState.displayName.trim()[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          if (appState.syncNotice != null) ...[
            Reveal(index: 0, child: _syncBanner(context)),
            const SizedBox(height: AppSpacing.lg),
          ],
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
                    Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(gradient: AppGradients.hero)),
                    ),
                    const Positioned.fill(child: StarField()),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            child: Text(initials,
                                style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appState.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                                Text(appState.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
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
            child: _section(context, 'آمار شما', [
              _row(context, 'سطح', 'سطح ${appState.level}'),
              _row(context, 'مجموع امتیاز', '${appState.totalXp}'),
              _row(context, 'روند فعلی',
                  '${appState.currentStreak} روز'),
              _row(context, 'طولانی‌ترین روند',
                  '${appState.longestStreak} روز'),
              _row(context, 'آیه حفظ شده', '${appState.ayatHeld}'),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 2,
            child: _section(context, 'کتابخانه شما', [
              _navRow(context, Icons.auto_stories_rounded, 'آیات حفظ شده',
                  () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const MemorizedPage()))),
              _navRow(context, Icons.star_rounded, 'نشان‌شده‌ها',
                  () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const BookmarksPage()))),
              _navRow(context, Icons.workspace_premium_rounded, 'دستاوردها',
                  () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AchievementsPage())),
                  last: true),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 3,
            child: _section(context, 'تنظیمات', [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: appState.darkMode,
                  activeColor: AppColors.primary,
                  onChanged: appState.toggleDark,
                  title: Text('حالت تیره',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
              _row(context, 'هدف روزانه',
                  '${appState.dailyGoalMinutes} دقیقه'),
              _row(context, 'تمرکز', appState.learningGoal),
              _row(context, 'حساب کاربری',
                  appState.hasSyncedAccount ? 'همگام‌شده با این رایانه' : 'فقط روی این دستگاه'),
              Pressable(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage()),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('قاری، سرعت و حالت',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      // Left, not right: the app is RTL, so "this row leads
                      // somewhere" points toward the reading-forward side,
                      // which is left here — a plain chevron_right would
                      // point backward against the reading direction.
                      Icon(Icons.chevron_left_rounded,
                          color: context.mutedColor),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          Reveal(
            index: 4,
            child: Pressable(
              onTap: () {
                appState.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login', (route) => false);
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.error),
                ),
                child: const Text('خروج از حساب',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.borderColor, width: 2),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _syncBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AppColors.secondaryDark),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              appState.syncNotice!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.secondaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navRow(BuildContext context, IconData icon, String label,
      VoidCallback onTap, {bool last = false}) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Icon(Icons.chevron_left_rounded, color: context.mutedColor),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
