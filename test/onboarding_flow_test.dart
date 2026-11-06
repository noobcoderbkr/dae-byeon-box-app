import 'dart:async';

import 'package:blackbox_driver_care/router/app_router.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/consent_service.dart';
import 'package:blackbox_driver_care/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup waits for consent before routing a granted account home',
      (tester) async {
    final consent = _StartupConsentController();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/splash');

    consent.setLoading();
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/splash');

    consent.setReady(granted: true);
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('login waits on splash until persisted consent is known',
      (tester) async {
    final auth = _MutableAuth();
    final consent = _StartupConsentController();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        consentControllerProvider.overrideWith((ref) => consent),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/login');

    auth.authenticate();
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/splash');

    consent.setReady(granted: true);
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('consent load error opens retry instead of the app',
      (tester) async {
    final consent = _StartupConsentController();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpRouter(tester);
    consent.setError();
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/consents');
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(consent.loadCalls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/consents');
  });

  testWidgets('explicit consent management stays open for a granted account',
      (tester) async {
    final consent = _StartupConsentController()..setReady(granted: true);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/');

    router.go('/consents');
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/consents');
  });

  for (final status in [
    ConsentLoadStatus.loading,
    ConsentLoadStatus.error,
  ]) {
    testWidgets(
        'read-only account routes remain available when consent is ${status.name}',
        (tester) async {
      final consent = _StartupConsentController();
      if (status == ConsentLoadStatus.loading) {
        consent.setLoading();
      } else {
        consent.setError();
      }
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _SignedInAuth()),
          consentControllerProvider.overrideWith((ref) => consent),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await _pumpRouter(tester);

      router.go('/my-reports');
      await _pumpRouter(tester);
      expect(router.routeInformationProvider.value.uri.path, '/my-reports');

      router.go('/mypage');
      await _pumpRouter(tester);
      expect(router.routeInformationProvider.value.uri.path, '/mypage');
    });
  }

  test('consent updates keep the in-progress router instance', () async {
    final consent = _TestConsentController(granted: false);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
      ],
    );
    addTearDown(container.dispose);

    final before = container.read(appRouterProvider);
    await consent.setGrant(ConsentDocument.privacy, true);
    final after = container.read(appRouterProvider);

    expect(identical(after, before), isTrue);
  });

  testWidgets(
      'required choices are committed only by final submit and optional AI stays off',
      (tester) async {
    final saveGate = Completer<void>();
    final consent = _TestConsentController(granted: false, saveGate: saveGate);
    final profile = _TestProfileService();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
        profileServiceProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('필수 · 개인정보 처리'));
    await tester.tap(find.text('필수 · 위치정보 처리'));
    await tester.pump();

    expect(consent.updates, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/consents');

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(find.text('동의하고 계속'));
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '기존 기록 보기'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '계정 관리 및 삭제'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '로그아웃'))
          .onPressed,
      isNull,
    );

    saveGate.complete();
    await tester.pumpAndSettle();

    expect(consent.updates, [
      (ConsentDocument.privacy, true),
      (ConsentDocument.location, true),
    ]);
    expect(consent.state.canUseExternalAi, isFalse);
    expect(profile.fetchCount, greaterThanOrEqualTo(1));
    expect(router.routeInformationProvider.value.uri.path, '/profile-setup');
    expect(find.text('운전자 정보 등록'), findsOneWidget);
  });

  testWidgets(
      'required consent write failure stays editable and retry succeeds',
      (tester) async {
    final retryGate = Completer<void>();
    final consent = _TestConsentController(
      granted: false,
      failLocationOnce: true,
      locationRetryGate: retryGate,
    );
    final profile = _TestProfileService();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
        profileServiceProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('필수 · 개인정보 처리'));
    await tester.tap(find.text('필수 · 위치정보 처리'));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();

    expect(find.text('동의 저장에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/consents');
    expect(profile.fetchCount, 0);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(
              CheckboxListTile,
              '필수 · 개인정보 처리',
              skipOffstage: false,
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(
              CheckboxListTile,
              '필수 · 위치정보 처리',
              skipOffstage: false,
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '동의하고 계속'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('동의하고 계속'));
    await tester.pump();
    expect(find.text('동의 저장에 실패했습니다. 다시 시도해 주세요.'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/consents');
    retryGate.complete();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/profile-setup');
    expect(profile.fetchCount, greaterThanOrEqualTo(1));
    expect(find.text('운전자 정보 등록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location permission failure shows feedback and stays on consent',
      (tester) async {
    const permissionChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        throw PlatformException(code: 'permission_request_failed');
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null));

    final consent = _TestConsentController(granted: false);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pump();
    await tester.tap(find.text('위치 권한 요청'));
    await tester.pumpAndSettle();

    expect(find.textContaining('위치 권한을 요청하지 못했습니다'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/consents');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile setup validates and saves required onboarding fields',
      (tester) async {
    final consent = _TestConsentController(granted: true);
    final profile = _TestProfileService();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _SignedInAuth()),
        consentControllerProvider.overrideWith((ref) => consent),
        profileServiceProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider)..go('/profile-setup');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운전자 정보 등록'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '보험사'),
      '테스트손해보험',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '보험사 연락처'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '운전면허번호'),
      '   ',
    );
    await tester.tap(find.text('등록 완료'));
    await tester.pump();

    expect(profile.saveCount, 0);
    expect(router.routeInformationProvider.value.uri.path, '/profile-setup');

    await tester.enterText(
      find.widgetWithText(TextFormField, '보험사 연락처'),
      '1588-0000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '운전면허번호'),
      '12-34-567890-12',
    );
    await tester.tap(find.text('등록 완료'));
    await tester.pumpAndSettle();

    expect(profile.saveCount, 1);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });
}

Future<void> _pumpRouter(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _SignedInAuth extends AuthNotifier {
  _SignedInAuth()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
          initialAccessToken: 'token',
        ) {
    state = const AuthState(
      status: AuthStatus.authenticated,
      email: 'driver@example.com',
      name: 'Driver',
    );
  }
}

class _MutableAuth extends AuthNotifier {
  _MutableAuth()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
        ) {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void authenticate() {
    state = const AuthState(
      status: AuthStatus.authenticated,
      email: 'driver@example.com',
    );
  }
}

class _StartupConsentController extends ConsentController {
  _StartupConsentController() : super(service: _RecordingConsentService());

  int loadCalls = 0;

  void setLoading() {
    state = const ConsentState(status: ConsentLoadStatus.loading);
  }

  void setReady({required bool granted}) {
    state = ConsentState(
      status: ConsentLoadStatus.ready,
      policies: _policies,
      snapshot: ConsentSnapshot(
        version: _version,
        grants: {
          ConsentDocument.privacy: granted,
          ConsentDocument.location: granted,
          ConsentDocument.externalAi: false,
        },
      ),
    );
  }

  void setError() {
    state = const ConsentState(
      status: ConsentLoadStatus.error,
      error: '동의 정보를 불러오지 못했습니다.',
    );
  }

  @override
  Future<void> load() async {
    loadCalls++;
    setLoading();
  }
}

class _TestConsentController extends ConsentController {
  _TestConsentController({
    required bool granted,
    this.saveGate,
    this.failLocationOnce = false,
    this.locationRetryGate,
  })  : updates = [],
        super(service: _RecordingConsentService()) {
    state = ConsentState(
      status: ConsentLoadStatus.ready,
      policies: _policies,
      snapshot: ConsentSnapshot(
        version: _version,
        grants: {
          ConsentDocument.privacy: granted,
          ConsentDocument.location: granted,
          ConsentDocument.externalAi: false,
        },
      ),
    );
  }

  final List<(ConsentDocument, bool)> updates;
  final Completer<void>? saveGate;
  bool failLocationOnce;
  final Completer<void>? locationRetryGate;
  int _locationAttempts = 0;

  @override
  Future<void> setGrant(ConsentDocument document, bool granted) async {
    updates.add((document, granted));
    await saveGate?.future;
    if (document == ConsentDocument.location) {
      _locationAttempts++;
      if (failLocationOnce) {
        failLocationOnce = false;
        throw Exception('location write failed');
      }
      if (_locationAttempts > 1) await locationRetryGate?.future;
    }
    final snapshot = state.snapshot!;
    state = state.copyWith(
      snapshot: ConsentSnapshot(
        version: snapshot.version,
        grants: {...snapshot.grants, document: granted},
      ),
    );
  }
}

class _RecordingConsentService extends ConsentService {
  _RecordingConsentService() : super(accessToken: () async => 'token');
}

class _TestProfileService extends ProfileService {
  _TestProfileService() : super(accessToken: () async => 'token');

  int fetchCount = 0;
  int saveCount = 0;

  @override
  Future<UserProfile?> fetchProfile() async {
    fetchCount++;
    return null;
  }

  @override
  Future<UserProfile?> saveProfile({
    required String displayName,
    Object? phone,
    Object? licenseNumber,
    Object? licensePlate,
    Object? insuranceCompany,
    Object? policyNumber,
    Object? insurancePhone,
    Object? vehicleType,
  }) async {
    saveCount++;
    return UserProfile(
      displayName: displayName,
      licenseNumber: licenseNumber as String?,
      insuranceCompany: insuranceCompany as String?,
      insurancePhone: insurancePhone as String?,
    );
  }
}

const _version = '2026-10-15';

const _policies = PolicyBundle(
  version: _version,
  disclaimer: '참고용',
  documents: [
    PolicyDocument(
      document: ConsentDocument.privacy,
      version: _version,
      title: '개인정보 처리',
      text: '사고 자료 처리 안내',
      required: true,
    ),
    PolicyDocument(
      document: ConsentDocument.location,
      version: _version,
      title: '위치정보 처리',
      text: '위치정보 처리 안내',
      required: true,
    ),
    PolicyDocument(
      document: ConsentDocument.externalAi,
      version: _version,
      title: '외부 AI',
      text: '외부 AI 처리 안내',
      required: false,
    ),
  ],
);
