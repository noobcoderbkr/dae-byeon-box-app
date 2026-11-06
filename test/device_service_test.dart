import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/device_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached device registration posts without deleting the existing device',
      () async {
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([
      _response(201, {
        'data': {
          'device': {'id': 'dev_new', 'name': 'Replacement dashcam'},
        },
      }),
    ]);
    final service = _serviceWith(adapter, store);

    final result = await service.registerDevice(' Replacement dashcam ');

    expect(result?.deviceId, 'dev_new');
    expect(result?.deviceName, 'Replacement dashcam');
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/api/v1/devices');
  });

  test('failed registration keeps cached device identity and does not delete',
      () async {
    final store = MemoryAuthStore({
      authAccessKey: 'cached-access-token',
      authRefreshKey: 'cached-refresh-token',
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([
      _response(400, {
        'error': {'message': 'registration rejected'},
      }),
    ]);
    final service = _serviceWith(adapter, store);

    final result = await service.registerDevice('Replacement dashcam');

    expect(result, isNull);
    expect(store.values, {
      authAccessKey: 'cached-access-token',
      authRefreshKey: 'cached-refresh-token',
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'POST');
  });

  test('metadata-only registration succeeds without a device credential',
      () async {
    final store = MemoryAuthStore();
    final adapter = _QueueAdapter([
      _response(201, {
        'data': {
          'device': {'id': 'dev_metadata', 'name': 'Road camera'},
        },
      }),
    ]);
    final service = _serviceWith(adapter, store);

    final result = await service.registerDevice('Road camera');

    expect(result?.deviceId, 'dev_metadata');
    expect(result?.deviceName, 'Road camera');
    expect(store.values, {
      'registered_device_id': 'dev_metadata',
      'registered_device_name': 'Road camera',
    });
  });

  test('unexpected device credential is ignored and never saved', () async {
    final store = MemoryAuthStore();
    final adapter = _QueueAdapter([
      _response(201, {
        'data': {
          'device': {'id': 'dev_metadata', 'name': 'Road camera'},
          'device_token': 'hardware-secret',
        },
      }),
    ]);
    final service = _serviceWith(adapter, store);

    final result = await service.registerDevice('Road camera');

    expect(result?.deviceId, 'dev_metadata');
    expect(store.values, {
      'registered_device_id': 'dev_metadata',
      'registered_device_name': 'Road camera',
    });
    expect(store.values.values, isNot(contains('hardware-secret')));
  });

  test('old-owner delayed registration cannot replace the new session cache',
      () async {
    final response = Completer<ResponseBody>();
    final store = MemoryAuthStore();
    final adapter = _QueueAdapter([response.future]);
    final auth = _TestAuth()..loginAs('first@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final pending = service.registerDevice('Old owner camera');
    await Future<void>.delayed(Duration.zero);
    auth.loginAs('second@example.com');
    await store.write('registered_device_id', 'dev_new_session');
    await store.write('registered_device_name', 'New session camera');
    response.complete(_response(201, {
      'data': {
        'device': {
          'id': 'dev_old_session',
          'name': 'Old owner camera',
        },
      },
    }));

    expect(await pending, isNull);
    expect(store.values, {
      'registered_device_id': 'dev_new_session',
      'registered_device_name': 'New session camera',
    });
  });

  test('explicit unregister deletes the saved device and clears local metadata',
      () async {
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([_response(204, {})]);
    final service = _serviceWith(adapter, store);

    await service.unregister();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/v1/devices/dev_existing');
    expect(store.values, isEmpty);
  });

  test('old-owner delayed unregister cannot clear the new session cache',
      () async {
    final response = Completer<ResponseBody>();
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_old_session',
      'registered_device_name': 'Old session camera',
    });
    final adapter = _QueueAdapter([response.future]);
    final auth = _TestAuth()..loginAs('first@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final pending = service.unregister();
    await Future<void>.delayed(Duration.zero);
    auth.loginAs('second@example.com');
    await store.write('registered_device_id', 'dev_new_session');
    await store.write('registered_device_name', 'New session camera');
    response.complete(_response(204, {}));
    await pending;

    expect(adapter.requests.single.path, '/api/v1/devices/dev_old_session');
    expect(store.values, {
      'registered_device_id': 'dev_new_session',
      'registered_device_name': 'New session camera',
    });
  });

  test('connectDevice links the verified front collector and caches backend id',
      () async {
    const backendId = 'dev_0123456789abcdef0123456789abcdef';
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'device': {
            'id': backendId,
            'name': 'Front camera',
            'collector': {
              'server_url': 'https://project-box.life',
              'device_id': 'violet-dashcam-1',
              'position': 'front',
            },
          },
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = await service.connectDevice(
        ' Front camera ', ' https://project-box.life/ ', 'front');

    expect(result?.deviceId, backendId);
    expect(result?.deviceName, 'Front camera');
    expect(result?.serverUrl, 'https://project-box.life');
    expect(result?.sourceDeviceId, 'violet-dashcam-1');
    expect(result?.position, 'front');
    expect(adapter.requests.single.path, '/api/v1/devices/link');
    expect(adapter.requests.single.data, {
      'name': 'Front camera',
      'server_url': 'https://project-box.life',
      'device_id': 'violet-dashcam-1',
      'position': 'front',
    });
    expect(store.values, {
      'registered_device_id': backendId,
      'registered_device_name': 'Front camera',
    });
  });

  test('connectDevice maps rear position to violet-dashcam-2', () async {
    const backendId = 'dev_11111111111111111111111111111111';
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'device': {
            'id': backendId,
            'name': 'Rear camera',
            'collector': {
              'server_url': 'https://collector.example',
              'device_id': 'violet-dashcam-2',
              'position': 'rear',
            },
          },
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, MemoryAuthStore(), auth: auth);

    final result = await service.connectDevice(
        'Rear camera', 'https://collector.example', 'rear');

    expect(result?.sourceDeviceId, 'violet-dashcam-2');
    expect(
        (adapter.requests.single.data as Map)['device_id'], 'violet-dashcam-2');
  });

  test('connectDevice rejects non-HTTPS or non-origin server URLs', () async {
    final adapter = _QueueAdapter([]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, MemoryAuthStore(), auth: auth);

    for (final serverUrl in [
      'http://project-box.life',
      'https://user@project-box.life',
      'https://project-box.life/collector',
      'https://project-box.life?source=front',
      'https://project-box.life#front',
    ]) {
      await expectLater(
        service.connectDevice('Camera', serverUrl, 'front'),
        throwsA(isA<DeviceConnectionException>().having(
          (error) => error.failure,
          'failure',
          DeviceConnectionFailure.invalidConfiguration,
        )),
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test('failed link keeps the previously cached device', () async {
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([
      _response(409, {
        'error': {'code': 'device_not_linked'},
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = service.connectDevice(
        'Replacement dashcam', 'https://project-box.life', 'front');

    await expectLater(
      result,
      throwsA(isA<DeviceConnectionException>().having(
        (error) => error.failure,
        'failure',
        DeviceConnectionFailure.operatorApprovalRequired,
      )),
    );
    expect(store.values, {
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
  });

  test('malformed successful link never replaces cached device', () async {
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'device': {
            'id': 'dev_22222222222222222222222222222222',
            'name': 'Front camera',
            'collector': {
              'server_url': 'https://different.example',
              'device_id': 'violet-dashcam-1',
              'position': 'front',
            },
          },
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = await service.connectDevice(
        'Front camera', 'https://project-box.life', 'front');

    expect(result, isNull);
    expect(store.values['registered_device_id'], 'dev_existing');
    expect(store.values['registered_device_name'], 'Existing dashcam');
  });

  test('successful link rejects a backend id outside the canonical shape',
      () async {
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'device': {
            'id': 'dev_NOT_CANONICAL',
            'name': 'Front camera',
            'collector': {
              'server_url': 'https://project-box.life',
              'device_id': 'violet-dashcam-1',
              'position': 'front',
            },
          },
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = await service.connectDevice(
        'Front camera', 'https://project-box.life', 'front');

    expect(result, isNull);
    expect(store.values['registered_device_id'], 'dev_existing');
    expect(store.values['registered_device_name'], 'Existing dashcam');
  });

  test('fetchConnection returns verified server metadata without credentials',
      () async {
    const backendId = 'dev_33333333333333333333333333333333';
    final store = MemoryAuthStore({
      'registered_device_id': backendId,
      'registered_device_name': 'Cached name',
    });
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'device': {
            'id': backendId,
            'name': 'Server name',
            'device_token': 'must-not-be-retained',
            'collector': {
              'server_url': 'https://project-box.life',
              'device_id': 'violet-dashcam-2',
              'position': 'rear',
            },
          },
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = await service.fetchConnection();

    expect(result?.deviceId, backendId);
    expect(result?.deviceName, 'Server name');
    expect(result?.serverUrl, 'https://project-box.life');
    expect(result?.sourceDeviceId, 'violet-dashcam-2');
    expect(result?.position, 'rear');
    expect(adapter.requests.single.path, '/api/v1/devices/$backendId');
    expect(store.values.values, isNot(contains('must-not-be-retained')));
  });

  test('fetchConnection treats a null collector as unbound', () async {
    const backendId = 'dev_44444444444444444444444444444444';
    final store = MemoryAuthStore({
      'registered_device_id': backendId,
      'registered_device_name': 'Cached name',
    });
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'device': {
            'id': backendId,
            'name': 'Server name',
            'collector': null,
          },
        },
      }),
      _response(200, {
        'data': {'devices': []},
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    expect(await service.fetchConnection(), isNull);
    expect(adapter.requests.map((request) => request.path), [
      '/api/v1/devices/$backendId',
      '/api/v1/devices',
    ]);
    expect(store.values['registered_device_id'], backendId);
    expect(store.values['registered_device_name'], 'Cached name');
  });

  test('fetchConnection recovers the only owned binding after cached 404',
      () async {
    const staleId = 'dev_44444444444444444444444444444444';
    const recoveredId = 'dev_55555555555555555555555555555555';
    final store = MemoryAuthStore({
      'registered_device_id': staleId,
      'registered_device_name': 'Revoked camera',
    });
    final adapter = _QueueAdapter([
      _response(404, {
        'error': {'code': 'device_not_found'},
      }),
      _response(200, {
        'data': {
          'devices': [
            {
              'id': recoveredId,
              'name': 'Owned camera',
              'collector': {
                'server_url': 'https://project-box.life',
                'device_id': 'violet-dashcam-2',
                'position': 'rear',
              },
            },
          ],
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = await service.fetchConnection();

    expect(result?.deviceId, recoveredId);
    expect(store.values, {
      'registered_device_id': recoveredId,
      'registered_device_name': 'Owned camera',
    });
  });

  test('fetchConnection restores the only owned linked device after cache loss',
      () async {
    const backendId = 'dev_88888888888888888888888888888888';
    final store = MemoryAuthStore();
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'devices': [
            {
              'id': backendId,
              'name': 'Recovered camera',
              'collector': {
                'server_url': 'https://project-box.life',
                'device_id': 'violet-dashcam-1',
                'position': 'front',
              },
            },
          ],
        },
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final result = await service.fetchConnection();

    expect(result?.deviceId, backendId);
    expect(adapter.requests.single.path, '/api/v1/devices');
    expect(store.values, {
      'registered_device_id': backendId,
      'registered_device_name': 'Recovered camera',
    });
  });

  test('fetchConnection never chooses between multiple owned linked devices',
      () async {
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {
          'devices': [
            {
              'id': 'dev_88888888888888888888888888888888',
              'name': 'Front camera',
              'collector': {
                'server_url': 'https://project-box.life',
                'device_id': 'violet-dashcam-1',
                'position': 'front',
              },
            },
            {
              'id': 'dev_99999999999999999999999999999999',
              'name': 'Rear camera',
              'collector': {
                'server_url': 'https://project-box.life',
                'device_id': 'violet-dashcam-2',
                'position': 'rear',
              },
            },
          ],
        },
      }),
    ]);
    final store = MemoryAuthStore();
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    await expectLater(
      service.fetchConnection(),
      throwsA(isA<DeviceConnectionException>().having(
        (error) => error.failure,
        'failure',
        DeviceConnectionFailure.selectionRequired,
      )),
    );
    expect(store.values, isEmpty);
  });

  test('cache-loss recovery is fenced when the owner changes', () async {
    final response = Completer<ResponseBody>();
    final adapter = _QueueAdapter([response.future]);
    final store = MemoryAuthStore();
    final auth = _TestAuth()..loginAs('first@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final pending = service.fetchConnection();
    await Future<void>.delayed(Duration.zero);
    auth.loginAs('second@example.com');
    response.complete(_response(200, {
      'data': {
        'devices': [
          {
            'id': 'dev_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'name': 'Old owner camera',
            'collector': {
              'server_url': 'https://project-box.life',
              'device_id': 'violet-dashcam-1',
              'position': 'front',
            },
          },
        ],
      },
    }));

    expect(await pending, isNull);
    expect(store.values, isEmpty);
  });

  test('connectDevice exposes auth, approval, config, and offline failures',
      () async {
    Future<DeviceConnectionFailure> failureFor(
      _QueueAdapter adapter, {
      AuthNotifier? auth,
      String serverUrl = 'https://project-box.life',
    }) async {
      final service = _serviceWith(adapter, MemoryAuthStore(), auth: auth);
      try {
        await service.connectDevice('Camera', serverUrl, 'front');
        fail('Expected DeviceConnectionException');
      } on DeviceConnectionException catch (error) {
        return error.failure;
      }
    }

    expect(
      await failureFor(
        _QueueAdapter([
          _response(409, {
            'error': {'code': 'device_not_linked'}
          })
        ]),
        auth: _TestAuth()..loginAs('owner@example.com'),
      ),
      DeviceConnectionFailure.operatorApprovalRequired,
    );
    expect(
      await failureFor(
        _QueueAdapter([
          _response(422, {
            'error': {'code': 'validation_error'}
          })
        ]),
        auth: _TestAuth()..loginAs('owner@example.com'),
      ),
      DeviceConnectionFailure.invalidConfiguration,
    );
    expect(
      await failureFor(_QueueAdapter([]),
          serverUrl: 'http://collector.example'),
      DeviceConnectionFailure.invalidConfiguration,
    );
    expect(
      await failureFor(_ThrowingAdapter(DioExceptionType.connectionError),
          auth: _TestAuth()..loginAs('owner@example.com')),
      DeviceConnectionFailure.networkOffline,
    );
    expect(
      await failureFor(_QueueAdapter([]), auth: _NoTokenAuth()),
      DeviceConnectionFailure.authenticationRequired,
    );
  });

  test('fetchConnection rejects a noncanonical cached backend id', () async {
    final adapter = _QueueAdapter([
      _response(200, {
        'data': {'devices': []},
      }),
    ]);
    final auth = _TestAuth()..loginAs('owner@example.com');
    final service = _serviceWith(
      adapter,
      MemoryAuthStore({'registered_device_id': 'dev_metadata'}),
      auth: auth,
    );

    expect(await service.fetchConnection(), isNull);
    expect(adapter.requests.single.path, '/api/v1/devices');
  });

  test('old-session link completion cannot publish or replace cached device',
      () async {
    final response = Completer<ResponseBody>();
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([response.future]);
    final auth = _TestAuth()..loginAs('first@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final pending = service.connectDevice(
        'Front camera', 'https://project-box.life', 'front');
    await Future<void>.delayed(Duration.zero);
    auth.loginAs('second@example.com');
    response.complete(_response(200, {
      'data': {
        'device': {
          'id': 'dev_55555555555555555555555555555555',
          'name': 'Front camera',
          'collector': {
            'server_url': 'https://project-box.life',
            'device_id': 'violet-dashcam-1',
            'position': 'front',
          },
        },
      },
    }));

    expect(await pending, isNull);
    expect(store.values['registered_device_id'], 'dev_existing');
    expect(store.values['registered_device_name'], 'Existing dashcam');
  });

  test('old-session connection read cannot publish metadata', () async {
    const backendId = 'dev_77777777777777777777777777777777';
    final response = Completer<ResponseBody>();
    final adapter = _QueueAdapter([response.future]);
    final auth = _TestAuth()..loginAs('first@example.com');
    final service = _serviceWith(
      adapter,
      MemoryAuthStore({'registered_device_id': backendId}),
      auth: auth,
    );

    final pending = service.fetchConnection();
    await Future<void>.delayed(Duration.zero);
    auth.loginAs('second@example.com');
    response.complete(_response(200, {
      'data': {
        'device': {
          'id': backendId,
          'name': 'Old owner camera',
          'collector': {
            'server_url': 'https://project-box.life',
            'device_id': 'violet-dashcam-1',
            'position': 'front',
          },
        },
      },
    }));

    expect(await pending, isNull);
  });

  test('connection publication is fenced by owner even at same generation',
      () async {
    final response = Completer<ResponseBody>();
    final store = MemoryAuthStore({
      'registered_device_id': 'dev_existing',
      'registered_device_name': 'Existing dashcam',
    });
    final adapter = _QueueAdapter([response.future]);
    final auth = _TestAuth()..loginAs('first@example.com');
    final service = _serviceWith(adapter, store, auth: auth);

    final pending = service.connectDevice(
        'Front camera', 'https://project-box.life', 'front');
    await Future<void>.delayed(Duration.zero);
    auth.replaceOwner('second@example.com');
    response.complete(_response(200, {
      'data': {
        'device': {
          'id': 'dev_66666666666666666666666666666666',
          'name': 'Front camera',
          'collector': {
            'server_url': 'https://project-box.life',
            'device_id': 'violet-dashcam-1',
            'position': 'front',
          },
        },
      },
    }));

    expect(await pending, isNull);
    expect(store.values['registered_device_id'], 'dev_existing');
    expect(store.values['registered_device_name'], 'Existing dashcam');
  });
}

DeviceService _serviceWith(
  _QueueAdapter adapter,
  AuthStore store, {
  AuthNotifier? auth,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://example.test',
    validateStatus: (status) => status != null && status < 500,
  ))
    ..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(
        (_) =>
            auth ??
            AuthNotifier(
              restoreSession: false,
              tokenStore: MemoryAuthStore(),
              initialAccessToken: 'access-token',
            ),
      ),
    ],
  );
  addTearDown(container.dispose);
  final provider = Provider<DeviceService>(
    (ref) => DeviceService(ref, dio: dio, storage: store),
  );
  return container.read(provider);
}

ResponseBody _response(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<FutureOr<ResponseBody>> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) {
      throw StateError('No response for ${options.method} ${options.path}');
    }
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter extends _QueueAdapter {
  _ThrowingAdapter(this.type) : super([]);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    throw DioException(requestOptions: options, type: type);
  }
}

class _TestAuth extends AuthNotifier {
  _TestAuth()
      : super(
          restoreSession: false,
          tokenStore: MemoryAuthStore(),
          initialAccessToken: 'access-token',
        );

  int _generation = 0;

  @override
  int get sessionGeneration => _generation;

  @override
  Future<String?> validAccessToken() async => 'access-token';

  void loginAs(String email) {
    _generation++;
    replaceOwner(email);
  }

  void replaceOwner(String email) {
    state = AuthState(
      status: AuthStatus.authenticated,
      email: email,
      name: email,
    );
  }
}

class _NoTokenAuth extends _TestAuth {
  @override
  Future<String?> validAccessToken() async => null;
}
