import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blackbox_driver_care/services/auth_service.dart';
import 'package:blackbox_driver_care/router/app_router.dart';
import 'package:blackbox_driver_care/services/blackbox_video_service.dart';
import 'package:blackbox_driver_care/services/case_service.dart';
import 'package:blackbox_driver_care/services/chat_service.dart';
import 'package:blackbox_driver_care/services/consent_service.dart';
import 'package:blackbox_driver_care/services/model_analysis_service.dart';
import 'package:blackbox_driver_care/services/profile_service.dart';
import 'package:blackbox_driver_care/services/push_service.dart';
import 'package:blackbox_driver_care/screens/auth/consent_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const caseId = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('revoked required consent still permits read and account routes', () {
    expect(canAccessWithoutCollectionConsent('/my-reports'), isTrue);
    expect(canAccessWithoutCollectionConsent('/mypage'), isTrue);
    expect(canAccessWithoutCollectionConsent('/analysis'), isTrue);
    expect(canAccessWithoutCollectionConsent('/timeline/$caseId'), isTrue);
    expect(canAccessWithoutCollectionConsent('/'), isFalse);
    expect(canAccessWithoutCollectionConsent('/chatbot'), isFalse);
  });

  test('public policies and current grants retain required document metadata',
      () async {
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'version': '2026-10-15',
          'disclaimer': legalReferenceWarning,
          'documents': [
            {
              'document': 'privacy',
              'version': '2026-10-15',
              'title': 'Privacy',
              'text': 'Privacy notice',
              'title_ko': '개인정보 처리',
              'text_ko': '사고 자료 처리 안내',
              'required': true,
            },
            {
              'document': 'location',
              'version': '2026-10-15',
              'title': '위치정보 이용',
              'text': '사고 위치 수집 안내',
              'required': true,
            },
            {
              'document': 'external_ai',
              'version': '2026-10-15',
              'title': '외부 AI 전송',
              'text': '선택한 미디어 전송 안내',
              'required': false,
            },
          ],
        }
      }),
      _reply(200, {
        'data': {
          'version': '2026-10-15',
          'grants': {
            'privacy': true,
            'location': true,
            'external_ai': false,
          }
        }
      }),
      _reply(200, {
        'data': {
          'document': 'external_ai',
          'version': '2026-10-15',
          'granted': false,
        }
      }),
    ]);
    final service = ConsentService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );

    final policies = await service.fetchPolicies();
    final consents = await service.fetchConsents();
    await service.setConsent(
      document: ConsentDocument.externalAi,
      version: policies.version,
      granted: false,
    );

    expect(policies.version, '2026-10-15');
    expect(policies.documents.map((item) => item.document), {
      ConsentDocument.privacy,
      ConsentDocument.location,
      ConsentDocument.externalAi,
    });
    expect(policies.documents.where((item) => item.required), hasLength(2));
    expect(policies.documents.first.title, '개인정보 처리');
    expect(policies.documents.first.text, '사고 자료 처리 안내');
    expect(consents.canCollect, isTrue);
    expect(consents.canUseExternalAi, isFalse);
    expect(adapter.requests.first.path, '/api/v1/policies');
    expect(adapter.requests.first.headers['Authorization'], isNull);
    expect(adapter.requests[1].path, '/api/v1/consents');
    expect(adapter.requests.last.path, '/api/v1/consents/external_ai');
    expect(_body(adapter.requests.last), {
      'version': '2026-10-15',
      'granted': false,
    });
  });

  test('policy refresh accepts a new bundle version but rejects mixed documents',
      () async {
    for (final mixed in [false, true]) {
      final adapter = _QueueAdapter([
        _reply(200, {
          'data': {
            'version': '2026-10-17',
            'disclaimer': legalReferenceWarning,
            'documents': [
              for (final document in ConsentDocument.values)
                {
                  'document': document.apiName,
                  'version': mixed && document == ConsentDocument.externalAi
                      ? '2026-10-15'
                      : '2026-10-17',
                  'title': document.apiName,
                  'text': 'Updated processing notice',
                  'required': document != ConsentDocument.externalAi,
                },
            ],
          },
        }),
      ]);
      final service = ConsentService(
        dio: _dio(adapter),
        accessToken: () async => 'token',
      );
      if (mixed) {
        await expectLater(service.fetchPolicies(),
            throwsA(isA<ConsentServiceException>()));
      } else {
        final policies = await service.fetchPolicies();
        expect(policies.version, '2026-10-17');
        expect(policies.documents.every((item) => item.version == policies.version),
            isTrue);
      }
    }
  });

  test('consent history JSON derives current grants when additive grants lag',
      () async {
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'consents': [
            {
              'id': 'consent_privacy',
              'document': 'privacy',
              'version': '2026-10-15',
              'granted_at': '2026-10-15T00:00:00Z',
              'revoked_at': null,
              'created_at': '2026-10-15T00:00:00Z',
            },
            {
              'id': 'consent_location',
              'document': 'location',
              'version': '2026-10-15',
              'granted_at': '2026-10-15T00:00:00Z',
              'revoked_at': '2026-10-15T01:00:00Z',
              'created_at': '2026-10-15T00:00:00Z',
            },
          ],
          'next_cursor': null,
        }
      }),
    ]);
    final service = ConsentService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );

    final snapshot = await service.fetchConsents();

    expect(snapshot.version, '2026-10-15');
    expect(snapshot.isGranted(ConsentDocument.privacy), isTrue);
    expect(snapshot.isGranted(ConsentDocument.location), isFalse);
    expect(snapshot.isGranted(ConsentDocument.externalAi), isFalse);
    expect(adapter.requests.single.queryParameters['limit'], 100);
  });

  test(
      'analysis sends both movement descriptions and parses road and mock speed',
      () async {
    final adapter = _QueueAdapter([
      _reply(202, {
        'data': {
          'job': {'id': 'job_1', 'case_id': caseId}
        }
      }),
      _reply(200, {
        'data': {
          'job': {
            'id': 'job_1',
            'case_id': caseId,
            'kind': 'analysis',
            'status': 'done',
          },
          'report': {
            'id': 'report_1',
            'case_id': caseId,
            'version': 1,
            'created_at': '2026-10-15T00:00:00Z',
            'text': '도로 선택 필요',
            'analysis': {
              'status': 'incomplete',
              'providers': {
                'model': 'real',
                'law': 'unavailable',
                'context': 'absent',
                'llm': 'absent',
              },
              'road': {
                'automatic': {'status': 'unavailable'},
                'selected': null,
              },
              'model_input': {'place': null, 'other_action': null},
              'speed_demo': {
                'value_kmh': 40,
                'source': 'mock',
                'is_mock': true,
              },
              'model': {'prediction': null, 'reason': 'place_required'},
            }
          }
        }
      }),
    ]);
    final service = ModelAnalysisService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
      pollInterval: Duration.zero,
    );

    final report = await service.requestAnalysis(
      caseId: caseId,
      movements: const VehicleMovements(
        ego: '직진 중이었습니다.',
        other: '차선을 바꾸고 있었습니다.',
      ),
    );

    expect(_body(adapter.requests.first), {
      'movements': {
        'ego': '직진 중이었습니다.',
        'other': '차선을 바꾸고 있었습니다.',
      }
    });
    expect(report.road.place, isNull);
    expect(report.road.automaticStatus, 'unavailable');
    expect(report.speedDemo?.valueKmh, 40);
    expect(report.speedDemo?.isMock, isTrue);
  });

  test('chat validates attachments and exposes media evidence status',
      () async {
    final adapter = _QueueAdapter([
      _reply(201, {
        'data': {
          'messages': [
            {
              'id': 'chat_1',
              'role': 'user',
              'text': '이 자료를 봐주세요.',
              'created_at': '2026-10-15T00:00:00Z',
            }
          ],
          'llm': {
            'provider': 'real',
            'status': 'unavailable',
            'error_code': 'media_provider_unavailable',
            'evidence_status': 'unavailable',
          }
        }
      }),
    ]);
    final service = ChatService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );

    final result = await service.sendMessage(
      caseId,
      '이 자료를 봐주세요.',
      fileIds: const ['photo_1', 'video_1'],
      movements: const VehicleMovements(ego: '직진', other: '끼어듦'),
    );

    expect(_body(adapter.requests.single), {
      'text': '이 자료를 봐주세요.',
      'file_ids': ['photo_1', 'video_1'],
      'movements': {'ego': '직진', 'other': '끼어듦'},
    });
    expect(result.llm.evidenceStatus, ChatEvidenceStatus.unavailable);
    expect(result.llm.errorCode, 'media_provider_unavailable');

    await expectLater(
      service.sendMessage(
        caseId,
        'too many',
        fileIds: const ['1', '2', '3', '4'],
      ),
      throwsA(isA<ChatServiceException>()),
    );
  });

  test('persisted vision observation renders as a normal assistant message',
      () async {
    final adapter = _QueueAdapter([
      _reply(201, {
        'data': {
          'messages': [
            {
              'id': 'chat_user',
              'role': 'user',
              'text': '이 사진을 확인해 주세요.',
              'created_at': '2026-10-15T00:00:00Z',
            },
            {
              'id': 'chat_vision',
              'role': 'assistant',
              'text': '선택한 사진에서 차선 경계를 확인했습니다.',
              'created_at': '2026-10-15T00:00:01Z',
            },
          ],
          'llm': {
            'provider': 'groq',
            'status': 'unavailable',
            'error_code': 'llm_unavailable',
            'evidence_status': 'complete',
          }
        }
      }),
    ]);
    final service = ChatService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );

    final result = await service.sendMessage(
      caseId,
      '이 사진을 확인해 주세요.',
      fileIds: const ['photo_1'],
    );

    expect(result.llm.evidenceStatus, ChatEvidenceStatus.complete);
    expect(result.messages.map((message) => message.id),
        ['chat_user', 'chat_vision']);
    expect(result.messages.last.role, ChatRole.assistant);
  });

  test('external AI consent gates media attachments but not text chat',
      () async {
    final adapter = _QueueAdapter([
      _reply(201, {
        'data': {
          'messages': const [],
          'llm': {
            'provider': 'mock',
            'status': 'mock',
            'evidence_status': 'not_requested',
          }
        }
      }),
    ]);
    final service = ChatService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
      canUseExternalAi: () => false,
    );

    await service.sendMessage(caseId, '텍스트 질문');
    await expectLater(
      service.sendMessage(caseId, '미디어 질문', fileIds: const ['photo_1']),
      throwsA(
        isA<ChatServiceException>().having(
          (error) => error.message,
          'message',
          contains('외부 AI'),
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('real text chat 403 requests external AI opt-in explicitly', () async {
    final adapter = _QueueAdapter([
      _reply(403, {
        'error': {
          'code': 'consent_required',
          'message': 'consent required',
          'details': {
            'documents': ['external_ai']
          },
        }
      }),
    ]);
    final service = ChatService(
      dio: _dio(adapter),
      accessToken: () async => 'token',
      canUseExternalAi: () => false,
    );

    await expectLater(
      service.sendMessage(caseId, '텍스트 질문'),
      throwsA(isA<ExternalAiConsentRequiredException>()),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('push registration is removed and can register for the next owner',
      () async {
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'registration': {'id': 'registration_1'}
        }
      }),
      _reply(200, {
        'data': {'deleted': true}
      }),
      _reply(200, {
        'data': {
          'registration': {'id': 'registration_2'}
        }
      }),
    ]);
    final client = PushRegistrationClient(dio: _dio(adapter));

    await client.register(
      token: 'firebase-token',
      accessToken: 'owner-a-token',
      isIOS: true,
    );
    await client.unregister();
    await client.register(
      token: 'firebase-token-2',
      accessToken: 'owner-b-token',
      isIOS: false,
    );

    expect(adapter.requests.map((request) => request.method),
        ['PUT', 'DELETE', 'PUT']);
    expect(adapter.requests[1].path, '/api/v1/push/tokens/registration_1');
    expect(
        adapter.requests.last.headers['Authorization'], 'Bearer owner-b-token');
  });

  test('push registration conflict is surfaced instead of accepted', () async {
    final client = PushRegistrationClient(
      dio: _dio(_QueueAdapter([
        _reply(409, {
          'error': {
            'code': 'push_token_conflict',
            'message': 'push token is already registered',
          }
        }),
      ])),
    );

    await expectLater(
      client.register(
        token: 'firebase-token',
        accessToken: 'owner-b-token',
        isIOS: false,
      ),
      throwsA(isA<PushRegistrationException>()),
    );
  });

  test('auth sign-out callback runs while the owner token is available',
      () async {
    String? tokenDuringCleanup;
    late AuthNotifier auth;
    auth = AuthNotifier(
      dio: _dio(_QueueAdapter([
        _reply(200, {
          'data': {'revoked': true}
        }),
      ])),
      tokenStore: MemoryAuthStore(),
      restoreSession: false,
      initialAccessToken: 'owner-token',
      initialRefreshToken: 'refresh-token',
      beforeSignOut: () async {
        tokenDuringCleanup = auth.accessToken;
      },
    );

    await auth.logout();

    expect(tokenDuringCleanup, 'owner-token');
  });

  test('chat attachment choices include only backend-supported AI MIME types',
      () async {
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'files': [
            _file('photo_jpeg', caseId, 'evidence_photo', 'image/jpeg'),
            _file('photo_png', caseId, 'evidence_photo', 'image/png'),
            _file('photo_gif', caseId, 'evidence_photo', 'image/gif'),
            _file('audio_1', caseId, 'evidence_audio', 'audio/mp4'),
            _file('video_mp4', caseId, 'additional_video', 'video/mp4'),
            _file('video_mov', caseId, 'additional_video', 'video/quicktime'),
            _file(
              'video_mkv',
              caseId,
              'additional_video',
              'video/x-matroska',
            ),
            _file('original_1', caseId, 'original_video', 'video/mp4'),
          ],
          'next_cursor': null,
        }
      }),
    ]);
    final service = BackendEvidenceService(
      apiDio: _dio(adapter),
      storageDio: Dio(),
      accessToken: () async => 'token',
    );

    final files = await service.listAiEligibleFiles(caseId);

    expect(files.map((file) => file.id), [
      'photo_jpeg',
      'photo_png',
      'video_mp4',
    ]);
  });

  test('AI attachment selection rejects more than 10 MiB before chat', () {
    final files = [
      BackendCaseFile.fromJson(
        {
          ..._file('photo_1', caseId, 'evidence_photo', 'image/jpeg'),
          'size': 6 * 1024 * 1024
        },
        expectedCaseId: caseId,
      ),
      BackendCaseFile.fromJson(
        {
          ..._file('video_1', caseId, 'additional_video', 'video/mp4'),
          'size': 5 * 1024 * 1024
        },
        expectedCaseId: caseId,
      ),
    ];

    expect(
      () => validateAiAttachmentSelection(files),
      throwsA(
        isA<EvidenceServiceException>().having(
          (error) => error.message,
          'message',
          '선택한 자료 합계는 10MB 이하여야 합니다',
        ),
      ),
    );
  });

  test('AI attachment selection rejects an unsupported photo MIME', () {
    final file = BackendCaseFile.fromJson(
      _file('photo_gif', caseId, 'evidence_photo', 'image/gif'),
      expectedCaseId: caseId,
    );

    expect(
      () => validateAiAttachmentSelection([file]),
      throwsA(
        isA<EvidenceServiceException>().having(
          (error) => error.message,
          'message',
          'AI 분석은 JPEG/PNG 사진과 MP4 영상만 지원합니다.',
        ),
      ),
    );
  });

  test('case creation is blocked before required collection consent', () async {
    var lookedUpDevice = false;
    final service = CaseService(
      dio: _dio(_QueueAdapter([])),
      accessToken: () async => 'token',
      savedDevice: () async {
        lookedUpDevice = true;
        return (id: 'device_1', name: 'device');
      },
      activeCase: () => null,
      onActiveCaseChanged: (_) {},
      canCollect: () => false,
    );

    await expectLater(
      service.createSensorCase(),
      throwsA(isA<CollectionConsentRequiredException>()),
    );
    expect(lookedUpDevice, isFalse);
  });

  test('push parser keeps analysis events scoped to their case and report', () {
    final ready = AppPushEvent.tryParse({
      'type': 'analysis_ready',
      'case_id': caseId,
      'job_id': 'job_1',
      'report_id': 'report_1',
    });
    final needsInput = AppPushEvent.tryParse({
      'type': 'analysis_needs_input',
      'case_id': caseId,
      'job_id': 'job_2',
      'report_id': 'report_2',
    });
    final failed = AppPushEvent.tryParse({
      'type': 'analysis_failed',
      'case_id': caseId,
      'job_id': 'job_3',
    });

    expect(ready?.type, AppPushType.analysisReady);
    expect(ready?.caseId, caseId);
    expect(ready?.reportId, 'report_1');
    expect(needsInput?.type, AppPushType.analysisNeedsInput);
    expect(failed?.type, AppPushType.analysisFailed);
    expect(PushService.registrationPayload('firebase-token', isIOS: true), {
      'provider': 'fcm',
      'token': 'firebase-token',
      'device_label': 'iOS device',
    });
  });

  test('analysis push routing verifies current job and auth generation',
      () async {
    final routes = <String>[];
    var generation = 7;
    final router = AnalysisPushRouter(
      validateEvent: (event) async => true,
      authGeneration: () => generation,
      onReady: (caseId, jobId, reportId) =>
          routes.add('ready:$caseId:$jobId:$reportId'),
      onNeedsInput: (caseId, jobId) => routes.add('needs:$caseId:$jobId'),
      onFailed: (caseId, jobId) => routes.add('failed:$caseId:$jobId'),
    );
    final ready = AppPushEvent.tryParse({
      'type': 'analysis_ready',
      'case_id': caseId,
      'job_id': 'job_1',
      'report_id': 'report_1',
    })!;
    final failed = AppPushEvent.tryParse({
      'type': 'analysis_failed',
      'case_id': caseId,
      'job_id': 'job_2',
    })!;

    expect(await router.handle(ready), isTrue);
    expect(await router.handle(ready), isFalse);
    expect(await router.handle(failed), isTrue);

    expect(routes, [
      'ready:$caseId:job_1:report_1',
      'failed:$caseId:job_2',
    ]);

    final delayed = Completer<bool>();
    final fencedRouter = AnalysisPushRouter(
      validateEvent: (_) => delayed.future,
      authGeneration: () => generation,
      onReady: (caseId, jobId, reportId) => routes.add('late'),
      onNeedsInput: (caseId, jobId) => routes.add('late'),
      onFailed: (caseId, jobId) => routes.add('late'),
    );
    final pending = fencedRouter.handle(ready);
    generation++;
    delayed.complete(true);
    expect(await pending, isFalse);
    expect(routes, isNot(contains('late')));
  });

  test('push verifier rejects a stale failure behind a newer owned report',
      () async {
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'job': {
            'id': 'job_old',
            'case_id': caseId,
            'kind': 'analysis',
            'status': 'failed',
            'available_at': '2026-10-15T00:00:00Z',
            'started_at': '2026-10-15T00:00:01Z',
            'finished_at': '2026-10-15T00:00:02Z',
            'error_code': 'job_failed',
          },
          'report': null,
        }
      }),
      _reply(200, {
        'data': {
          'reports': [
            {
              'id': 'report_new',
              'case_id': caseId,
              'version': 2,
              'created_at': '2026-10-15T00:01:00Z',
              'text': 'newer',
              'analysis': const <String, dynamic>{},
            }
          ],
          'next_cursor': null,
        }
      }),
    ]);
    final verifier = AnalysisPushEventVerifier(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );
    final event = AppPushEvent.tryParse({
      'type': 'analysis_failed',
      'case_id': caseId,
      'job_id': 'job_old',
    })!;

    expect(await verifier.validate(event), isFalse);
    expect(adapter.requests.first.path, '/api/v1/cases/$caseId/jobs/job_old');
    expect(adapter.requests.last.path, '/api/v1/cases/$caseId/reports');
  });

  test('push verifier requires ready report to belong to exact current job',
      () async {
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'job': {
            'id': 'job_1',
            'case_id': caseId,
            'kind': 'analysis',
            'status': 'done',
            'available_at': '2026-10-15T00:00:00Z',
            'started_at': '2026-10-15T00:00:01Z',
            'finished_at': '2026-10-15T00:00:02Z',
            'error_code': null,
          },
          'report': {
            'id': 'report_other',
            'case_id': caseId,
            'version': 1,
            'created_at': '2026-10-15T00:00:02Z',
            'text': 'other',
            'analysis': const <String, dynamic>{},
          },
        }
      }),
    ]);
    final verifier = AnalysisPushEventVerifier(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );
    final event = AppPushEvent.tryParse({
      'type': 'analysis_ready',
      'case_id': caseId,
      'job_id': 'job_1',
      'report_id': 'report_expected',
    })!;

    expect(await verifier.validate(event), isFalse);
    expect(adapter.requests, hasLength(1));
  });

  test('push verifier accepts the exact ready report only when it is latest',
      () async {
    final report = {
      'id': 'report_1',
      'case_id': caseId,
      'version': 2,
      'created_at': '2026-10-15T00:00:02Z',
      'text': 'ready',
      'analysis': {
        'status': 'complete',
        'model': {'needs_user_input': const <String>[]},
      },
    };
    final adapter = _QueueAdapter([
      _reply(200, {
        'data': {
          'job': {
            'id': 'job_1',
            'case_id': caseId,
            'kind': 'analysis',
            'status': 'done',
            'available_at': '2026-10-15T00:00:00Z',
            'started_at': '2026-10-15T00:00:01Z',
            'finished_at': '2026-10-15T00:00:02Z',
            'error_code': null,
          },
          'report': report,
        }
      }),
      _reply(200, {
        'data': {
          'reports': [report],
          'next_cursor': null,
        }
      }),
    ]);
    final verifier = AnalysisPushEventVerifier(
      dio: _dio(adapter),
      accessToken: () async => 'token',
    );
    final event = AppPushEvent.tryParse({
      'type': 'analysis_ready',
      'case_id': caseId,
      'job_id': 'job_1',
      'report_id': 'report_1',
    })!;

    expect(await verifier.validate(event), isTrue);
  });

  group('consent lifecycle', () {
    testWidgets('consent intro covers configured text and selected media',
        (tester) async {
      final controller = ConsentController(
        service: _FakeConsentService(_snapshot(true, true, false)),
      );
      await controller.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            consentControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: ConsentScreen()),
        ),
      );

      expect(find.textContaining('텍스트 답변'), findsOneWidget);
      expect(find.textContaining('선택한 사진·추가 영상'), findsOneWidget);
      expect(find.textContaining('사진이나 추가 영상을 보낼 때만'), findsNothing);
    });

    test('new user remains gated without automatic unchecked grants', () async {
      final service = _FakeConsentService(_snapshot(false, false, false));
      final controller = ConsentController(service: service);

      await controller.load();

      expect(controller.state.needsRequiredConsent, isTrue);
      expect(controller.state.canUseExternalAi, isFalse);
      expect(service.updates, isEmpty);
    });

    test('returning user with current required grants can collect', () async {
      final service = _FakeConsentService(_snapshot(true, true, false));
      final controller = ConsentController(service: service);

      await controller.load();

      expect(controller.state.needsRequiredConsent, isFalse);
      expect(controller.state.canCollect, isTrue);
    });

    test('external AI can be revoked without blocking collection', () async {
      final service = _FakeConsentService(_snapshot(true, true, true));
      final controller = ConsentController(service: service);
      await controller.load();

      await controller.setGrant(ConsentDocument.externalAi, false);

      expect(controller.state.canCollect, isTrue);
      expect(controller.state.canUseExternalAi, isFalse);
      expect(service.updates.single, (ConsentDocument.externalAi, false));
    });

    test('concurrent document responses merge into latest consent state',
        () async {
      final service = _DelayedConsentService(_snapshot(true, true, false));
      final controller = ConsentController(service: service);
      await controller.load();

      final privacy = controller.setGrant(ConsentDocument.privacy, false);
      final location = controller.setGrant(ConsentDocument.location, false);
      service.complete(ConsentDocument.location);
      await location;
      service.complete(ConsentDocument.privacy);
      await privacy;

      expect(controller.state.snapshot!.isGranted(ConsentDocument.privacy),
          isFalse);
      expect(controller.state.snapshot!.isGranted(ConsentDocument.location),
          isFalse);
    });

    test('same-document writes persist in tap order', () async {
      final service = _DelayedConsentService(_snapshot(true, true, false));
      final controller = ConsentController(service: service);
      await controller.load();

      final first = controller.setGrant(ConsentDocument.externalAi, true);
      final second = controller.setGrant(ConsentDocument.externalAi, false);

      expect(service.pending, hasLength(1));
      expect(service.pending.single.granted, isTrue);
      service.completeAt(0);
      await first;
      await Future<void>.delayed(Duration.zero);

      expect(service.pending, hasLength(2));
      expect(service.pending.last.granted, isFalse);
      service.completeAt(1);
      await second;

      expect(service.snapshot.isGranted(ConsentDocument.externalAi), isFalse);
      expect(controller.state.snapshot!.isGranted(ConsentDocument.externalAi),
          isFalse);
    });

    test('failed same-document write does not wedge the latest intent',
        () async {
      final service = _DelayedConsentService(_snapshot(true, true, false));
      final controller = ConsentController(service: service);
      await controller.load();

      final first = controller.setGrant(ConsentDocument.externalAi, true);
      final firstFailure = expectLater(first, throwsA(isA<StateError>()));
      final second = controller.setGrant(ConsentDocument.externalAi, false);

      expect(service.pending, hasLength(1));
      service.failAt(0, StateError('grant failed'));
      await firstFailure;
      await Future<void>.delayed(Duration.zero);

      expect(service.pending, hasLength(2));
      expect(service.pending.last.granted, isFalse);
      service.completeAt(1);
      await second;

      expect(service.snapshot.isGranted(ConsentDocument.externalAi), isFalse);
      expect(controller.state.snapshot!.isGranted(ConsentDocument.externalAi),
          isFalse);
    });
  });

  test('insurance cache is owner fenced and explicitly stale', () async {
    final store = MemoryAuthStore();
    final cache = OwnerFencedInsuranceCache(store);
    await cache.write(
      owner: 'first@example.com',
      company: '첫 보험',
      phone: '1111',
    );

    expect(await cache.read('second@example.com'), isNull);
    final restored = await cache.read('first@example.com');
    expect(restored?.company, '첫 보험');
    expect(restored?.isStale, isTrue);
  });

  test('delayed insurance write cannot resurrect cache after owner changes',
      () async {
    final store = _DelayedAuthStore();
    final cache = OwnerFencedInsuranceCache(store);
    var current = true;

    final pending = cache.write(
      owner: 'first@example.com',
      company: '첫 보험',
      phone: '1111',
      isCurrentOwner: () => current,
    );
    await store.ownerWriteStarted.future;
    current = false;
    store.releaseOwnerWrite.complete();

    expect(await pending, isFalse);
    expect(await cache.read('first@example.com'), isNull);
  });

  test('stale insurance cleanup cannot erase a newer same-owner write',
      () async {
    final store = _DelayedAuthStore();
    final cache = OwnerFencedInsuranceCache(store);
    var oldGeneration = true;

    final oldWrite = cache.write(
      owner: 'same@example.com',
      company: '이전 보험',
      isCurrentOwner: () => oldGeneration,
    );
    await store.ownerWriteStarted.future;
    oldGeneration = false;
    expect(
      await cache.write(
        owner: 'same@example.com',
        company: '새 보험',
        isCurrentOwner: () => true,
      ),
      isTrue,
    );
    store.releaseOwnerWrite.complete();
    expect(await oldWrite, isFalse);

    expect((await cache.read('same@example.com'))?.company, '새 보험');
  });
}

