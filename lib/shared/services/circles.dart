import 'dart:math';
import 'package:flutter/foundation.dart';
import 'app_log.dart';
import 'app_state.dart';
import 'backend.dart';

/// A learner visible on a circle owner's dashboard — just enough to answer
/// "how's my kid/student doing" (streak, level, last active), nothing a
/// chat or assignment feature would need. Computed straight from the
/// `profiles` row `circle_members` embeds (see `Backend.listCircleMembers`
/// — allowed only for the circle's owner, via a dedicated RLS policy).
class CircleMember {
  final String userId;
  final String displayName;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final String? lastActiveDate;
  final bool isPro;
  final DateTime joinedAt;

  const CircleMember({
    required this.userId,
    required this.displayName,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActiveDate,
    required this.isPro,
    required this.joinedAt,
  });

  /// Same formula as `AppState.level` — kept as a one-line duplicate
  /// rather than a shared import, the same call this codebase already
  /// makes elsewhere for small, stable formulas (see `main.dart`'s
  /// `_dateKey`, also duplicated rather than shared).
  int get level => 1 + (totalXp ~/ 150);

  factory CircleMember.fromRow(Map<String, dynamic> row) {
    final p = row['profiles'] as Map<String, dynamic>? ?? const {};
    final name = (p['display_name'] as String?)?.trim();
    return CircleMember(
      userId: row['user_id'] as String,
      displayName: (name == null || name.isEmpty) ? 'دانش‌آموز' : name,
      totalXp: (p['total_xp'] as num?)?.toInt() ?? 0,
      currentStreak: (p['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (p['longest_streak'] as num?)?.toInt() ?? 0,
      lastActiveDate: p['last_active_date'] as String?,
      isPro: p['is_pro'] as bool? ?? false,
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }
}

/// A circle this user has joined as a *member*, not the one (if any) they
/// own — for the "I'm part of these" list and for leaving one.
class JoinedCircle {
  final String circleId;
  final String name;
  final String ownerId;
  final DateTime joinedAt;

  const JoinedCircle({
    required this.circleId,
    required this.name,
    required this.ownerId,
    required this.joinedAt,
  });

  factory JoinedCircle.fromRow(Map<String, dynamic> row) {
    final c = row['circles'] as Map<String, dynamic>;
    return JoinedCircle(
      circleId: c['id'] as String,
      name: c['name'] as String,
      ownerId: c['owner_id'] as String,
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }
}

/// Family/teacher circles: an owner shares an invite code, a learner who
/// redeems it becomes visible (streak/level/last-active only — no chat, no
/// assignments) on the owner's dashboard. One owned circle per user, plus
/// however many circles they've joined as a member of someone else's.
///
/// Deliberately its own service rather than folded into `AppState` — same
/// reasoning as `prayer_reminder.dart`/`offline_audio.dart`: a
/// self-contained feature with its own state shape shouldn't keep growing
/// the one class everything else already depends on. Reads `appState`'s
/// session (`authToken`/`userId`) rather than owning a second copy of it.
class CirclesState extends ChangeNotifier {
  CirclesState._();
  static final CirclesState instance = CirclesState._();

  Map<String, dynamic>? ownedCircle;
  List<CircleMember> members = <CircleMember>[];
  List<JoinedCircle> joinedCircles = <JoinedCircle>[];
  bool loading = false;
  String? error;

  String? get ownedCircleId => ownedCircle?['id'] as String?;
  String? get ownedCircleName => ownedCircle?['name'] as String?;
  String? get ownedInviteCode => ownedCircle?['invite_code'] as String?;

  Future<void> refresh() async {
    final token = appState.authToken;
    final uid = appState.userId;
    if (token == null || uid == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      ownedCircle = await Backend.getOwnedCircle(token, uid);
      final owned = ownedCircle;
      members = owned == null
          ? <CircleMember>[]
          : (await Backend.listCircleMembers(token, owned['id'] as String))
              .map(CircleMember.fromRow)
              .toList();
      joinedCircles = (await Backend.listJoinedCircles(token, uid))
          .where((r) => r['circles'] != null)
          .map(JoinedCircle.fromRow)
          .toList();
    } on Object catch (e) {
      error = 'به‌روزرسانی حلقه‌ها انجام نشد.';
      AppLog.warn('circles refresh failed', error: e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Excludes visually-ambiguous characters (0/O, 1/I/L) — this gets read
  /// aloud or typed by hand at least as often as it gets copy-pasted.
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _generateInviteCode() {
    final rnd = Random.secure();
    return List<String>.generate(
        6, (_) => _codeAlphabet[rnd.nextInt(_codeAlphabet.length)]).join();
  }

  Future<void> createCircle({String name = 'حلقهٔ من'}) async {
    final token = appState.authToken;
    final uid = appState.userId;
    if (token == null || uid == null) {
      throw StateError('باید وارد حساب شوید.');
    }
    // A 6-character code from a 32-symbol alphabet is ~1 billion
    // combinations — collision odds are negligible at this app's scale,
    // but retrying with a fresh code on any failure is cheap insurance
    // against the one-in-a-billion case rather than surfacing a confusing
    // error for it.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        ownedCircle = await Backend.createCircle(
          token,
          ownerId: uid,
          name: name,
          inviteCode: _generateInviteCode(),
        );
        members = <CircleMember>[];
        notifyListeners();
        return;
      } on Object {
        if (attempt == 2) rethrow;
      }
    }
  }

  Future<void> renameCircle(String name) async {
    final token = appState.authToken;
    final id = ownedCircleId;
    if (token == null || id == null) return;
    await Backend.updateCircle(token, id, name: name);
    ownedCircle = <String, dynamic>{...?ownedCircle, 'name': name};
    notifyListeners();
  }

  Future<void> regenerateInviteCode() async {
    final token = appState.authToken;
    final id = ownedCircleId;
    if (token == null || id == null) return;
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = _generateInviteCode();
      try {
        await Backend.updateCircle(token, id, inviteCode: code);
        ownedCircle = <String, dynamic>{...?ownedCircle, 'invite_code': code};
        notifyListeners();
        return;
      } on Object {
        if (attempt == 2) rethrow;
      }
    }
  }

  Future<void> deleteCircle() async {
    final token = appState.authToken;
    final id = ownedCircleId;
    if (token == null || id == null) return;
    await Backend.deleteCircle(token, id);
    ownedCircle = null;
    members = <CircleMember>[];
    notifyListeners();
  }

  /// Redeems an invite code. Returns null on success, or an error code
  /// (`invalid_code`, `cannot_join_own_circle`, `not_authenticated`) the
  /// caller turns into a Persian message — see `join_circle_by_code`'s
  /// migration for exactly which codes it can return.
  Future<String?> joinByCode(String code) async {
    final token = appState.authToken;
    if (token == null) return 'not_authenticated';
    final result =
        await Backend.joinCircleByCode(token, code.trim().toUpperCase());
    if (result['ok'] != true) {
      return result['error'] as String? ?? 'unknown';
    }
    await refresh();
    return null;
  }

  /// A member leaving and an owner removing a member are the same call —
  /// RLS allows either caller (see the migration).
  Future<void> leaveCircle(String circleId) async {
    final token = appState.authToken;
    final uid = appState.userId;
    if (token == null || uid == null) return;
    await Backend.removeCircleMember(token, circleId, uid);
    joinedCircles = joinedCircles.where((c) => c.circleId != circleId).toList();
    notifyListeners();
  }

  Future<void> removeMember(String userId) async {
    final token = appState.authToken;
    final id = ownedCircleId;
    if (token == null || id == null) return;
    await Backend.removeCircleMember(token, id, userId);
    members = members.where((m) => m.userId != userId).toList();
    notifyListeners();
  }
}

final circles = CirclesState.instance;
