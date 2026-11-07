import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/profile_service.dart';
import 'package:blackbox_driver_care/services/local_files.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    _directory = await Directory.systemTemp.createTemp('task5-auth');
  });
  tearDown(() async {
    await _directory.delete(recursive: true);
  });
  test('expired JWT refreshes before an authenticated profile request',
      () async {
    final expired = _jwt(946684800);
    final fresh = _jwt(4102444800);
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/refresh') {
        expect(request.method, 'POST');
        expect(_body(request), {'refresh_token': 'refresh-old'});
        return _response(200, _tokens(fresh, 'refresh-new'));
      }
      expect(request.path, '/api/v1/profile');
      expect(request.headers['Authorization'], 'Bearer $fresh');
      return _response(200, {
        'data': {
          'profile': {'display_name': 'Driver'},
        },
      });
    });
    final store = MemoryAuthStore();
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      restoreSession: false,
      initialAccessToken: expired,
      initialRefreshToken: 'refresh-old',
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    final before = auth.state;
    final profile = ProfileService(
      dio: _dio(adapter),
      accessToken: auth.validAccessToken,
    );

    expect((await profile.fetchProfile())?.displayName, 'Driver');
    expect(auth.state, same(before));
    expect(store.values[authAccessKey], fresh);
    expect(store.values[authRefreshKey], 'refresh-new');
    expect(adapter.requests.map((request) => request.path), [
      '/api/v1/auth/refresh',
      '/api/v1/profile',
    ]);
  });

  test('concurrent expired token callers share one refresh request', () async {
    final gate = Completer<ResponseBody>();
    final fresh = _jwt(4102444800);
    final adapter = _Adapter((request) {
      expect(request.path, '/api/v1/auth/refresh');
      expect(_body(request), {'refresh_token': 'refresh-old'});
      return gate.future;
    });
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: MemoryAuthStore(),
      restoreSession: false,
      initialAccessToken: _jwt(946684800),
      initialRefreshToken: 'refresh-old',
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    addTearDown(() {
      if (!gate.isCompleted) {
        gate.complete(_response(200, _tokens(fresh, 'refresh-new')));
      }
    });
    final before = auth.state;
    final pending = List.generate(8, (_) => auth.validAccessToken());
    await pumpEventQueue();

    expect(adapter.requests, hasLength(1));
    gate.complete(_response(200, _tokens(fresh, 'refresh-new')));
    expect(await Future.wait(pending), List.filled(8, fresh));
    expect(auth.state, same(before));
  });

  test('unexpired JWT and opaque fixture tokens do not trigger refresh',
      () async {
    for (final token in [_jwt(4102444800), 'access-token', 'bad.%.token']) {
      final adapter = _Adapter((request) {
        fail('Unexpected HTTP request: ${request.path}');
      });
      final auth = AuthNotifier(
        dio: _dio(adapter),
        tokenStore: MemoryAuthStore(),
        restoreSession: false,
        initialAccessToken: token,
        initialRefreshToken: 'refresh-old',
        cleanupLocalFiles: _cleanupTempFiles,
      );
      expect(await auth.validAccessToken(), token);
      expect(adapter.requests, isEmpty);
      auth.dispose();
    }
  });

  for (final status in [401, 403]) {
    test(
        '$status refresh rejection clears the authenticated identity and private values',
        () async {
      final expired = _jwt(946684800);
      final adapter = _Adapter((request) {
        if (request.path == '/api/v1/auth/login') {
          return _response(200, _tokens(expired, 'refresh-old'));
        }
        if (request.path == '/api/v1/auth/me') {
          return _response(200, _user('first@example.com'));
        }
        expect(request.path, '/api/v1/auth/refresh');
        return _response(status, {
          'error': {'code': 'invalid_token'}
        });
      });
      final store = MemoryAuthStore();
      final auth = AuthNotifier(
        dio: _dio(adapter),
        tokenStore: store,
        restoreSession: false,
        cleanupLocalFiles: _cleanupTempFiles,
      );
      addTearDown(auth.dispose);
      expect(await _login(auth, 'first@example.com'), isTrue);
      store.values['license_number'] = 'private-license';
      store.values['insurance_phone'] = 'private-phone';

      expect(await auth.validAccessToken(), isNull);

      expect(auth.state.status, AuthStatus.unauthenticated);
      expect(auth.state.email, isNull);
      expect(auth.state.name, isNull);
      expect(auth.accessToken, isNull);
      expect(store.values, isEmpty);
    });
  }

  for (final failure in ['timeout', '503', '503 response']) {
    test('$failure refresh before deletion preserves session and private data',
        () async {
      final expired = _jwt(946684800);
      var cleanupCalls = 0;
      final adapter = _Adapter((request) {
        if (request.path == '/api/v1/auth/login') {
          return _response(200, _tokens(expired, 'refresh-old'));
        }
        if (request.path == '/api/v1/auth/me') {
          return _response(200, _user('first@example.com'));
        }
        expect(request.path, '/api/v1/auth/refresh');
        if (failure == 'timeout') {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _response(503, {
          'error': {'code': 'unavailable'},
        });
      });
      final dio = _dio(adapter);
      if (failure == '503 response') {
        dio.options.validateStatus = (_) => true;
      }
      final store = MemoryAuthStore();
      final auth = AuthNotifier(
        dio: dio,
        tokenStore: store,
        restoreSession: false,
        cleanupLocalFiles: () async {
          cleanupCalls++;
          await _cleanupTempFiles();
        },
      );
      addTearDown(auth.dispose);
      expect(await _login(auth, 'first@example.com'), isTrue);
      cleanupCalls = 0;
      store.values['license_number'] = 'private-license';
      store.values['insurance_phone'] = 'private-phone';
      final savedValues = Map<String, String>.from(store.values);
      final before = auth.state;
      final file = File('${_directory.path}/DriveGuard_private.pdf');
      await file.writeAsString('private report');

      final result = await auth.requestAccountDeletion('password');

      expect(result, AccountDeletionResult.failed);
      expect(cleanupCalls, 0);
      expect(auth.state.status, AuthStatus.authenticated);
      expect(auth.state, same(before));
      expect(auth.state.email, 'first@example.com');
      expect(auth.accessToken, expired);
      expect(store.values, savedValues);
      expect(await file.readAsString(), 'private report');
      expect(adapter.requests.where((request) => request.method == 'DELETE'),
          isEmpty);
      expect(
          adapter.requests
              .where((request) => request.path == '/api/v1/auth/refresh'),
          hasLength(1));
    });
  }

  test('failed session restoration clears previous user data before next login',
      () async {
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/me' &&
          request.headers['Authorization'] == 'Bearer previous-access') {
        return _response(401, {
          'error': {'code': 'invalid_token'}
        });
      }
      if (request.path == '/api/v1/auth/refresh') {
        return _response(401, {
          'error': {'code': 'invalid_token'}
        });
      }
      if (request.path == '/api/v1/auth/login') {
        return _response(200, _tokens('next-access', 'next-refresh'));
      }
      expect(request.path, '/api/v1/auth/me');
      return _response(200, _user('next@example.com'));
    });
    final store = MemoryAuthStore({
      authAccessKey: 'previous-access',
      authRefreshKey: 'previous-refresh',
      'license_number': 'previous-license',
      'insurance_phone': 'previous-phone',
      'registered_device_id': 'previous-device',
    });
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    await _waitForSignedOut(auth);

    expect(store.values, isEmpty);
    expect(await _login(auth, 'next@example.com'), isTrue);
    expect(auth.state.email, 'next@example.com');
    expect(store.values['license_number'], isNull);
    expect(store.values['insurance_phone'], isNull);
    expect(store.values['registered_device_id'], isNull);
  });

  test('changing authenticated principal clears the previous private values',
      () async {
    var principal = 'first@example.com';
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/login') {
        principal = _body(request)['email'] as String;
        return _response(
            200, _tokens('access-$principal', 'refresh-$principal'));
      }
      expect(request.path, '/api/v1/auth/me');
      return _response(200, _user(principal));
    });
    final store = MemoryAuthStore();
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      restoreSession: false,
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    expect(await _login(auth, 'first@example.com'), isTrue);
    store.values['license_number'] = 'first-license';
    store.values['insurance_phone'] = 'first-phone';
    store.values['registered_device_id'] = 'first-device';

    expect(await _login(auth, 'second@example.com'), isTrue);

    expect(auth.state.email, 'second@example.com');
    expect(store.values['license_number'], isNull);
    expect(store.values['insurance_phone'], isNull);
    expect(store.values['registered_device_id'], isNull);
    expect(store.values[authAccessKey], 'access-second@example.com');
  });

  test('confirmed 202 remains accepted and signed out when local cleanup fails',
      () async {
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/login') {
        return _response(200, _tokens('access', 'refresh'));
      }
      if (request.path == '/api/v1/auth/me') {
        return _response(200, _user('first@example.com'));
      }
      expect(request.path, '/api/v1/account');
      expect(request.method, 'DELETE');
      return _response(202, {
        'data': {'status': 'delete_requested'}
      });
    });
    final store = _FailingCleanupStore();
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      restoreSession: false,
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    expect(await _login(auth, 'first@example.com'), isTrue);
    store.failCleanup = true;

    expect(await auth.requestAccountDeletion('password'),
        AccountDeletionResult.accepted);
    expect(auth.state.status, AuthStatus.unauthenticated);
    expect(auth.state.email, isNull);
    expect(auth.state.name, isNull);
    expect(auth.accessToken, isNull);
    expect(auth.state.error, contains('로컬'));
    expect(await auth.requestAccountDeletion('password'),
        AccountDeletionResult.failed);
    expect(adapter.requests.where((request) => request.method == 'DELETE'),
        hasLength(1));
  });

  test('logout finalizes unauthenticated state despite cleanup exceptions',
      () async {
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/login') {
        return _response(200, _tokens('access', 'refresh'));
      }
      if (request.path == '/api/v1/auth/me') {
        return _response(200, _user('first@example.com'));
      }
      expect(request.path, '/api/v1/auth/logout');
      return _response(500, {
        'error': {'code': 'unavailable'}
      });
    });
    final store = _FailingCleanupStore();
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      restoreSession: false,
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    expect(await _login(auth, 'first@example.com'), isTrue);
    store.failCleanup = true;

    await auth.logout();

    expect(auth.state.status, AuthStatus.unauthenticated);
    expect(auth.state.email, isNull);
    expect(auth.state.name, isNull);
    expect(auth.accessToken, isNull);
    expect(auth.state.error, contains('로컬'));
  });

  for (final deleteAccount in [false, true]) {
    test(
        '${deleteAccount ? 'accepted deletion' : 'logout'} cleans only app-owned files',
        () async {
      final adapter = _Adapter((request) => deleteAccount
          ? _response(202, {
              'data': {'status': 'delete_requested'}
            })
          : _response(200, {
              'data': {'revoked': true}
            }));
      final auth = AuthNotifier(
        dio: _dio(adapter),
        tokenStore: MemoryAuthStore(),
        restoreSession: false,
        initialAccessToken: 'access',
        initialRefreshToken: 'refresh',
        cleanupLocalFiles: _cleanupTempFiles,
      );
      addTearDown(auth.dispose);
      const ownedNames = [
        'blackbox_case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.mp4',
        'accident_case_aaa_123.m4a',
        'DriveGuard_legacy.pdf',
      ];
      for (final name in [
        ...ownedNames,
        'family-video.mp4',
        'tax-return.pdf'
      ]) {
        await File('${_directory.path}/$name').writeAsString('private content');
      }

      if (deleteAccount) {
        expect(await auth.requestAccountDeletion('password'),
            AccountDeletionResult.accepted);
      } else {
        await auth.logout();
      }

      expect(auth.state.status, AuthStatus.unauthenticated);
      for (final name in ownedNames) {
        expect(File('${_directory.path}/$name').existsSync(), isFalse);
      }
      expect(File('${_directory.path}/family-video.mp4').existsSync(), isTrue);
      expect(File('${_directory.path}/tax-return.pdf').existsSync(), isTrue);
    });
  }

  test('file cleanup failure warns without undoing accepted deletion',
      () async {
    final adapter = _Adapter((request) => _response(202, {
          'data': {'status': 'delete_requested'}
        }));
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: MemoryAuthStore(),
      restoreSession: false,
      initialAccessToken: 'access',
      initialRefreshToken: 'refresh',
      cleanupLocalFiles: () async => throw const FileSystemException('denied'),
    );
    addTearDown(auth.dispose);

    expect(await auth.requestAccountDeletion('password'),
        AccountDeletionResult.accepted);

    expect(auth.state.status, AuthStatus.unauthenticated);
    expect(auth.state.email, isNull);
    expect(auth.state.error, contains('로컬'));
  });
  test('late refresh response cannot restore a logged out session', () async {
    final gate = Completer<ResponseBody>();
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/refresh') return gate.future;
      expect(request.path, '/api/v1/auth/logout');
      return _response(200, {
        'data': {'revoked': true}
      });
    });
    final store = MemoryAuthStore();
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      restoreSession: false,
      initialAccessToken: _jwt(946684800),
      initialRefreshToken: 'refresh-old',
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    final pending = auth.validAccessToken();
    await pumpEventQueue();
    expect(adapter.requests, hasLength(1));

    await auth.logout();
    gate.complete(_response(200, _tokens(_jwt(4102444800), 'refresh-new')));

    expect(await pending, isNull);
    expect(auth.accessToken, isNull);
    expect(auth.state.status, AuthStatus.unauthenticated);
    expect(store.values, isEmpty);
  });

  test('restoring the same verified principal preserves its private values',
      () async {
    final adapter = _Adapter((request) {
      expect(request.path, '/api/v1/auth/me');
      return _response(200, _user('first@example.com'));
    });
    final store = MemoryAuthStore({
      authAccessKey: 'access',
      authRefreshKey: 'refresh',
      'auth_account_identity': 'first@example.com',
      'insurance_phone': 'first-phone',
    });
    final done = Completer<void>();
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: store,
      cleanupLocalFiles: _cleanupTempFiles,
    );
    addTearDown(auth.dispose);
    final remove = auth.addListener((state) {
      if (state.status == AuthStatus.authenticated && !done.isCompleted) {
        done.complete();
      }
    });
    await done.future.timeout(const Duration(seconds: 2));
    remove();

    expect(auth.state.email, 'first@example.com');
    expect(store.values['insurance_phone'], 'first-phone');
    expect(store.values[authAccessKey], 'access');
  });

  test(
      'principal change cleanup failure stays signed out and retains its warning',
      () async {
    var cleanupCalls = 0;
    final adapter = _Adapter((request) {
      if (request.path == '/api/v1/auth/login') {
        return _response(200, _tokens('new-access', 'new-refresh'));
      }
      expect(request.path, '/api/v1/auth/me');
      return _response(200, _user('second@example.com'));
    });
    final auth = AuthNotifier(
      dio: _dio(adapter),
      tokenStore: MemoryAuthStore({
        'auth_account_identity': 'first@example.com',
        'insurance_phone': 'first-phone',
      }),
      restoreSession: false,
      cleanupLocalFiles: () async {
        cleanupCalls++;
        if (cleanupCalls == 1) {
          throw const FileSystemException('temporary cleanup failure');
        }
        await _cleanupTempFiles();
      },
    );
    addTearDown(auth.dispose);

    expect(await _login(auth, 'second@example.com'), isFalse);

    expect(auth.state.status, AuthStatus.unauthenticated);
    expect(auth.state.email, isNull);
    expect(auth.state.error, contains('로컬'));
  });
}

