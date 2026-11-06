import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/services/chat_service.dart';
import 'package:blackbox_driver_care/services/model_analysis_service.dart';
import 'package:blackbox_driver_care/services/profile_service.dart';
import 'package:blackbox_driver_care/services/verdict_search_service.dart';
import 'package:blackbox_driver_care/screens/chatbot/chatbot_screen.dart';

void main() {
  test('chat consent copy names configured external text processors', () {
    expect(externalAiTextConsentDescription, contains('Groq'));
    expect(externalAiTextConsentDescription, contains('Google Gemini'));
    expect(externalAiTextConsentDescription, contains('텍스트 처리'));
    expect(externalAiTextConsentDescription, isNot(contains('Groq만')));
  });

  group('chat message presentation', () {
    CaseChatMessage message(String text, {ChatRole role = ChatRole.user}) =>
        CaseChatMessage(
          id: 'message-1',
          role: role,
          text: text,
          createdAt: DateTime.utc(2026, 10, 17),
        );

    test('classifies a valid road selection but hides it from chat', () async {
      const raw =
          '{"type":"road_selection","place":1,"other_action":null,"revision":1}';
      final saved = message(raw);
      final notifier = ChatbotNotifier(
        chatService: _FakeChatService(history: [saved]),
        caseId: 'case-a',
        userId: 'driver-a',
      );

      await notifier.loadHistory();

      expect(saved.displayText, '도로유형 선택을 저장했습니다.');
      expect(saved.isInternalRecord, isTrue);
      expect(notifier.state.messages.single.id, startsWith('greeting:'));
      expect(
        notifier.state.messages.single.text,
        isNot(contains('도로유형 선택을 저장했습니다.')),
      );
      expect(saved.text, raw);
    });

    test('leaves unrecognized or invalid message text unchanged', () {
      const cases = <({String text, ChatRole role})>[
        (text: '{"kind":"ordinary","value":1}', role: ChatRole.user),
        (text: '{not-json', role: ChatRole.user),
        (
          text:
              '{"type":"future_control","place":1,"other_action":null,"revision":1}',
          role: ChatRole.user,
        ),
        (
          text:
              '{"type":"road_selection","place":1,"other_action":null,"revision":1}',
          role: ChatRole.assistant,
        ),
        (
          text:
              '{"type":"road_selection","place":8,"other_action":null,"revision":1}',
          role: ChatRole.user,
        ),
        (
          text:
              '{"type":"road_selection","place":6,"other_action":"left","revision":1}',
          role: ChatRole.user,
        ),
      ];

      for (final item in cases) {
        expect(message(item.text, role: item.role).displayText, item.text);
      }
    });
  });

  group('Task 5 backend services', () {
    test('GET data.chats history follows cursors and is returned oldest first',
        () async {
      final adapter = _JsonAdapter((request) {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(request.path, '/api/v1/cases/case_abc/chats');
        if (request.queryParameters['cursor'] == null) {
          return _reply(200, {
            'data': {
              'chats': [
                _message('m2', 'assistant', 'second', '2026-10-15T02:00:00Z'),
              ],
              'next_cursor': 'next-page',
            },
          });
        }
        expect(request.queryParameters['cursor'], 'next-page');
        return _reply(200, {
          'data': {
            'chats': [
              _message('m1', 'user', 'first', '2026-10-15T01:00:00Z'),
            ],
            'next_cursor': null,
          },
        });
      });
      final service = ChatService(
        dio: _dio(adapter),
        accessToken: () async => 'access-token',
      );

      final messages = await service.fetchHistory('case_abc');

      expect(messages.map((message) => message.id), ['m1', 'm2']);
      expect(adapter.requests, hasLength(2));
    });

    test('unavailable chat response keeps the saved note without a fake answer',
        () async {
      final adapter = _JsonAdapter((request) {
        expect(request.method, 'POST');
        expect(_requestJson(request), {'text': 'save this note'});
        return _reply(201, {
          'data': {
            'messages': [
              _message(
                  'saved', 'user', 'save this note', '2026-10-15T01:00:00Z'),
              _message(
                  'saved', 'user', 'save this note', '2026-10-15T01:00:00Z'),
            ],
            'llm': {
              'provider': 'real',
              'status': 'unavailable',
              'error_code': 'provider_timeout',
            },
          },
        });
      });
      final service = ChatService(
        dio: _dio(adapter),
        accessToken: () async => 'access-token',
      );

      final result = await service.sendMessage('case_abc', 'save this note');

      expect(result.messages, hasLength(1));
      expect(result.messages.single.role, ChatRole.user);
      expect(result.llm.status, ChatLlmStatus.unavailable);
      expect(result.llm.errorCode, 'provider_timeout');
      expect(
          result.messages
              .where((message) => message.role == ChatRole.assistant),
          isEmpty);
    });

    test('profile parses every backend field and sends null to clear values',
        () async {
      final adapter = _JsonAdapter((request) {
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(_requestJson(request), {
          'display_name': 'Driver',
          'phone': '010-1234-5678',
          'license_number': null,
          'license_plate': '12가 3456',
          'insurance_company': null,
          'policy_number': 'P-1',
          'insurance_phone': '1588-0000',
          'vehicle_type': 'SUV',
        });
        return _reply(200, {
          'data': {
            'profile': {
              'id': 'profile-1',
              ..._requestJson(request),
            },
          },
        });
      });
      final service = ProfileService(
        dio: _dio(adapter),
        accessToken: () async => 'access-token',
      );

      final profile = await service.saveProfile(
        displayName: 'Driver',
        phone: '010-1234-5678',
        licenseNumber: null,
        licensePlate: '12가 3456',
        insuranceCompany: null,
        policyNumber: 'P-1',
        insurancePhone: '1588-0000',
        vehicleType: 'SUV',
      );

      expect(profile?.phone, '010-1234-5678');
      expect(profile?.licenseNumber, isNull);
      expect(profile?.licensePlate, '12가 3456');
      expect(profile?.insuranceCompany, isNull);
      expect(profile?.policyNumber, 'P-1');
      expect(profile?.insurancePhone, '1588-0000');
      expect(profile?.vehicleType, 'SUV');
    });

    test('LAW search is authenticated and preserves explicit unavailable state',
        () async {
      final adapter = _JsonAdapter((request) {
        expect(request.path, '/api/v1/law/search');
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(request.queryParameters, {'q': '차선 변경', 'limit': 10});
        return _reply(200, {
          'data': {
            'provider': 'mock',
            'status': 'unavailable',
            'results': <Object>[],
          },
        });
      });
      final service = VerdictSearchService(
        dio: _dio(adapter),
        accessToken: () async => 'access-token',
      );

      final results = await service.search('차선 변경');

      expect(results, isEmpty);
      expect(service.lastProvider, 'mock');
      expect(service.lastStatus, VerdictSearchStatus.unavailable);
    });

    test('202 account deletion clears auth and local account data', () async {
      final adapter = _JsonAdapter((request) {
        expect(request.method, 'DELETE');
        expect(request.path, '/api/v1/account');
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(_requestJson(request), {'password': 'correct horse'});
        return _reply(202, {
          'data': {'status': 'delete_requested'},
        });
      });
      final store = MemoryAuthStore({
        authAccessKey: 'access-token',
        authRefreshKey: 'refresh-token',
        'license_number': 'stored-license',
        'registered_device_id': 'device-1',
      });
      final notifier = AuthNotifier(
        dio: _dio(adapter),
        tokenStore: store,
        restoreSession: false,
        initialAccessToken: 'access-token',
        initialRefreshToken: 'refresh-token',
        cleanupLocalFiles: () async {},
      );

      final result = await notifier.requestAccountDeletion('correct horse');

      expect(result, AccountDeletionResult.accepted);
      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.accessToken, isNull);
      expect(store.values, isEmpty);
    });

    test('logout clears private local data before another user can sign in',
        () async {
      final adapter = _JsonAdapter((request) {
        expect(request.path, '/api/v1/auth/logout');
        expect(_requestJson(request), {'refresh_token': 'refresh-token'});
        return _reply(200, {
          'data': {'revoked': true},
        });
      });
      final store = MemoryAuthStore({
        authAccessKey: 'access-token',
        authRefreshKey: 'refresh-token',
        'insurance_phone': '1588-0000',
        'registered_device_id': 'device-1',
      });
      final notifier = AuthNotifier(
        dio: _dio(adapter),
        tokenStore: store,
        restoreSession: false,
        initialAccessToken: 'access-token',
        initialRefreshToken: 'refresh-token',
        cleanupLocalFiles: () async {},
      );

      await notifier.logout();

      expect(store.values, isEmpty);
      expect(notifier.state.status, AuthStatus.unauthenticated);
    });
  });

  group('case-scoped chatbot state', () {
    test('empty analysis history does not claim completion or real law',
        () async {
      final notifier = ChatbotNotifier(
        chatService: _FakeChatService(),
        caseId: 'case_a',
        userId: 'driver-a',
        screenContext: 'analysis',
      );

      await notifier.loadHistory();

      final greeting = notifier.state.messages.single.text;
      expect(greeting, contains('저장된 사건 정보'));
      expect(greeting, contains('미확인'));
      expect(greeting, isNot(contains('목업')));
      expect(greeting, isNot(contains('시연용')));
      expect(greeting, isNot(contains('Mock')));
      expect(greeting, isNot(contains('분석이 완료')));
      expect(greeting, isNot(contains('법적 근거')));
      expect(greeting, isNot(contains('유사 판례')));
    });

    test('refuses to send accident advice without an active case', () async {
      final service = _FakeChatService();
      final notifier = ChatbotNotifier(
        chatService: service,
        caseId: null,
        userId: 'driver-a',
        screenContext: 'accident',
      );

      await notifier.sendMessage('What is my fault ratio?');

      expect(service.sent, isEmpty);
      expect(notifier.state.requiresCase, isTrue);
      expect(notifier.state.messages.single.text, contains('사고 건을 선택'));
    });

    test('keeps saved note once and exposes unavailable status', () async {
      final saved = CaseChatMessage(
        id: 'saved-note',
        role: ChatRole.user,
        text: '현장 메모',
        createdAt: DateTime.utc(2026, 10, 15),
      );
      final service = _FakeChatService(
        sendResult: ChatSendResult(
          messages: [saved, saved],
          llm: const ChatLlmResult(
            provider: 'real',
            status: ChatLlmStatus.unavailable,
            errorCode: 'provider_timeout',
          ),
        ),
      );
      final notifier = ChatbotNotifier(
        chatService: service,
        caseId: 'case_a',
        userId: 'driver-a',
      );

      await notifier.loadHistory();
      await notifier.sendMessage('현장 메모');

      expect(notifier.state.messages.where((m) => m.id == 'saved-note'),
          hasLength(1));
      expect(notifier.state.notice, contains('저장'));
      expect(notifier.state.notice, contains('답변'));
    });

    test('does not expose implementation labels for an unavailable reply',
        () async {
      final service = _FakeChatService();
      final notifier = ChatbotNotifier(
        chatService: service,
        caseId: 'case_a',
        userId: 'driver-a',
      );

      await notifier.sendMessage('과실 비율을 알려줘');

      expect(notifier.state.notice, contains('자동 답변'));
      expect(notifier.state.notice, contains('제공할 수 없습니다'));
      expect(notifier.state.notice, isNot(contains('Mock')));
      expect(notifier.state.notice, isNot(contains('목업')));
    });

    test('separate user and case notifiers do not share history', () async {
      final first = ChatbotNotifier(
        chatService: _FakeChatService(history: [
          CaseChatMessage(
            id: 'a',
            role: ChatRole.user,
            text: 'case a',
            createdAt: DateTime.utc(2026, 10, 15),
          ),
        ]),
        caseId: 'case_a',
        userId: 'driver-a',
      );
      final second = ChatbotNotifier(
        chatService: _FakeChatService(history: [
          CaseChatMessage(
            id: 'b',
            role: ChatRole.user,
            text: 'case b',
            createdAt: DateTime.utc(2026, 10, 16),
          ),
        ]),
        caseId: 'case_b',
        userId: 'driver-b',
      );

      await Future.wait([first.loadHistory(), second.loadHistory()]);

      expect(first.state.messages.single.id, 'a');
      expect(second.state.messages.single.id, 'b');
    });
  });
}

