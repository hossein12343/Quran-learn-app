"""One-time content fetch: pulls the standard 604-page Uthmani mushaf
pagination from api.quran.com (the same source `fetch_quran.py` already
uses for the app's text) and writes just the boundaries — which
(surah, ayah) starts each page — to assets/quran_pages.json.

Not run by the app itself — this is how assets/quran_pages.json was
produced. Re-run only if the source data needs refreshing.
"""
import json
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
    boundaries = []
    last_page = None
    for ch in chapters:
        n = ch["id"]
        verses_count = ch["verses_count"]
        data = get(
            f"/verses/by_chapter/{n}",
            {"fields": "page_number", "per_page": max(verses_count, 10)},
        )
        for v in data["verses"]:
            page = v["page_number"]
            if page != last_page:
                boundaries.append(
                    {"page": page, "surah": n, "ayah": v["verse_number"]}
                )
                last_page = page

    print(f"{len(boundaries)} page boundaries (expect 604)")
    out_path = "assets/quran_pages.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"pages": boundaries}, f, ensure_ascii=False)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
