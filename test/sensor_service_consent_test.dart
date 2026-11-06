import 'dart:async';

import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/case_service.dart';
import 'package:blackbox_driver_care/services/consent_service.dart';
import 'package:blackbox_driver_care/services/sensor_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'grant then start then revoke stops monitoring and blocks every impact side effect',
      (tester) async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(accelerometer.close);
    final consent = _MutableConsentController(granted: true);
    final cases = _DelayedCaseService();
    final platformCalls = <MethodCall>[];
    const notification =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    for (final channel in [notification, geolocator, launcher]) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          platformCalls.add(call);
          return false;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
    }
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuth()),
      consentControllerProvider.overrideWith((ref) => consent),
      caseServiceProvider.overrideWithValue(cases),
    ]);
    addTearDown(container.dispose);
    final provider = Provider<SensorNotifier>((ref) => SensorNotifier(
          ref,
          accelerometerEvents: accelerometer.stream,
        ));
    final sensor = container.read(provider);

    sensor.startMonitoring();
    expect(sensor.state.isMonitoring, isTrue);
    consent.revoke();
    expect(sensor.state.isMonitoring, isFalse);

    accelerometer.add(AccelerometerEvent(30, 0, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));

    expect(sensor.state.currentGForce, 0);
    expect(sensor.state.isImpactDetected, isFalse);
    expect(sensor.state.caseId, isNull);
    expect(cases.resolveCalls, 0);
    expect(platformCalls, isEmpty);
  });

  testWidgets(
      'revocation during case creation blocks late publication and alerts',
      (tester) async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(accelerometer.close);
    final consent = _MutableConsentController(granted: true);
    final cases = _DelayedCaseService();
    final notificationCalls = <MethodCall>[];
    const notification =
        MethodChannel('dexterous.com/flutter/local_notifications');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      notification,
      (call) async {
        notificationCalls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(notification, null));
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuth()),
      consentControllerProvider.overrideWith((ref) => consent),
      caseServiceProvider.overrideWithValue(cases),
    ]);
    addTearDown(container.dispose);
    final provider = Provider<SensorNotifier>((ref) => SensorNotifier(
          ref,
          accelerometerEvents: accelerometer.stream,
        ));
    final sensor = container.read(provider)..startMonitoring();

    accelerometer.add(AccelerometerEvent(30, 0, 0));
    await tester.pump();
    expect(cases.resolveCalls, 1);
    consent.revoke();
    cases.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));

    expect(sensor.state.isMonitoring, isFalse);
    expect(sensor.state.isImpactDetected, isFalse);
    expect(sensor.state.caseId, isNull);
    expect(notificationCalls, isEmpty);
  });

  test('auth revocation stops monitoring before another sensor callback',
      () async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(accelerometer.close);
    final auth = _SignedInAuth();
    final consent = _MutableConsentController(granted: true);
    final cases = _DelayedCaseService();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      consentControllerProvider.overrideWith((ref) => consent),
      caseServiceProvider.overrideWithValue(cases),
    ]);
    addTearDown(container.dispose);
    final provider = Provider<SensorNotifier>((ref) => SensorNotifier(
          ref,
          accelerometerEvents: accelerometer.stream,
        ));
    final sensor = container.read(provider)..startMonitoring();

    auth.revoke();
    accelerometer.add(AccelerometerEvent(30, 0, 0));
    await Future<void>.delayed(Duration.zero);

    expect(sensor.state, isA<SensorState>());
    expect(sensor.state.isMonitoring, isFalse);
    expect(sensor.state.currentGForce, 0);
    expect(cases.resolveCalls, 0);
  });

  for (final loss in ['consent', 'auth']) {
    testWidgets('$loss recovery resumes the same monitor and detects impact',
        (tester) async {
      final accelerometer = StreamController<AccelerometerEvent>.broadcast();
      addTearDown(accelerometer.close);
      final auth = _SignedInAuth();
      final consent = _MutableConsentController(granted: true);
      final cases = _DelayedCaseService();
      final notifications = <MethodCall>[];
      const channel =
          MethodChannel('dexterous.com/flutter/local_notifications');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        notifications.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith((ref) => auth),
        consentControllerProvider.overrideWith((ref) => consent),
        caseServiceProvider.overrideWithValue(cases),
        sensorProvider.overrideWith((ref) => SensorNotifier(
              ref,
              accelerometerEvents: accelerometer.stream,
            )..startMonitoring()),
      ]);
      addTearDown(container.dispose);
      final sensor = container.read(sensorProvider.notifier);
      expect(container.read(sensorProvider).isMonitoring, isTrue);

      if (loss == 'consent') {
        consent.revoke();
      } else {
        auth.revoke();
      }
      expect(container.read(sensorProvider).isMonitoring, isFalse);
      if (loss == 'consent') {
        consent.grant();
      } else {
        auth.signIn();
      }
      expect(container.read(sensorProvider.notifier), same(sensor));
      expect(container.read(sensorProvider).isMonitoring, isTrue);

      accelerometer.add(AccelerometerEvent(30, 0, 0));
      await tester.pump();
      expect(cases.resolveCalls, 1);
      cases.complete();
      await tester.pump();
      expect(container.read(sensorProvider).isImpactDetected, isTrue);
      expect(container.read(sensorProvider).caseId,
          'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(notifications.single.method, 'show');
      sensor.dismissAlert();
      await tester.pump(const Duration(seconds: 11));
    });
  }

  testWidgets('regrant keeps pre-revocation case completion fenced',
      (tester) async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(accelerometer.close);
    final consent = _MutableConsentController(granted: true);
    final cases = _DelayedCaseService();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuth()),
      consentControllerProvider.overrideWith((ref) => consent),
      caseServiceProvider.overrideWithValue(cases),
      sensorProvider.overrideWith((ref) => SensorNotifier(
            ref,
            accelerometerEvents: accelerometer.stream,
          )..startMonitoring()),
    ]);
    addTearDown(container.dispose);

    container.read(sensorProvider);
    accelerometer.add(AccelerometerEvent(30, 0, 0));
    await tester.pump();
    expect(cases.resolveCalls, 1);
    consent.revoke();
    consent.grant();
    expect(container.read(sensorProvider).isMonitoring, isTrue);
    cases.complete();
    await tester.pump();

    expect(container.read(sensorProvider).isImpactDetected, isFalse);
    expect(container.read(sensorProvider).caseId, isNull);
  });

  test('authorized updates and regrant preserve an explicit manual stop',
      () async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(accelerometer.close);
    final auth = _SignedInAuth();
    final consent = _MutableConsentController(granted: true);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => auth),
      consentControllerProvider.overrideWith((ref) => consent),
      sensorProvider.overrideWith((ref) => SensorNotifier(
            ref,
            accelerometerEvents: accelerometer.stream,
          )..startMonitoring()),
    ]);
    addTearDown(container.dispose);
    final sensor = container.read(sensorProvider.notifier);
    sensor.stopMonitoring();
    consent.grant();
    auth.signIn();
    expect(container.read(sensorProvider).isMonitoring, isFalse);
    consent.revoke();
    consent.grant();
    expect(container.read(sensorProvider).isMonitoring, isFalse);
  });
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
    );
  }

  void revoke() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void signIn() {
    state = const AuthState(
      status: AuthStatus.authenticated,
      email: 'driver@example.com',
    );
  }
}

