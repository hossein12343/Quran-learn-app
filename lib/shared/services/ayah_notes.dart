import 'store/local_store.dart';

/// A private reflection attached to one ayah — distinct from a
/// bookmark (a star, no content) or a share (someone else's copy of
/// the text). Deliberately **device-local, not synced** through
/// Supabase the way bookmarks/progress are: this app already has a
/// real sync pipeline (see `AppState`'s `_pullBookmarks`/
/// `toggleBookmark`), but wiring a whole second synced table+RLS
/// policy+pull/push cycle for a feature this small wasn't worth the
/// added surface — a device-local note that survives reloads (see
/// `LocalStore`) covers the actual need ("what did I think about this
/// ayah") without it. Revisit if cross-device notes are ever
/// specifically asked for.
abstract class AyahNotes {
  static const _prefix = 'ayah_note:';

  static String _key(int surah, int ayah) => '$_prefix$surah:$ayah';

  static String? get(int surah, int ayah) => LocalStore.get(_key(surah, ayah));

  static bool has(int surah, int ayah) => get(surah, ayah) != null;

  /// An empty/whitespace-only [text] deletes the note rather than
  /// storing a blank one — the UI's "save" and "clear" actions both
  /// just call this.
  static void set(int surah, int ayah, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      LocalStore.remove(_key(surah, ayah));
    } else {
      LocalStore.set(_key(surah, ayah), trimmed);
    }
  }
}
