// lib/services/device_service.dart
//
// 블랙박스 기기 등록 / 조회 (백엔드 연동)
//   - POST /api/v1/devices            기기 등록
//   - POST /api/v1/devices/link       수집 서버의 소유 기기 연결
//   - GET  /api/v1/devices            소유한 연결 기기 복원 후보 조회
//   - GET  /api/v1/devices/{id}       연결 메타데이터 조회
//   - 등록된 device_id 는 secure_storage 에 저장 (사고 생성 등에 사용)
//
// 등록 흐름:
//   앱(로그인) → POST /devices {name} → 등록된 기기 메타데이터 저장
//
// 모든 요청은 로그인 토큰이 필요하다. 응답은 {"data": {...}} envelope.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

// secure_storage 키
const _kDeviceIdKey = 'registered_device_id';
const _kDeviceNameKey = 'registered_device_name';

// 등록 결과
class DeviceRegistration {
  final String deviceId;
  final String deviceName;

  const DeviceRegistration({
    required this.deviceId,
    required this.deviceName,
  });
}

class DeviceConnection {
  final String deviceId;
  final String deviceName;
  final String serverUrl;
  final String sourceDeviceId;
  final String position;

  const DeviceConnection({
    required this.deviceId,
    required this.deviceName,
    required this.serverUrl,
    required this.sourceDeviceId,
    required this.position,
  });
}

enum DeviceConnectionFailure {
  authenticationRequired,
  operatorApprovalRequired,
  invalidConfiguration,
  networkOffline,
  selectionRequired,
  serverError,
}

class DeviceConnectionException implements Exception {
  const DeviceConnectionException(this.failure, this.message);

  final DeviceConnectionFailure failure;
  final String message;

  @override
  String toString() => message;
}

