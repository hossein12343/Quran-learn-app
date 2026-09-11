/// A thin cache layer over recitation audio, so a surah downloaded once
/// plays back with no network — real offline use, not just "the app shell
/// loads while offline." Backed by the browser's Cache Storage API on web
/// (see `offline_audio_impl/offline_audio_factory_web.dart`); a no-op
/// stub everywhere else.
///
/// Deliberately dumb: this only knows "is this exact clip URL cached",
/// "cache it", "drop it", and "give me the best URL to actually play". The
/// surah-level workflow (loop every ayah, track progress, remember which
/// surahs are downloaded) lives in the reader UI that actually needs it —
/// see `quran_page.dart`'s `SurahReaderPage`.
abstract class OfflineAudio {
  /// False off-web, or if this browser has no Cache Storage API at all.
  bool get available;

  Future<bool> isCached(String url);

  /// Downloads [url] and stores it. Returns whether it succeeded — a
  /// failed fetch (offline, 404, ...) leaves nothing cached rather than
  /// half-writing a broken entry.
  Future<bool> cache(String url);

  Future<void> uncache(String url);

  /// The best URL to actually set as an `<audio>` element's `src`: an
  /// object: URL backed by the cached blob if [url] was downloaded,
  /// otherwise [url] itself, unchanged. Never throws — falls back to the
  /// live URL on any error, same as an uncached clip always did.
  Future<String> resolve(String url);
}

class NoOfflineAudio implements OfflineAudio {
  const NoOfflineAudio();

  @override
  bool get available => false;

  @override
  Future<bool> isCached(String url) async => false;

  @override
  Future<bool> cache(String url) async => false;

  @override
  Future<void> uncache(String url) async {}

  @override
  Future<String> resolve(String url) async => url;
}

/// Real Cache Storage on web, the no-op stub everywhere else. Set once in
/// main().
OfflineAudio offlineAudio = const NoOfflineAudio();
