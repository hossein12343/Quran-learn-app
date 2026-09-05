# Backend, APIs and auth

Everything the app needs from a server, what each feature depends on, and the
order to build it in.

## What's actually built now (read this first)

The plan below was written when nothing had a real backend yet. Since then:

- **Auth + sync is real**, via **PocketBase** running locally (`../backend/`),
  not Supabase — pub.dev is still unreachable from this machine (see §0), so
  there is no `supabase_flutter` package to install. PocketBase is one
  executable with auth, a database and realtime built in, so it needs no
  cloud account. `lib/shared/services/backend.dart` talks to it over plain
  HTTP (no `pocketbase` or `http` package either — see `lib/shared/services/net/`).
  Every call is try/caught and falls back to local-only mode if the server
  isn't running.
- **Settings and session persist across reloads now**, via
  `lib/shared/services/store/local_store.dart` (browser `localStorage` on
  web, a JSON file on desktop). This didn't exist in the plan below at all.
- **Reciters are real, verified everyayah.com folders** (Alafasy, Al-Husary,
  Abdul Basit, As-Sudais), not placeholders.
- **Audio playback is real on the web build**, via the browser's own
  `<audio>` element (`lib/shared/services/audio_impl/audio_factory_web.dart`)
  streaming from everyayah.com — no `just_audio` needed for that platform.
  Desktop still uses the silent stub, §5 below still applies there.
- **New:** bookmarks, a "memorised ayat" screen, and a client-computed
  achievements screen — none of these needed a package.

See `../backend/README.md` for how to run/reset PocketBase and what its
schema looks like. Everything else below — §0 (pub.dev), §4 (content API),
§6 (recite-aloud), §7's remaining rows (notifications, offline sync, friends,
full 114-surah import) — is still exactly as written: not built, and still
the right plan for building it.

---

## 0. Before anything else: fix pub.dev

Your machine is getting `Insufficient permissions to the resource at the
https://pub.dev package repository` on a package that requires no auth at all.
That is not a project problem. Until it is fixed, **no feature below that
needs a package can be built** — audio, microphone, notifications, Supabase,
and offline storage all need packages.

Try in order:

```powershell
dart pub token remove https://pub.dev
Remove-Item "$env:APPDATA\dart\pub-credentials.json" -ErrorAction SilentlyContinue
flutter pub get
```

If that fails, it is network-level. Open https://pub.dev in Chrome. If the
site itself does not load, something between you and pub.dev is blocking it —
a VPN, a corporate proxy, or a regional block. Two ways around it:

```powershell
# Route through a mirror
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
flutter pub get
```

Or set `HTTP_PROXY` / `HTTPS_PROXY` if you are behind a proxy. Verify with
`dart pub global list` before continuing.

---

## 1. Why Chrome felt laggy

Three causes, in order of size.

**Debug mode.** `flutter run -d chrome` builds an unoptimised debug bundle.
Dart is compiled to JavaScript with every assertion and service extension
live, and it is genuinely 5–20× slower than a release build. This alone
accounts for most of what you saw. To judge real performance:

```bash
flutter run -d chrome --profile     # real speed, keeps the profiler
flutter build web --release         # what users actually get
```

**A real bug in my code, now fixed.** The home screen listened to the scroll
controller and called `setState` on every scroll frame. That rebuilt the
entire page — two gradient cards, two `CustomPaint` rings, every shadow and
every animated counter — sixty times a second. It now writes the offset into a
`ValueNotifier` and only the header rebuilds. This was the biggest avoidable
cost.

**Blurred shadows.** Each `BoxShadow` with a `blurRadius` is a separate raster
pass on the web canvas. Cards had two shadows each; a list of twenty was forty
blur passes per frame. Now one shadow each, and the heavy cards are wrapped in
`RepaintBoundary` so they do not repaint when neighbours change.

If it is still not smooth in profile mode, the next lever is the renderer:

```bash
flutter run -d chrome --profile --web-renderer canvaskit
```

CanvasKit gives consistent, fast rendering and correct Arabic shaping, at the
cost of about a 2 MB one-time download. The HTML renderer starts faster but
handles complex text and blur worse. For an Arabic-heavy app, CanvasKit is
usually the right trade.

---

## 2. Auth

Use Supabase Auth with **email plus password**, which is what you settled on
after dropping Google sign-in.

```yaml
dependencies:
  supabase_flutter: ^2.5.0
```

```dart
await Supabase.initialize(
  url: 'https://YOUR-PROJECT.supabase.co',
  anonKey: 'YOUR-ANON-KEY',
);
```

The anon key is safe in the client — it is public by design, and Row Level
Security is what actually protects data. The **service role key must never be
in the app**; it bypasses RLS entirely.

Flows you need:

| Flow | Call |
|---|---|
| Sign up | `auth.signUp(email:, password:)` |
| Sign in | `auth.signInWithPassword(email:, password:)` |
| Sign out | `auth.signOut()` |
| Reset password | `auth.resetPasswordForEmail(email)` |
| Session changes | `auth.onAuthStateChange` stream |

