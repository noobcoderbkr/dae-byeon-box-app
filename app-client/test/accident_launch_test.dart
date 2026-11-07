import 'package:blackbox_driver_care/main.dart';
import 'package:blackbox_driver_care/router/app_router.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/case_service.dart';
import 'package:blackbox_driver_care/services/consent_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _caseId = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  for (final failFirstRead in [false, true]) {
    testWidgets(
        'cold and repeated notification taps open countdown (retry=$failFirstRead)',
        (tester) async {
      var initialReads = 0;
      var permissionRequests = 0;
      const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
      const notifications =
          MethodChannel('dexterous.com/flutter/local_notifications');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(messaging,
          (call) async {
        if (call.method == 'Messaging#getInitialMessage') {
          initialReads++;
          if (failFirstRead && initialReads == 1) {
            throw PlatformException(code: 'launch_message_not_ready');
          }
          return {
            'messageId': 'cold-accident',
            'data': {'type': 'accident', 'case_id': _caseId},
          };
        }
        if (call.method == 'Messaging#requestPermission') {
          permissionRequests++;
          return {'authorizationStatus': 1};
        }
        if (call.method == 'Messaging#getToken') return <String, String>{};
        return null;
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          notifications,
          (call) async => call.method == 'initialize' ? true : null);
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(messaging, null);
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(notifications, null);
      });

      final auth = _StartupAuth();
      final consent = _StartupConsent();
      final cases = _OwnedCases();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('Home')),
        GoRoute(
          path: '/first-response',
          name: 'first-response',
          builder: (_, state) => Text('First response: ${state.extra}'),
        ),
        GoRoute(
          path: '/accident-detected',
          name: 'accident-detected',
          builder: (_, state) => Text('Countdown: ${state.extra}'),
        ),
      ]);
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith((_) => auth),
        consentControllerProvider.overrideWith((_) => consent),
        caseServiceProvider.overrideWithValue(cases),
        appRouterProvider.overrideWithValue(router),
      ]);
      addTearDown(() {
        container.dispose();
        router.dispose();
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const BlackboxApp(),
      ));
      await _pumpEvents(tester);

      expect(initialReads, 1);
      expect(permissionRequests, 0);
      expect(cases.selected, isEmpty);
      auth.authenticate();
      await _pumpEvents(tester);
      expect(cases.selected, isEmpty);
      consent.grant();
      await _pumpEvents(tester);
      expect(
          router.routeInformationProvider.value.uri.path, '/accident-detected');
      expect(find.text('Countdown: $_caseId'), findsOneWidget);
      expect(find.text('First response: $_caseId'), findsNothing);
      expect(cases.selected, [_caseId]);
      expect(initialReads, failFirstRead ? 2 : 1);

      router.go('/');
      await _pumpEvents(tester);
      FirebaseMessagingPlatform.onMessageOpenedApp.add(const RemoteMessage(
        messageId: 'later-accident',
        data: {'type': 'accident', 'case_id': _caseId},
      ));
      await _pumpEvents(tester);
      expect(
          router.routeInformationProvider.value.uri.path, '/accident-detected');
      expect(cases.selected, [_caseId, _caseId]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<void> _pumpEvents(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _StartupAuth extends AuthNotifier {
  _StartupAuth() : super(restoreSession: false, tokenStore: MemoryAuthStore());

  void authenticate() => state = const AuthState(
        status: AuthStatus.authenticated,
        email: 'driver@example.com',
      );
}

class _StartupConsent extends ConsentController {
  _StartupConsent()
      : super(service: ConsentService(accessToken: () async => null)) {
    state = const ConsentState(status: ConsentLoadStatus.loading);
  }

  void grant() => state = const ConsentState(
        status: ConsentLoadStatus.ready,
        snapshot: ConsentSnapshot(version: 'test', grants: {
          ConsentDocument.privacy: true,
          ConsentDocument.location: true,
        }),
      );
}

class _OwnedCases extends Fake implements CaseService {
  final selected = <String>[];

  @override
  Future<BackendCase> selectOwnedCase(String caseId) async {
    selected.add(caseId);
    return BackendCase(
      id: caseId,
      deviceId: 'device_test',
      title: 'Accident',
      status: 'uploaded',
      createdAt: DateTime.utc(2026, 10, 17),
    );
  }
}