Map<String, dynamic> _file(
  String id,
  String caseId,
  String kind,
  String mime,
) =>
    {
      'id': id,
      'case_id': caseId,
      'kind': kind,
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'size': 100,
      'mime': mime,
      'created_at': '2026-10-15T00:00:00Z',
    };

ConsentSnapshot _snapshot(bool privacy, bool location, bool externalAi) =>
    ConsentSnapshot(
      version: '2026-10-15',
      grants: {
        ConsentDocument.privacy: privacy,
        ConsentDocument.location: location,
        ConsentDocument.externalAi: externalAi,
      },
    );

class _FakeConsentService extends ConsentService {
  _FakeConsentService(this.snapshot) : super(accessToken: () async => 'token');

  ConsentSnapshot snapshot;
  final updates = <(ConsentDocument, bool)>[];

  @override
  Future<PolicyBundle> fetchPolicies() async => PolicyBundle(
        version: '2026-10-15',
        disclaimer: legalReferenceWarning,
        documents: ConsentDocument.values
            .map((document) => PolicyDocument(
                  document: document,
                  version: '2026-10-15',
                  title: document.apiName,
                  text: '${document.apiName} policy',
                  required: document != ConsentDocument.externalAi,
                ))
            .toList(),
      );

  @override
  Future<ConsentSnapshot> fetchConsents() async => snapshot;

