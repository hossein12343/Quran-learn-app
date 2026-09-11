"""One-time content fetch: pulls the full Qur'an from Al Quran Cloud's
`quran-tajweed` edition (Uthmani text with tajweed rules embedded as inline
bracket markup, e.g. `مَ[f:1375[ن ذ]َا`) and writes a trimmed version —
just surah/ayah numbers and the raw marked-up text, matching this app's own
ayah numbering (`numberInSurah`, not the API's global ayah id) — to
assets/quran_tajweed.json.

Not run by the app itself — this is how assets/quran_tajweed.json was
produced. Re-run only if the source data needs refreshing.

Source: https://alquran.cloud/api (free, no key). Text attribution to
Tanzil is requested by their terms — see the About page's tajweed card.
"""
import json
import urllib.request

URL = "https://api.alquran.cloud/v1/quran/quran-tajweed"


def main():
    req = urllib.request.Request(URL, headers={"User-Agent": "curl/8.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read().decode())

    surahs = []
    for s in data["data"]["surahs"]:
        ayat = [
            {"number": a["numberInSurah"], "text": a["text"]}
            for a in s["ayahs"]
        ]
        surahs.append({"number": s["number"], "ayat": ayat})
        print(f"  {s['number']:>3} {s['englishName']:<24} {len(ayat)} ayat")

    out_path = "assets/quran_tajweed.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"surahs": surahs}, f, ensure_ascii=False)
    total_ayat = sum(len(s["ayat"]) for s in surahs)
    print(f"wrote {out_path}: {len(surahs)} surahs, {total_ayat} ayat")


if __name__ == "__main__":
    main()
