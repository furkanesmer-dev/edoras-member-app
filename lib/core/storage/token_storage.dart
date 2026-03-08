import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _keyAccessToken = 'access_token';
  final FlutterSecureStorage _storage;

  TokenStorage(this._storage);

  Future<String?> readToken() => _storage.read(key: _keyAccessToken);

  Future<void> writeToken(String token) => _storage.write(
        key: _keyAccessToken,
        value: token,
      );

  Future<void> clear() => _storage.delete(key: _keyAccessToken);
}