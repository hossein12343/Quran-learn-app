"""One-time content fetch: pulls the full Hisnul Muslim ("Fortress of
the Muslim") collection of everyday duas and adhkar from
hisnmuslim.com's public JSON API and writes assets/quran_duas.json.

hisnmuslim.com only serves "en" and "ar" — no Farsi variant exists
(every other language code tried came back 404), so this content is
English-only, same constraint that pushed the tafsir feature toward
English too. 132 chapters total (1..132, confirmed by probing until
404 — this matches the well-known printed book's own chapter count,
a useful independent sanity check that nothing was mis-numbered).

Each chapter's JSON has exactly one top-level key (the chapter's own
English title) mapping to a list of dua entries — that odd shape is
flattened here into {number, title, duas: [...]}. The API's own AUDIO
field is an http:// URL; upgraded to https:// here since the same
server answers correctly on https and the app itself is served over
https (a live http:// audio fetch from an https:// page is mixed
content and gets silently blocked by the browser).

Not run by the app itself — this is how assets/quran_duas.json was
produced. Re-run only if the source data needs refreshing.
"""
import json
import sys
import time
import urllib.request

# Windows' console defaults to cp1252, which can't print every
# character some chapter titles carry (mid-run crash hit this on a
# stray Arabic diacritic) — force UTF-8 output instead of guessing
# which titles are "safe".
sys.stdout.reconfigure(encoding="utf-8")

BASE = "https://www.hisnmuslim.com/api/en"


def get(chapter):
    url = f"{BASE}/{chapter}.json"
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        # A UTF-8 BOM precedes every response body on this API, and at
        # least one chapter's text embeds a raw control character
        # inside a JSON string (invalid per strict JSON, tolerated
        # here rather than trying to guess which chapter and patch it).
        raw = resp.read().decode("utf-8-sig")
        return json.loads(raw, strict=False)


def main():
    chapters = []
    skipped = []
    n = 1
    while True:
        try:
            data = get(n)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                break
            raise
        except json.JSONDecodeError as e:
            # This API's JSON is inconsistently malformed across
            # different chapters (hit two different kinds of breakage
            # on two different chapters during development — looks
            # like naive string templating on the server side, not one
            # isolated quirk). Skipping a broken chapter loses some
            # content but keeps the other 130+ usable; aborting the
            # whole fetch over one bad chapter would lose all of it.
            print(f"  {n:>3} SKIPPED — malformed JSON ({e})")
            skipped.append(n)
            n += 1
            time.sleep(0.1)
            continue
        title = next(iter(data.keys()))
        # The Arabic-text key isn't even consistently named across
        # chapters — every other one uses "ARABIC_TEXT", chapter 132
        # uses plain "Text" instead. Skipping an individual entry with
        # neither (rather than crashing) rather than assuming they're
        # interchangeable everywhere.
        duas = []
        for d in data[title]:
            arabic = (d.get("ARABIC_TEXT") or d.get("Text") or "").strip()
            if not arabic:
                continue
            duas.append({
                "arabic": arabic,
                "transliteration": d.get(
                    "LANGUAGE_ARABIC_TRANSLATED_TEXT", "").strip(),
                "translation": d.get("TRANSLATED_TEXT", "").strip(),
                "repeat": d.get("REPEAT", 1),
                "audio": (d.get("AUDIO") or "").replace(
                    "http://", "https://", 1),
            })
        chapters.append({"number": n, "title": title.strip(), "duas": duas})
        print(f"  {n:>3} {title[:50]:<50} {len(duas)} duas")
        n += 1
        time.sleep(0.1)

    out_path = "assets/quran_duas.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"chapters": chapters}, f, ensure_ascii=False)
    total_duas = sum(len(c["duas"]) for c in chapters)
    print(f"wrote {out_path}: {len(chapters)} chapters, {total_duas} duas")
    if skipped:
        print(f"skipped {len(skipped)} chapter(s) with malformed source "
              f"JSON: {skipped}")


if __name__ == "__main__":
    main()