  @override
  Future<void> setConsent({
    required ConsentDocument document,
    required String version,
    required bool granted,
  }) async {
    updates.add((document, granted));
    snapshot = ConsentSnapshot(
      version: snapshot.version,
      grants: {...snapshot.grants, document: granted},
    );
  }
}

class _DelayedConsentService extends _FakeConsentService {
  _DelayedConsentService(super.snapshot);

  final pending =
      <({ConsentDocument document, bool granted, Completer<void> done})>[];

  @override
  Future<void> setConsent({
    required ConsentDocument document,
    required String version,
    required bool granted,
  }) {
    final done = Completer<void>();
    pending.add((document: document, granted: granted, done: done));
    return done.future;
  }

  void complete(ConsentDocument document) {
    completeAt(pending.indexWhere((item) => item.document == document));
  }

  void completeAt(int index) {
    final request = pending[index];
    snapshot = ConsentSnapshot(
      version: snapshot.version,
      grants: {...snapshot.grants, request.document: request.granted},
    );
    request.done.complete();
  }

  void failAt(int index, Object error) =>
      pending[index].done.completeError(error);
}

class _DelayedAuthStore extends MemoryAuthStore {
  final ownerWriteStarted = Completer<void>();
  final releaseOwnerWrite = Completer<void>();
  var _delayedOwner = false;

  @override
  Future<void> write(String key, String value) async {
    if (key == 'insurance_cache_owner' && !_delayedOwner) {
      _delayedOwner = true;
      ownerWriteStarted.complete();
      await releaseOwnerWrite.future;
    }
    await super.write(key, value);
  }
}

Map<String, dynamic> _body(RequestOptions request) {
  final data = request.data;
  if (data is String) return Map<String, dynamic>.from(jsonDecode(data) as Map);
  return Map<String, dynamic>.from(data as Map);
}

Dio _dio(HttpClientAdapter adapter) => Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ))
      ..httpClientAdapter = adapter;

({int status, Map<String, dynamic> body}) _reply(
  int status,
  Map<String, dynamic> body,
) =>
    (status: status, body: body);

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<({int status, Map<String, dynamic> body})> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
