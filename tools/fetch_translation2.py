"""One-time content fetch: pulls a second Persian translation
(IslamHouse.com, id 135 on api.quran.com — the only other Persian
translation that API hosts besides the Hussein Taji Kal Dari one already
bundled as the default, per `fetch_quran_fa.py`) and writes it to
assets/quran_translation2.json, keyed by surah number + ayah-in-surah
number to match quran_seed.dart's own numbering.

Not run by the app itself — this is how assets/quran_translation2.json
was produced. Re-run only if the source data needs refreshing.
"""
import json
import time
import urllib.request

BASE = "https://api.quran.com/api/v4"
TRANSLATION_ID = 135  # IslamHouse.com


def get(path, params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    url = f"{BASE}{path}?{qs}"
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode())


def main():
    chapters = get("/chapters", {"language": "en"})["chapters"]
    surahs = []
    for ch in chapters:
        n = ch["id"]
        data = get(
            f"/quran/translations/{TRANSLATION_ID}", {"chapter_number": n}
        )
        ayat = [
            {"number": i + 1, "text": t["text"]}
            for i, t in enumerate(data["translations"])
        ]
        surahs.append({"number": n, "ayat": ayat})
        print(f"  {n:>3} {ch['name_simple']:<24} {len(ayat)} ayat")
        time.sleep(0.1)

    out_path = "assets/quran_translation2.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"surahs": surahs}, f, ensure_ascii=False)
    total_ayat = sum(len(s["ayat"]) for s in surahs)
    print(f"wrote {out_path}: {len(surahs)} surahs, {total_ayat} ayat")


if __name__ == "__main__":
    main()
