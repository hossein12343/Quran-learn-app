import 'dart:convert';
import 'package:flutter/material.dart';
import 'prayer_times.dart';
import 'store/local_store.dart';

/// What a reminder's time-of-day is anchored to.
enum ReminderAnchor { fixedTime, afterPrayer }

/// How a surah is broken up for memorisation.
enum LearnMode {
  ayah, // one ayah at a time
  page, // a mushaf page at a time
  surah, // the whole surah at once
}

extension LearnModeLabel on LearnMode {
  String get label {
    switch (this) {
      case LearnMode.ayah:
        return 'آیه به آیه';
      case LearnMode.page:
        return 'صفحه به صفحه';
      case LearnMode.surah:
        return 'کل سوره';
    }
  }

  String get blurb {
    switch (this) {
      case LearnMode.ayah:
        return 'امن‌ترین روش برای سوره‌های بلند و برای شروع کار.';
      case LearnMode.page:
        return 'آیات را بر اساس صفحه مصحف گروه‌بندی می‌کند — روشی که اغلب حافظان استفاده می‌کنند.';
      case LearnMode.surah:
        return 'کل سوره در یک جلسه. فقط سوره‌های کوتاه.';
    }
  }
}

/// A reciter. `folder` is the everyayah.com directory the audio player
/// streams from — verified to exist (see BACKEND.md's note on never
/// hardcoding a reciter id from memory: these were checked against the
/// live host, not guessed).
class Qari {
  final String id;
  final String name;
  final String nativeName;
  final String style;
  final String folder;

  /// Gated behind Pro (see `shared/services/plan.dart`). Two of the four
  /// known reciters stay free so the app is fully usable without ever
  /// upgrading — this only ever narrows an already-generous default down
  /// to "the other two," never locks reciting itself.
  final bool isPro;

  const Qari({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.style,
    required this.folder,
    this.isPro = false,
  });
}

const List<Qari> knownQaris = <Qari>[
  Qari(
      id: 'alafasy',
      name: 'Mishary Alafasy',
      nativeName: 'مشاري العفاسي',
      style: 'مرتل — آهسته، بسیار شفاف',
      folder: 'Alafasy_128kbps'),
  Qari(
      id: 'husary',
      name: 'Mahmoud Al-Husary',
      nativeName: 'محمود الحصري',
      style: 'مرتل — منظم، تجوید کلاسیک',
      folder: 'Husary_128kbps'),
  Qari(
      id: 'abdulbasit',
      name: 'Abdul Basit Abdus Samad',
      nativeName: 'عبد الباسط عبد الصمد',
      style: 'مجوّد — تزئین‌شده، آرام',
      folder: 'Abdul_Basit_Murattal_192kbps',
      isPro: true),
  Qari(
      id: 'sudais',
      name: 'Abdur-Rahman As-Sudais',
      nativeName: 'عبد الرحمن السديس',
      style: 'مرتل — مناسب برای مبتدیان',
      folder: 'Abdurrahmaan_As-Sudais_192kbps',
      isPro: true),
];

