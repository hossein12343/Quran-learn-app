import 'package:flutter/material.dart';
import '../motion/motion.dart';
import '../theme/app_theme.dart';
import '../../shared/services/settings.dart';

/// A small EN/فارسی switch, reusable wherever someone should be able to
/// pick a language without first signing in or digging into Settings —
/// notably the login/signup screens, the very first thing anyone (signed
/// in or not) ever sees. Same look and behaviour as the chips in
/// `SettingsPage._langChip`, just compact enough to sit in a corner.
///
/// Reading/writing `settings.language` directly is enough to work
/// correctly wherever this is placed — the app rebuilds on every
/// `settings` change (see `main.dart`), so tapping a chip here updates
/// this widget's own highlight and the whole app's text direction in the
/// same frame, with no extra plumbing needed at the call site.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(context, 'en', 'English'),
        const SizedBox(width: AppSpacing.xs),
        _chip(context, 'fa', 'فارسی'),
      ],
    );
  }

  Widget _chip(BuildContext context, String code, String label) {
    final on = settings.language == code;
    return Pressable(
      onTap: () => settings.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: on
              ? AppColors.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.circular),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: on ? AppColors.white : context.mutedColor,
          ),
        ),
      ),
    );
  }
}
