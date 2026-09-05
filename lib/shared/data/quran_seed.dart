import 'dart:convert';
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

/// Spaced review: a level sealed today comes due again in 4 days, then the
/// gap widens each time it's cleared cleanly. Keyed off "clean recalls" —
/// how many times in a row it's survived review without a mistake — not
/// calendar time, so a lapse (handled by whoever calls this) can reset the
/// count and shrink the gap back down.
abstract class ReviewSchedule {
  static const List<int> days = <int>[4, 7, 14, 30, 60, 90];

  static DateTime nextDue(DateTime last, int cleanRecalls) =>
      last.add(Duration(days: days[cleanRecalls.clamp(0, days.length - 1)]));

  static bool isDue(DateTime due) => !DateTime.now().isBefore(due);
}

bool quranFullyLoaded = false;

/// Replaces the 4-surah fallback above with all 114 surahs. Called once at
/// startup (see splash_page.dart); safe to call again, and leaves the
/// fallback in place if the asset can't be read for any reason.
Future<void> loadFullQuran() async {
  if (quranFullyLoaded) return;
  try {
    final raw = await rootBundle.loadString('assets/quran_full.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final loaded = (data['surahs'] as List)
        .map((s) => Surah.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    surahs = loaded;
    quranFullyLoaded = true;
  } on Object {
    // Asset missing or malformed — keep the 4-surah fallback.
  }
}
