import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blackbox_driver_care/screens/auth/login_screen.dart';
import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('blank and invalid emails show a prompt without a request',
      (tester) async {
    final adapter = await _showLogin(tester);

    await tester.tap(find.text('로그인').last);
    await tester.pump();
    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.tap(find.text('로그인').last);
    await tester.pump();
    expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('blank login password shows a prompt without a request',
      (tester) async {
    final adapter = await _showLogin(tester);

    await tester.enterText(find.byType(TextField).first, 'driver@example.com');
    await tester.tap(find.text('로그인').last);
    await tester.pump();

    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('login submits an existing one-character password',
      (tester) async {
    final adapter = await _showLogin(tester);

    await tester.enterText(find.byType(TextField).first, 'driver@example.com');
    await tester.enterText(find.byType(TextField).last, 'x');
    await tester.tap(find.text('로그인').last);
    await tester.pumpAndSettle();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/api/v1/auth/login');
    expect(_body(adapter.requests.single), {
      'email': 'driver@example.com',
      'password': 'x',
    });
  });

  testWidgets('signup requires a name without sending a request',
      (tester) async {
    final adapter = await _showSignup(tester);
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), 'driver@example.com');
    await tester.enterText(fields.at(2), 'password');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('signup rejects values beyond the backend email and name bounds',
      (tester) async {
    final adapter = await _showSignup(tester);
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), '${'a' * 317}@b.c');
    await tester.enterText(fields.at(1), 'Driver');
    await tester.enterText(fields.at(2), 'password');
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(find.text('이메일은 320자 이하로 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);

    await tester.enterText(fields.at(0), 'driver@example.com');
    await tester.enterText(fields.at(1), 'n' * 256);
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(find.text('이름은 255자 이하로 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('signup rejects passwords outside 8 through 1024 characters',
      (tester) async {
    final adapter = await _showSignup(tester);
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), 'driver@example.com');
    await tester.enterText(fields.at(1), 'Driver');
    await tester.enterText(fields.at(2), '1234567');
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(find.text('비밀번호는 8자 이상 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);

    await tester.enterText(fields.at(2), 'p' * 1025);
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(find.text('비밀번호는 1024자 이하로 입력해 주세요.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('signup accepts the backend lower and upper bounds',
      (tester) async {
    final lowerAdapter = await _showSignup(tester);
    var fields = find.byType(TextField);

    await tester.enterText(fields.at(0), '${'a' * 316}@b.c');
    await tester.enterText(fields.at(1), 'n' * 255);
    await tester.enterText(fields.at(2), 'p' * 8);
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(lowerAdapter.requests, hasLength(1));
    expect(lowerAdapter.requests.single.path, '/api/v1/auth/signup');

    final upperAdapter = await _showSignup(tester);
    fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'driver@example.com');
    await tester.enterText(fields.at(1), 'Driver');
    await tester.enterText(fields.at(2), 'p' * 1024);
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(upperAdapter.requests, hasLength(1));
    expect(upperAdapter.requests.single.path, '/api/v1/auth/signup');
  });
}

Future<_RecordingAdapter> _showLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final adapter = _RecordingAdapter();
  final dio = Dio(BaseOptions(
    baseUrl: 'http://example.test',
    validateStatus: (status) => status != null && status < 500,
  ))
    ..httpClientAdapter = adapter;
  final auth = AuthNotifier(
    dio: dio,
    tokenStore: MemoryAuthStore(),
    restoreSession: false,
  );
  addTearDown(dio.close);

  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [authProvider.overrideWith((_) => auth)],
    child: const MaterialApp(home: LoginScreen()),
  ));
  await tester.pump();
  return adapter;
}

Future<_RecordingAdapter> _showSignup(WidgetTester tester) async {
  final adapter = await _showLogin(tester);
  await tester.tap(find.textContaining('회원가입', findRichText: true));
  await tester.pump();
  return adapter;
}

Map<String, dynamic> _body(RequestOptions request) => request.data is String
    ? Map<String, dynamic>.from(jsonDecode(request.data as String) as Map)
    : Map<String, dynamic>.from(request.data as Map);

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'message': 'fixture rejection'}
      }),
      400,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