**Email verification.** Turn it on in Authentication → Providers → Email. The
user gets a link; until they click it `session.user.emailConfirmedAt` is null.
Gate the app on that, and give them a "resend" button — this is the single
most common place a sign-up flow silently dies.

**Session persistence** is automatic in `supabase_flutter`; it stores the
refresh token and restores on launch. Your splash should await
`Supabase.instance.client.auth.currentSession` before deciding which route to
show, or users see the login screen flash on every cold start.

In this build, replace the body of `AppState.signIn` / `signOut` in
`lib/shared/services/app_state.dart`. No screen touches auth directly.

---

## 3. Database

Postgres via Supabase. Your original 18-table schema was sound; these are the
tables that matter for the features you asked about.

```sql
-- Profile row, one per auth user
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  daily_goal_minutes int default 10,
  qari_id text default 'parhizgar',
  playback_speed numeric default 1.0,
  learn_mode text default 'ayah',      -- ayah | page | surah
  language text default 'en',
  total_xp int default 0,
  current_streak int default 0,
  longest_streak int default 0,
  last_active_date date,
  created_at timestamptz default now()
);

-- The memorisation state the engine produces
create table ayah_memory (
  user_id uuid references profiles(id) on delete cascade,
  surah int not null,
  ayah int not null,
  drills_cleared int default 0,        -- 0..3
  held boolean default false,
  lapses int default 0,
  clean_recalls int default 0,
  last_reviewed timestamptz,
  next_due date,                       -- spaced repetition
  primary key (user_id, surah, ayah)
);

create table surah_state (
  user_id uuid references profiles(id) on delete cascade,
  surah int not null,
  sealed boolean default false,
  sealed_at timestamptz,
  primary key (user_id, surah)
);

-- Friends and racing
create table friendships (
  requester uuid references profiles(id) on delete cascade,
  addressee uuid references profiles(id) on delete cascade,
  status text default 'pending',       -- pending | accepted | blocked
  created_at timestamptz default now(),
  primary key (requester, addressee)
);

create table achievements (
  key text primary key,
  name text not null,
  description text,
  criteria jsonb                       -- {"type":"streak","value":7}
);

create table user_achievements (
  user_id uuid references profiles(id) on delete cascade,
  achievement_key text references achievements(key),
  unlocked_at timestamptz default now(),
  primary key (user_id, achievement_key)
);

-- Recite-aloud attempts
create table recitation_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  surah int, ayah int,
  score numeric,                       -- 0..1
  transcript text,
  audio_path text,                     -- Storage key, nullable
  created_at timestamptz default now()
);
```

### Row Level Security

Turn RLS on for every user table. Without it your anon key reads everyone's
data.

```sql
alter table profiles enable row level security;
alter table ayah_memory enable row level security;
alter table surah_state enable row level security;

create policy "own profile" on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "own memory" on ayah_memory
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

For friends, you need a **read** policy that lets accepted friends see a
limited view. Do not open `profiles` to friends — expose a view instead:

```sql
create view friend_progress as
  select p.id, p.display_name, p.total_xp, p.current_streak,
         (select count(*) from ayah_memory m
           where m.user_id = p.id and m.held) as ayat_held
  from profiles p;
```

Then policy that view on "there exists an accepted friendship between
`auth.uid()` and `p.id`". This is what makes racing possible without leaking
email addresses.

### Sync strategy

Do not write to the database on every answer — that is a request per tap.
Batch at session end. `Session` already holds everything needed:

```dart
await supabase.from('ayah_memory').upsert(
  session.items.map((i) => {
    'user_id': uid,
    'surah': surah.number,
    'ayah': surah.ayat[i.index].number,
    'drills_cleared': i.cleared.length,
    'held': i.held,
    'lapses': i.lapses,
    'last_reviewed': DateTime.now().toIso8601String(),
  }).toList(),
);
```

Streaks belong in a Postgres function, not the client — a client-side streak
is trivially cheatable by changing the device clock.

---

## 4. Qur'an content API

**Quran.com API v4**, base `https://api.quran.com/api/v4`. Free, and the text
is scholar-verified, which matters more than convenience here.

| Need | Endpoint |
|---|---|
| All 114 surahs | `/chapters?language=en` |
| Ayat of a surah | `/verses/by_chapter/{n}?fields=text_uthmani` |
| **A mushaf page** | `/verses/by_page/{1..604}` |
| Translations available | `/resources/translations` |
| **Reciters available** | `/resources/recitations` |
| Per-ayah audio for a reciter | `/recitations/{id}/by_chapter/{n}` |
| Whole-chapter audio file | `/chapter_recitations/{id}/{chapter}` |

Two things worth stressing:

**Page-by-page needs `/verses/by_page/`.** Mushaf page boundaries are not
derivable from surah and ayah numbers — they are a property of the printed
Madani mushaf. Fetch them; do not compute them. Cache the 604 page→ayah
mappings once and you never call it again.

