"""One-time content fetch: pulls per-word Uthmani text + Persian
word-by-word translation for every ayah from api.quran.com
(`?words=true&language=fa`) and writes assets/quran_wbw.json.

Each verse's `words` array from the API also includes one trailing
entry with char_type_name "end" (the little ayah-number marker, e.g.
"١") — not a real word, filtered out here.

Deliberately does NOT try to align these per-word Arabic tokens against
quran_seed.dart's own `arabic` field (whitespace-split there breaks on
pause marks like "ۚ"/"ۗ"/"ۖ", which the word-by-word API instead
attaches to the *preceding* word's own text_uthmani, e.g. "ٱلْقَيُّومُ
ۚ" as one token) — the word-by-word view renders straight from this
file's own `arabic` tokens instead, which are internally consistent by
construction.

Not run by the app itself — this is how assets/quran_wbw.json was
produced. Re-run only if the source data needs refreshing.
"""
import json
import time
import urllib.request

BASE = "https://api.quran.com/api/v4"


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
            f"/verses/by_chapter/{n}",
            {"words": "true", "word_fields": "text_uthmani,char_type_name",
             "language": "fa", "per_page": 300},
        )
        ayat = []
        for v in data["verses"]:
            words = [
                {"arabic": w["text_uthmani"].strip(),
                 "translation": w["translation"]["text"]}
                for w in v["words"]
                if w["char_type_name"] == "word"
            ]
            ayat.append({"number": v["verse_number"], "words": words})
        surahs.append({"number": n, "ayat": ayat})
        total_words = sum(len(a["words"]) for a in ayat)
        print(f"  {n:>3} {ch['name_simple']:<24} {len(ayat)} ayat, "
              f"{total_words} words")
        time.sleep(0.1)

    out_path = "assets/quran_wbw.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"surahs": surahs}, f, ensure_ascii=False)
    total_ayat = sum(len(s["ayat"]) for s in surahs)
    total_words = sum(len(a["words"]) for s in surahs for a in s["ayat"])
    print(f"wrote {out_path}: {len(surahs)} surahs, {total_ayat} ayat, "
          f"{total_words} words")


if __name__ == "__main__":
    main()
