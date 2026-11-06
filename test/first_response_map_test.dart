import 'package:blackbox_driver_care/screens/accident/first_response_screen.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/blackbox_video_service.dart';
import 'package:blackbox_driver_care/services/case_service.dart';
import 'package:blackbox_driver_care/services/map_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const caseId = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  testWidgets('video map is lazy and stays scoped to the selected owned case',
      (tester) async {
    final maps = _Maps();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _Auth()),
          caseServiceProvider.overrideWithValue(_Cases()),
          blackboxVideoProvider.overrideWith((_) => _Video()),
          mapServiceProvider.overrideWithValue(maps),
        ],
        child: const MaterialApp(
            home: FirstResponseScreen(
                accidentId: caseId, initialVideoStep: true))));
    await tester.pumpAndSettle();
    expect(find.text('사고 위치 보기'), findsOneWidget);
    expect(maps.requests, isEmpty);
    await tester.ensureVisible(find.text('사고 위치 보기'));
    await tester.tap(find.text('사고 위치 보기'));
    await tester.pumpAndSettle();
    expect(maps.requests, [caseId]);
    expect(find.textContaining('GPS'), findsOneWidget);
    expect(find.text('AI 과실 분석 시작'), findsOneWidget);
  });
}

class _Auth extends AuthNotifier {
  _Auth()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
          initialAccessToken: 'token',
        ) {
    state = const AuthState(
      status: AuthStatus.authenticated,
      email: 'owner@example.test',
    );
  }
}

class _Cases extends CaseService {
  _Cases()
      : super(
            dio: Dio(),
            accessToken: () async => 'token',
            savedDevice: () async => (id: 'dev_a', name: 'Camera'),
            activeCase: () => caseId,
            onActiveCaseChanged: (_) {});
  @override
  Future<BackendCase> selectOwnedCase(String id) async => BackendCase(
      id: id,
      deviceId: 'dev_a',
      title: 'Case',
      status: 'done',
      createdAt: DateTime.utc(2026, 10, 17));
}

class _Video extends BlackboxVideoNotifier {
  _Video()
      : super(
            evidenceService: BackendEvidenceService(
                apiDio: Dio(),
                storageDio: Dio(),
                accessToken: () async => 'token'),
            ensureOwnedCase: (_) async {},
            principal: () => 'owner@example.test') {
    state = const BlackboxVideoState(
        caseId: caseId,
        status: VideoStatus.ready,
        localPath: '/tmp/test-case-video.mp4');
  }
  @override
  Future<void> fetchAndDownload(String id) async {}
}

class _Maps extends MapService {
  _Maps() : super(dio: Dio(), accessToken: () async => 'token');
  final requests = <String>[];
  @override
  Future<AccidentMap> fetchCaseMap(String id) async {
    requests.add(id);
    return AccidentMap(
        caseId: id,
        status: AccidentMapStatus.noGps,
        imageBytes: null,
        hasRoute: false,
        latitude: null,
        longitude: null,
        capturedAt: null,
        gpsIsAssumed: false,
        retryAfterSeconds: null);
  }
}
