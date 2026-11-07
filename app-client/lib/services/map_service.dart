import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'case_service.dart';

const int _maxDecodedPngBytes = 2 * 1024 * 1024;
const int _maxPngDimension = 4096;
const int _maxPngPixels = 16 * 1024 * 1024;
const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

enum AccidentMapStatus { ready, pending, noGps, unavailable }

class AccidentMap {
  const AccidentMap({
    required this.caseId,
    required this.status,
    required this.imageBytes,
    required this.hasRoute,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.gpsIsAssumed,
    required this.retryAfterSeconds,
  });

  final String caseId;
  final AccidentMapStatus status;
  final Uint8List? imageBytes;
  final bool hasRoute;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;
  final bool gpsIsAssumed;
  final int? retryAfterSeconds;
}

class MapServiceException implements Exception {
  const MapServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MapAuthenticationException extends MapServiceException {
  const MapAuthenticationException() : super('로그인이 필요합니다.');
}

class MapRequestCancelledException extends MapServiceException {
  const MapRequestCancelledException()
      : super('지도 요청이 새 세션 또는 사건 요청으로 대체되었습니다.');
}

class MapService {
  MapService({
    required Dio dio,
    required AccessTokenProvider accessToken,
  })  : _dio = dio,
        _accessToken = accessToken;

  final Dio _dio;
  final AccessTokenProvider _accessToken;
  final Set<CancelToken> _pending = <CancelToken>{};
  int _requestGeneration = 0;
  bool _disposed = false;

  Future<AccidentMap> fetchCaseMap(String caseId) async {
    if (!CaseService.isBackendCaseId(caseId)) {
      throw const MapServiceException('유효한 사고 사건을 확인할 수 없습니다.');
    }

    final generation = _requestGeneration;
    String? token;
    try {
      token = await _accessToken();
    } catch (_) {
      _requireCurrent(generation);
      throw const MapAuthenticationException();
    }
    _requireCurrent(generation);
    if (token == null || token.isEmpty) {
      throw const MapAuthenticationException();
    }

    final cancelToken = CancelToken();
    _pending.add(cancelToken);
    late final Response<dynamic> response;
    try {
      response = await _dio.get(
        '/api/v1/cases/$caseId/map',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || generation != _requestGeneration) {
        throw const MapRequestCancelledException();
      }
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        invalidateSession();
        throw const MapAuthenticationException();
      }
      throw const MapServiceException('사고 위치 지도를 불러올 수 없습니다.');
    } finally {
      _pending.remove(cancelToken);
    }

    _requireCurrent(generation);
    if (response.statusCode == 401 || response.statusCode == 403) {
      invalidateSession();
      throw const MapAuthenticationException();
    }
    if (response.statusCode != 200) {
      throw const MapServiceException('사고 위치 지도를 불러올 수 없습니다.');
    }
    return _parseResponse(response.data, expectedCaseId: caseId);
  }

  void cancelPendingRequests() {
    _cancelPending('map request superseded');
  }

  void invalidateSession() {
    _cancelPending('authentication session changed');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelPending('map service disposed');
  }

  void _cancelPending(String reason) {
    _requestGeneration++;
    final pending = List<CancelToken>.of(_pending);
    _pending.clear();
    for (final token in pending) {
      if (!token.isCancelled) token.cancel(reason);
    }
  }

  void _requireCurrent(int generation) {
    if (_disposed || generation != _requestGeneration) {
      throw const MapRequestCancelledException();
    }
  }
}

final mapApiDioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (_) => true,
    )));

final mapServiceProvider = Provider<MapService>((ref) {
  late final MapService service;
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (_authSessionChanged(previous, next)) service.invalidateSession();
  });
  service = MapService(
    dio: ref.read(mapApiDioProvider),
    accessToken: () => ref.read(authProvider.notifier).validAccessToken(),
  );
  ref.onDispose(service.dispose);
  return service;
});

bool _authSessionChanged(AuthState? previous, AuthState next) {
  final previousPrincipal = previous == null
      ? null
      : authenticatedPrincipal(previous);
  final nextPrincipal = authenticatedPrincipal(next);
  final loginStarted = previous?.status == AuthStatus.authenticated &&
      previous?.isBusy == false &&
      next.isBusy;
  return previousPrincipal != nextPrincipal || loginStarted;
}

