import 'package:flutter/material.dart';

/// Colors a tajweed rule the fixed way every printed colour-coded Tajweed
/// mushaf does — these are a recognized standard, not a design choice, so
/// they stay the same across light/dark theme rather than being run
/// through `context.borderColor`-style theme-aware tokens. Values and rule
/// mapping cross-checked against Al Quran Cloud's own published legend
/// (https://alquran.cloud/tajweed-guide) and a working open-source parser
/// for the same `quran-tajweed` edition, not guessed.
const Map<String, Color> tajweedRuleColors = <String, Color>{
  'h': Color(0xFFAAAAAA), // hamzat-ul-wasl (silent)
  'l': Color(0xFFAAAAAA), // laam shamsiyyah
  's': Color(0xFFAAAAAA), // other silent letters
  'n': Color(0xFF537FFF), // madd normal
  'p': Color(0xFF4050FF), // madd permissible
  'm': Color(0xFF000EBC), // madd necessary
  'o': Color(0xFF2144C1), // madd obligatory
  'q': Color(0xFFDD0008), // qalqalah
  'c': Color(0xFFD500B7), // ikhafa shafawi
  'f': Color(0xFF9400A8), // ikhafa
  'w': Color(0xFF58B800), // idgham shafawi
  'i': Color(0xFF26BFFD), // iqlab
  'a': Color(0xFF169777), // idgham with ghunnah
  'u': Color(0xFF169200), // idgham without ghunnah
  'd': Color(0xFFA1A1A1), // idgham mutajanisayn
  'b': Color(0xFFA1A1A1), // idgham mutaqaribayn
  'g': Color(0xFFFF7E1E), // ghunnah
};

const String _metaChars = 'hslnpmqocfwiaudbg';

/// Splits the raw tajweed text into `[`/digit/`:`-free tokens, breaking
/// wherever a meta-rule letter or a closing `]` appears — e.g.
/// `مَ[f:1375[ن ذ]َا` tokenizes to `['مَ', 'f', 'ن ذ', ']', 'َا']`. A span can
/// legitimately cover several characters (an idgham rule merges across a
/// word boundary, space included), so this is a token stream, not a
/// one-char-per-rule mapping.
List<String> _tokenize(String rawWithoutMarkerChars) {
  final tokens = <String>[];
  final buf = StringBuffer();
  for (final rune in rawWithoutMarkerChars.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == ']' || _metaChars.contains(ch)) {
      if (buf.isNotEmpty) {
        tokens.add(buf.toString());
        buf.clear();
      }
      tokens.add(ch);
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) tokens.add(buf.toString());
  return tokens;
}

final RegExp _markerChars = RegExp(r'[\[0-9:]');

/// Turns Al Quran Cloud's tajweed-edition markup into colored spans ready
/// for `Text.rich`. Plain (un-marked) text — most of any ayah — keeps
/// [style] unchanged; a marked span gets [style] with its rule's color.
/// Text with no markup at all (e.g. a fallback plain string) safely comes
/// back as a single unstyled span, so callers don't need to branch on
/// whether tajweed data was actually available for a given ayah.
List<InlineSpan> parseTajweed(String raw, TextStyle style) {
  final tokens = _tokenize(raw.replaceAll(_markerChars, ''));
  final spans = <InlineSpan>[];
  String? pendingRule;
  for (final token in tokens) {
    if (token == ']') continue;
    if (token.length == 1 && _metaChars.contains(token)) {
      pendingRule = token;
      continue;
    }
    final color = pendingRule == null ? null : tajweedRuleColors[pendingRule];
    spans.add(TextSpan(
      text: token,
      style: color == null ? style : style.copyWith(color: color),
    ));
    pendingRule = null;
  }
  return spans;
}
