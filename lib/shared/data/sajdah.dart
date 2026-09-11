/// The 14 verses requiring physical prostration during recitation —
/// api.quran.com's own `sajdah_number` field, independently confirmed
/// by scanning all 114 chapters rather than trusting a memorized list
/// (see `tools/fetch_word_by_word.py`'s docstring for how). This is
/// the Hanafi count; some other schools count a 15th sajdah at 22:77
/// (a second one in Al-Hajj) — api.quran.com's own data doesn't mark
/// that one, so neither does this app.
///
/// Tiny and fully static (Quran verse numbering never changes), so
/// unlike every other data source in this app it's a plain hardcoded
/// constant rather than a lazy-loaded asset — marking sajdah ayat is
/// mushaf etiquette, not a study toggle, so it needs to be available
/// immediately for every ayah, not gated behind a feature toggle's
/// lazy load.
const Set<String> sajdahVerseKeys = {
  '7:206',
  '13:15',
  '16:50',
  '17:109',
  '19:58',
  '22:18',
  '25:60',
  '27:26',
  '32:15',
  '38:24',
  '41:38',
  '53:62',
  '84:21',
  '96:19',
};

bool isSajdahAyah(int surahNumber, int ayahNumber) =>
    sajdahVerseKeys.contains('$surahNumber:$ayahNumber');
