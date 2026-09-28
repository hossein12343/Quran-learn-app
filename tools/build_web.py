"""Release build for the web: `flutter build web --release`, then stamp the
offline cache (build/web/app_cache_sw.js) with a hash of what was built.

The stamp is what lets repeat visits load the app from the phone's saved
copy instead of asking the server for every file (see app_cache_sw.js): a
new build gets a new hash, a new cache, and the browser sees the worker
changed and picks the update up. A build that isn't stamped still works,
it just falls back to asking the network first, so forgetting this step is
slow, never stale.

Usage (from the project root):  python tools/build_web.py
"""

import hashlib
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'build' / 'web'
SW = OUT / 'app_cache_sw.js'
PLACEHOLDER = "'__BUILD__'"


def build():
    flutter = 'flutter.bat' if sys.platform == 'win32' else 'flutter'
    subprocess.run([flutter, 'build', 'web', '--release', *sys.argv[1:]],
                   cwd=ROOT, check=True)


def build_hash():
    h = hashlib.sha256()
    for f in sorted(OUT.rglob('*')):
        if f.is_file() and f != SW:
            h.update(str(f.relative_to(OUT)).replace('\\', '/').encode())
            h.update(f.read_bytes())
    return h.hexdigest()[:12]


def stamp():
    text = SW.read_text(encoding='utf-8')
    if PLACEHOLDER not in text:
        sys.exit(f'{SW} has no {PLACEHOLDER} to stamp')
    stamp_value = build_hash()
    SW.write_text(text.replace(PLACEHOLDER, f"'{stamp_value}'"),
                  encoding='utf-8', newline='\n')
    print(f'Stamped app_cache_sw.js with build {stamp_value}')


if __name__ == '__main__':
    build()
    stamp()
