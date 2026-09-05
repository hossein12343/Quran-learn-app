class LocalStore {
  static final Map<String, String> _mem = <String, String>{};
  static String? get(String key) => _mem[key];
  static void set(String key, String value) => _mem[key] = value;
  static void remove(String key) => _mem.remove(key);
}
