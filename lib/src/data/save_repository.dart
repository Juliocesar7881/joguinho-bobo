import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

abstract interface class SaveStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesSaveStorage implements SaveStorage {
  PreferencesSaveStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String key = 'lexinexo.save.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(key);

  @override
  Future<void> write(String value) => _preferences.setString(key, value);
}

class SaveRepository {
  SaveRepository(this._storage);

  final SaveStorage _storage;
  Future<void> _writeQueue = Future<void>.value();

  Future<AppSave> load() async {
    try {
      final raw = await _storage.read();
      if (raw == null || raw.isEmpty) return AppSave();
      return AppSave.fromJson(jsonDecode(raw));
    } on Object {
      return AppSave();
    }
  }

  Future<void> save(AppSave save) {
    final payload = jsonEncode(save.toJson());
    final operation = _writeQueue
        .catchError((Object _) {})
        .then((_) => _storage.write(payload));
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> flush() => _writeQueue.catchError((Object _) {});
}
