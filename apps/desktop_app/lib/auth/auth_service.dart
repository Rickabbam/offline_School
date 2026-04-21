import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
class AuthService extends ChangeNotifier {
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
  Future<void>? _refreshFuture;

  AuthUser? _currentUser;
  AuthState _state = AuthState.unknown;
  bool _isOfflineSession = false;

  AuthUser? get currentUser => _currentUser;
  AuthState get state => _state;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isOfflineSession => _isOfflineSession;

  /// Call once at app startup. Attempts to restore session from stored tokens.
  Future<void> initialise() async {
    _dio = _buildDio();

    final userJson = await _storage.getUserJson();
    if (userJson == null) {
      _setUnauthenticated();
      return;
    }

    final accessToken = await _storage.getAccessToken();
    if (accessToken != null) {
      _currentUser =
          AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      _isOfflineSession = false;
      _state = AuthState.authenticated;
      notifyListeners();
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
      _currentUser =
          AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _isOfflineSession = true;
      _state = AuthState.authenticated;
      _logger.i('Authenticated offline via device token.');
      notifyListeners();
      return;
    }

    _setUnauthenticated();
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
    _setAuthenticated(user, isOfflineSession: false);

    try {
      await ensureTrustedDeviceRegistered();
    } catch (e) {
      _logger.w('Trusted-device registration failed after login: $e');
    }

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

  Future<void> ensureTrustedDeviceRegistered([String? deviceName]) async {
    final existingToken = await _storage.getOfflineToken();
    if (existingToken != null) return;

    final resolvedDeviceName = deviceName?.trim().isNotEmpty == true
        ? deviceName!.trim()
        : _defaultDeviceName();
    await registerDevice(resolvedDeviceName);
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _setUnauthenticated();
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
    _setAuthenticated(user, isOfflineSession: false);
  }

  Dio createAuthenticatedClient() {
    if (_currentUser == null) {
      throw StateError('No authenticated user available.');
    }

    final dio = _buildDio();
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_isOfflineSession) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'This action requires an online session.',
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  statusMessage: 'Offline session',
                ),
              ),
            );
            return;
          }

          final authHeader = _dio.options.headers['Authorization'];
          if (authHeader != null) {
            options.headers['Authorization'] = authHeader;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          if (statusCode != 401 || alreadyRetried || _isOfflineSession) {
            handler.next(error);
            return;
          }

          try {
            await _refreshAccessTokenIfNeeded();
            final retryOptions = Options(
              method: error.requestOptions.method,
              headers: Map<String, dynamic>.from(error.requestOptions.headers)
                ..['Authorization'] = _dio.options.headers['Authorization'],
              responseType: error.requestOptions.responseType,
              contentType: error.requestOptions.contentType,
              sendTimeout: error.requestOptions.sendTimeout,
              receiveTimeout: error.requestOptions.receiveTimeout,
              extra: Map<String, dynamic>.from(error.requestOptions.extra)
                ..['retried'] = true,
            );

            final response = await dio.request<dynamic>(
              error.requestOptions.path,
              data: error.requestOptions.data,
              queryParameters: error.requestOptions.queryParameters,
              options: retryOptions,
            );
            handler.resolve(response);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
    return dio;
  }

  AuthUser updateCurrentUserFromJson(Map<String, dynamic> json) {
    final user = AuthUser.fromJson(json);
    _storage.saveUserJson(jsonEncode(user.toJson()));
    _setAuthenticated(user, isOfflineSession: _isOfflineSession);
    return user;
  }

  Dio _buildDio() {
    return Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  String _defaultDeviceName() {
    final host = Platform.localHostname.trim();
    return host.isEmpty ? 'Offline School Desktop' : host;
  }

  Future<void> _refreshAccessTokenIfNeeded() async {
    if (_refreshFuture != null) {
      await _refreshFuture;
      return;
    }

    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      await _handleRefreshFailure();
      throw StateError('No refresh token available.');
    }

    final future = _refreshOnline(refreshToken);
    _refreshFuture = future;
    try {
      await future;
    } catch (e) {
      await _handleRefreshFailure();
      rethrow;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _handleRefreshFailure() async {
    await _storage.clearAccessToken();
    await _storage.clearRefreshToken();
    _dio.options.headers.remove('Authorization');
    _setUnauthenticated();
  }

  void _setAuthenticated(AuthUser user, {required bool isOfflineSession}) {
    _currentUser = user;
    _isOfflineSession = isOfflineSession;
    _state = AuthState.authenticated;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _currentUser = null;
    _isOfflineSession = false;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }
}
