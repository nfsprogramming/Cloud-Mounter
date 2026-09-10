import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeychainService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
    mOptions: MacOsOptions(),
  );

  static String _credKey(String connId) => 'cloudmounter_cred_$connId';
  static String _cryptKey(String connId) => 'cloudmounter_crypt_$connId';

  /// Store credentials JSON string for a connection
  static Future<void> storeCredentials(String connId, String credentialsJson) async {
    await _storage.write(key: _credKey(connId), value: credentialsJson);
  }

  /// Retrieve credentials JSON string for a connection
  static Future<String?> getCredentials(String connId) async {
    return _storage.read(key: _credKey(connId));
  }

  /// Delete credentials for a connection
  static Future<void> deleteCredentials(String connId) async {
    await _storage.delete(key: _credKey(connId));
  }

  /// Store encryption password for a connection
  static Future<void> storeCryptPassword(String connId, String password) async {
    await _storage.write(key: _cryptKey(connId), value: password);
  }

  /// Retrieve encryption password for a connection
  static Future<String?> getCryptPassword(String connId) async {
    return _storage.read(key: _cryptKey(connId));
  }

  /// Delete encryption password for a connection
  static Future<void> deleteCryptPassword(String connId) async {
    await _storage.delete(key: _cryptKey(connId));
  }

  /// Delete all data for a connection
  static Future<void> deleteAll(String connId) async {
    await Future.wait([
      deleteCredentials(connId),
      deleteCryptPassword(connId),
    ]);
  }
}
