import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blackbox_driver_care/services/map_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _caseA = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _caseB = 'case_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  group('MapService', () {
    test('loads a ready map only from the authenticated case endpoint',
        () async {
      final adapter = _QueueAdapter([
        _jsonResponse(200, _envelope(_mapJson(
          caseId: _caseA,
          status: 'ready',
          image: _pngBase64,
          hasRoute: true,
          lat: 37.5665,
          lon: 126.978,
          capturedAt: '2026-10-17T01:02:03Z',
          gpsIsAssumed: true,
        ))),
      ]);
      final service = _service(adapter, token: 'owner-token');

      final map = await service.fetchCaseMap(_caseA);

      expect(map.caseId, _caseA);
      expect(map.status, AccidentMapStatus.ready);
      expect(map.imageBytes, base64Decode(_pngBase64));
      expect(map.hasRoute, isTrue);
      expect(map.latitude, 37.5665);
      expect(map.longitude, 126.978);
      expect(map.capturedAt, DateTime.utc(2026, 10, 17, 1, 2, 3));
      expect(map.gpsIsAssumed, isTrue);
      expect(map.retryAfterSeconds, isNull);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/v1/cases/$_caseA/map');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer owner-token',
      );
    });

    test('parses no_gps and pending without inventing image evidence',
        () async {
      final adapter = _QueueAdapter([
        _jsonResponse(
          200,
          _envelope(_mapJson(caseId: _caseA, status: 'no_gps')),
        ),
        _jsonResponse(
          200,
          _envelope(_mapJson(
            caseId: _caseA,
            status: 'pending',
            retryAfterSeconds: 8,
          )),
        ),
      ]);
      final service = _service(adapter);

      final noGps = await service.fetchCaseMap(_caseA);
      final pending = await service.fetchCaseMap(_caseA);

      expect(noGps.status, AccidentMapStatus.noGps);
      expect(noGps.imageBytes, isNull);
      expect(noGps.hasRoute, isFalse);
      expect(pending.status, AccidentMapStatus.pending);
      expect(pending.imageBytes, isNull);
      expect(pending.retryAfterSeconds, 8);
      expect(adapter.requests, hasLength(2));
    });

    test('rejects invalid ids, another case, and non-numeric coordinates',
        () async {
      final adapter = _QueueAdapter([
        _jsonResponse(
          200,
          _envelope(_mapJson(caseId: _caseB, status: 'no_gps')),
        ),
        _jsonResponse(
          200,
          _envelope(_mapJson(
            caseId: _caseA,
            status: 'ready',
            image: _pngBase64,
            lat: '37.5665',
            lon: 126.978,
          )),
        ),
      ]);
      final service = _service(adapter);

      await expectLater(
        service.fetchCaseMap('local-event-1'),
        throwsA(isA<MapServiceException>()),
      );
      expect(adapter.requests, isEmpty);
      await expectLater(
        service.fetchCaseMap(_caseA),
        throwsA(
          isA<MapServiceException>().having(
            (error) => error.message,
            'message',
            contains('사건'),
          ),
        ),
      );
      await expectLater(
        service.fetchCaseMap(_caseA),
        throwsA(
          isA<MapServiceException>().having(
            (error) => error.message,
            'message',
            contains('위도'),
          ),
        ),
      );
    });

    test('rejects malformed, non-PNG, and decoded PNGs over 2 MiB',
        () async {
      final oversized = base64Encode(Uint8List(2 * 1024 * 1024 + 1)
        ..setRange(0, 8, const [137, 80, 78, 71, 13, 10, 26, 10]));
      final adapter = _QueueAdapter([
        _jsonResponse(
          200,
          _envelope(_mapJson(
            caseId: _caseA,
            status: 'ready',
            image: 'not-base64!',
          )),
        ),
        _jsonResponse(
          200,
          _envelope(_mapJson(
            caseId: _caseA,
            status: 'ready',
            image: base64Encode(const [1, 2, 3, 4]),
          )),
        ),
        _jsonResponse(
          200,
          _envelope(_mapJson(
            caseId: _caseA,
            status: 'ready',
            image: oversized,
          )),
        ),
      ]);
      final service = _service(adapter);

      for (var i = 0; i < 3; i++) {
        await expectLater(
          service.fetchCaseMap(_caseA),
          throwsA(isA<MapServiceException>()),
        );
      }
    });

    test('strictly rejects non-200 responses and missing authentication',
        () async {
      final adapter = _QueueAdapter([
        _jsonResponse(202, _envelope(_mapJson(
          caseId: _caseA,
          status: 'pending',
        ))),
        _jsonResponse(401, {
          'error': {'message': 'expired'},
        }),
      ]);
      final service = _service(adapter);

      await expectLater(
        service.fetchCaseMap(_caseA),
        throwsA(isA<MapServiceException>()),
      );
      await expectLater(
        service.fetchCaseMap(_caseA),
        throwsA(isA<MapAuthenticationException>()),
      );

      final noTokenAdapter = _QueueAdapter([]);
      await expectLater(
        _service(noTokenAdapter, token: null).fetchCaseMap(_caseA),
        throwsA(isA<MapAuthenticationException>()),
      );
      expect(noTokenAdapter.requests, isEmpty);
    });

    test('session invalidation cancels stale evidence before another user loads',
        () async {
      var token = 'user-a-token';
      final adapter = _ControlledAdapter();
      final service = MapService(
        dio: _dio(adapter),
        accessToken: () async => token,
      );

      final stale = service.fetchCaseMap(_caseA);
      await adapter.waitForRequests(1);
      token = 'user-b-token';
      service.invalidateSession();

      await expectLater(stale, throwsA(isA<MapRequestCancelledException>()));

      final fresh = service.fetchCaseMap(_caseB);
      await adapter.waitForRequests(2);
      adapter.complete(
        1,
        _jsonResponse(
          200,
          _envelope(_mapJson(caseId: _caseB, status: 'no_gps')),
        ),
      );

      expect((await fresh).caseId, _caseB);
      expect(adapter.requests[0].headers['Authorization'], 'Bearer user-a-token');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer user-b-token');
    });
  });
}

