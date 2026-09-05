/// Short synthesized feedback tones — the correct-answer "ding", the soft
/// wrong-answer buzz, the level-seal fanfare. Same reasoning as
/// `audio.dart`'s `RecitationPlayer`: this is an interface plus a no-op
/// implementation on purpose, because Flutter's SDK has no audio playback
/// of its own and a real *audio file* player needs a pub.dev package this
/// machine can't fetch. The difference here is these are tones, not
/// recordings — synthesized on the fly from a couple of oscillator nodes
/// via `dart:web_audio`, a real browser SDK library (not a pub.dev
/// package, same footing as the `dart:html` the recitation player already
/// uses), so no audio *file* is needed either. Every screen talks to
/// `sfx` only, so swapping in real sample-based sounds later is one new
/// file and one line in main() — see `audio_impl/audio_factory.dart` for
/// the established shape of that swap.
abstract class SoundEffects {
  /// Whether real audio is wired up (false off-web, where this stays a
  /// silent no-op).
  bool get available;

  /// A quick, bright two-note "ding" for a correct answer — fires
  /// constantly (after nearly every exercise), so it has to stay short
  /// and pleasant rather than draw attention to itself.
  void right();

  /// A short, soft low tone for a wrong answer — deliberately gentle,
  /// not a harsh buzzer; getting an answer wrong already stings a little.
  void wrong();

  /// A bigger ascending fanfare for sealing a level or surah — the one
  /// moment that's allowed to sound like an actual accomplishment.
  void seal();

  /// Pays whatever one-time setup cost the real implementation has (on
  /// web: constructing the `AudioContext`, a documented source of a
  /// multi-second stall the first time a page does it) as early and as
  /// far from any actual quiz moment as possible. No-op off-web. Call
  /// once, from a real early user gesture — see `main.dart`.
  void warmUp();
}

class SilentSoundEffects implements SoundEffects {
  const SilentSoundEffects();

  @override
  bool get available => false;

  @override
  void right() {}

  @override
  void wrong() {}

  @override
  void seal() {}

  @override
  void warmUp() {}
}

/// Real synthesized tones on web, the silent stub everywhere else. Set
/// once in main().
SoundEffects sfx = const SilentSoundEffects();