class _MutableConsentController extends ConsentController {
  _MutableConsentController({required bool granted})
      : super(service: ConsentService(accessToken: () async => 'token')) {
    _set(granted);
  }

  void revoke() => _set(false);
  void grant() => _set(true);

  void _set(bool granted) {
    state = ConsentState(
      status: ConsentLoadStatus.ready,
      snapshot: ConsentSnapshot(
        version: '2026-10-15',
        grants: {
          ConsentDocument.privacy: granted,
          ConsentDocument.location: granted,
          ConsentDocument.externalAi: false,
        },
      ),
    );
  }
}

class _DelayedCaseService extends CaseService {
  _DelayedCaseService()
      : super(
          dio: Dio(),
          accessToken: () async => 'token',
          savedDevice: () async => (id: 'dev_owned', name: 'Camera'),
          activeCase: () => null,
          onActiveCaseChanged: (_) {},
        );

  final _pending = Completer<BackendCase>();
  int resolveCalls = 0;

  @override
  Future<BackendCase> resolveForAccident({
    String? caseId,
    double? lat,
    double? lon,
    DateTime? occurredAt,
  }) {
    resolveCalls++;
    return _pending.future;
  }

  void complete() => _pending.complete(BackendCase(
        id: 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        deviceId: 'dev_owned',
        title: 'Impact',
        status: 'created',
        createdAt: DateTime.utc(2026, 10, 17),
      ));
}
