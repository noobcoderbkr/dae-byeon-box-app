import 'dart:async';

import 'package:blackbox_driver_care/screens/mypage/mypage_screen.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/device_service.dart';
import 'package:blackbox_driver_care/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret = 'real-device-credential-must-not-be-rendered';

class _Devices extends DeviceService {
  _Devices(super.ref);

  ({String name, String serverUrl, String position})? connectCall;
  DeviceRegistration? registrationResult =
      const DeviceRegistration(deviceId: 'dev_owned', deviceName: 'My camera');
  DeviceConnection? connectionResult;
  DeviceConnectionException? connectionError;
  ({String? id, String? name}) saved = (id: null, name: null);
  Future<({String? id, String? name})>? pendingSaved;
  Future<DeviceRegistration?>? pendingRegistration;

  @override
  Future<({String? id, String? name})> savedDevice() async {
    final pending = pendingSaved;
    if (pending != null) return await pending;
    return saved;
  }

  @override
  Future<DeviceRegistration?> registerDevice(String name) async =>
      pendingRegistration != null
          ? await pendingRegistration
          : registrationResult == null
              ? null
              : DeviceRegistration(deviceId: 'dev_owned', deviceName: name);

  @override
  Future<DeviceConnection?> connectDevice(
      String name, String serverUrl, String position) async {
    connectCall = (name: name, serverUrl: serverUrl, position: position);
    if (connectionError != null) throw connectionError!;
    return connectionResult;
  }

  @override
  Future<DeviceConnection?> fetchConnection() async => connectionResult;
}

class _Profile extends ProfileService {
  @override
  Future<UserProfile?> fetchProfile() async =>
      const UserProfile(displayName: 'Test');

  @override
  Future<bool> pingServer() async => true;
}

