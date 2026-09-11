import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/circles.dart';

void main() {
  group('CircleMember.fromRow', () {
    test(
        'reads profile fields and computes the same level formula as '
        'AppState', () {
      final m = CircleMember.fromRow({
        'user_id': 'u1',
        'joined_at': '2026-09-01T00:00:00Z',
        'profiles': {
          'display_name': 'مریم',
          'total_xp': 450,
          'current_streak': 5,
          'longest_streak': 9,
          'last_active_date': '2026-09-10',
          'is_pro': true,
        },
      });

      expect(m.displayName, 'مریم');
      expect(m.level, 4); // 1 + 450 ~/ 150
      expect(m.currentStreak, 5);
      expect(m.isPro, true);
    });

    test(
        'falls back to a placeholder name when display_name is missing '
        'or blank', () {
      final missing = CircleMember.fromRow({
        'user_id': 'u1',
        'joined_at': '2026-09-01T00:00:00Z',
        'profiles': <String, dynamic>{},
      });
      final blank = CircleMember.fromRow({
        'user_id': 'u2',
        'joined_at': '2026-09-01T00:00:00Z',
        'profiles': {'display_name': '   '},
      });

      expect(missing.displayName, 'دانش‌آموز');
      expect(blank.displayName, 'دانش‌آموز');
      expect(missing.level, 1);
      expect(missing.isPro, false);
    });
  });

  group('CircleMember.weeklyXp', () {
    String currentWeekKey() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sinceSaturday = (today.weekday + 1) % 7;
      final saturday = today.subtract(Duration(days: sinceSaturday));
      return '${saturday.year.toString().padLeft(4, '0')}-'
          '${saturday.month.toString().padLeft(2, '0')}-'
          '${saturday.day.toString().padLeft(2, '0')}';
    }

    test(
        'is the totalXp/base delta when the stored week matches this '
        'week', () {
      final m = CircleMember.fromRow({
        'user_id': 'u1',
        'joined_at': '2026-09-01T00:00:00Z',
        'profiles': {
          'total_xp': 620,
          'weekly_xp_base': 500,
          'weekly_xp_week_start': currentWeekKey(),
        },
      });

      expect(m.weeklyXp, 120);
    });

    test(
        'is 0 when the stored week is stale (member has not played yet '
        'this week) even though total_xp minus base would be nonzero', () {
      final m = CircleMember.fromRow({
        'user_id': 'u1',
        'joined_at': '2026-09-01T00:00:00Z',
        'profiles': {
          'total_xp': 900,
          'weekly_xp_base': 500,
          'weekly_xp_week_start': '2000-01-01', // guaranteed a past week
        },
      });

      expect(m.weeklyXp, 0);
    });

    test('is 0 when weekly_xp_week_start was never set', () {
      final m = CircleMember.fromRow({
        'user_id': 'u1',
        'joined_at': '2026-09-01T00:00:00Z',
        'profiles': {'total_xp': 900},
      });

      expect(m.weeklyXp, 0);
    });
  });

  group('JoinedCircle.fromRow', () {
    test('reads the embedded circle fields', () {
      final c = JoinedCircle.fromRow({
        'circle_id': 'c1',
        'joined_at': '2026-09-01T00:00:00Z',
        'circles': {
          'id': 'c1',
          'name': 'حلقهٔ خانواده',
          'owner_id': 'owner1',
        },
      });

      expect(c.circleId, 'c1');
      expect(c.name, 'حلقهٔ خانواده');
      expect(c.ownerId, 'owner1');
    });
  });
}