AccidentMap _parseResponse(
  Object? body, {
  required String expectedCaseId,
}) {
  final root = _requiredMap(body, '서버 응답');
  final data = _requiredMap(root['data'], '서버 응답 data');
  final map = _requiredMap(data['map'], '서버 응답 map');
  const requiredFields = <String>{
    'case_id',
    'status',
    'image_png_base64',
    'has_route',
    'lat',
    'lon',
    'captured_at',
    'gps_is_assumed',
    'retry_after_seconds',
  };
  if (!map.keys.toSet().containsAll(requiredFields)) {
    throw const MapServiceException('서버의 지도 응답 항목이 올바르지 않습니다.');
  }

  final caseId = map['case_id'];
  if (caseId is! String || caseId != expectedCaseId) {
    throw const MapServiceException('요청한 사고 사건과 지도 응답의 사건이 일치하지 않습니다.');
  }
  final status = _parseStatus(map['status']);
  final hasRoute = map['has_route'];
  if (hasRoute is! bool) {
    throw const MapServiceException('서버의 경로 포함 여부가 올바르지 않습니다.');
  }
  final gpsIsAssumed = map['gps_is_assumed'];
  if (gpsIsAssumed is! bool) {
    throw const MapServiceException('서버의 GPS 추정 여부가 올바르지 않습니다.');
  }

  final latitude = _coordinate(map['lat'], '위도', min: -90, max: 90);
  final longitude = _coordinate(map['lon'], '경도', min: -180, max: 180);
  if ((latitude == null) != (longitude == null)) {
    throw const MapServiceException('서버의 위도와 경도는 함께 제공되어야 합니다.');
  }

  final capturedAt = _timestamp(map['captured_at']);
  final retryAfterSeconds = _retryAfter(map['retry_after_seconds']);
  final image = _imageBytes(map['image_png_base64']);

  if (status == AccidentMapStatus.ready && image == null) {
    throw const MapServiceException('준비된 지도 응답에 PNG 이미지가 없습니다.');
  }
  if (status != AccidentMapStatus.ready && image != null) {
    throw const MapServiceException('준비되지 않은 지도 응답에 이미지가 포함되어 있습니다.');
  }
  if (status == AccidentMapStatus.noGps &&
      (latitude != null || hasRoute || gpsIsAssumed)) {
    throw const MapServiceException('GPS 없음 상태의 지도 응답이 올바르지 않습니다.');
  }
  if (hasRoute && status != AccidentMapStatus.ready) {
    throw const MapServiceException('준비되지 않은 지도에는 이동 경로가 포함될 수 없습니다.');
  }

  return AccidentMap(
    caseId: caseId,
    status: status,
    imageBytes: image,
    hasRoute: hasRoute,
    latitude: latitude,
    longitude: longitude,
    capturedAt: capturedAt,
    gpsIsAssumed: gpsIsAssumed,
    retryAfterSeconds: retryAfterSeconds,
  );
}

Map<String, dynamic> _requiredMap(Object? value, String label) {
  if (value is! Map) {
    throw MapServiceException('$label 형식이 올바르지 않습니다.');
  }
  try {
    return Map<String, dynamic>.from(value);
  } on TypeError {
    throw MapServiceException('$label 형식이 올바르지 않습니다.');
  }
}

AccidentMapStatus _parseStatus(Object? value) {
  switch (value) {
    case 'ready':
      return AccidentMapStatus.ready;
    case 'pending':
      return AccidentMapStatus.pending;
    case 'no_gps':
      return AccidentMapStatus.noGps;
    case 'unavailable':
      return AccidentMapStatus.unavailable;
    default:
      throw const MapServiceException('서버의 지도 상태가 올바르지 않습니다.');
  }
}

double? _coordinate(Object? value, String label,
    {required double min, required double max}) {
  if (value == null) return null;
  if (value is! num) {
    throw MapServiceException('서버의 $label 값은 숫자여야 합니다.');
  }
  final coordinate = value.toDouble();
  if (!coordinate.isFinite || coordinate < min || coordinate > max) {
    throw MapServiceException('서버의 $label 값이 유효 범위를 벗어났습니다.');
  }
  return coordinate;
}

DateTime? _timestamp(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const MapServiceException('서버의 촬영 시각 형식이 올바르지 않습니다.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const MapServiceException('서버의 촬영 시각 형식이 올바르지 않습니다.');
  }
  return parsed.toUtc();
}

int? _retryAfter(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0) {
    throw const MapServiceException('서버의 지도 재시도 시간이 올바르지 않습니다.');
  }
  return value;
}

Uint8List? _imageBytes(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const MapServiceException('서버의 지도 PNG 형식이 올바르지 않습니다.');
  }
  const maxEncodedLength = ((_maxDecodedPngBytes + 2) ~/ 3) * 4;
  if (value.length > maxEncodedLength) {
    throw const MapServiceException('지도 PNG 크기가 2 MiB 제한을 초과했습니다.');
  }

  late final Uint8List bytes;
  try {
    bytes = base64Decode(value);
  } on FormatException {
    throw const MapServiceException('서버의 지도 PNG 인코딩이 올바르지 않습니다.');
  }
  if (bytes.length > _maxDecodedPngBytes) {
    throw const MapServiceException('지도 PNG 크기가 2 MiB 제한을 초과했습니다.');
  }
  if (bytes.length < _pngSignature.length) {
    throw const MapServiceException('서버 응답이 PNG 이미지가 아닙니다.');
  }
  for (var index = 0; index < _pngSignature.length; index++) {
    if (bytes[index] != _pngSignature[index]) {
      throw const MapServiceException('서버 응답이 PNG 이미지가 아닙니다.');
    }
  }
  _validatePngDimensions(bytes);
  return bytes;
}

void _validatePngDimensions(Uint8List bytes) {
  if (bytes.length < 24 ||
      bytes[8] != 0 ||
      bytes[9] != 0 ||
      bytes[10] != 0 ||
      bytes[11] != 13 ||
      bytes[12] != 73 ||
      bytes[13] != 72 ||
      bytes[14] != 68 ||
      bytes[15] != 82) {
    throw const MapServiceException('서버의 지도 PNG 헤더가 올바르지 않습니다.');
  }
  final header = ByteData.sublistView(bytes);
  final width = header.getUint32(16, Endian.big);
  final height = header.getUint32(20, Endian.big);
  if (width == 0 ||
      height == 0 ||
      width > _maxPngDimension ||
      height > _maxPngDimension ||
      width * height > _maxPngPixels) {
    throw const MapServiceException('지도 PNG 해상도가 허용 범위를 초과했습니다.');
  }
}