class _UiAuth extends AuthNotifier {
  _UiAuth()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
          initialAccessToken: 'access-token',
        );

  int _generation = 0;

  @override
  int get sessionGeneration => _generation;

  void loginAs(String email) {
    _generation++;
    state = AuthState(
      status: AuthStatus.authenticated,
      email: email,
      name: email,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_Devices> showMypage(
    WidgetTester tester, {
    Size size = const Size(1000, 2400),
    void Function(_Devices devices)? configure,
    AuthNotifier? auth,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    late _Devices devices;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((_) =>
            auth ??
            AuthNotifier(
              restoreSession: false,
              tokenStore: MemoryAuthStore(),
            )),
        profileServiceProvider.overrideWith((_) => _Profile()),
        deviceServiceProvider.overrideWith((ref) {
          devices = _Devices(ref);
          configure?.call(devices);
          return devices;
        }),
      ],
      child: const MaterialApp(home: MypageScreen()),
    ));
    await tester.pumpAndSettle();
    return devices;
  }

  Future<void> openDeviceActions(WidgetTester tester) async {
    final action = find.text('설정').evaluate().isNotEmpty
        ? find.text('설정')
        : find.text('등록');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'connection flow offers server URL and explicit front/rear choice',
      (tester) async {
    final devices = await showMypage(tester, size: const Size(390, 844));
    devices.connectionResult = const DeviceConnection(
      deviceId: 'dev_rear',
      deviceName: 'Rear camera',
      serverUrl: 'https://project-box.life',
      sourceDeviceId: 'violet-dashcam-2',
      position: 'rear',
    );

    await openDeviceActions(tester);
    expect(find.text('서버 연결'), findsOneWidget);
    expect(find.text('이름만 등록'), findsOneWidget);
    await tester.tap(find.text('서버 연결'));
    await tester.pumpAndSettle();

    expect(find.text('전방'), findsOneWidget);
    expect(find.text('후방'), findsOneWidget);
    final serverField = tester
        .widgetList<TextField>(find.byType(TextField))
        .singleWhere((field) => field.decoration?.labelText == '수집 서버');
    expect(serverField.controller?.text, 'https://project-box.life');
    expect(find.text('기기 토큰'), findsNothing);
    await tester.tap(find.text('후방'));
    await tester.tap(find.text('연결'));
    await tester.pumpAndSettle();

    expect(devices.connectCall, isNotNull);
    expect(devices.connectCall!.serverUrl, 'https://project-box.life');
    expect(devices.connectCall!.position, 'rear');
    expect(find.text('후방 · https://project-box.life'), findsOneWidget);
    expect(find.text('블랙박스가 영상 수신 서버에 연결되었습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old saved-device completion is ignored after owner switch',
      (tester) async {
    final saved = Completer<({String? id, String? name})>();
    final auth = _UiAuth()..loginAs('first@example.com');
    await showMypage(
      tester,
      auth: auth,
      configure: (devices) => devices.pendingSaved = saved.future,
    );

    auth.loginAs('second@example.com');
    saved.complete((id: 'dev_old_owner', name: 'Old owner camera'));
    await tester.pumpAndSettle();

    expect(find.text('Old owner camera'), findsNothing);
    expect(find.text('등록된 블랙박스 없음'), findsOneWidget);
  });

  testWidgets('old-owner delayed registration is not published by MyPage',
      (tester) async {
    final registration = Completer<DeviceRegistration?>();
    final auth = _UiAuth()..loginAs('first@example.com');
    await showMypage(
      tester,
      auth: auth,
      configure: (devices) => devices.pendingRegistration = registration.future,
    );

    await openDeviceActions(tester);
    await tester.tap(find.text('이름만 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '등록'));
    await tester.pump();
    auth.loginAs('second@example.com');
    registration.complete(const DeviceRegistration(
      deviceId: 'dev_old_owner',
      deviceName: 'Old owner camera',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Old owner camera'), findsNothing);
    expect(find.text('기기가 등록되었습니다. 영상 수신 연결은 별도 설정이 필요합니다.'), findsNothing);
  });

  testWidgets('failed connection keeps the existing device and reports failure',
      (tester) async {
    await showMypage(
      tester,
      configure: (devices) =>
          devices.saved = (id: 'dev_existing', name: 'Existing dashcam'),
    );

    await openDeviceActions(tester);
    await tester.tap(find.text('서버 연결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전방'));
    await tester.tap(find.text('연결'));
    await tester.pumpAndSettle();

    expect(find.text('Existing dashcam'), findsOneWidget);
    expect(find.text('서버 연결에 실패했습니다. 설정과 계정 권한을 확인해 주세요.'), findsOneWidget);
    expect(find.text('블랙박스가 영상 수신 서버에 연결되었습니다.'), findsNothing);
  });

  for (final failure in <DeviceConnectionFailure, String>{
    DeviceConnectionFailure.authenticationRequired:
        '로그인이 만료되었습니다. 다시 로그인해 주세요.',
    DeviceConnectionFailure.operatorApprovalRequired:
        '운영자 승인이 필요한 블랙박스입니다. 승인 후 다시 연결해 주세요.',
    DeviceConnectionFailure.invalidConfiguration:
        '수집 서버 주소와 카메라 위치 설정을 확인해 주세요.',
    DeviceConnectionFailure.networkOffline:
        '네트워크에 연결할 수 없습니다. 인터넷 연결을 확인해 주세요.',
  }.entries) {
    testWidgets('connection displays ${failure.key.name} failure',
        (tester) async {
      await showMypage(
        tester,
        configure: (devices) => devices.connectionError =
            DeviceConnectionException(failure.key, failure.value),
      );

      await openDeviceActions(tester);
      await tester.tap(find.text('서버 연결'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('연결'));
      await tester.pumpAndSettle();

      expect(find.text(failure.value), findsOneWidget);
      expect(find.text('블랙박스가 영상 수신 서버에 연결되었습니다.'), findsNothing);
    });
  }

  testWidgets('registration does not render or copy a device credential',
      (tester) async {
    await showMypage(tester);
    await openDeviceActions(tester);
    await tester.tap(find.text('이름만 등록'));
    await tester.pumpAndSettle();
    final dialogRegister = find.descendant(
        of: find.byType(AlertDialog), matching: find.text('등록'));
    await tester.tap(dialogRegister);
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsNothing);
    expect(find.text('기기 토큰'), findsNothing);
    expect(find.text('기기가 등록되었습니다. 영상 수신 연결은 별도 설정이 필요합니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
