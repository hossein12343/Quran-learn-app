import 'dart:convert';
import 'dart:io';

class LocalStore {
  static Map<String, String>? _cache;

  static File _file() {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory('$base/QuranLearnApp');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/store.json');
  }

  static Map<String, String> _load() {
    if (_cache != null) return _cache!;
    try {
      final f = _file();
      if (f.existsSync()) {
        final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        _cache = raw.map((k, v) => MapEntry(k, v.toString()));
        return _cache!;
      }
    } on Object {
      // Corrupt or unreadable store — start fresh rather than crash.
    }
    _cache = <String, String>{};
    return _cache!;
  }

  static void _save() {
    try {
      _file().writeAsStringSync(jsonEncode(_cache));
    } on Object {
      // Best-effort persistence; nothing to do if the disk write fails.
    }
  }

  static String? get(String key) => _load()[key];

  static void set(String key, String value) {
    _load()[key] = value;
    _save();
  }

  static void remove(String key) {
    _load().remove(key);
    _save();
  }
}
