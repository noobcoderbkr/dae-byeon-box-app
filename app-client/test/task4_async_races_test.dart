import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blackbox_driver_care/screens/report/my_reports_screen.dart';
import 'package:blackbox_driver_care/screens/accident/first_response_screen.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/blackbox_video_service.dart';
import 'package:blackbox_driver_care/services/case_service.dart';
import 'package:blackbox_driver_care/services/local_files.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late TestAuth auth;
  late DeferredHttp api;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  Future<String?> Function()? documents;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('task4-async-races-');
    auth = TestAuth()..loginAs('a@example.com');
    api = DeferredHttp();
    documents = () async => directory.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) => documents!());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await directory.delete(recursive: true);
  });

  test('principal change rejects a delayed owned-case activation', () async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      caseApiDioProvider.overrideWithValue(api.dio),
    ]);
    addTearDown(container.dispose);
    final service = container.read(caseServiceProvider);
    final pending = service.selectOwnedCase(caseA);
    final outcome = expectLater(
      pending,
      throwsA(isA<SupersededCaseOperationException>()),
    );
    await api.waitForCount(1);
    auth.loginAs('b@example.com');
    api.reply(0, {'case': caseJson(caseA)});
    await outcome;
    expect(container.read(activeCaseProvider), isNull);
  });

  test('principal change rejects a delayed latest-hardware activation',
      () async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      caseApiDioProvider.overrideWithValue(api.dio),
    ]);
    addTearDown(container.dispose);
    final service = container.read(caseServiceProvider);
    final pending = service.selectLatestHardwareCase();
    final outcome = expectLater(
      pending,
      throwsA(isA<SupersededCaseOperationException>()),
    );
    await api.waitForCount(1);
    auth.loginAs('b@example.com');
    api.reply(0, {'case': caseJson(caseA)});

    await outcome;
    expect(container.read(activeCaseProvider), isNull);
  });

  test('principal change during saved-device lookup prevents sensor creation',
      () async {
    // This service is invalidated by the same lifecycle method used by its provider.
    final device = Completer<({String? id, String? name})>();
    String? active;
    final service = CaseService(
      dio: api.dio,
      accessToken: () async => 'token',
      savedDevice: () => device.future,
      activeCase: () => active,
      onActiveCaseChanged: (id) => active = id,
    );
    final pending = service.createSensorCase();
    final outcome = expectLater(
      pending,
      throwsA(isA<SupersededCaseOperationException>()),
    );
    service.invalidatePendingActivation();
    device.complete((id: 'dev_a', name: 'A'));
    // A buggy implementation proceeds to HTTP; release it so RED cannot hang.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (api.requests.isNotEmpty) api.reply(0, {'case': caseJson(caseA)}, 201);
    await outcome;
    expect(api.requests, isEmpty);
    expect(active, isNull);
  });

  Future<void> showHistory(
    WidgetTester tester, {
    BlackboxVideoNotifier? videoNotifier,
  }) async {
    final service = CaseService(
      dio: api.dio,
      accessToken: () async => 'token',
      savedDevice: () async => (id: 'dev_a', name: 'A'),
      activeCase: () => null,
      onActiveCaseChanged: (_) {},
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        caseServiceProvider.overrideWithValue(service),
        if (videoNotifier != null)
          blackboxVideoProvider.overrideWith((ref) => videoNotifier),
      ],
      child: const MaterialApp(home: MyReportsScreen()),
    ));
    await flush(tester);
  }

  Future<void> refresh(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await flush(tester);
  }

  testWidgets('delayed case load-more cannot append after refresh',
      (tester) async {
    await showHistory(tester);
    api.reply(0, cases([caseA], next: 'next'));
    await flush(tester);
    await tester.tap(find.text('사고 더 불러오기'));
    await flush(tester);
    await refresh(tester);
    api.reply(2, cases([caseB]));
    await flush(tester);
    api.reply(1, cases([caseC]));
    await flush(tester);
    expect(find.text('Case $caseB'), findsOneWidget);
    expect(find.text('Case $caseC'), findsNothing);
    expect(find.text('Case $caseA'), findsNothing);
  });

  testWidgets('old-user cases cannot populate history after another login',
      (tester) async {
    await showHistory(tester);
    auth.loginAs('b@example.com');
    await flush(tester);
    api.reply(0, cases([caseA]));
    await flush(tester);
    expect(find.text('Case $caseA'), findsNothing);
    expect(api.requests, hasLength(2));
    api.reply(1, cases([caseB]));
    await flush(tester);
    expect(find.text('Case $caseB'), findsOneWidget);
  });

  testWidgets('refresh clears report-loading locks and ignores old completion',
      (tester) async {
    await showHistory(tester);
    api.reply(0, cases([caseA]));
    await flush(tester);
    await tester.tap(find.text('Case $caseA'));
    await flush(tester);
    await refresh(tester);
    api.reply(2, cases([caseA]));
    await flush(tester);
    await tester.tap(find.text('Case $caseA'));
    await flush(tester);
    expect(api.requests, hasLength(4));
    api.reply(3, reports(caseA, 2));
    await flush(tester);
    api.reply(1, reports(caseA, 1));
    await flush(tester);
    expect(find.text('분석 리포트 v2'), findsOneWidget);
    expect(find.text('분석 리포트 v1'), findsNothing);
  });

  testWidgets('old-user report completion is ignored after another login',
      (tester) async {
    await showHistory(tester);
    api.reply(0, cases([caseA]));
    await flush(tester);
    await tester.tap(find.text('Case $caseA'));
    await flush(tester);
    auth.loginAs('b@example.com');
    await flush(tester);
    if (api.requests.length > 2) api.reply(2, cases([caseB]));
    api.reply(1, reports(caseA, 9));
    await flush(tester);
    expect(find.text('분석 리포트 v9'), findsNothing);
    expect(find.text('Case $caseA'), findsNothing);
  });

  testWidgets(
      'history report opens exact version read-only without analysis POST',
      (tester) async {
    await showHistory(tester);
    api.reply(0, cases([caseA]));
    await flush(tester);
    await tester.tap(find.text('Case $caseA'));
    await flush(tester);
    api.reply(
        1, reportsFor(caseA, const [(1, 'selected v1'), (2, 'selected v2')]));
    await flush(tester);

    await tester.tap(find.text('분석 리포트 v1'));
    await flush(tester);
    api.reply(2, {'case': caseJson(caseA)});
    await flush(tester);

    expect(find.text('selected v1'), findsOneWidget);
    expect(find.text('selected v2'), findsNothing);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('분석 리포트 v2'));
    await flush(tester);
    api.reply(3, {'case': caseJson(caseA)});
    await flush(tester);
    expect(find.text('selected v2'), findsOneWidget);
    expect(find.text('selected v1'), findsNothing);
    expect(api.requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('late PDF scan cannot expose a previous user after login',
      (tester) async {
    final pdfA = LocalAppFiles.scopedPdfName(
      ownerScope: LocalAppFiles.ownerScope('a@example.com'),
      caseId: caseA,
      suffix: 'report',
    );
    final pdfB = LocalAppFiles.scopedPdfName(
      ownerScope: LocalAppFiles.ownerScope('b@example.com'),
      caseId: caseB,
      suffix: 'report',
    );
    await tester.runAsync(() async {
      await File('${directory.path}/$pdfA').writeAsString('A');
      await File('${directory.path}/$pdfB').writeAsString('B');
    });
    final delayedDirectory = Completer<String?>();
    var lookups = 0;
    documents = () =>
        lookups++ == 0 ? delayedDirectory.future : Future.value(directory.path);
    await showHistory(tester);
    auth.loginAs('b@example.com');
    await flush(tester);
    delayedDirectory.complete(directory.path);
    await flush(tester);
    await tester.tap(find.text('내보낸 PDF'));
    await flush(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await flush(tester);
    expect(find.textContaining(pdfA), findsNothing);
    expect(find.textContaining(pdfB), findsOneWidget);
  });

  testWidgets('202 case deletion cleans media and preserves manual PDF delete',
      (tester) async {
    final pdf = LocalAppFiles.scopedPdfName(
      ownerScope: LocalAppFiles.ownerScope('a@example.com'),
      caseId: caseA,
      suffix: 'report',
    );
    await tester.runAsync(() async {
      for (final name in [
        'blackbox_$caseA.mp4',
        'accident_${caseA}_123.m4a',
        'accident_${caseB}_123.m4a',
        pdf,
      ]) {
        await File('${directory.path}/$name').writeAsString(name);
      }
    });
    await showHistory(tester);
    api.reply(0, cases([caseA]));
    await flush(tester);
    await tester.tap(find.byTooltip('클라우드 사고 삭제'));
    await flush(tester);
    await tester.tap(find.text('삭제 요청'));
    await flush(tester);
    expect(File('${directory.path}/blackbox_$caseA.mp4').existsSync(), isTrue);
    api.reply(1, {'case_id': caseA, 'status': 'delete_requested'}, 202);
    await flush(tester);
    expect(find.text('Case $caseA'), findsNothing);
    expect(File('${directory.path}/blackbox_$caseA.mp4').existsSync(), isFalse);
    expect(File('${directory.path}/accident_${caseA}_123.m4a').existsSync(),
        isFalse);
    expect(File('${directory.path}/accident_${caseB}_123.m4a').existsSync(),
        isTrue);
    expect(File('${directory.path}/$pdf').existsSync(), isTrue);
    await tester.tap(find.text('내보낸 PDF'));
    await flush(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await flush(tester);
    await tester.tap(find.text('삭제'));
    await flush(tester);
    expect(File('${directory.path}/$pdf').existsSync(), isFalse);
  });

  testWidgets('local cleanup failure warns without restoring accepted case',
      (tester) async {
    await showHistory(tester);
    api.reply(0, cases([caseA]));
    await flush(tester);
    await tester.tap(find.byTooltip('클라우드 사고 삭제'));
    await flush(tester);
    await tester.tap(find.text('삭제 요청'));
    await flush(tester);
    documents = () async => throw const FileSystemException('denied');
    api.reply(1, {'case_id': caseA, 'status': 'delete_requested'}, 202);
    await flush(tester);
    expect(find.text('Case $caseA'), findsNothing);
    expect(find.textContaining('로컬 영상'), findsOneWidget);
  });

  testWidgets(
      'accepted 202 cancels matching video after reports screen disposal',
      (tester) async {
    final mediaApi = DeferredHttp();
    final storage = DelayedStorage();
    final notifier = BlackboxVideoNotifier(
      evidenceService: BackendEvidenceService(
        apiDio: mediaApi.dio,
        storageDio: Dio()..httpClientAdapter = storage,
        accessToken: () async => 'token',
      ),
      ensureOwnedCase: (_) async {},
      principal: () => authenticatedPrincipal(auth.state),
    );
    await showHistory(tester, videoNotifier: notifier);
    final download = notifier.fetchAndDownload(caseA);
    await flush(tester);
    await mediaApi.waitForCount(1);
    mediaApi.reply(0, originalFiles(caseA));
    await flush(tester);
    await mediaApi.waitForCount(2);
    api.reply(0, cases([caseA]));
    await flush(tester);
    await tester.tap(find.byTooltip('클라우드 사고 삭제'));
    await flush(tester);
    await tester.tap(find.text('삭제 요청'));
    await flush(tester);

    Navigator.of(tester.element(find.byType(MyReportsScreen))).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
    );
    await tester.pumpAndSettle();
    api.reply(1, {'case_id': caseA, 'status': 'delete_requested'}, 202);
    await flush(tester);
    mediaApi
        .reply(1, {'file_id': 'original', 'url': 'https://storage.test/video'});
    await download;

    expect(storage.started.isCompleted, isFalse);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains(caseA)),
      isEmpty,
    );
  });

  testWidgets('missing original video keeps final-step analysis disabled',
      (tester) async {
    final ownedApi = OwnedHttp();
    final service = CaseService(
      dio: ownedApi.dio,
      accessToken: () async => 'token',
      savedDevice: () async => (id: 'dev_a', name: 'A'),
      activeCase: () => null,
      onActiveCaseChanged: (_) {},
    );
    final evidence = BackendEvidenceService(
      apiDio: ownedApi.dio,
      storageDio: Dio()..httpClientAdapter = ImmediateStorage(),
      accessToken: () async => 'token',
    );
    final router = GoRouter(
      initialLocation: '/response',
      routes: [
        GoRoute(
          path: '/response',
          builder: (_, __) => const FirstResponseScreen(accidentId: caseA),
        ),
        GoRoute(
          path: '/analysis',
          name: 'analysis',
          builder: (_, state) => Text('analysis:${state.extra}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        caseServiceProvider.overrideWithValue(service),
        backendEvidenceServiceProvider.overrideWithValue(evidence),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await flush(tester);

    for (var step = 0; step < 2; step++) {
      await tester.tap(find.text('다음 단계'));
      await tester.pump();
    }

    expect(find.text('사진 촬영'), findsOneWidget);
    expect(find.text('추가 영상 촬영'), findsOneWidget);
    await tester.tap(find.text('다음 단계'));
    await tester.pump();

    expect(find.text('블랙박스 영상 확인'), findsOneWidget);
    expect(find.text('음성 녹취'), findsNothing);
    expect(find.textContaining('디지털 타임스탬프'), findsNothing);
    expect(find.text('AI 과실 분석 시작'), findsOneWidget);

    await tester.tap(find.text('AI 과실 분석 시작'));
    await tester.pumpAndSettle();

    expect(find.text('analysis:$caseA'), findsNothing);
    expect(find.text('원본 영상 준비 대기 중'), findsOneWidget);
    expect(find.text('최신 수신 영상 보기'), findsOneWidget);
  });

  for (final succeeds in [false, true]) {
    testWidgets(
        'camera upload ${succeeds ? 'success removes' : 'failure retains'} '
        'only app-owned scoped photo', (tester) async {
      late File source;
      await tester.runAsync(() async {
        final camera =
            await Directory('${directory.path}/picker-cache').create();
        source =
            await File('${camera.path}/camera.jpg').writeAsBytes([1, 2, 3, 4]);
      });
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      const secure =
          MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      const recorder = MethodChannel('com.llfbandit.record/messages');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(picker, (_) async => source.path);
      messenger.setMockMethodCallHandler(secure, (_) async => null);
      messenger.setMockMethodCallHandler(recorder, (_) async => null);
      documents = () async => directory.path;
      messenger.setMockMethodCallHandler(
          paths,
          (call) async => call.method == 'getTemporaryDirectory'
              ? '${directory.path}/picker-cache'
              : directory.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(picker, null);
        messenger.setMockMethodCallHandler(secure, null);
        messenger.setMockMethodCallHandler(recorder, null);
      });
      api = OwnedHttp();
      final service = CaseService(
        dio: api.dio,
        accessToken: () async => 'token',
        savedDevice: () async => (id: 'dev_a', name: 'A'),
        activeCase: () => null,
        onActiveCaseChanged: (_) {},
      );
      final evidence = BackendEvidenceService(
        apiDio: api.dio,
        storageDio: Dio()..httpClientAdapter = ImmediateStorage(),
        accessToken: () async => 'token',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          caseServiceProvider.overrideWithValue(service),
          backendEvidenceServiceProvider.overrideWithValue(evidence),
        ],
        child: const MaterialApp(home: FirstResponseScreen(accidentId: caseA)),
      ));
      await flush(tester);
      await tester.tap(find.text('다음 단계'));
      await tester.pump();
      await tester.tap(find.text('다음 단계'));
      await tester.pump();
      await tester.tap(find.text('사진 촬영'));
      await flush(tester);
      await flush(tester);
      expect(api.requests, hasLength(1));
      if (succeeds) {
        api.reply(
            0,
            {
              'upload_id': 'upload_photo',
              'put_url': 'https://storage.test/photo',
              'required_headers': {
                'Content-Type': 'image/jpeg',
                'Content-Length': '4'
              },
            },
            201);
        await flush(tester);
        await flush(tester);
        expect(api.requests, hasLength(2));
        api.reply(1, {
          'file': {
            'id': 'photo_one',
            'case_id': caseA,
            'kind': 'evidence_photo',
            'sha256':
                '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
            'size': 4,
            'mime': 'image/jpeg',
            'created_at': '2026-10-15T00:00:00Z',
          }
        });
      } else {
        api.reply(0, {'error': 'unavailable'}, 503);
      }
      await flush(tester);
      await flush(tester);
      final cached = directory.listSync().whereType<File>().toList();
      if (succeeds) {
        expect(cached, isEmpty);
        expect(source.existsSync(), isFalse);
      } else {
        expect(cached, hasLength(1));
        expect(cached.single.path,
            startsWith('${directory.path}/evidence_${caseA}_'));
        await tester.runAsync(() => LocalAppFiles.cleanupAccount(directory));
        expect(cached.single.existsSync(), isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await flush(tester);
    });
  }

  test('logout cancels an in-flight storage stream and cleans its partial file',
      () async {
    final storage = DelayedStorage();
    final evidence = BackendEvidenceService(
      apiDio: api.dio,
      storageDio: Dio()..httpClientAdapter = storage,
      accessToken: () async => auth.accessToken,
    );
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      backendEvidenceServiceProvider.overrideWithValue(evidence),
      caseServiceProvider.overrideWithValue(CaseService(
        dio: api.dio,
        accessToken: () async => auth.accessToken,
        savedDevice: () async => (id: 'dev_a', name: 'A'),
        activeCase: () => null,
        onActiveCaseChanged: (_) {},
      )),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(blackboxVideoProvider.notifier);
    final pending = notifier.fetchAndDownload(caseA);
    await api.waitForCount(1);
    api.reply(0, {'case': caseJson(caseA)});
    await api.waitForCount(2);
    api.reply(1, originalFiles(caseA));
    await api.waitForCount(3);
    api.reply(2, {'file_id': 'original', 'url': 'https://storage.test/video'});
    await storage.started.future;
    storage.chunks.add(Uint8List.fromList([1, 2]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final publishedEarly =
        File('${directory.path}/blackbox_$caseA.mp4').existsSync();
    await LocalAppFiles.cleanupAccount(directory);
    auth.signOut();
    // A transport can still deliver buffered data after cancellation.
    storage.chunks.add(Uint8List.fromList([3, 4]));
    await storage.chunks.close();
    await pending;
    expect(publishedEarly, isFalse);
    expect(storage.cancelled, isTrue);
    expect(container.read(blackboxVideoProvider).status, VideoStatus.waiting);
    expect(await directory.list().toList(), isEmpty);
  });

  test('account cleanup blocks late publication before auth state changes',
      () async {
    final storage = DelayedStorage();
    final service = BackendEvidenceService(
      apiDio: api.dio,
      storageDio: Dio()..httpClientAdapter = storage,
      accessToken: () async => 'token',
    );
    final pending = service.downloadOriginalVideo(
      caseId: caseA,
      savePath: '${directory.path}/blackbox_$caseA.mp4',
    );
    final outcome = expectLater(pending, throwsA(isA<DioException>()));
    await api.waitForCount(1);
    api.reply(0, originalFiles(caseA));
    await api.waitForCount(2);
    api.reply(1, {'file_id': 'original', 'url': 'https://storage.test/video'});
    await storage.started.future;
    await LocalAppFiles.cleanupAccount(directory);
    storage.chunks.add(Uint8List.fromList([1, 2, 3, 4]));
    await storage.chunks.close();
    await outcome;
    expect(await directory.list().toList(), isEmpty);
  });
}

const caseA = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const caseB = 'case_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const caseC = 'case_cccccccccccccccccccccccccccccccc';

Map<String, Object?> caseJson(String id) => {
      'id': id,
      'device_id': 'dev_a',
      'title': 'Case $id',
      'status': 'created',
      'created_at': '2026-10-15T00:00:00Z',
    };

Map<String, Object?> cases(List<String> ids, {String? next}) => {
      'cases': ids.map(caseJson).toList(),
      'next_cursor': next,
    };

Map<String, Object?> reports(String caseId, int version) => {
      'reports': [
        {
          'id': 'report_$version',
          'case_id': caseId,
          'version': version,
          'text': 'Report $version',
          'created_at': '2026-10-15T00:00:00Z',
          'analysis': <String, Object?>{},
        }
      ],
      'next_cursor': null,
    };

Map<String, Object?> reportsFor(
  String caseId,
  List<(int, String)> versions,
) =>
    {
      'reports': [
        for (final version in versions)
          {
            'id': 'report_${version.$1}',
            'case_id': caseId,
            'version': version.$1,
            'text': version.$2,
            'created_at': '2026-10-15T00:00:00Z',
            'analysis': <String, Object?>{},
          }
      ],
      'next_cursor': null,
    };

Map<String, Object?> originalFiles(String caseId) => {
      'files': [
        {
          'id': 'original',
          'case_id': caseId,
          'kind': 'original_video',
          'sha256': 'a' * 64,
          'size': 4,
          'mime': 'video/mp4',
          'created_at': '2026-10-15T00:00:00Z',
        }
      ],
      'next_cursor': null,
    };

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class TestAuth extends AuthNotifier {
  TestAuth()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
          initialAccessToken: 'token',
          cleanupLocalFiles: () async {},
        );

  void loginAs(String email) => state = AuthState(
        status: AuthStatus.authenticated,
        email: email,
      );

  void signOut() => state = const AuthState(status: AuthStatus.unauthenticated);
}

class DeferredHttp implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final pending = <Completer<ResponseBody>>[];
  final _changed = StreamController<void>.broadcast(sync: true);

  Dio get dio =>
      Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = this;

  Future<void> waitForCount(int count) async {
    while (requests.length < count) {
      await _changed.stream.first.timeout(const Duration(seconds: 3));
    }
  }

  void reply(int index, Map<String, Object?> data, [int status = 200]) {
    final response = pending[index];
    if (response.isCompleted) return;
    response.complete(ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    ));
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    final result = Completer<ResponseBody>();
    pending.add(result);
    cancelFuture?.then((_) {
      if (!result.isCompleted) {
        result.completeError(DioException.requestCancelled(
          requestOptions: options,
          reason: 'cancelled by test client',
        ));
      }
    });
    _changed.add(null);
    return result.future;
  }

  @override
  void close({bool force = false}) {}
}

class DelayedStorage implements HttpClientAdapter {
  final started = Completer<void>();
  final chunks = StreamController<Uint8List>();
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    cancelFuture?.then((_) => cancelled = true);
    started.complete();
    return ResponseBody(chunks.stream, 200, headers: {
      Headers.contentLengthHeader: ['4']
    });
  }

  @override
  void close({bool force = false}) {}
}

class OwnedHttp extends DeferredHttp {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method != 'GET') {
      return super.fetch(options, requestStream, cancelFuture);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': options.path.endsWith('/files')
            ? {'files': [], 'next_cursor': null}
            : {'case': caseJson(caseA)},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }
}

class ImmediateStorage implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await requestStream?.drain<void>();
    return ResponseBody.fromBytes([], 200);
  }

  @override
  void close({bool force = false}) {}
}
