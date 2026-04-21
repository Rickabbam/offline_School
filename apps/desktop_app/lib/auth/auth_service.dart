import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import 'token_storage.dart';

/// Model of the currently authenticated user.
class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? tenantId;
  final String? schoolId;
  final String? campusId;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.tenantId,
    this.schoolId,
    this.campusId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        tenantId: json['tenantId'] as String?,
        schoolId: json['schoolId'] as String?,
        campusId: json['campusId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'role': role,
        'tenantId': tenantId,
        'schoolId': schoolId,
        'campusId': campusId,
      };
}

enum AuthState { unknown, authenticated, unauthenticated }

/// Handles online JWT login, token refresh, and offline device-token login.
///
/// On startup, [initialise] checks for a stored token.
/// The rest of the app reads [currentUser] and [state] to decide what to show.
class AuthService {
  AuthService({String? backendBaseUrl})
      : _baseUrl = backendBaseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://localhost:3000',
            );

  final String _baseUrl;
  final _storage = TokenStorage();
  final _logger = Logger();
  final _uuid = const Uuid();

  late final Dio _dio;

  AuthUser? _currentUser;
  AuthState _state = AuthState.unknown;

  AuthUser? get currentUser => _currentUser;
  AuthState get state => _state;
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// Call once at app startup. Attempts to restore session from stored tokens.
  Future<void> initialise() async {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final userJson = await _storage.getUserJson();
    if (userJson == null) {
      _state = AuthState.unauthenticated;
      return;
    }

    final accessToken = await _storage.getAccessToken();
    if (accessToken != null) {
      _currentUser = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _state = AuthState.authenticated;
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      return;
    }

    // Try refresh token if access token missing.
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _refreshOnline(refreshToken);
        return;
      } catch (_) {
        _logger.w('Refresh failed on startup, falling back to offline token.');
      }
    }

    // Try offline device token.
    final offlineToken = await _storage.getOfflineToken();
    final fingerprint = await _storage.getDeviceFingerprint();
    if (offlineToken != null && fingerprint != null) {
      _currentUser = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _state = AuthState.authenticated;
      _logger.i('Authenticated offline via device token.');
      return;
    }

    _state = AuthState.unauthenticated;
  }

  /// Online email + password login.
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data!;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.saveAccessToken(data['accessToken'] as String);
    await _storage.saveRefreshToken(data['refreshToken'] as String);
    await _storage.saveUserJson(jsonEncode(user.toJson()));

    _dio.options.headers['Authorization'] = 'Bearer ${data['accessToken']}';
    _currentUser = user;
    _state = AuthState.authenticated;

    return user;
  }

  /// Register this device for offline trusted-device login.
  /// Must be called after a successful online login.
  Future<String> registerDevice(String deviceName) async {
    var fingerprint = await _storage.getDeviceFingerprint();
    if (fingerprint == null) {
      fingerprint = _uuid.v4();
      await _storage.saveDeviceFingerprint(fingerprint);
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register-device',
      data: {'deviceName': deviceName, 'deviceFingerprint': fingerprint},
    );

    final offlineToken = response.data!['offlineToken'] as String;
    await _storage.saveOfflineToken(offlineToken);
    _logger.i('Device registered for offline access.');
    return offlineToken;
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _currentUser = null;
    _state = AuthState.unauthenticated;
  }

  Future<void> _refreshOnline(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data!;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.saveAccessToken(data['accessToken'] as String);
    await _storage.saveRefreshToken(data['refreshToken'] as String);
    await _storage.saveUserJson(jsonEncode(user.toJson()));

    _dio.options.headers['Authorization'] = 'Bearer ${data['accessToken']}';
    _currentUser = user;
    _state = AuthState.authenticated;
  }
}