late Directory _directory;

Future<void> _cleanupTempFiles() async {
  await LocalAppFiles.cleanupAccount(_directory);
}

String _jwt(int exp) => 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'exp': exp
        }))).replaceAll('=', '')}.signature';

Map<String, dynamic> _tokens(String access, String refresh) => {
      'data': {'access_token': access, 'refresh_token': refresh},
    };

Map<String, dynamic> _user(String email) => {
      'data': {
        'user': {'id': 'user-$email', 'email': email, 'name': 'Driver'},
      },
    };

Future<bool> _login(AuthNotifier auth, String email) =>
    auth.login(email: email, password: 'password');

Future<void> _waitForSignedOut(AuthNotifier auth) async {
  if (auth.state.status == AuthStatus.unauthenticated) return;
  final done = Completer<void>();
  final remove = auth.addListener((state) {
    if (state.status == AuthStatus.unauthenticated && !done.isCompleted) {
      done.complete();
    }
  });
  try {
    await done.future.timeout(const Duration(seconds: 2));
  } finally {
    remove();
  }
}

Map<String, dynamic> _body(RequestOptions request) => request.data is String
    ? Map<String, dynamic>.from(jsonDecode(request.data as String) as Map)
    : Map<String, dynamic>.from(request.data as Map);

Dio _dio(HttpClientAdapter adapter) => Dio(BaseOptions(
      baseUrl: 'http://example.test',
      validateStatus: (status) => status != null && status < 500,
    ))
      ..httpClientAdapter = adapter;

ResponseBody _response(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FailingCleanupStore extends MemoryAuthStore {
  bool failCleanup = false;

  @override
  Future<void> clearAccountData() async {
    if (failCleanup) throw StateError('storage unavailable');
    await super.clearAccountData();
  }
}