const List<double> playbackSpeeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5];

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  String qariId = knownQaris.first.id;
  double speed = 1.0;
  int repeatCount = 3; // times each ayah replays before moving on
  LearnMode mode = LearnMode.ayah;
  String language = 'fa'; // 'en' or 'fa' — Persian by default
  bool dailyReminder = true;

  /// The resolved time-of-day the reminder actually fires at. When
  /// [reminderAnchor] is [ReminderAnchor.afterPrayer], this is recomputed
  /// once a day from today's prayer times (see `prayer_reminder.dart`) —
  /// it is *not* itself the source of truth in that mode, just the last
  /// resolved value, so every existing call site that reads it (the
  /// per-minute check in main.dart, the push-reminder sync) keeps working
  /// unchanged regardless of which mode is active.
  TimeOfDay reminderTime = const TimeOfDay(hour: 6, minute: 30);

  ReminderAnchor reminderAnchor = ReminderAnchor.fixedTime;
  Prayer reminderPrayer = Prayer.isha;

  /// Minutes after (never before — praying comes first) [reminderPrayer].
  int reminderOffsetMinutes = 15;

  /// Multiplies every Arabic font size in the app. Kept modest so layouts
  /// never break: 0.85 (small) .. 1.35 (large).
  double arabicScale = 1.0;

  /// Multiplies every *other* piece of text — Persian UI labels, buttons,
  /// settings copy — via a `TextScaler` at the app's root (see
  /// `QuranLearnApp`'s `builder` in main.dart), not per-widget. This
  /// app's audience skews older at one end (a parent or grandparent doing
  /// hifz alongside their kids) and younger at the other; `arabicScale`
  /// alone only helped the ayah itself read bigger, not the menus and
  /// buttons around it. Same conservative range as arabicScale, for the
  /// same reason — layouts stop being tested past it.
  double uiTextScale = 1.0;

  /// Colors each ayah by tajweed rule (see `shared/data/tajweed_parser.dart`)
  /// in the Qur'an reader. Off by default — this is a reading aid for
  /// people actively working on pronunciation, not how most people expect
  /// their first look at an ayah to render.
  bool tajweedEnabled = false;

  /// Shows the second Persian translation (IslamHouse.com, see
  /// `shared/data/translation2.dart`) instead of the default one.
  bool useTranslation2 = false;

  /// Renders each ayah as tappable words (see
  /// `shared/data/word_by_word.dart`) instead of one solid line, so a
  /// reader can check a single word's meaning without leaving the
  /// ayah. Off by default, same reasoning as [tajweedEnabled] — a
  /// study aid, not the default reading experience.
  bool wordByWordEnabled = false;

  Qari get qari => knownQaris.firstWhere((q) => q.id == qariId,
      orElse: () => knownQaris.first);

  bool get isRtl => language == 'fa';

  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  void setQari(String id) {
    qariId = id;
    notifyListeners();
    _save();
  }

  void setSpeed(double v) {
    speed = v;
    notifyListeners();
    _save();
  }

  void setRepeat(int v) {
    repeatCount = v;
    notifyListeners();
    _save();
  }

  void setMode(LearnMode m) {
    mode = m;
    notifyListeners();
    _save();
  }

  void setLanguage(String code) {
    language = code;
    notifyListeners();
    _save();
  }

  void setReminder(bool on, [TimeOfDay? at]) {
    dailyReminder = on;
    if (at != null) reminderTime = at;
    notifyListeners();
    _save();
  }

  /// Switches between a fixed clock time and a prayer-anchored one.
  /// Picking [ReminderAnchor.fixedTime] restores manual control over
  /// [reminderTime] via [setReminder]; picking [ReminderAnchor.afterPrayer]
  /// hands that over to `resolvePrayerAnchoredReminderTime()`, which the
  /// caller (Settings page, main.dart) is expected to invoke right after —
  /// this setter only records the choice, since resolving the actual time
  /// needs a network round trip this class has no business making.
  void setReminderAnchor(ReminderAnchor anchor) {
    reminderAnchor = anchor;
    notifyListeners();
    _save();
  }

  void setReminderPrayer(Prayer p) {
    reminderPrayer = p;
    notifyListeners();
    _save();
  }

  void setReminderOffsetMinutes(int m) {
    reminderOffsetMinutes = m.clamp(0, 90);
    notifyListeners();
    _save();
  }

  /// Called by the prayer-time resolver once it has computed today's
  /// anchored time — distinct from [setReminder] so it never flips
  /// [reminderAnchor] back to fixed or touches [dailyReminder].
  void setResolvedReminderTime(TimeOfDay t) {
    if (reminderTime == t) return;
    reminderTime = t;
    notifyListeners();
    _save();
  }

  void setArabicScale(double v) {
    arabicScale = v.clamp(0.85, 1.35);
    notifyListeners();
    _save();
  }

  void setUiTextScale(double v) {
    uiTextScale = v.clamp(0.85, 1.35);
    notifyListeners();
    _save();
  }

  void setTajweedEnabled(bool on) {
    tajweedEnabled = on;
    notifyListeners();
    _save();
  }

  void setUseTranslation2(bool on) {
    useTranslation2 = on;
    notifyListeners();
    _save();
  }

  void setWordByWordEnabled(bool on) {
    wordByWordEnabled = on;
    notifyListeners();
    _save();
  }

  /// Restores saved settings on this device. Called once at app boot.
  void restore() {
    final raw = LocalStore.get('settings');
    if (raw == null) return;
    try {
      final s = jsonDecode(raw) as Map<String, dynamic>;
      qariId = s['qariId'] as String? ?? qariId;
      speed = (s['speed'] as num?)?.toDouble() ?? speed;
      repeatCount = (s['repeatCount'] as num?)?.toInt() ?? repeatCount;
      mode = LearnMode.values[(s['mode'] as num?)?.toInt() ?? mode.index];
      language = s['language'] as String? ?? language;
      dailyReminder = s['dailyReminder'] as bool? ?? dailyReminder;
      final h = (s['reminderHour'] as num?)?.toInt();
      final m = (s['reminderMinute'] as num?)?.toInt();
      if (h != null && m != null) {
        reminderTime = TimeOfDay(hour: h, minute: m);
      }
      reminderAnchor = ReminderAnchor.values[
          (s['reminderAnchor'] as num?)?.toInt() ?? reminderAnchor.index];
      reminderPrayer = Prayer.values[
          (s['reminderPrayer'] as num?)?.toInt() ?? reminderPrayer.index];
      reminderOffsetMinutes = (s['reminderOffsetMinutes'] as num?)?.toInt() ??
          reminderOffsetMinutes;
      arabicScale = (s['arabicScale'] as num?)?.toDouble() ?? arabicScale;
      uiTextScale = (s['uiTextScale'] as num?)?.toDouble() ?? uiTextScale;
      tajweedEnabled = s['tajweedEnabled'] as bool? ?? tajweedEnabled;
      useTranslation2 = s['useTranslation2'] as bool? ?? useTranslation2;
      wordByWordEnabled = s['wordByWordEnabled'] as bool? ?? wordByWordEnabled;
    } on Object {
      // Corrupt local settings — keep defaults.
    }
  }

  void _save() {
    LocalStore.set(
      'settings',
      jsonEncode({
        'qariId': qariId,
        'speed': speed,
        'repeatCount': repeatCount,
        'mode': mode.index,
        'language': language,
        'dailyReminder': dailyReminder,
        'reminderHour': reminderTime.hour,
        'reminderMinute': reminderTime.minute,
        'reminderAnchor': reminderAnchor.index,
        'reminderPrayer': reminderPrayer.index,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'arabicScale': arabicScale,
        'uiTextScale': uiTextScale,
        'tajweedEnabled': tajweedEnabled,
        'useTranslation2': useTranslation2,
        'wordByWordEnabled': wordByWordEnabled,
      }),
    );
  }
}

