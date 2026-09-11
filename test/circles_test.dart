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
