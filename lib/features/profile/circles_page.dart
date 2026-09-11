import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../shared/services/circles.dart';

/// Family/teacher circles — see `shared/services/circles.dart` for the
/// data model. A circle owner (parent/teacher) sees each member's streak,
/// level, and last-active date; a member sees which circles they've
/// joined and can leave. No chat, no assignments — a check-in view, not a
/// classroom.
class CirclesPage extends StatefulWidget {
  const CirclesPage({super.key});

  @override
  State<CirclesPage> createState() => _CirclesPageState();
}

class _CirclesPageState extends State<CirclesPage> {
  final _joinController = TextEditingController();
  bool _joining = false;
  String? _joinError;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    circles.refresh();
  }

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await circles.createCircle();
    } on Object {
      if (mounted) _snack('ساخت حلقه انجام نشد. دوباره امتحان کنید.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    final code = _joinController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _joining = true;
      _joinError = null;
    });
    final error = await circles.joinByCode(code);
    if (!mounted) return;
    setState(() {
      _joining = false;
      _joinError = error == null ? null : _joinErrorMessage(error);
    });
    if (error == null) {
      _joinController.clear();
      _snack('با موفقیت به حلقه پیوستی.');
    }
  }

  String _joinErrorMessage(String code) {
    switch (code) {
      case 'invalid_code':
        return 'این کد معتبر نیست.';
      case 'cannot_join_own_circle':
        return 'این کد مربوط به حلقهٔ خودت است.';
      case 'not_authenticated':
        return 'باید وارد حساب شوید.';
      default:
        return 'پیوستن انجام نشد. دوباره امتحان کنید.';
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _copyCode(String code) {
    unawaited(Clipboard.setData(ClipboardData(text: code)));
    _snack('کد کپی شد.');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: circles,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('حلقه‌ها')),
        body: RefreshIndicator(
          onRefresh: circles.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
            children: [
              Reveal(
                index: 0,
                child: Text(
                  'یه حلقه بساز و کدش رو با خانواده یا شاگردت به اشتراک '
                  'بذار — روند، سطح و آخرین فعالیتشون رو می‌بینی. بدون چت، '
                  'بدون تکلیف؛ فقط یه نگاه سریع.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 1, child: _ownedSection(context)),
              const SizedBox(height: AppSpacing.xxxl),
              Reveal(index: 2, child: _joinedSection(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownedSection(BuildContext context) {
    final owned = circles.ownedCircle;
    if (owned == null) {
      return _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حلقهٔ من', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text('هنوز حلقه‌ای نساختی.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            DuoButton(
              label: _creating ? 'در حال ساخت…' : 'ساخت حلقه',
              onTap: _creating ? null : _create,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(owned['name'] as String? ?? 'حلقهٔ من',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'کد جدید',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => _confirmRegenerate(context),
                  ),
                  IconButton(
                    tooltip: 'حذف حلقه',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    onPressed: () => _confirmDeleteCircle(context),
                  ),
                ],
              ),
              Text('کد دعوت', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Pressable(
                onTap: () => _copyCode(circles.ownedInviteCode ?? ''),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          circles.ownedInviteCode ?? '',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: AppColors.primaryDeep),
                        ),
                      ),
                      const Icon(Icons.copy_rounded,
                          size: 18, color: AppColors.primaryDeep),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('اعضا (${circles.members.length})',
            style: Theme.of(context).textTheme.titleSmall),
        if (circles.members.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'رتبه‌بندی بر اساس امتیاز این هفته — هر شنبه از نو شروع می‌شود.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (circles.loading && circles.members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (circles.members.isEmpty)
          _card(
            context,
            child: Text('هنوز کسی با این کد عضو نشده.',
                style: Theme.of(context).textTheme.bodySmall),
          )
        else
          ..._rankedMembers().map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _memberCard(context, entry.$1, entry.$2),
              )),
      ],
    );
  }

  /// Sorted by this week's XP, highest first — ties keep their original
  /// (join) order rather than reshuffling. Rank is only meaningful (and
  /// only shown as a medal) for the top 3 *with actual XP this week*: a
  /// member who hasn't played yet shouldn't be badged "#2" just because
  /// two other people also have 0.
  List<(CircleMember, int?)> _rankedMembers() {
    final sorted = [...circles.members]
      ..sort((a, b) => b.weeklyXp.compareTo(a.weeklyXp));
    return List.generate(sorted.length, (i) {
      final rank = i < 3 && sorted[i].weeklyXp > 0 ? i + 1 : null;
      return (sorted[i], rank);
    });
  }

  static const List<Color> _medalColors = [
    AppColors.gold,
    Color(0xFFA8A8B3),
    Color(0xFFC08A56),
  ];

  Widget _memberCard(BuildContext context, CircleMember m, int? rank) {
    return _card(
      context,
      child: Row(
        children: [
          if (rank != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _medalColors[rank - 1],
                shape: BoxShape.circle,
              ),
              child: Text('$rank',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white)),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (m.isPro) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.workspace_premium_rounded,
                          size: 14, color: AppColors.goldDark),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'سطح ${m.level} · ${m.currentStreak} روز پشت‌سرهم · '
                  '${_lastActiveLabel(m.lastActiveDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text('${m.weeklyXp} XP',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDeep)),
          ),
          IconButton(
            tooltip: 'حذف از حلقه',
            icon: Icon(Icons.person_remove_outlined, color: context.mutedColor),
            onPressed: () => _confirmRemoveMember(context, m),
          ),
        ],
      ),
    );
  }

  Widget _joinedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('پیوستن به یک حلقه',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _joinController,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'کد دعوت',
                  errorText: _joinError,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            DuoButton(
              label: _joining ? '...' : 'پیوستن',
              fullWidth: false,
              height: 52,
              onTap: _joining ? null : _join,
            ),
          ],
        ),
        if (circles.joinedCircles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('حلقه‌هایی که عضوشان هستم',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ...circles.joinedCircles.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _card(
                  context,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      TextButton(
                        onPressed: () => _confirmLeave(context, c),
                        child: const Text('خروج',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.borderColor, width: 2),
        ),
        child: child,
      );

  String _lastActiveLabel(String? dateKey) {
    if (dateKey == null) return 'هنوز فعالیتی نداشته';
    final parts = dateKey.split('-').map(int.parse).toList();
    if (parts.length != 3) return 'هنوز فعالیتی نداشته';
    final date = DateTime(parts[0], parts[1], parts[2]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(date).inDays;
    if (days <= 0) return 'امروز فعال بوده';
    if (days == 1) return 'دیروز فعال بوده';
    return '$days روز پیش فعال بوده';
  }

  void _confirmRegenerate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('کد جدید بسازیم؟'),
        content: const Text(
            'کد فعلی از کار می‌افتد — هرکسی که هنوز عضو نشده، با کد قبلی '
            'دیگر نمی‌تواند بپیوندد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              circles.regenerateInviteCode();
            },
            child: const Text('کد جدید'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCircle(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حلقه حذف شود؟'),
        content: const Text(
            'همهٔ اعضا از حلقه خارج می‌شوند و کد دعوت دیگر کار نمی‌کند. '
            'این کار قابل بازگشت نیست.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              circles.deleteCircle();
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, CircleMember m) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${m.displayName} از حلقه حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              circles.removeMember(m.userId);
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, JoinedCircle c) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('از «${c.name}» خارج شوی؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              circles.leaveCircle(c.circleId);
            },
            child: const Text('خروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
