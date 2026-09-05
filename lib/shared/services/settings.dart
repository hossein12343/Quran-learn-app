import 'dart:convert';
import 'package:flutter/material.dart';
import 'store/local_store.dart';

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

  const Qari({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.style,
    required this.folder,
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
      folder: 'Abdul_Basit_Murattal_192kbps'),
  Qari(
      id: 'sudais',
      name: 'Abdur-Rahman As-Sudais',
      nativeName: 'عبد الرحمن السديس',
      style: 'مرتل — مناسب برای مبتدیان',
      folder: 'Abdurrahmaan_As-Sudais_192kbps'),
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
  TimeOfDay reminderTime = const TimeOfDay(hour: 6, minute: 30);

  /// Multiplies every Arabic font size in the app. Kept modest so layouts
  /// never break: 0.85 (small) .. 1.35 (large).
  double arabicScale = 1.0;

  Qari get qari =>
      knownQaris.firstWhere((q) => q.id == qariId, orElse: () => knownQaris.first);

  bool get isRtl => language == 'fa';

  TextDirection get direction =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

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

  void setArabicScale(double v) {
    arabicScale = v.clamp(0.85, 1.35);
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
      arabicScale = (s['arabicScale'] as num?)?.toDouble() ?? arabicScale;
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
        'arabicScale': arabicScale,
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
