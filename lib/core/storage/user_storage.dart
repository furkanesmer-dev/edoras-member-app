import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserStorage {
  static const _kUserJson = 'user_json';
  final _s = const FlutterSecureStorage();

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _s.write(key: _kUserJson, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _s.read(key: _kUserJson);
    if (raw == null || raw.isEmpty) return null;
    final obj = jsonDecode(raw);
    if (obj is Map<String, dynamic>) return obj;
    return Map<String, dynamic>.from(obj as Map);
  }

  Future<void> clear() => _s.delete(key: _kUserJson);
}