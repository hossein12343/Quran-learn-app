"""One-time content fetch: pulls all 114 surahs (Uthmani Arabic text +
Saheeh International translation) from api.quran.com and writes them to
assets/quran_full.json, bundled with the app.

Not run by the app itself — this is how assets/quran_full.json was produced.
Re-run only if the source data needs refreshing.
"""
import json
import re
import time
import urllib.request

BASE = "https://api.quran.com/api/v4"
TRANSLATION_ID = 20  # Saheeh International


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
    chapters = get("/chapters", {"language": "en"})["chapters"]
    print(f"{len(chapters)} chapters")

    surahs = []
    for ch in chapters:
        n = ch["id"]
        verses_count = ch["verses_count"]
        data = get(
            f"/verses/by_chapter/{n}",
            {
                "translations": TRANSLATION_ID,
                "fields": "text_uthmani",
                "per_page": max(verses_count, 10),
            },
        )
        ayat = []
        for v in data["verses"]:
            translation = ""
            if v.get("translations"):
                translation = clean_translation(v["translations"][0]["text"])
            ayat.append(
                {
                    "number": v["verse_number"],
                    "arabic": v["text_uthmani"],
                    "translation": translation,
                }
            )
        surahs.append(
            {
                "number": n,
                "arabicName": ch["name_arabic"],
                "englishName": ch["name_simple"],
                "meaning": ch["translated_name"]["name"],
                "revelation": "Meccan" if ch["revelation_place"] == "makkah" else "Medinan",
                "ayat": ayat,
            }
        )
        print(f"  {n:>3} {ch['name_simple']:<24} {len(ayat)} ayat")
        time.sleep(0.15)

    out_path = "assets/quran_full.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"surahs": surahs}, f, ensure_ascii=False)
    total_ayat = sum(len(s["ayat"]) for s in surahs)
    print(f"wrote {out_path}: {len(surahs)} surahs, {total_ayat} ayat")


if __name__ == "__main__":
    main()
