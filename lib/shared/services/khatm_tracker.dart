import 'package:flutter/foundation.dart';
import 'store/local_store.dart';

/// Tracks progress through a full khatm (ختم) — reading all 30 juz once —
/// completely separate from the app's memorization tracking in
/// [AppState]. This is a reading checklist people mostly use during
/// Ramadan, not graded progress, so it stays purely local (no account
/// needed, no Supabase sync): a phone-local tally is exactly the right
/// amount of durability for it.
class KhatmTracker extends ChangeNotifier {
  static const _completedKey = 'khatm_completed';
  static const _startKey = 'khatm_start_date';

  /// Ramadan is conventionally 29 or 30 days — this is the pace target
  /// shown to the user, not an enforced deadline (finishing early or late
  /// is still tracked the same way).
  static const int targetDays = 30;

  Set<int> _completed = _readCompleted();
  String? _startDate = LocalStore.get(_startKey);

  Set<int> get completed => _completed;
  String? get startDate => _startDate;
  bool get isDone => _completed.length >= 30;

  static Set<int> _readCompleted() {
    final raw = LocalStore.get(_completedKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
  }

  void _writeCompleted() => LocalStore.set(_completedKey, _completed.join(','));

  /// The first tap on any juz silently starts the pace clock — no separate
  /// "شروع کن" step to remember, since forgetting to press a start button
  /// is exactly the kind of friction that makes a tracker like this go
  /// unused.
  void toggle(int juz) {
    if (_startDate == null) _setStartDate(_todayKey());
    if (!_completed.remove(juz)) _completed.add(juz);
    _writeCompleted();
    notifyListeners();
  }

  /// Clears every checked juz and restarts the pace clock from today —
  /// for beginning a fresh khatm (next Ramadan, or a deliberate restart)
  /// without stale progress skewing the daily-pace suggestion.
  void reset() {
    _completed = {};
    _writeCompleted();
    _setStartDate(_todayKey());
    notifyListeners();
  }

  void _setStartDate(String key) {
    _startDate = key;
    LocalStore.set(_startKey, key);
  }

  /// Juz-per-day still needed to finish within [targetDays] of the start
  /// date — null before anything's been started. Clamped to at least 1 day
  /// remaining so a khatm that's run past its 30-day target still shows a
  /// real (just steeper) number instead of dividing by zero or going
  /// negative.
  int? get suggestedDailyPace {
    final start = _startDate;
    if (start == null) return null;
    final remaining = 30 - _completed.length;
    if (remaining <= 0) return 0;
    final elapsed = _daysBetween(start, _todayKey());
    final daysLeft = (targetDays - elapsed).clamp(1, targetDays);
    return (remaining / daysLeft).ceil();
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static int _daysBetween(String from, String to) {
    final a = _parseKey(from);
    final b = _parseKey(to);
    return b.difference(a).inDays;
  }

  static DateTime _parseKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
}

final khatmTracker = KhatmTracker();