class DeviceService {
  DeviceService(
    this._ref, {
    Dio? dio,
    AuthStore? storage,
  }) : _storage = storage ?? const SecureAuthStore() {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
          validateStatus: (code) => code != null && code < 500,
        ));
  }

  final Ref _ref;
  late final Dio _dio;
  final AuthStore _storage;
  static final _backendDeviceIdPattern = RegExp(r'^dev_[0-9a-f]{32}$');

  // ── 저장된(등록된) 기기 정보 조회 ────────────────────────
  Future<({String? id, String? name})> savedDevice() async {
    final session = _sessionSnapshot();
    try {
      final id = await _storage.read(_kDeviceIdKey);
      final name = await _storage.read(_kDeviceNameKey);
      if (!_isCurrentSession(session)) return (id: null, name: null);
      return (id: id, name: name);
    } catch (_) {
      return (id: null, name: null);
    }
  }

  // ── 기기 등록 ────────────────────────────────────────────
  Future<DeviceRegistration?> registerDevice(String name) async {
    final session = _sessionSnapshot();
    final access = await _ref.read(authProvider.notifier).validAccessToken();
    if (access == null) return null;
    if (!_isCurrentSession(session)) return null;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    try {
      final res = await _dio.post(
        '/api/v1/devices',
        data: {'name': trimmed},
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      if (!_isCurrentSession(session)) return null;
      if (res.statusCode == 201) {
        final data = res.data['data'] as Map<String, dynamic>;
        final device = Map<String, dynamic>.from(data['device'] as Map);
        final deviceId = device['id'] as String;
        final deviceName = device['name'] as String? ?? trimmed;

        // 일반 앱은 기기 인증 credential 을 파싱하거나 보관하지 않는다.
        if (!await _cacheDeviceForSession(
          deviceId: deviceId,
          deviceName: deviceName,
          session: session,
        )) {
          return null;
        }
        if (!_isCurrentSession(session)) {
          await _deleteIfUnchanged(_kDeviceIdKey, deviceId);
          await _deleteIfUnchanged(_kDeviceNameKey, deviceName);
          return null;
        }

        return DeviceRegistration(
          deviceId: deviceId,
          deviceName: deviceName,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<DeviceConnection?> connectDevice(
    String name,
    String serverUrl,
    String position,
  ) async {
    final trimmedName = name.trim();
    final canonicalServerUrl = _normalizeServerOrigin(serverUrl);
    final sourceDeviceId = _sourceDeviceId(position);
    if (trimmedName.isEmpty ||
        canonicalServerUrl == null ||
        sourceDeviceId == null) {
      throw const DeviceConnectionException(
        DeviceConnectionFailure.invalidConfiguration,
        '수집 서버 주소와 카메라 위치 설정을 확인해 주세요.',
      );
    }

    final session = _sessionSnapshot();
    final access = await _ref.read(authProvider.notifier).validAccessToken();
    if (access == null) {
      throw const DeviceConnectionException(
        DeviceConnectionFailure.authenticationRequired,
        '로그인이 만료되었습니다. 다시 로그인해 주세요.',
      );
    }
    if (!_isCurrentSession(session)) return null;

    try {
      final response = await _dio.post(
        '/api/v1/devices/link',
        data: {
          'name': trimmedName,
          'server_url': canonicalServerUrl,
          'device_id': sourceDeviceId,
          'position': position,
        },
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      if (!_isCurrentSession(session)) return null;
      if (response.statusCode != 200) {
        throw _responseException(response.statusCode, response.data);
      }
      final connection = _parseConnection(
        response.data,
        expectedServerUrl: canonicalServerUrl,
        expectedSourceDeviceId: sourceDeviceId,
        expectedPosition: position,
      );
      if (connection == null || !_isCurrentSession(session)) return null;
      if (!await _cacheDeviceForSession(
        deviceId: connection.deviceId,
        deviceName: connection.deviceName,
        session: session,
      )) {
        return null;
      }
      if (!_isCurrentSession(session)) {
        await _deleteIfUnchanged(_kDeviceIdKey, connection.deviceId);
        await _deleteIfUnchanged(_kDeviceNameKey, connection.deviceName);
        return null;
      }
      return connection;
    } on DeviceConnectionException {
      rethrow;
    } on DioException catch (error) {
      throw _dioException(error);
    }
  }

  Future<DeviceConnection?> fetchConnection() async {
    final session = _sessionSnapshot();
    try {
      final deviceId = (await _storage.read(_kDeviceIdKey))?.trim();
      if (!_isCurrentSession(session)) return null;
      final access = await _ref.read(authProvider.notifier).validAccessToken();
      if (access == null) {
        throw const DeviceConnectionException(
          DeviceConnectionFailure.authenticationRequired,
          '로그인이 만료되었습니다. 다시 로그인해 주세요.',
        );
      }
      if (!_isCurrentSession(session)) return null;
      if (deviceId == null || !_isValidBackendDeviceId(deviceId)) {
        return await _recoverConnection(access, session);
      }
      final response = await _dio.get(
        '/api/v1/devices/$deviceId',
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      if (!_isCurrentSession(session)) return null;
      if (response.statusCode != 200) {
        if (response.statusCode == 404) {
          return await _recoverConnection(access, session);
        }
        throw _responseException(response.statusCode, response.data);
      }
      final connection = _parseConnection(
        response.data,
        expectedDeviceId: deviceId,
      );
      if (!_isCurrentSession(session)) return null;
      if (connection == null) {
        return await _recoverConnection(access, session);
      }
      return connection;
    } on DeviceConnectionException {
      rethrow;
    } on DioException catch (error) {
      throw _dioException(error);
    }
  }

  Future<DeviceConnection?> _recoverConnection(
    String access,
    ({int generation, String? owner}) session,
  ) async {
    final response = await _dio.get(
      '/api/v1/devices',
      options: Options(headers: {'Authorization': 'Bearer $access'}),
    );
    if (!_isCurrentSession(session)) return null;
    if (response.statusCode != 200) {
      throw _responseException(response.statusCode, response.data);
    }
    final data = response.data is Map ? response.data['data'] : null;
    final devices = data is Map ? data['devices'] : null;
    if (devices is! List) return null;
    final connections = devices.map(_parseDevice).whereType<DeviceConnection>();
    if (connections.isEmpty) return null;
    if (connections.length > 1) {
      throw const DeviceConnectionException(
        DeviceConnectionFailure.selectionRequired,
        '연결된 블랙박스가 여러 대입니다. 사용할 기기를 선택해 주세요.',
      );
    }
    final connection = connections.single;
    if (!_isCurrentSession(session)) return null;
    if (!await _cacheDeviceForSession(
      deviceId: connection.deviceId,
      deviceName: connection.deviceName,
      session: session,
    )) {
      return null;
    }
    return _isCurrentSession(session) ? connection : null;
  }

  DeviceConnection? _parseConnection(
    dynamic responseData, {
    String? expectedDeviceId,
    String? expectedServerUrl,
    String? expectedSourceDeviceId,
    String? expectedPosition,
  }) {
    if (responseData is! Map) return null;
    final data = responseData['data'];
    if (data is! Map) return null;
    final device = data['device'];
    return _parseDevice(
      device,
      expectedDeviceId: expectedDeviceId,
      expectedServerUrl: expectedServerUrl,
      expectedSourceDeviceId: expectedSourceDeviceId,
      expectedPosition: expectedPosition,
    );
  }

  DeviceConnection? _parseDevice(
    dynamic device, {
    String? expectedDeviceId,
    String? expectedServerUrl,
    String? expectedSourceDeviceId,
    String? expectedPosition,
  }) {
    if (device is! Map) return null;
    final collector = device['collector'];
    if (collector is! Map) return null;

    final deviceId = _nonEmptyString(device['id']);
    final deviceName = _nonEmptyString(device['name']);
    final serverUrl = _normalizeServerOrigin(collector['server_url']);
    final sourceDeviceId = _nonEmptyString(collector['device_id']);
    final position = _nonEmptyString(collector['position']);
    if (deviceId == null ||
        deviceName == null ||
        serverUrl == null ||
        sourceDeviceId == null ||
        position == null ||
        !_isValidBackendDeviceId(deviceId) ||
        _sourceDeviceId(position) != sourceDeviceId) {
      return null;
    }
    if (expectedDeviceId != null && deviceId != expectedDeviceId) return null;
    if (expectedServerUrl != null && serverUrl != expectedServerUrl) {
      return null;
    }
    if (expectedSourceDeviceId != null &&
        sourceDeviceId != expectedSourceDeviceId) {
      return null;
    }
    if (expectedPosition != null && position != expectedPosition) return null;

    return DeviceConnection(
      deviceId: deviceId,
      deviceName: deviceName,
      serverUrl: serverUrl,
      sourceDeviceId: sourceDeviceId,
      position: position,
    );
  }

  DeviceConnectionException _responseException(int? status, dynamic data) {
    if (status == 401) {
      return const DeviceConnectionException(
        DeviceConnectionFailure.authenticationRequired,
        '로그인이 만료되었습니다. 다시 로그인해 주세요.',
      );
    }
    if (status == 409) {
      return const DeviceConnectionException(
        DeviceConnectionFailure.operatorApprovalRequired,
        '운영자 승인이 필요한 블랙박스입니다. 승인 후 다시 연결해 주세요.',
      );
    }
    if (status == 422) {
      return const DeviceConnectionException(
        DeviceConnectionFailure.invalidConfiguration,
        '수집 서버 주소와 카메라 위치 설정을 확인해 주세요.',
      );
    }
    return const DeviceConnectionException(
      DeviceConnectionFailure.serverError,
      '블랙박스 연결 정보를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  DeviceConnectionException _dioException(DioException error) {
    if (error.response != null) {
      return _responseException(
          error.response?.statusCode, error.response?.data);
    }
    return const DeviceConnectionException(
      DeviceConnectionFailure.networkOffline,
      '네트워크에 연결할 수 없습니다. 인터넷 연결을 확인해 주세요.',
    );
  }

  Future<bool> _cacheDeviceForSession(
      {required String deviceId,
      required String deviceName,
      required ({int generation, String? owner}) session}) async {
    if (!_isCurrentSession(session)) return false;
    await _storage.write(_kDeviceIdKey, deviceId);
    if (!_isCurrentSession(session)) {
      await _deleteIfUnchanged(_kDeviceIdKey, deviceId);
      return false;
    }
    await _storage.write(_kDeviceNameKey, deviceName);
    if (!_isCurrentSession(session)) {
      await _deleteIfUnchanged(_kDeviceIdKey, deviceId);
      await _deleteIfUnchanged(_kDeviceNameKey, deviceName);
      return false;
    }
    return true;
  }

  Future<void> _deleteIfUnchanged(String key, String value) async {
    if (await _storage.read(key) == value) await _storage.delete(key);
  }

  ({int generation, String? owner}) _sessionSnapshot() {
    final auth = _ref.read(authProvider.notifier);
    return (
      generation: auth.sessionGeneration,
      owner: _normalizeOwner(_ref.read(authProvider).email),
    );
  }

  bool _isCurrentSession(({int generation, String? owner}) session) {
    final auth = _ref.read(authProvider.notifier);
    return auth.sessionGeneration == session.generation &&
        _normalizeOwner(_ref.read(authProvider).email) == session.owner;
  }

  String? _normalizeOwner(String? owner) {
    final normalized = owner?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _sourceDeviceId(String position) {
    if (position == 'front') return 'violet-dashcam-1';
    if (position == 'rear') return 'violet-dashcam-2';
    return null;
  }

  String? _nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isValidBackendDeviceId(String value) =>
      _backendDeviceIdPattern.hasMatch(value);

  String? _normalizeServerOrigin(dynamic value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    return Uri(
      scheme: 'https',
      host: uri.host,
      port: uri.hasPort && uri.port != 443 ? uri.port : null,
    ).toString();
  }

  // ── 서버에서 기기 해제 (DELETE /devices/{id}) ────────────
  Future<void> _revokeOnServer(String deviceId, String access) async {
    try {
      await _dio.delete(
        '/api/v1/devices/$deviceId',
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
    } catch (_) {
      // 서버 해제 실패가 로컬 기록 정리를 막지 않도록 한다.
    }
  }

  // ── 등록 완전 해제 (서버 revoke + 로컬 삭제) ──────────────
  Future<void> unregister() async {
    final session = _sessionSnapshot();
    final access = await _ref.read(authProvider.notifier).validAccessToken();
    if (!_isCurrentSession(session)) return;
    final id = await _storage.read(_kDeviceIdKey);
    if (!_isCurrentSession(session)) return;
    final name = await _storage.read(_kDeviceNameKey);
    if (!_isCurrentSession(session)) return;
    if (id != null && id.isNotEmpty && access != null) {
      await _revokeOnServer(id, access);
    }
    if (!_isCurrentSession(session)) return;
    if (id != null) await _deleteIfUnchanged(_kDeviceIdKey, id);
    if (name != null) await _deleteIfUnchanged(_kDeviceNameKey, name);
  }

  // ── 등록 해제 (로컬 기록만 삭제) ──────────────────────────
  Future<void> clearLocal() async {
    try {
      await _storage.delete(_kDeviceIdKey);
      await _storage.delete(_kDeviceNameKey);
    } catch (_) {}
  }
}

// ── Provider ──────────────────────────────────────────────
final deviceServiceProvider =
    Provider<DeviceService>((ref) => DeviceService(ref));
