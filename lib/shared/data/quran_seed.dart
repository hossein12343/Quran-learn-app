import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;

/// Qur'anic text reproduced verbatim from the standard Hafs mushaf — the
/// four surahs below are the original hand-checked seed and stay as the
/// fallback if the full mushaf asset ever fails to load. The other 110 come
/// from `assets/quran_full.json` (Uthmani text + Saheeh International,
/// pulled from api.quran.com — see `tools/fetch_quran.py`), loaded once at
/// startup by [loadFullQuran].
class Ayah {
  final int number;
  final String arabic;
  final String translation;

  const Ayah(this.number, this.arabic, this.translation);

  List<String> get words =>
      arabic.split(' ').where((w) => w.trim().isNotEmpty).toList();
}

class Surah {
  final int number;
  final String arabicName;
  final String englishName;
  final String meaning;
  final String revelation;
  final List<Ayah> ayat;

  const Surah({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.meaning,
    required this.revelation,
    required this.ayat,
  });

  int get length => ayat.length;

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
        number: json['number'] as int,
        arabicName: json['arabicName'] as String,
        englishName: json['englishName'] as String,
        meaning: json['meaning'] as String,
        revelation: json['revelation'] as String,
        ayat: (json['ayat'] as List)
            .map((a) => Ayah(
                  a['number'] as int,
                  a['arabic'] as String,
                  a['translation'] as String,
                ))
            .toList(),
      );
}

List<Surah> surahs = <Surah>[
  Surah(
    number: 1,
    arabicName: 'ٱلْفَاتِحَة',
    englishName: 'Al-Fatiha',
    meaning: 'گشایش',
    revelation: 'مکی',
    ayat: <Ayah>[
      Ayah(1, 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
          'به نام خداوند بخشندۀ مهربان'),
      Ayah(2, 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
          'ستایش مخصوص الله است که پروردگار جهانیان است.'),
      Ayah(3, 'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
          'بخشندۀ مهربان است'),
      Ayah(4, 'مَٰلِكِ يَوْمِ ٱلدِّينِ', 'مالک روز جزاء است.'),
      Ayah(5, 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
          'تنها تو را می‌پرستیم؛ و تنها از تو یاری می‌جوییم.'),
      Ayah(6, 'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ',
          'ما را به راه راست هدایت کن.'),
      Ayah(
          7,
          'صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ',
          'راه کسانی‌که بر آنان نعمت دادی؛ نه خشم گرفتگان بر آن‌ها؛ و نه گمراهان.'),
    ],
  ),
  Surah(
    number: 112,
    arabicName: 'ٱلْإِخْلَاص',
    englishName: 'Al-Ikhlas',
    meaning: 'اخلاص',
    revelation: 'مکی',
    ayat: <Ayah>[
      Ayah(1, 'قُلْ هُوَ ٱللَّهُ أَحَدٌ', '(ای پیامبر) بگو: «او الله یکتا و یگانه است.'),
      Ayah(2, 'ٱللَّهُ ٱلصَّمَدُ', 'الله بی‌نیاز است (و همه نیازمند او هستند).'),
      Ayah(3, 'لَمْ يَلِدْ وَلَمْ يُولَدْ',
          'نه (فرزندی) زاده و نه زاده شده است.'),
      Ayah(4, 'وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ',
          'و هیچ کس همانند و همتای او نبوده و نیست».'),
    ],
  ),
  Surah(
    number: 113,
    arabicName: 'ٱلْفَلَق',
    englishName: 'Al-Falaq',
    meaning: 'سپیده‌دم',
    revelation: 'مکی',
    ayat: <Ayah>[
      Ayah(1, 'قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ',
          '(ای پیامبر) بگو: «به پروردگار سپیده دم پناه می‌برم،'),
      Ayah(2, 'مِن شَرِّ مَا خَلَقَ',
          'از شر تمام آنچه آفریده است،'),
      Ayah(3, 'وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ',
          'و از شر تاریکی شب، آنگاه که همه جا را فرا گیرد.'),
      Ayah(4, 'وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ',
          'و از شر (زنان جادوگر) که با افسون در گره‌ها می‌دمند.'),
      Ayah(5, 'وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
          'و از شر حسود آنگاه که حسد ورزد».'),
    ],
  ),
  Surah(
    number: 114,
    arabicName: 'ٱلنَّاس',
    englishName: 'An-Nas',
    meaning: 'مردم',
    revelation: 'مکی',
    ayat: <Ayah>[
      Ayah(1, 'قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ',
          '(ای پیامبر) بگو: «به پروردگار مردم پناه می‌برم،'),
      Ayah(2, 'مَلِكِ ٱلنَّاسِ', 'فرمانروای مردم،'),
      Ayah(3, 'إِلَٰهِ ٱلنَّاسِ', '(إله و) معبود مردم،'),
      Ayah(4, 'مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ',
          'از شر (شیطان) وسوسه‌گر باز پس رونده (به هنگام ذکر الله).'),
      Ayah(5, 'ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ',
          'همان که در دل‌های مردم وسوسه می‌کند.'),
      Ayah(6, 'مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ', 'از جنیان (باشد) و (یا از) آدمیان».'),
    ],
  ),
];

