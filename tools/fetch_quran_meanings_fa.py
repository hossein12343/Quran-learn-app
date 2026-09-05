"""Replaces assets/quran_full.json's `meaning` field (currently English,
e.g. "The Cow" for Al-Baqarah, for all 114 surahs — even surah 1, despite
quran_seed.dart's own hardcoded 4-surah fallback already having Persian
for it, since the JSON asset is what actually loads at runtime and
overrides that fallback) with the standard Persian meaning of each surah
name, in place. Arabic text, translations, and every other field are left
untouched.

Not fetched from an API: api.quran.com's /chapters?language=fa was tried
first and confirmed live to silently fall back to English for
`translated_name` regardless of the language param (checked via curl —
`language=fa` and `language=en` returned identical English text), so this
is a hand-compiled table of the standard/widely-used Persian gloss for
each of the 114 surah names instead — stable reference data, not
something that benefits from a live fetch. Re-run only if a surah's
meaning wording needs revising.
"""
import json

MEANINGS_FA = {
    1: "گشایش", 2: "گاو", 3: "خاندان عمران", 4: "زنان", 5: "سفره",
    6: "چهارپایان", 7: "اعراف", 8: "غنایم جنگی", 9: "توبه", 10: "یونس",
    11: "هود", 12: "یوسف", 13: "رعد", 14: "ابراهیم", 15: "حجر",
    16: "زنبور عسل", 17: "سفر شبانه", 18: "غار", 19: "مریم", 20: "طه",
    21: "پیامبران", 22: "حج", 23: "مؤمنان", 24: "نور", 25: "جداکنندهٔ حق از باطل",
    26: "شاعران", 27: "مورچه", 28: "داستان‌ها", 29: "عنکبوت", 30: "روم",
    31: "لقمان", 32: "سجده", 33: "احزاب", 34: "سبأ", 35: "آفریننده",
    36: "یس", 37: "صف‌بستگان", 38: "ص", 39: "گروه‌ها", 40: "آمرزنده",
    41: "شرح داده‌شده", 42: "مشورت", 43: "زر و زیور", 44: "دود", 45: "به‌زانودرآمده",
    46: "ریگزارها", 47: "محمد", 48: "پیروزی", 49: "حجره‌ها", 50: "ق",
    51: "بادهای پراکنده‌کننده", 52: "کوه طور", 53: "ستاره", 54: "ماه", 55: "بخشنده",
    56: "واقعهٔ قطعی", 57: "آهن", 58: "زن مجادله‌کننده", 59: "تبعید", 60: "زن آزموده‌شده",
    61: "صف", 62: "جمعه", 63: "منافقان", 64: "مغبون‌شدن متقابل", 65: "طلاق",
    66: "تحریم", 67: "فرمانروایی", 68: "قلم", 69: "واقعهٔ حتمی", 70: "راه‌های صعود",
    71: "نوح", 72: "جن", 73: "جامه‌به‌خودپیچیده", 74: "جامه‌به‌خودپوشیده", 75: "قیامت",
    76: "انسان", 77: "فرستادگان", 78: "خبر بزرگ", 79: "برکَنندگان", 80: "چهره درهم کشید",
    81: "درهم‌پیچیدن خورشید", 82: "شکافتن آسمان", 83: "کم‌فروشان", 84: "شکافته‌شدن آسمان",
    85: "برج‌ها", 86: "ستارهٔ شب‌رو", 87: "والاترین", 88: "فراگیرنده", 89: "سپیده‌دم",
    90: "شهر", 91: "خورشید", 92: "شب", 93: "چاشتگاه", 94: "گشایش سینه",
    95: "انجیر", 96: "خون بسته", 97: "قدر", 98: "دلیل روشن", 99: "زلزله",
    100: "اسبان دونده", 101: "کوبنده", 102: "فزون‌خواهی", 103: "عصر", 104: "بدگوی عیب‌جو",
    105: "فیل", 106: "قریش", 107: "وسایل ضروری زندگی", 108: "خیر فراوان",
    109: "کافران", 110: "یاری", 111: "لیف خرما", 112: "اخلاص", 113: "سپیده‌دم",
    114: "مردم",
}


def main():
    path = "assets/quran_full.json"
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    assert len(MEANINGS_FA) == 114, f"expected 114 entries, got {len(MEANINGS_FA)}"

    changed = 0
    for surah in data["surahs"]:
        n = surah["number"]
        fa = MEANINGS_FA.get(n)
        if fa is None:
            print(f"  !! no Persian meaning for surah {n}, leaving as-is")
            continue
        if surah.get("meaning") != fa:
            surah["meaning"] = fa
            changed += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    print(f"wrote {path}: {changed} surah meanings updated to Persian")


if __name__ == "__main__":
    main()
