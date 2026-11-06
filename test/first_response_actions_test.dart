import 'dart:ui';

import 'package:blackbox_driver_care/screens/accident/first_response_screen.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/blackbox_video_service.dart';
import 'package:blackbox_driver_care/services/case_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final launcherCalls = <MethodCall>[];
  var launchResult = true;
  var launchException = false;

  setUp(() {
    launcherCalls.clear();
    launchResult = true;
    launchException = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
      launcherCalls.add(call);
      if (launchException) {
        throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
      }
      return launchResult;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  Future<void> showFirstResponse(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SignedOutAuth()),
          caseServiceProvider.overrideWithValue(_ImmediateCaseService()),
          blackboxVideoProvider.overrideWith(
            (ref) => _NoopBlackboxVideoNotifier(),
          ),
        ],
        child: const MaterialApp(
          home: FirstResponseScreen(accidentId: _caseId),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> showCallStep(WidgetTester tester) async {
    await showFirstResponse(tester);
    await tester.tap(find.text('다음 단계'));
    await tester.pump();
  }

  testWidgets('safety checklist items toggle independently', (tester) async {
    await showFirstResponse(tester);

    await tester.tap(find.text('비상등 점등'));
    await tester.pump();

    final first = tester.getSemantics(find.text('비상등 점등'));
    final second = tester.getSemantics(find.text('차량을 갓길로 이동'));
    expect(first.flagsCollection.isChecked, CheckedState.isTrue);
    expect(second.flagsCollection.isChecked, CheckedState.isFalse);

    await tester.tap(find.text('차량을 갓길로 이동'));
    await tester.pump();

    expect(
      tester.getSemantics(find.text('비상등 점등')).flagsCollection.isChecked,
      CheckedState.isTrue,
    );
    expect(
      tester.getSemantics(find.text('차량을 갓길로 이동')).flagsCollection.isChecked,
      CheckedState.isTrue,
    );
  });

  for (final number in ['119', '112']) {
    testWidgets('$number asks for confirmation and cancel avoids launch', (
      tester,
    ) async {
      await showCallStep(tester);

      await tester.tap(find.text(number));
      await tester.pumpAndSettle();

      expect(find.textContaining('$number에 전화할까요?'), findsOneWidget);
      expect(launcherCalls, isEmpty);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.textContaining('$number에 전화할까요?'), findsNothing);
      expect(launcherCalls, isEmpty);
    });
  }

  testWidgets('failed native phone launch explains simulator limitation', (
    tester,
  ) async {
    launchResult = false;
    await showCallStep(tester);

    await tester.tap(find.text('119'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전화 걸기'));
    await tester.pumpAndSettle();

    expect(launcherCalls, hasLength(1));
    expect(launcherCalls.single.method, 'launch');
    expect(launcherCalls.single.arguments, containsPair('url', 'tel:119'));
    expect(find.textContaining('시뮬레이터에서는 전화를 걸 수 없습니다'), findsOneWidget);
  });

  testWidgets('native phone launcher exception explains simulator limitation', (
    tester,
  ) async {
    launchException = true;
    await showCallStep(tester);

    await tester.tap(find.text('119'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전화 걸기'));
    await tester.pumpAndSettle();

    expect(launcherCalls, hasLength(1));
    expect(launcherCalls.single.method, 'launch');
    expect(launcherCalls.single.arguments, containsPair('url', 'tel:119'));
    expect(find.textContaining('시뮬레이터에서는 전화를 걸 수 없습니다'), findsOneWidget);
  });
}

const _caseId = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _SignedOutAuth extends AuthNotifier {
  _SignedOutAuth()
      : super(restoreSession: false, tokenStore: MemoryAuthStore());
}

class _ImmediateCaseService extends CaseService {
  _ImmediateCaseService()
      : super(
          dio: Dio(),
          accessToken: () async => 'token',
          savedDevice: () async => (id: 'dev_a', name: 'Dashcam'),
          activeCase: () => _caseId,
          onActiveCaseChanged: (_) {},
        );

  @override
  Future<BackendCase> selectOwnedCase(String caseId) async => BackendCase(
        id: caseId,
        deviceId: 'dev_a',
        title: 'Test accident',
        status: 'open',
        createdAt: DateTime.utc(2026, 10, 15),
      );
}

class _NoopBlackboxVideoNotifier extends BlackboxVideoNotifier {
  _NoopBlackboxVideoNotifier()
      : super(
          evidenceService: BackendEvidenceService(
            apiDio: Dio(),
            storageDio: Dio(),
            accessToken: () async => 'token',
          ),
          ensureOwnedCase: (_) async {},
          principal: () => null,
        );

  @override
  Future<void> fetchAndDownload(String accidentId) async {}
}
