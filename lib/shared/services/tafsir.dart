import 'dart:convert';
import 'net/net.dart';

/// On-demand English tafsir (Qur'anic commentary) for one ayah at a
/// time — deliberately NOT bundled as a data asset like the two
/// translations or the word-by-word breakdown. Ibn Kathir's *full*
/// commentary runs to tens of thousands of characters per ayah (a
/// single fetch for Al-Fatiha's ayah 1 alone, which carries the surah's
/// whole introduction, came back at 60KB); bundling that for all 6,236
/// ayat would be tens of megabytes for content most sessions never
/// open. A per-tap fetch, cached in memory for the rest of the
/// session, fits how tafsir actually gets used — read occasionally,
/// for one specific ayah someone is curious about, not bulk-loaded
/// reading material the way a translation is.
///
/// English only: api.quran.com hosts no Persian tafsir at all (checked
/// directly against `/resources/tafsirs` — only English, Urdu, and a
/// handful of other languages, no Farsi), same constraint that pushed
/// the second-translation feature toward another Persian *translation*
/// instead of a Persian tafsir.
abstract class TafsirService {
  /// Null on any failure (offline, malformed response, ayah not
  /// covered) — the caller just shows "not available" rather than
  /// surfacing a raw network error for what's a secondary, opt-in
  /// panel.
  Future<String?> fetch(int surah, int ayah);
}

class ApiTafsirService implements TafsirService {
  // Ibn Kathir (Abridged) — chosen over the two other English options
  // api.quran.com offers (Ma'arif al-Qur'an, Tazkirul Quran) for being
  // the best-known classical tafsir in English and already trimmed to
  // "abridged," keeping individual fetches closer to ~15-20KB rather
  // than the full, much longer original.
  static const _resourceId = 169;

  final Map<String, String> _cache = {};

  @override
  Future<String?> fetch(int surah, int ayah) async {
    final key = '$surah:$ayah';
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final res = await Net.request(
        'GET',
        'https://api.quran.com/api/v4/tafsirs/$_resourceId/by_ayah/$key',
      );
      if (!res.ok) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = (data['tafsir'] as Map<String, dynamic>?)?['text'] as String?;
      if (raw == null || raw.isEmpty) return null;
      final text = htmlToPlainText(raw);
      _cache[key] = text;
      return text;
    } on Object {
      return null;
    }
  }
}

/// api.quran.com's tafsir text comes back as HTML. No HTML-rendering
/// widget exists in this app and pulling in a parser package isn't an
/// option (see BACKEND.md's pub.dev note), so this is a plain
/// tags-out-newlines-in conversion — good enough for a read-only
/// commentary panel, not meant to preserve every bit of the original
/// markup's structure.
String htmlToPlainText(String html) {
  var text = html.replaceAllMapped(
    RegExp(r'<(p|h1|h2|h3|h4|br|li)[ />]', caseSensitive: false),
    (m) => '\n${m[0]}',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  final lines =
      text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
  return lines.join('\n\n').trim();
}

TafsirService tafsirService = ApiTafsirService();