MapService _service(_QueueAdapter adapter, {String? token = 'token'}) =>
    MapService(
      dio: _dio(adapter),
      accessToken: () async => token,
    );

Dio _dio(HttpClientAdapter adapter) => Dio(BaseOptions(
      baseUrl: 'https://backend.test',
      validateStatus: (_) => true,
    ))..httpClientAdapter = adapter;

Map<String, Object?> _envelope(Map<String, Object?> map) => {
      'data': {'map': map},
      'request_id': 'req-map-test',
    };

Map<String, Object?> _mapJson({
  required String caseId,
  required String status,
  String? image,
  bool hasRoute = false,
  Object? lat,
  Object? lon,
  String? capturedAt,
  bool gpsIsAssumed = false,
  int? retryAfterSeconds,
}) =>
    {
      'case_id': caseId,
      'status': status,
      'image_png_base64': image,
      'has_route': hasRoute,
      'lat': lat,
      'lon': lon,
      'captured_at': capturedAt,
      'gps_is_assumed': gpsIsAssumed,
      'retry_after_seconds': retryAfterSeconds,
    };

ResponseBody _jsonResponse(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<ResponseBody> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) throw StateError('No response queued');
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

class _ControlledAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final pending = <Completer<ResponseBody>>[];
  final _changed = StreamController<void>.broadcast(sync: true);

  Future<void> waitForRequests(int count) async {
    while (requests.length < count) {
      await _changed.stream.first.timeout(const Duration(seconds: 2));
    }
  }

  void complete(int index, ResponseBody response) {
    if (!pending[index].isCompleted) pending[index].complete(response);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final completer = Completer<ResponseBody>();
    pending.add(completer);
    cancelFuture?.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(DioException.requestCancelled(
          requestOptions: options,
          reason: 'session invalidated',
        ));
      }
    });
    _changed.add(null);
    return completer.future;
  }

  @override
  void close({bool force = false}) {
    _changed.close();
  }
}
