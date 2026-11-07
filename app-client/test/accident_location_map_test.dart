import 'dart:async';
import 'dart:typed_data';

import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/map_service.dart';
import 'package:blackbox_driver_care/widgets/accident_location_map.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _caseA = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _caseB = 'case_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _png = <int>[
  137, 80, 78, 71, 13, 10, 26, 10,
  0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1,
  8, 4, 0, 0, 0, 181, 28, 12,
  2, 0, 0, 0, 11, 73, 68, 65,
  84, 120, 218, 99, 100, 248, 15, 0,
  1, 5, 1, 1, 39, 24, 227, 102,
  0, 0, 0, 0, 73, 69, 78, 68,
  174, 66, 96, 130,
];

void main() {
  testWidgets('ready map shows bounded image evidence and factual metadata',
      (tester) async {
    final service = _FakeMapService()
      ..enqueueValue(_readyMap(
        _caseA,
        lat: 37.5665,
        lon: 126.978,
        hasRoute: true,
        gpsIsAssumed: true,
      ));

    await tester.pumpWidget(_app(service: service, caseId: _caseA));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    expect(find.text('이동 경로 포함'), findsOneWidget);
    expect(find.textContaining('37.566500'), findsOneWidget);
    expect(find.textContaining('126.978000'), findsOneWidget);
    expect(find.textContaining('2026-10-17'), findsOneWidget);
    expect(find.textContaining('추정 GPS'), findsOneWidget);
    expect(find.textContaining('km/h'), findsNothing);
    expect(find.textContaining('날씨'), findsNothing);
    expect(find.textContaining('주소'), findsNothing);

    final frame = tester.getSize(find.byKey(accidentMapFrameKey));
    expect(frame.height, lessThanOrEqualTo(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no GPS and unavailable states never retain an image',
      (tester) async {
    final service = _FakeMapService()
      ..enqueueValue(_map(_caseA, AccidentMapStatus.noGps))
      ..enqueueValue(_map(_caseB, AccidentMapStatus.unavailable));

    await tester.pumpWidget(_app(service: service, caseId: _caseA));
    await tester.pump();
    expect(find.textContaining('GPS'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(_app(service: service, caseId: _caseB));
    await tester.pump();
    expect(find.textContaining('불러올 수 없습니다'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('pending state retries only after the user taps retry',
      (tester) async {
    final service = _FakeMapService()
      ..enqueueValue(_map(
        _caseA,
        AccidentMapStatus.pending,
        retryAfterSeconds: 30,
      ))
      ..enqueueValue(_readyMap(_caseA));

    await tester.pumpWidget(_app(service: service, caseId: _caseA));
    await tester.pump();

    expect(find.textContaining('생성 중'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(service.requests, [_caseA]);

    await tester.pump(const Duration(minutes: 2));
    expect(service.requests, [_caseA]);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(service.requests, [_caseA, _caseA]);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('case switch clears old evidence and ignores its late response',
      (tester) async {
    final first = Completer<AccidentMap>();
    final second = Completer<AccidentMap>();
    final service = _FakeMapService()
      ..enqueueFuture(first.future)
      ..enqueueFuture(second.future);

    await tester.pumpWidget(_app(service: service, caseId: _caseA));
    await tester.pump();
    await tester.pumpWidget(_app(service: service, caseId: _caseB));
    await tester.pump();

    first.complete(_readyMap(_caseA, lat: 11, lon: 22));
    await tester.pump();
    expect(find.textContaining('11.000000'), findsNothing);
    expect(find.byType(Image), findsNothing);

    second.complete(_readyMap(_caseB, lat: 33, lon: 44));
    await tester.pump();
    expect(find.textContaining('33.000000'), findsOneWidget);
    expect(find.textContaining('44.000000'), findsOneWidget);
  });

  testWidgets('logout clears visible evidence and cancels the active session',
      (tester) async {
    final auth = _TestAuthNotifier()..authenticate('first@example.com');
    final service = _FakeMapService()
      ..enqueueValue(_readyMap(_caseA, lat: 37.1, lon: 127.1));

    await tester.pumpWidget(_app(
      service: service,
      caseId: _caseA,
      auth: auth,
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    auth.signOutForTest();
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('37.100000'), findsNothing);
    expect(service.invalidations, 1);
  });

  testWidgets('late auth failure for another case cannot show previous evidence',
      (tester) async {
    final failure = Completer<AccidentMap>();
    final service = _FakeMapService()
      ..enqueueValue(_readyMap(_caseA, lat: 1, lon: 2))
      ..enqueueFuture(failure.future);

    await tester.pumpWidget(_app(service: service, caseId: _caseA));
    await tester.pump();
    expect(find.textContaining('1.000000'), findsOneWidget);

    await tester.pumpWidget(_app(service: service, caseId: _caseB));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('1.000000'), findsNothing);

    failure.completeError(const MapAuthenticationException());
    await tester.pump();
    expect(find.textContaining('로그인'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('map frame does not overflow at 320 logical pixels wide',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeMapService()
      ..enqueueValue(_readyMap(
        _caseA,
        lat: -89.123456,
        lon: -179.123456,
        gpsIsAssumed: true,
      ));

    await tester.pumpWidget(_app(service: service, caseId: _caseA));
    await tester.pump();

    expect(tester.getSize(find.byKey(accidentMapFrameKey)).height, 200);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required _FakeMapService service,
  required String caseId,
  _TestAuthNotifier? auth,
}) =>
    ProviderScope(
      overrides: [
        if (auth != null) authProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AccidentLocationMap(caseId: caseId, service: service),
        ),
      ),
    );

AccidentMap _readyMap(
  String caseId, {
  double? lat,
  double? lon,
  bool hasRoute = false,
  bool gpsIsAssumed = false,
}) =>
    AccidentMap(
      caseId: caseId,
      status: AccidentMapStatus.ready,
      imageBytes: Uint8List.fromList(_png),
      hasRoute: hasRoute,
      latitude: lat,
      longitude: lon,
      capturedAt: DateTime.utc(2026, 10, 17, 1, 2, 3),
      gpsIsAssumed: gpsIsAssumed,
      retryAfterSeconds: null,
    );

AccidentMap _map(
  String caseId,
  AccidentMapStatus status, {
  int? retryAfterSeconds,
}) =>
    AccidentMap(
      caseId: caseId,
      status: status,
      imageBytes: null,
      hasRoute: false,
      latitude: null,
      longitude: null,
      capturedAt: null,
      gpsIsAssumed: false,
      retryAfterSeconds: retryAfterSeconds,
    );

class _FakeMapService extends MapService {
  _FakeMapService()
      : super(
          dio: Dio(),
          accessToken: () async => 'test-token',
        );

  final requests = <String>[];
  final _results = <Future<AccidentMap>>[];
  int invalidations = 0;

  void enqueueValue(AccidentMap map) {
    _results.add(Future.value(map));
  }

  void enqueueFuture(Future<AccidentMap> map) {
    _results.add(map);
  }

  @override
  Future<AccidentMap> fetchCaseMap(String caseId) {
    requests.add(caseId);
    if (_results.isEmpty) throw StateError('No map result queued');
    return _results.removeAt(0);
  }

  @override
  void invalidateSession() {
    invalidations++;
    super.invalidateSession();
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
          cleanupLocalFiles: () async {},
        );

  void authenticate(String email) {
    state = AuthState(status: AuthStatus.authenticated, email: email);
  }

  void signOutForTest() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
