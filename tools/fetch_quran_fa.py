"""Replaces assets/quran_full.json's `translation` field (currently Saheeh
International / English) with a Persian translation, in place — Arabic
text and every other field are left untouched, only re-fetches translation
text per ayah.

Translation: Hussein Taji Kal Dari (api.quran.com id 29) — the app's
default English translation, Saheeh International, has no Persian
equivalent hosted there; this was the best-quality option actually
available via api.quran.com's own translation list (checked via
/resources/translations — Makarem Shirazi/Fooladvand are not hosted there).

Not run by the app itself — re-run only if the translation needs
refreshing or swapping to a different source.
"""
import json
import re
import time
import urllib.request

BASE = "https://api.quran.com/api/v4"
TRANSLATION_ID = 29  # Hussein Taji Kal Dari (Persian)


def get(path, params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    url = f"{BASE}{path}?{qs}"
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode())


def clean_translation(text):
    text = re.sub(r"<sup[^>]*>.*?</sup>", "", text)
    text = re.sub(r"<[^>]+>", "", text)
    return text.strip()


def main():
    path = "assets/quran_full.json"
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    for surah in data["surahs"]:
        n = surah["number"]
        verses_count = len(surah["ayat"])
        resp = get(
            f"/verses/by_chapter/{n}",
            {
                "translations": TRANSLATION_ID,
                "fields": "text_uthmani",
                "per_page": max(verses_count, 10),
            },
        )
        by_number = {}
        for v in resp["verses"]:
            translation = ""
            if v.get("translations"):
                translation = clean_translation(v["translations"][0]["text"])
            by_number[v["verse_number"]] = translation

        missing = 0
        for ayah in surah["ayat"]:
            t = by_number.get(ayah["number"])
            if t:
                ayah["translation"] = t
            else:
                missing += 1

        print(f"  {n:>3} {surah['englishName']:<24} {len(surah['ayat'])} ayat"
              f"{f' ({missing} missing!)' if missing else ''}")
        time.sleep(0.15)

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    print(f"wrote {path} with Persian translations")


if __name__ == "__main__":
    main()
