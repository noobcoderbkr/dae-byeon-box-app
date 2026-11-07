// lib/services/auth_service.dart
//
// 백엔드 인증 연동 (회원가입 / 로그인 / 토큰 저장 / 자동 갱신)
//   - POST /api/v1/auth/signup   {email, name, password}
//   - POST /api/v1/auth/login    {email, password} -> {access_token, refresh_token}
//   - POST /api/v1/auth/refresh  {refresh_token}    -> 새 토큰쌍
//   - GET  /api/v1/auth/me        (Authorization: Bearer access_token)
//
// 응답은 {"data": {...}, "request_id": "..."} 형태로 감싸져 있음.
//
// 사용 패키지: dio, flutter_secure_storage, flutter_riverpod

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_files.dart';

// ── 백엔드 API 서버 주소 ──────────────────────────────────
// 로컬 Docker 백엔드: 안드로이드 에뮬레이터에서는 10.0.2.2 로 접근
// (서버 배포 주소가 생기면 이 한 줄만 교체)
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

// ── 토큰 저장 키 ──────────────────────────────────────────
const authAccessKey = 'auth_access_token';
const authRefreshKey = 'auth_refresh_token';
const _accountIdentityKey = 'auth_account_identity';

enum AccountDeletionResult { accepted, failed }

abstract class AuthStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clearAccountData();
}

class SecureAuthStore implements AuthStore {
  const SecureAuthStore();
  static const _storage = FlutterSecureStorage();
  static const _accountKeys = <String>[
    authAccessKey,
    authRefreshKey,
    _accountIdentityKey,
    'license_number',
    'license_plate',
    'insurance_company',
    'policy_number',
    'insurance_phone',
    'insurance_cache_owner',
    'insurance_cache_company',
    'insurance_cache_phone',
    'insurance_cache_generation',
    'vehicle_type',
    'registered_device_id',
    'registered_device_name',
  ];

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> clearAccountData() async {
    for (final key in _accountKeys) {
      await _storage.delete(key: key);
    }
  }
}

class MemoryAuthStore implements AuthStore {
  MemoryAuthStore([Map<String, String>? initial])
      : values = Map<String, String>.from(initial ?? const {});

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clearAccountData() async => values.clear();
}

// ══════════════════════════════════════════════════════════
// 인증 상태
// ══════════════════════════════════════════════════════════
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? name;
  final bool isBusy;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.email,
    this.name,
    this.isBusy = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? name,
    bool? isBusy,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        email: email ?? this.email,
        name: name ?? this.name,
        isBusy: isBusy ?? this.isBusy,
        error: error,
      );
}

