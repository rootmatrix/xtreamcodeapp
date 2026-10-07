import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/catalog.dart';

class SavedCredentials {
  final String server;
  final String username;
  final String password;

  const SavedCredentials({
    required this.server,
    required this.username,
    required this.password,
  });
}

class LocalStore {
  LocalStore({
    FlutterSecureStorage? secure,
    SharedPreferences? prefs,
  })  : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _prefs = prefs;

  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveCredentials(SavedCredentials creds) async {
    await _secure.write(key: StorageKeys.server, value: creds.server);
    await _secure.write(key: StorageKeys.username, value: creds.username);
    await _secure.write(key: StorageKeys.password, value: creds.password);
  }

  Future<SavedCredentials?> readCredentials() async {
    final server = await _secure.read(key: StorageKeys.server);
    final username = await _secure.read(key: StorageKeys.username);
    final password = await _secure.read(key: StorageKeys.password);
    if (server == null ||
        username == null ||
        password == null ||
        server.isEmpty ||
        username.isEmpty) {
      return null;
    }
    return SavedCredentials(
      server: server,
      username: username,
      password: password,
    );
  }

  Future<void> clearCredentials() async {
    await _secure.delete(key: StorageKeys.server);
    await _secure.delete(key: StorageKeys.username);
    await _secure.delete(key: StorageKeys.password);
  }

  Future<List<Favorite>> readFavorites() async {
    final raw = (await _p()).getString(StorageKeys.favorites);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) => Favorite.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFavorites(List<Favorite> items) async {
    await (await _p()).setString(
      StorageKeys.favorites,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<WatchEntry>> readHistory() async {
    final raw = (await _p()).getString(StorageKeys.history);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) => WatchEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<WatchEntry> items) async {
    await (await _p()).setString(
      StorageKeys.history,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearCache() async {
    final prefs = await _p();
    await prefs.remove(StorageKeys.favorites);
    await prefs.remove(StorageKeys.history);
  }
}
