"""Checks every ayah bundled in assets/quran_full.json against api.quran.com,
the source it was fetched from (tools/fetch_quran.py), character for
character.

Run before publishing any change to the Quran text:
    python tools/verify_quran_text.py

Prints each mismatch and exits non-zero if there are any. Needs network
access; the offline structural checks live in test/quran_text_test.dart.
"""
import json
import sys
import time
import urllib.request

BASE = "https://api.quran.com/api/v4"
ASSET = "assets/quran_full.json"


def get(path, params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    req = urllib.request.Request(f"{BASE}{path}?{qs}",
                                 headers={"User-Agent": "curl/8.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode())
        except OSError:
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    with open(ASSET, encoding="utf-8") as f:
        surahs = json.load(f)["surahs"]

    checked = 0
    mismatches = []
    for s in surahs:
        n = s["number"]
        data = get(f"/verses/by_chapter/{n}",
                   {"fields": "text_uthmani", "per_page": 300})
        source = {v["verse_number"]: v["text_uthmani"] for v in data["verses"]}
        if len(source) != len(s["ayat"]):
            mismatches.append((n, 0, f"{len(s['ayat'])} ayat bundled",
                               f"{len(source)} at source"))
        for a in s["ayat"]:
            checked += 1
            expected = source.get(a["number"])
            if a["arabic"] != expected:
                mismatches.append((n, a["number"], a["arabic"], expected))

    print(f"Checked {checked} ayat in {len(surahs)} surahs against api.quran.com.")
    if not mismatches:
        print("Every ayah matches the source exactly.")
        return 0
    print(f"{len(mismatches)} mismatches:")
    for n, ayah, bundled, source in mismatches[:50]:
        print(f"  {n}:{ayah}\n    bundled: {bundled}\n    source:  {source}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