**Get reciter ids from `/resources/recitations` at runtime.** The ids in
`settings.dart` are placeholders matched to reciter *names*. Fetch the list,
match on name, store the real id. Hardcoding ids from memory plays the wrong
reciter, which for a Qur'an app is a serious defect.

Import once into your own `surahs` / `verses` / `translations` tables rather
than calling the API at runtime — you already built that importer. Attribution
requirements are in Quran.com's terms; honour them.

---

## 5. Audio: qaris and playback speed

```yaml
dependencies:
  just_audio: ^0.9.36
  audio_session: ^0.1.18
```

`just_audio` gives you `setSpeed()` natively, which is exactly what the speed
control needs. Implement `RecitationPlayer` in
`lib/shared/services/audio.dart` — the interface is already written and every
screen already calls it:

```dart
class JustAudioPlayer implements RecitationPlayer {
  final _player = AudioPlayer();
  @override bool get available => true;

  @override
  Future<void> play({required int surah, required int ayah,
      required String qariId, double speed = 1.0}) async {
    await _player.setUrl(urlFor(qariId, surah, ayah));
    await _player.setSpeed(speed);
    await _player.play();
  }
}
```

Then `recitation = JustAudioPlayer();` in `main()`. Nothing else changes.

**Sources.** Two work: the Quran.com audio endpoints above, or everyayah.com,
whose layout is `{base}/{reciterFolder}/{surah}{ayah}.mp3` with both numbers
zero-padded to three digits. Read the reciter folder names off the source —
they are not guessable.

**Caching matters.** A full mushaf of one reciter is roughly 1–2 GB. Never
bundle it. Stream, cache what the user has actually studied, and let them
delete a reciter's cache from settings. `just_audio_cache` or a manual
`path_provider` cache both work.

**Licensing is your responsibility.** Recitation recordings are performances
with rights holders. Free-to-stream is not the same as free-to-redistribute in
your app. Check before shipping — this is the kind of thing that gets an app
pulled.

---

## 6. Recite-aloud grading

The hardest feature here, and the one most likely to disappoint if rushed.

```yaml
dependencies:
  record: ^5.0.4
  permission_handler: ^11.3.0
```

**The permission prompt that never appeared in your APK** was almost certainly
a missing manifest declaration. The package alone is not enough:

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

`ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>To grade your recitation aloud.</string>
```

Then request at runtime, before recording, and handle refusal:
```dart
final status = await Permission.microphone.request();
if (!status.isGranted) { /* explain, offer openAppSettings() */ }
```

On web, `getUserMedia` requires **HTTPS or localhost** — it silently fails on
plain HTTP, which is a common source of "the mic just doesn't work".

**Grading approach.** Do not send audio to a general speech-to-text service
and compare strings — general models are trained on conversational Arabic and
will mangle Qur'anic recitation. Options, from cheapest to best:

1. **Transcribe then align.** A Whisper-class model with Arabic, then compare
   to the expected ayah. `RecitationScorer` in `recite_check.dart` already
   does the comparison — it strips diacritics (no recogniser emits them),
   normalises alif and ta-marbuta variants, and returns per-word problems.
   Testable today, no packages needed.
2. **Forced alignment.** Because you already know the expected text, align
   audio to it rather than transcribing freely. Far more accurate for this
   task.
3. **Purpose-built tajweed models.** Best results, but you are buying a
   service or training one.

Run whichever you choose in a **Supabase Edge Function**, not in the app. The
app uploads to Storage, the function transcribes and scores, and the API key
for the model never touches the client.

Be honest in the UI about what the score means. A pronunciation score that
looks authoritative but is not will make people distrust the whole app, and
for Qur'anic recitation the stakes of a wrong correction are higher than in a
language app.

---

## 7. Remaining features and what each needs

| Feature | Needs | Notes |
|---|---|---|
| Page-by-page | `/verses/by_page/` + a `pages` table | UI mode already in settings |
| Whole-surah mode | Nothing new | Already in settings |
| Friends and racing | `friendships` + the `friend_progress` view | Realtime subscription for live races |
| Achievements | `achievements` tables | Evaluate server-side in a trigger so they cannot be forged |
| Daily reminders | `flutter_local_notifications` + `timezone` | Android 13+ needs `POST_NOTIFICATIONS` at runtime |
| Offline sync | `drift` or `sqflite` + a queue | Write local first, push on reconnect, last-write-wins per ayah |
| Memorised-ayat screen | Query `ayah_memory where held` | Frame it encouragingly, as you asked |
| Language switcher | Already built | Add locales to `L10n` in `settings.dart` |

---

## 8. Suggested order

1. Fix pub.dev. Nothing else moves until this does.
2. Supabase auth + `profiles` + RLS. Get sign-up working end to end.
3. Sync `ayah_memory` at session end. Now progress survives reinstalls.
4. Import all 114 surahs, including page boundaries.
5. Audio with qari and speed. This is the biggest single jump in perceived quality.
6. Notifications and achievements — cheap, and they drive retention.
7. Friends and racing.
8. Recite-aloud grading last. It is the hardest and the easiest to get wrong.
