/// The 99 Names of Allah (Asma ul-Husna) — Arabic form, a Latin
/// transliteration, and an English meaning. Fetched once from
/// api.aladhan.com's own `/asmaAlHusna` endpoint (already used and
/// CSP-allowlisted for prayer times, so no new external origin is
/// needed for this) and hardcoded here rather than bundled as a
/// lazy-loaded asset — 99 short, fully static, never-changing entries
/// is small enough that a JSON asset + loader would be pure overhead,
/// same reasoning as `sajdah.dart`. English only: no Persian meaning
/// field exists on this endpoint.
class AsmaName {
  final int number;
  final String arabic;
  final String transliteration;
  final String meaning;

  const AsmaName({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
  });
}

const List<AsmaName> asmaAlHusna = <AsmaName>[
  AsmaName(
      number: 1,
      arabic: 'الرَّحْمَنُ',
      transliteration: 'Ar Rahmaan',
      meaning: 'The Beneficent'),
  AsmaName(
      number: 2,
      arabic: 'الرَّحِيمُ',
      transliteration: 'Ar Raheem',
      meaning: 'The Merciful'),
  AsmaName(
      number: 3,
      arabic: 'الْمَلِكُ',
      transliteration: 'Al Malik',
      meaning: 'The King / Eternal Lord'),
  AsmaName(
      number: 4,
      arabic: 'الْقُدُّوسُ',
      transliteration: 'Al Quddus',
      meaning: 'The Purest'),
  AsmaName(
      number: 5,
      arabic: 'السَّلاَمُ',
      transliteration: 'As Salaam',
      meaning: 'The Source of Peace'),
  AsmaName(
      number: 6,
      arabic: 'الْمُؤْمِنُ',
      transliteration: 'Al Mu\'min',
      meaning: 'The inspirer of faith'),
  AsmaName(
      number: 7,
      arabic: 'الْمُهَيْمِنُ',
      transliteration: 'Al Muhaymin',
      meaning: 'The Guardian'),
  AsmaName(
      number: 8,
      arabic: 'الْعَزِيزُ',
      transliteration: 'Al Azeez',
      meaning: 'The Precious / The Most Mighty'),
  AsmaName(
      number: 9,
      arabic: 'الْجَبَّارُ',
      transliteration: 'Al Jabbaar',
      meaning: 'The Compeller'),
  AsmaName(
      number: 10,
      arabic: 'الْمُتَكَبِّرُ',
      transliteration: 'Al Mutakabbir',
      meaning: 'The Greatest'),
  AsmaName(
      number: 11,
      arabic: 'الْخَالِقُ',
      transliteration: 'Al Khaaliq',
      meaning: 'The Creator'),
  AsmaName(
      number: 12,
      arabic: 'الْبَارِئُ',
      transliteration: 'Al Baari',
      meaning: 'The Maker of Order'),
  AsmaName(
      number: 13,
      arabic: 'الْمُصَوِّرُ',
      transliteration: 'Al Musawwir',
      meaning: 'The Shaper of Beauty'),
  AsmaName(
      number: 14,
      arabic: 'الْغَفَّارُ',
      transliteration: 'Al Ghaffaar',
      meaning: 'The Forgiving'),
  AsmaName(
      number: 15,
      arabic: 'الْقَهَّارُ',
      transliteration: 'Al Qahhaar',
      meaning: 'The Subduer'),
  AsmaName(
      number: 16,
      arabic: 'الْوَهَّابُ',
      transliteration: 'Al Wahhaab',
      meaning: 'The Giver of All'),
  AsmaName(
      number: 17,
      arabic: 'الرَّزَّاقُ',
      transliteration: 'Ar Razzaaq',
      meaning: 'The Sustainer'),
  AsmaName(
      number: 18,
      arabic: 'الْفَتَّاحُ',
      transliteration: 'Al Fattaah',
      meaning: 'The Opener'),
  AsmaName(
      number: 19,
      arabic: 'اَلْعَلِيْمُ',
      transliteration: 'Al \'Aleem',
      meaning: 'The Knower of all'),
  AsmaName(
      number: 20,
      arabic: 'الْقَابِضُ',
      transliteration: 'Al Qaabid',
      meaning: 'The Constrictor'),
  AsmaName(
      number: 21,
      arabic: 'الْبَاسِطُ',
      transliteration: 'Al Baasit',
      meaning: 'The Reliever'),
  AsmaName(
      number: 22,
      arabic: 'الْخَافِضُ',
      transliteration: 'Al Khaafid',
      meaning: 'The Abaser'),
  AsmaName(
      number: 23,
      arabic: 'الرَّافِعُ',
      transliteration: 'Ar Raafi\'',
      meaning: 'The Exalter'),
  AsmaName(
      number: 24,
      arabic: 'الْمُعِزُّ',
      transliteration: 'Al Mu\'iz',
      meaning: 'The Bestower of Honour'),
  AsmaName(
      number: 25,
      arabic: 'المُذِلُّ',
      transliteration: 'Al Mudhil',
      meaning: 'The Humiliator'),
  AsmaName(
      number: 26,
      arabic: 'السَّمِيعُ',
      transliteration: 'As Samee\'',
      meaning: 'The Hearer of all'),
  AsmaName(
      number: 27,
      arabic: 'الْبَصِيرُ',
      transliteration: 'Al Baseer',
      meaning: 'The Seer of all'),
  AsmaName(
      number: 28,
      arabic: 'الْحَكَمُ',
      transliteration: 'Al Hakam',
      meaning: 'The Judge'),
  AsmaName(
      number: 29,
      arabic: 'الْعَدْلُ',
      transliteration: 'Al \'Adl',
      meaning: 'The Just'),
  AsmaName(
      number: 30,
      arabic: 'اللَّطِيفُ',
      transliteration: 'Al Lateef',
      meaning: 'The Subtle One'),
  AsmaName(
      number: 31,
      arabic: 'الْخَبِيرُ',
      transliteration: 'Al Khabeer',
      meaning: 'The All Aware'),
  AsmaName(
      number: 32,
      arabic: 'الْحَلِيمُ',
      transliteration: 'Al Haleem',
      meaning: 'The Forebearing'),
  AsmaName(
      number: 33,
      arabic: 'الْعَظِيمُ',
      transliteration: 'Al \'Azeem',
      meaning: 'The Maginificent'),
  AsmaName(
      number: 34,
      arabic: 'الْغَفُورُ',
      transliteration: 'Al Ghafoor',
      meaning: 'The Great Forgiver'),
  AsmaName(
      number: 35,
      arabic: 'الشَّكُورُ',
      transliteration: 'Ash Shakoor',
      meaning: 'The Rewarder of Thankfulness'),
  AsmaName(
      number: 36,
      arabic: 'الْعَلِيُّ',
      transliteration: 'Al \'Aliyy',
      meaning: 'The Highest'),
  AsmaName(
      number: 37,
      arabic: 'الْكَبِيرُ',
      transliteration: 'Al Kabeer',
      meaning: 'The Greatest'),
  AsmaName(
      number: 38,
      arabic: 'الْحَفِيظُ',
      transliteration: 'Al Hafeez',
      meaning: 'The Preserver'),
  AsmaName(
      number: 39,
      arabic: 'المُقيِت',
      transliteration: 'Al Muqeet',
      meaning: 'The Nourisher'),
  AsmaName(
      number: 40,
      arabic: 'الْحسِيبُ',
      transliteration: 'Al Haseeb',
      meaning: 'The Reckoner'),
  AsmaName(
      number: 41,
      arabic: 'الْجَلِيلُ',
      transliteration: 'Al Jaleel',
      meaning: 'The Majestic'),
  AsmaName(
      number: 42,
      arabic: 'الْكَرِيمُ',
      transliteration: 'Al Kareem',
      meaning: 'The Generous'),
  AsmaName(
      number: 43,
      arabic: 'الرَّقِيبُ',
      transliteration: 'Ar Raqeeb',
      meaning: 'The Watchful One'),
  AsmaName(
      number: 44,
      arabic: 'الْمُجِيبُ',
      transliteration: 'Al Mujeeb ',
      meaning: 'The Responder to Prayer'),
  AsmaName(
      number: 45,
      arabic: 'الْوَاسِعُ',
      transliteration: 'Al Waasi\'',
      meaning: 'The All Comprehending'),
  AsmaName(
      number: 46,
      arabic: 'الْحَكِيمُ',
      transliteration: 'Al Hakeem',
      meaning: 'The Perfectly Wise'),
  AsmaName(
      number: 47,
      arabic: 'الْوَدُودُ',
      transliteration: 'Al Wudood',
      meaning: 'The Loving One'),
  AsmaName(
      number: 48,
      arabic: 'الْمَجِيدُ',
      transliteration: 'Al Majeed',
      meaning: 'The Most Glorious One'),
  AsmaName(
      number: 49,
      arabic: 'الْبَاعِثُ',
      transliteration: 'Al Baa\'ith',
      meaning: 'The Resurrector'),
  AsmaName(
      number: 50,
      arabic: 'الشَّهِيدُ',
      transliteration: 'Ash Shaheed',
      meaning: 'The Witness'),
  AsmaName(
      number: 51,
      arabic: 'الْحَقُّ',
      transliteration: 'Al Haqq',
      meaning: 'The Truth'),
  AsmaName(
      number: 52,
      arabic: 'الْوَكِيلُ',
      transliteration: 'Al Wakeel',
      meaning: 'The Trustee'),
  AsmaName(
      number: 53,
      arabic: 'الْقَوِيُّ',
      transliteration: 'Al Qawiyy',
      meaning: 'The Possessor of all strength'),
  AsmaName(
      number: 54,
      arabic: 'الْمَتِينُ',
      transliteration: 'Al Mateen',
      meaning: 'The Forceful'),
  AsmaName(
      number: 55,
      arabic: 'الْوَلِيُّ',
      transliteration: 'Al Waliyy',
      meaning: 'The Protector'),
  AsmaName(
      number: 56,
      arabic: 'الْحَمِيدُ',
      transliteration: 'Al Hameed',
      meaning: 'The Praised'),
  AsmaName(
      number: 57,
      arabic: 'الْمُحْصِي',
      transliteration: 'Al Muhsi',
      meaning: 'The Appraiser'),
  AsmaName(
      number: 58,
      arabic: 'الْمُبْدِئُ',
      transliteration: 'Al Mubdi',
      meaning: 'The Originator'),
  AsmaName(
      number: 59,
      arabic: 'الْمُعِيدُ',
      transliteration: 'Al Mu\'eed',
      meaning: 'The Restorer'),
  AsmaName(
      number: 60,
      arabic: 'الْمُحْيِي',
      transliteration: 'Al Muhiy',
      meaning: 'The Giver of life'),
  AsmaName(
      number: 61,
      arabic: 'اَلْمُمِيتُ',
      transliteration: 'Al Mumeet',
      meaning: 'The Taker of life'),
  AsmaName(
      number: 62,
      arabic: 'الْحَيُّ',
      transliteration: 'Al Haiyy',
      meaning: 'The Ever Living'),
  AsmaName(
      number: 63,
      arabic: 'الْقَيُّومُ',
      transliteration: 'Al Qayyoom',
      meaning: 'The Self Existing'),
  AsmaName(
      number: 64,
      arabic: 'الْوَاجِدُ',
      transliteration: 'Al Waajid',
      meaning: 'The Finder'),
  AsmaName(
      number: 65,
      arabic: 'الْمَاجِدُ',
      transliteration: 'Al Maajid',
      meaning: 'The Glorious'),
  AsmaName(
      number: 66,
      arabic: 'الْواحِدُ',
      transliteration: 'Al Waahid',
      meaning: 'The Only One'),
  AsmaName(
      number: 67,
      arabic: 'اَلاَحَدُ',
      transliteration: 'Al Ahad',
      meaning: 'The One'),
  AsmaName(
      number: 68,
      arabic: 'الصَّمَدُ',
      transliteration: 'As Samad',
      meaning: 'The Supreme Provider'),
  AsmaName(
      number: 69,
      arabic: 'الْقَادِرُ',
      transliteration: 'Al Qaadir',
      meaning: 'The Powerful'),
  AsmaName(
      number: 70,
      arabic: 'الْمُقْتَدِرُ',
      transliteration: 'Al Muqtadir',
      meaning: 'The Creator of all power'),
  AsmaName(
      number: 71,
      arabic: 'الْمُقَدِّمُ',
      transliteration: 'Al Muqaddim',
      meaning: 'The Expediter'),
  AsmaName(
      number: 72,
      arabic: 'الْمُؤَخِّرُ',
      transliteration: 'Al Mu’akhir',
      meaning: 'The Delayer'),
  AsmaName(
      number: 73,
      arabic: 'الأوَّلُ',
      transliteration: 'Al Awwal',
      meaning: 'The First'),
  AsmaName(
      number: 74,
      arabic: 'الآخِرُ',
      transliteration: 'Al Aakhir',
      meaning: 'The Last'),
  AsmaName(
      number: 75,
      arabic: 'الظَّاهِرُ',
      transliteration: 'Az Zaahir',
      meaning: 'The Manifest'),
  AsmaName(
      number: 76,
      arabic: 'الْبَاطِنُ',
      transliteration: 'Al Baatin',
      meaning: 'The Hidden'),
  AsmaName(
      number: 77,
      arabic: 'الْوَالِي',
      transliteration: 'Al Waali',
      meaning: 'The Governor'),
  AsmaName(
      number: 78,
      arabic: 'الْمُتَعَالِي',
      transliteration: 'Al Muta’ali',
      meaning: 'The Supreme One'),
  AsmaName(
      number: 79,
      arabic: 'الْبَرُّ',
      transliteration: 'Al Barr',
      meaning: 'The Doer of Good'),
  AsmaName(
      number: 80,
      arabic: 'التَّوَابُ',
      transliteration: 'At Tawwaab',
      meaning: 'The Guide to Repentence'),
  AsmaName(
      number: 81,
      arabic: 'الْمُنْتَقِمُ',
      transliteration: 'Al Muntaqim',
      meaning: 'The Avenger'),
  AsmaName(
      number: 82,
      arabic: 'العَفُوُّ',
      transliteration: 'Al Afuww',
      meaning: 'The Forgiver'),
  AsmaName(
      number: 83,
      arabic: 'الرَّؤُوفُ',
      transliteration: 'Ar Ra’oof',
      meaning: 'The Clement'),
  AsmaName(
      number: 84,
      arabic: 'مَالِكُ الْمُلْكِ',
      transliteration: 'Maalik Ul Mulk',
      meaning: 'The Owner / Soverign of All'),
  AsmaName(
      number: 85,
      arabic: 'ذُوالْجَلاَلِ وَالإكْرَامِ',
      transliteration: 'Dhu Al Jalaali Wa Al Ikraam',
      meaning: 'Possessor of Majesty and Bounty'),
  AsmaName(
      number: 86,
      arabic: 'الْمُقْسِطُ',
      transliteration: 'Al Muqsit',
      meaning: 'The Equitable One'),
  AsmaName(
      number: 87,
      arabic: 'الْجَامِعُ',
      transliteration: 'Al Jaami\'',
      meaning: 'The Gatherer'),
  AsmaName(
      number: 88,
      arabic: 'الْغَنِيُّ',
      transliteration: 'Al Ghaniyy',
      meaning: 'The Rich One'),
  AsmaName(
      number: 89,
      arabic: 'الْمُغْنِي',
      transliteration: 'Al Mughi',
      meaning: 'The Enricher'),
  AsmaName(
      number: 90,
      arabic: 'اَلْمَانِعُ',
      transliteration: 'Al Maani\'',
      meaning: 'The Preventer of harm'),
  AsmaName(
      number: 91,
      arabic: 'الضَّارَّ',
      transliteration: 'Ad Daaarr',
      meaning: 'The Creator of the harmful'),
  AsmaName(
      number: 92,
      arabic: 'النَّافِعُ',
      transliteration: 'An Naafi’',
      meaning: 'The Bestower of Benefits'),
  AsmaName(
      number: 93,
      arabic: 'النُّورُ',
      transliteration: 'An Noor',
      meaning: 'The Light'),
  AsmaName(
      number: 94,
      arabic: 'الْهَادِي',
      transliteration: 'Al Haadi',
      meaning: 'The Guider'),
  AsmaName(
      number: 95,
      arabic: 'الْبَدِيعُ',
      transliteration: 'Al Badi\'',
      meaning: 'The Originator'),
  AsmaName(
      number: 96,
      arabic: 'اَلْبَاقِي',
      transliteration: 'Al Baaqi',
      meaning: 'The Everlasting One'),
  AsmaName(
      number: 97,
      arabic: 'الْوَارِثُ',
      transliteration: 'Al Waarith',
      meaning: 'The Inhertior'),
  AsmaName(
      number: 98,
      arabic: 'الرَّشِيدُ',
      transliteration: 'Ar Rasheed',
      meaning: 'The Most Righteous Guide'),
  AsmaName(
      number: 99,
      arabic: 'الصَّبُورُ',
      transliteration: 'As Saboor',
      meaning: 'The Patient One'),
];
