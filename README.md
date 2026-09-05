# Quran Learn

Memorise the Qur'an, ayah by ayah — five tabs (Home, Learn, Qur'an, Progress,
Profile), a level/XP/streak dashboard, a learning path that only unlocks a
surah once the one before it is sealed, and a quiz engine that will not mark
an ayah "held" until it survives three different drill types plus a final
unaided, timed, zero-mistake recall of the whole surah in order. See
`BACKEND.md` for exactly why each of those rules exists and what still needs
building.

## Run it

Two things run together: this Flutter app, and a small local backend.

```powershell
# 1. Start the backend (once, leave it running)
cd ..\backend
.\pocketbase.exe serve --http=127.0.0.1:8090

# 2. Run the app, from this folder
flutter pub get --offline   # pub.dev is unreachable from this machine; the
                             # packages you need are already in the local
                             # cache — see BACKEND.md §0 if this fails.
flutter run -d chrome
# or: flutter run -d windows
```

The app works fully without the backend running — every screen falls back
to local-only mode and nothing blocks on the network (see `AppState`). With
it running, your account, progress and bookmarks persist across reinstalls
and (eventually) other devices on the same network.

## What's here

Everything from the original build, preserved:

- Five-tab shell, onboarding, level/XP/streak dashboard, learning path
- The quiz engine's four drill types, four-lamp session, and sealing gate
  (`lib/features/quiz/quiz_engine.dart` — pure Dart, no Flutter import, so
  it's directly unit-testable)
- Qur'an reader and search, Reveal/Pressable/Shaker/GoldSweep/ProgressRing
  motion, light and dark themes, English/Persian with RTL

Added on top:

- **A real local backend** (PocketBase) for signup/login and syncing
  progress + bookmarks — see `BACKEND.md`'s new top section and
  `../backend/README.md`
- **Settings and your signed-in session now survive a reload** — previously
  every refresh reset to the login screen
- **Bookmarks** — star any ayah while reading; a dedicated Bookmarks screen
  lists them
- **A "memorised ayat" screen** — the exact ayat you're holding, surah by
  surah, framed as what you have rather than what's missing
- **Achievements** — eight milestones computed from your existing stats,
  nothing new to store
- **Real reciters** — four verified everyayah.com voices in place of the
  unverified placeholder ids, with actual audio playback on the web build
- **An Arabic text size setting**, applied in the reader and the quiz

## Tests

```powershell
flutter test
```

Covers the XP/held-ayah/sealing math and bookmark toggling in `AppState`
(`test/app_state_test.dart`) — runs on the Dart VM, no browser needed.
