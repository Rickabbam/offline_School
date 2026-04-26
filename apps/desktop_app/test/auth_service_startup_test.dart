import 'dart:convert';

import 'package:desktop_app/auth/auth_service.dart';
import 'package:desktop_app/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage(this._values);

  final Map<String, String> _values;

  @override
  Future<String?> getAccessToken() async => _values['accessToken'];

  @override
  Future<String?> getRefreshToken() async => _values['refreshToken'];

  @override
  Future<String?> getOfflineToken() async => _values['offlineToken'];

  @override
  Future<String?> getDeviceFingerprint() async => _values['fingerprint'];

  @override
  Future<String?> getUserJson() async => _values['userJson'];

  @override
  Future<String?> getTrustedUserJson() async => _values['trustedUserJson'];

  @override
  Future<void> saveAccessToken(String token) async {
    _values['accessToken'] = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _values['refreshToken'] = token;
  }

  @override
  Future<void> saveUserJson(String json) async {
    _values['userJson'] = json;
  }

  @override
  Future<void> saveTrustedUserJson(String json) async {
    _values['trustedUserJson'] = json;
  }

  @override
  Future<void> clearSession() async {
    _values.remove('accessToken');
    _values.remove('refreshToken');
    _values.remove('userJson');
  }

  @override
  Future<void> clearTrustedDevice() async {
    _values.remove('offlineToken');
    _values.remove('fingerprint');
    _values.remove('trustedUserJson');
  }
}

Dio _offlineDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'offline',
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  test('startup restores trusted workspace identity when backend is offline',
      () async {
    const user = AuthUser(
      id: 'user-1',
      email: 'admin@example.com',
      fullName: 'Admin User',
      role: 'admin',
      tenantId: 'tenant-1',
      schoolId: 'school-1',
      campusId: 'campus-1',
    );

    final service = AuthService(
      storage: _MemoryTokenStorage({
        'offlineToken': 'offline-token',
        'fingerprint': 'device-fingerprint',
        'trustedUserJson': jsonEncode(user.toJson()),
      }),
      dioFactory: _offlineDio,
    );

    await service.initialise();

    expect(service.state, AuthState.authenticated);
    expect(service.isOfflineSession, isTrue);
    expect(service.currentUser?.id, user.id);
    expect(service.currentUser?.tenantId, user.tenantId);
    expect(service.currentUser?.schoolId, user.schoolId);
    expect(service.currentUser?.campusId, user.campusId);
  });
}