final settings = Settings.instance;

/// Minimal string table. Persian is RTL; the app flips direction with it.
class L10n {
  static const Map<String, Map<String, String>> _t = {
    'en': {
      'home': 'Home',
      'learn': 'Learn',
      'quran': 'Quran',
      'progress': 'Progress',
      'profile': 'Profile',
      'settings': 'Settings',
      'reciter': 'Reciter',
      'speed': 'Playback speed',
      'repeat': 'Repeats per ayah',
      'mode': 'Learning mode',
      'language': 'Language',
      'reminder': 'Daily reminder',
      'ayatHeld': 'Ayat held',
      'recite': 'Recite aloud',
      'bookmarks': 'Bookmarks',
      'memorized': 'Memorised ayat',
      'achievements': 'Achievements',
      'fontSize': 'Arabic text size',
    },
    'fa': {
      'home': 'خانه',
      'learn': 'یادگیری',
      'quran': 'قرآن',
      'progress': 'پیشرفت',
      'profile': 'پروفایل',
      'settings': 'تنظیمات',
      'reciter': 'قاری',
      'speed': 'سرعت پخش',
      'repeat': 'تکرار هر آیه',
      'mode': 'شیوهٔ یادگیری',
      'language': 'زبان',
      'reminder': 'یادآور روزانه',
      'ayatHeld': 'آیات حفظ‌شده',
      'recite': 'تلاوت با صدا',
      'bookmarks': 'نشان‌شده‌ها',
      'memorized': 'آیات حفظ‌شده',
      'achievements': 'دستاوردها',
      'fontSize': 'اندازه متن عربی',
    },
  };

  static String t(String key) => _t[settings.language]?[key] ?? key;
}
