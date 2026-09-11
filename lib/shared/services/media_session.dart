/// Reported to the OS/browser's own now-playing surface (a phone's lock
/// screen, a notification shade, a hardware media key) whenever real
/// audio is actually sounding — otherwise those controls have nothing
/// to show and no way to pause what's playing without switching back
/// to the tab first, which is the actual gap this fixes.
///
/// Real on web: `media_session_impl/media_session_factory_web.dart`
/// backs this with `navigator.mediaSession` — no typed `dart:html`
/// binding covers it, so it's the same hand-installed JS engine +
/// `dart:js` `JsFunction.withThis` callback pattern as
/// `share_factory_web.dart`. Off-web (and any browser without Media
/// Session support) this stays [UnavailableMediaSession] — recitation
/// still plays and pauses normally from inside the app, it just has no
/// presence outside the tab.
abstract class MediaSessionController {
  bool get available;

  /// What the system's now-playing surface shows. [artist] is used for
  /// the reciter's name — that surface has no separate slot for
  /// anything more specific, so playback speed/reciter changes just
  /// mean calling this again.
  void setMetadata({required String title, String? artist});

  /// Lets the OS-level play/pause controls actually reflect and drive
  /// playback state, instead of a lock-screen pause button doing
  /// nothing because the browser thinks nothing is "really" playing.
  void setPlaying(bool playing);

  /// Registers the callbacks the system's play/pause/stop controls
  /// invoke. Deliberately no previous/next-track handlers — those would
  /// need every playback call site (continuous reading, quiz
  /// teach-step auto-advance, the mushaf page view) to agree on what
  /// "next" means, which is a bigger change than this pass is scoped
  /// for; play/pause/stop alone already covers the actual reported
  /// gap ("can't control playback once I've locked my phone").
  void setHandlers({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onStop,
  });

  /// Clears metadata and handlers once nothing is playing, so a stale
  /// "now playing" card doesn't linger after playback genuinely ends.
  void clear();
}

class UnavailableMediaSession implements MediaSessionController {
  @override
  bool get available => false;

  @override
  void setMetadata({required String title, String? artist}) {}

  @override
  void setPlaying(bool playing) {}

  @override
  void setHandlers({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onStop,
  }) {}

  @override
  void clear() {}
}

MediaSessionController mediaSession = UnavailableMediaSession();