// ══════════════════════════════════════════════════════════
// 인증 Notifier
// ══════════════════════════════════════════════════════════
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    Dio? dio,
    AuthStore? tokenStore,
    bool restoreSession = true,
    String? initialAccessToken,
    String? initialRefreshToken,
    Future<void> Function()? cleanupLocalFiles,
    this.beforeSignOut,
  })  : _storage = tokenStore ?? const SecureAuthStore(),
        _cleanupLocalFiles = cleanupLocalFiles ?? _cleanupAppFiles,
        _accessToken = initialAccessToken,
        _refreshToken = initialRefreshToken,
        super(const AuthState()) {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
          // 4xx 도 예외로 던지지 않고 직접 처리
          validateStatus: (code) => code != null && code < 500,
        ));
    if (restoreSession) _restoreSession();
  }

  late final Dio _dio;
  final AuthStore _storage;
  final Future<void> Function() _cleanupLocalFiles;
  Future<void> Function()? beforeSignOut;

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshFuture;
  int _sessionGeneration = 0;

  String? get accessToken => _accessToken;
  int get sessionGeneration => _sessionGeneration;

  // 저장된 토큰으로 세션 복원 (앱 시작 시)
  Future<void> _restoreSession() async {
    final generation = _sessionGeneration;
    try {
      final access = await _storage.read(authAccessKey);
      final refresh = await _storage.read(authRefreshKey);
      if (!mounted || generation != _sessionGeneration) return;
      _accessToken = access;
      _refreshToken = refresh;
    } catch (_) {}

    if (_accessToken == null && _refreshToken == null) {
      await _finishSignOut();
      return;
    }
    // me 조회로 토큰 유효성 확인 (만료면 refresh 시도)
    final ok = await _fetchMe();
    if (!ok) {
      if (!mounted || generation != _sessionGeneration) return;
      final refreshed = await _refreshTokens();
      if (refreshed) {
        final restored = await _fetchMe();
        if (!restored && generation == _sessionGeneration) {
          await _finishSignOut();
        }
      }
    }
  }

  // ── 회원가입 ────────────────────────────────────────────
  Future<bool> signup({
    required String email,
    required String name,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      final res = await _dio.post('/api/v1/auth/signup', data: {
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'password': password,
      });
      if (res.statusCode == 201) {
        // 가입 성공 → 바로 로그인
        return await login(email: email, password: password);
      }
      state = state.copyWith(
        isBusy: false,
        error: _errorMessage(res, '회원가입에 실패했습니다.'),
      );
      return false;
    } catch (e) {
      debugPrint('AUTH ERROR(signup): $e');
      state = state.copyWith(isBusy: false, error: '서버에 연결할 수 없습니다.');
      return false;
    }
  }

  // ── 로그인 ──────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _sessionGeneration++;
    _refreshFuture = null;
    state = state.copyWith(isBusy: true, error: null);
    try {
      final res = await _dio.post('/api/v1/auth/login', data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      });
      if (res.statusCode == 200) {
        final data = res.data['data'] as Map<String, dynamic>;
        await _saveTokens(
          data['access_token'] as String,
          data['refresh_token'] as String,
        );
        if (!await _fetchMe()) {
          if (state.status != AuthStatus.unauthenticated) {
            await _finishSignOut();
          }
          return false;
        }
        state = state.copyWith(isBusy: false, error: null);
        return true;
      }
      state = state.copyWith(
        isBusy: false,
        error: _errorMessage(res, '이메일 또는 비밀번호를 확인해 주세요.'),
      );
      return false;
    } catch (e) {
      debugPrint('AUTH ERROR(login): $e');
      state = state.copyWith(isBusy: false, error: '서버에 연결할 수 없습니다.');
      return false;
    }
  }

  // ── 로그아웃 ────────────────────────────────────────────
  Future<void> logout() async {
    final refresh = _refreshToken;
    _sessionGeneration++;
    _refreshFuture = null;
    try {
      if (refresh != null) {
        await _dio
            .post('/api/v1/auth/logout', data: {'refresh_token': refresh});
      }
    } catch (_) {}
    await _finishSignOut();
  }

  Future<AccountDeletionResult> requestAccountDeletion(String password) async {
    final token = await validAccessToken();
    if (token == null || password.isEmpty) return AccountDeletionResult.failed;
    try {
      final response = await _dio.delete(
        '/api/v1/account',
        data: {'password': password},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 202) return AccountDeletionResult.failed;
    } catch (_) {
      return AccountDeletionResult.failed;
    }
    // The server has accepted deletion even if local cleanup fails.
    await _finishSignOut();
    return AccountDeletionResult.accepted;
  }

  // ── 내 정보 조회 (토큰 유효성 확인) ──────────────────────
  Future<bool> _fetchMe() async {
    if (_accessToken == null) return false;
    final generation = _sessionGeneration;
    final access = _accessToken!;
    final refresh = _refreshToken;
    try {
      final res = await _dio.get(
        '/api/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
      );
      if (res.statusCode == 200) {
        if (!mounted || generation != _sessionGeneration) return false;
        final user = res.data['data']['user'] as Map<String, dynamic>;
        final identity = (user['email'] as String).trim().toLowerCase();
        final previousIdentity =
            state.email ?? await _storage.read(_accountIdentityKey);
        if (previousIdentity != identity) {
          final warning = await _clearPrivateAccountData();
          if (warning != null) {
            await _finishSignOut(warning: warning);
            return false;
          }
          if (!mounted || generation != _sessionGeneration) return false;
          if (refresh != null) await _saveTokens(access, refresh);
        }
        await _storage.write(_accountIdentityKey, identity);
        if (!mounted || generation != _sessionGeneration) return false;
        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: user['email'] as String?,
          name: user['name'] as String?,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── 토큰 갱신 ───────────────────────────────────────────
  Future<bool> _refreshTokens() {
    final pending = _refreshFuture;
    if (pending != null) return pending;
    late final Future<bool> refresh;
    refresh = _performRefresh().whenComplete(() {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    });
    _refreshFuture = refresh;
    return refresh;
  }

  Future<bool> _performRefresh() async {
    final generation = _sessionGeneration;
    final refresh = _refreshToken;
    if (refresh == null) return false;
    var rejected = false;
    try {
      final res = await _dio
          .post('/api/v1/auth/refresh', data: {'refresh_token': refresh});
      if (!mounted || generation != _sessionGeneration) return false;
      if (res.statusCode == 200) {
        final data = res.data['data'] as Map<String, dynamic>;
        await _saveTokens(
          data['access_token'] as String,
          data['refresh_token'] as String,
        );
        return true;
      }
      rejected = res.statusCode == 401 || res.statusCode == 403;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      rejected = status == 401 || status == 403;
    } catch (_) {}
    if (rejected && mounted && generation == _sessionGeneration) {
      await _finishSignOut();
    }
    return false;
  }

  // Decode exp only to schedule refresh; the server still verifies the JWT.
  Future<String?> validAccessToken() async {
    final access = _accessToken;
    if (access != null && !_expiresSoon(access)) return access;
    if (access == null && _refreshToken == null) return null;
    if (!await _refreshTokens()) return null;
    return _accessToken;
  }

  bool _expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return false;
      final exp = payload['exp'];
      if (exp is! num || !exp.isFinite) return false;
      return exp <= DateTime.now().millisecondsSinceEpoch / 1000 + 30;
    } on FormatException {
      return false;
    }
  }

  // ── 토큰 저장/삭제 ──────────────────────────────────────
  Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    try {
      await _storage.write(authAccessKey, access);
      await _storage.write(authRefreshKey, refresh);
    } catch (_) {}
  }

  Future<void> _finishSignOut({String? warning}) async {
    try {
      await beforeSignOut?.call();
    } catch (_) {}
    final generation = ++_sessionGeneration;
    _refreshFuture = null;
    _accessToken = null;
    _refreshToken = null;
    final cleanupWarning = await _clearPrivateAccountData();
    if (mounted && generation == _sessionGeneration) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: warning ?? cleanupWarning,
      );
    }
  }

  Future<String?> _clearPrivateAccountData() async {
    var failed = false;
    try {
      await _storage.clearAccountData();
    } catch (_) {
      failed = true;
      for (final key in [authAccessKey, authRefreshKey, _accountIdentityKey]) {
        try {
          await _storage.delete(key);
        } catch (_) {}
      }
    }
    try {
      await _cleanupLocalFiles();
    } catch (_) {
      failed = true;
    }
    return failed ? '일부 로컬 데이터 정리에 실패했습니다. 기기에 남은 데이터를 확인해 주세요.' : null;
  }

  static Future<void> _cleanupAppFiles() async {
    await cleanupAllAppOwnedLocalFiles();
  }

  String _errorMessage(Response res, String fallback) {
    try {
      final err = res.data['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
      final msg = res.data['message'];
      if (msg is String) return msg;
    } catch (_) {}
    return fallback;
  }
}

// ── Provider ──────────────────────────────────────────────
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