/// Ayat per lesson level. Long surahs (Al-Baqarah is 286 ayat) are learned
/// and gated a level at a time rather than as one sitting — the "recall the
/// whole thing blind, zero mistakes" gate that makes this app work only
/// stays learnable at a bounded size. Short surahs (at or under this size)
/// are a single level. Shared between the quiz engine and AppState's level
/// tracking, which is why it lives here rather than in the quiz feature.
const int kChunkSize = 8;

int chunkCountFor(Surah s) => (s.length / kChunkSize).ceil();

/// What the spaced-review scheduler tracks per sealed level: how many
/// times in a row it has been recalled, a per-level ease factor (how fast
/// its gap grows — SM-2's core idea: an item you find easy spaces out
/// faster than one you keep stumbling on), and the current gap in days.
class ReviewState {
  final int reps;
  final double ease;
  final int intervalDays;

  const ReviewState({
    required this.reps,
    required this.ease,
    required this.intervalDays,
  });
}

/// SM-2-style spaced review, adapted to this app's coarse signal. Anki/
/// SuperMemo grade each recall 0–5; here a review level only ever clears
/// *cleanly* or clears *with a lapse in it*, so this maps that two-way
/// signal onto the same mechanics:
///
///  * first seal → due tomorrow (the forgetting curve is steepest in the
///    first day), then +3 days, then each clean recall multiplies the gap
///    by the level's ease and nudges the ease up;
///  * a lapse shrinks the gap and the ease but — unlike the old fixed
///    `[4,7,14,30,60,90]` ladder, which reset to day 4 on any mistake —
///    does NOT discard everything the level earned. One slip after months
///    of clean recalls costs a step, not a restart.
abstract class ReviewSchedule {
  static const double startEase = 2.3;
  static const double _minEase = 1.3;
  static const double _maxEase = 2.8;
  static const int _maxInterval = 180;

  /// Legacy `[4,7,14,30,60,90]` ladder — kept only to migrate the interval
  /// for levels sealed before this scheduler existed (their snapshot has a
  /// rep count but no stored interval/ease).
  static const List<int> legacyLadder = <int>[4, 7, 14, 30, 60, 90];

  static ReviewState onFirstSeal() =>
      const ReviewState(reps: 1, ease: startEase, intervalDays: 1);

  static ReviewState onReview(ReviewState s, {required bool clean}) {
    if (clean) {
      final reps = s.reps + 1;
      final ease = (s.ease + 0.12).clamp(_minEase, _maxEase);
      final interval = reps <= 1
          ? 1
          : reps == 2
              ? 3
              : (s.intervalDays * s.ease).round().clamp(1, _maxInterval);
      return ReviewState(reps: reps, ease: ease, intervalDays: interval);
    }
    return ReviewState(
      reps: s.reps > 1 ? s.reps - 1 : 1,
      ease: (s.ease - 0.2).clamp(_minEase, _maxEase),
      intervalDays: (s.intervalDays * 0.4).round().clamp(1, _maxInterval),
    );
  }

  static DateTime dueDate(DateTime from, int intervalDays) =>
      DateTime(from.year, from.month, from.day)
          .add(Duration(days: intervalDays));

  static bool isDue(DateTime due) => !DateTime.now().isBefore(due);
}

bool quranFullyLoaded = false;

/// Bumped once [loadFullQuran] has swapped in all 114 surahs. The app no
/// longer blocks startup on that parse (a 3MB `jsonDecode` plus ~6,236
/// object allocations — real seconds on a mid-range phone): the shell
/// opens immediately on the 4-surah fallback and rebuilds against this
/// notifier when the full mushaf is ready. `main.dart` merges it into the
/// top-level `AnimatedBuilder`.
final ValueNotifier<int> quranRevision = ValueNotifier<int>(0);

/// Replaces the 4-surah fallback above with all 114 surahs. Called once at
/// startup (see splash_page.dart); safe to call again, and leaves the
/// fallback in place if the asset can't be read for any reason.
///
/// The parse itself (`jsonDecode` plus building ~6,236 `Ayah` objects out
/// of a 3MB string) runs via [compute] on a background isolate rather
/// than inline here — measured on a mid-range Android device, that parse
/// alone was long enough to visibly stall the splash screen's own
/// animation, on top of whatever it delayed navigating away from. `raw`
/// (already-decoded UTF-8 text) and the returned `List<Surah>` are plain
/// data — Strings, ints, and Lists of those — which is exactly what
/// `compute` can move across the isolate boundary without extra work.
Future<void> loadFullQuran() async {
  if (quranFullyLoaded) return;
  try {
    final raw = await rootBundle.loadString('assets/quran_full.json');
    surahs = await compute(_parseQuranSurahs, raw);
    quranFullyLoaded = true;
    quranRevision.value++;
  } on Object {
    // Asset missing or malformed — keep the 4-surah fallback.
  }
}

List<Surah> _parseQuranSurahs(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return (data['surahs'] as List)
      .map((s) => Surah.fromJson(s as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => a.number.compareTo(b.number));
}
