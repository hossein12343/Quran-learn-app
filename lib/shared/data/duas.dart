import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// One dua/dhikr — Arabic text, a Latin transliteration, an English
/// meaning (see `tools/fetch_duas.py` — hisnmuslim.com has no Farsi
/// variant, same constraint as the tafsir feature), how many times it
/// is traditionally repeated, and an optional recitation clip.
class Dua {
  final String arabic;
  final String transliteration;
  final String translation;
  final int repeat;
  final String audio;

  const Dua({
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.repeat,
    required this.audio,
  });
}

class DuaChapter {
  final int number;
  final String title;
  final List<Dua> duas;

  const DuaChapter(
      {required this.number, required this.title, required this.duas});
}

List<DuaChapter> duaChapters = [];

bool duasLoaded = false;

/// Loaded lazily on first visit to the duas screen — a reference
/// collection most sessions open occasionally, not core reading data
/// needed at splash.
Future<void> loadDuas() async {
  if (duasLoaded) return;
  try {
    final raw = await rootBundle.loadString('assets/quran_duas.json');
    duaChapters = await compute(_parseDuasJson, raw);
    duasLoaded = true;
  } on Object {
    // Asset missing or malformed — the screen just shows an empty
    // state rather than crashing.
  }
}

List<DuaChapter> _parseDuasJson(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final c in data['chapters'] as List)
      DuaChapter(
        number: (c as Map<String, dynamic>)['number'] as int,
        title: c['title'] as String,
        duas: [
          for (final d in c['duas'] as List)
            Dua(
              arabic: (d as Map<String, dynamic>)['arabic'] as String,
              transliteration: d['transliteration'] as String,
              translation: d['translation'] as String,
              repeat: d['repeat'] as int,
              audio: d['audio'] as String,
            ),
        ],
      ),
  ];
}
