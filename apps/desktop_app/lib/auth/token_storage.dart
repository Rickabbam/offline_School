import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages encrypted local storage of JWT tokens and the offline device token.
/// Uses [flutter_secure_storage] which encrypts with the OS keystore on Windows.
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyOfflineToken = 'offline_token';
  static const _keyDeviceFingerprint = 'device_fingerprint';
  static const _keyUserJson = 'current_user_json';

  // ─── Access token ──────────────────────────────────────────────────────────
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _keyAccessToken, value: token);
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<void> clearAccessToken() => _storage.delete(key: _keyAccessToken);

  // ─── Refresh token ─────────────────────────────────────────────────────────
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _keyRefreshToken, value: token);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  // ─── Offline device token ──────────────────────────────────────────────────
  Future<void> saveOfflineToken(String token) =>
      _storage.write(key: _keyOfflineToken, value: token);
  Future<String?> getOfflineToken() => _storage.read(key: _keyOfflineToken);

  // ─── Device fingerprint ────────────────────────────────────────────────────
  Future<void> saveDeviceFingerprint(String fp) =>
      _storage.write(key: _keyDeviceFingerprint, value: fp);
  Future<String?> getDeviceFingerprint() =>
      _storage.read(key: _keyDeviceFingerprint);

  // ─── Current user ──────────────────────────────────────────────────────────
  Future<void> saveUserJson(String json) =>
      _storage.write(key: _keyUserJson, value: json);
  Future<String?> getUserJson() => _storage.read(key: _keyUserJson);

  /// Clear all auth state (on logout or device deregistration).
  Future<void> clearAll() => _storage.deleteAll();
}