Map<String, dynamic> _message(
  String id,
  String role,
  String text,
  String createdAt,
) =>
    {'id': id, 'role': role, 'text': text, 'created_at': createdAt};

Map<String, dynamic> _requestJson(RequestOptions request) {
  final data = request.data;
  if (data is String) return Map<String, dynamic>.from(jsonDecode(data) as Map);
  return Map<String, dynamic>.from(data as Map);
}

Dio _dio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    headers: {'Content-Type': 'application/json'},
    validateStatus: (status) => status != null && status < 500,
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

({int status, Map<String, dynamic> body}) _reply(
  int status,
  Map<String, dynamic> body,
) =>
    (status: status, body: body);

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final ({int status, Map<String, dynamic> body}) Function(RequestOptions)
      handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = handler(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeChatService extends ChatService {
  _FakeChatService({
    this.history = const [],
    ChatSendResult? sendResult,
  })  : sendResult = sendResult ??
            const ChatSendResult(
              messages: [],
              llm: ChatLlmResult(
                provider: 'mock',
                status: ChatLlmStatus.mock,
              ),
            ),
        super(accessToken: _token);

  final List<CaseChatMessage> history;
  final ChatSendResult sendResult;
  final List<(String, String)> sent = [];

  static Future<String?> _token() async => 'token';

  @override
  Future<List<CaseChatMessage>> fetchHistory(String caseId) async => history;

  @override
  Future<ChatSendResult> sendMessage(
    String caseId,
    String text, {
    List<String> fileIds = const [],
    VehicleMovements? movements,
  }) async {
    sent.add((caseId, text));
    return sendResult;
  }
}
