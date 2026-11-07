// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'router/app_router.dart';
import 'services/case_service.dart';
import 'services/notification_service.dart';
import 'services/sensor_service.dart';
import 'services/push_service.dart';
import 'services/auth_service.dart';
import 'services/consent_service.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (FCM 푸시 알림)
  // 웹에서는 별도 Firebase Web 설정이 필요하므로 네이티브(Android/iOS)에서만 초기화한다.
  // 웹은 '결과 조회·표시' 전용이므로 푸시 없이도 동작한다.
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 백그라운드/종료 상태 FCM 메시지 핸들러 등록 (최상위 함수)
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  runApp(
    // ProviderScope: Riverpod 전역 상태 컨테이너
    const ProviderScope(
      child: BlackboxApp(),
    ),
  );
}

class BlackboxApp extends ConsumerStatefulWidget {
  const BlackboxApp({super.key});

  @override
  ConsumerState<BlackboxApp> createState() => _BlackboxAppState();
}

class _BlackboxAppState extends ConsumerState<BlackboxApp> {
  bool _pushWired = false;
  late final AnalysisPushRouter _analysisPushRouter;
  late final AccidentPushRouter _accidentPushRouter;
  AccidentPush? _pendingAccidentOpen;

  @override
  void initState() {
    super.initState();

    // 사고 푸시 수신 → 블박(외부) 트리거로 사고 동작 연결
    final push = ref.read(pushServiceProvider);
    ref.read(authProvider.notifier).beforeSignOut = push.endSession;
    final pushVerifier = AnalysisPushEventVerifier(
      accessToken: () => ref.read(authProvider.notifier).validAccessToken(),
    );
    _analysisPushRouter = AnalysisPushRouter(
      validateEvent: pushVerifier.validate,
      authGeneration: () => ref.read(authProvider.notifier).sessionGeneration,
      onReady: (caseId, jobId, reportId) => ref.read(appRouterProvider).goNamed(
        'analysis',
        extra: {
          'case_id': caseId,
          'job_id': jobId,
          'report_id': reportId,
        },
      ),
      onNeedsInput: (caseId, jobId) => ref.read(appRouterProvider).goNamed(
        'analysis',
        extra: {
          'case_id': caseId,
          'job_id': jobId,
          'error': '현재 모델은 도로유형 선택이 필요합니다',
        },
      ),
      onFailed: (caseId, jobId) => ref.read(appRouterProvider).goNamed(
        'analysis',
        extra: {
          'case_id': caseId,
          'job_id': jobId,
          'error': '분석에 실패했습니다. 입력을 확인한 뒤 다시 시도해 주세요.',
        },
      ),
    );
    _accidentPushRouter = AccidentPushRouter(
      validateOwnedCase: (caseId) async {
        final owned =
            await ref.read(caseServiceProvider).selectOwnedCase(caseId);
        return owned.id == caseId;
      },
      authGeneration: () => ref.read(authProvider.notifier).sessionGeneration,
      canCollect: () => ref.read(consentControllerProvider).canCollect,
      onOpen: (accident) {
        ref.read(sensorProvider.notifier).dismissAlert();
        ref.read(appRouterProvider).goNamed(
              'accident-detected',
              extra: accident.caseId,
            );
      },
    );
    push.onAccidentPush = (accident) {
      if (!ref.read(consentControllerProvider).canCollect) return;
      ref.read(sensorProvider.notifier).triggerFromExternal(
            caseId: accident.caseId,
            lat: accident.lat,
            lon: accident.lon,
            gForce: accident.gForce,
          );
    };
    push.onAccidentOpened = _openAccidentNotification;
    push.onAnalysisPush = (event) async {
      await _analysisPushRouter.handle(event);
    };
    unawaited(push.listen());
    NotificationService.initialize(
      onAccidentOpened: (caseId) =>
          _openAccidentNotification(AccidentPush(caseId: caseId)),
    ).then((caseId) {
      if (caseId != null) {
        _openAccidentNotification(AccidentPush(caseId: caseId));
      }
    });
  }

  Future<void> _openAccidentNotification(AccidentPush accident) async {
    if (!CaseService.isBackendCaseId(accident.caseId)) return;
    final auth = ref.read(authProvider);
    final consent = ref.read(consentControllerProvider);
    if (auth.status == AuthStatus.unknown ||
        consent.status == ConsentLoadStatus.idle ||
        consent.status == ConsentLoadStatus.loading) {
      _pendingAccidentOpen = accident;
      return;
    }
    _pendingAccidentOpen = null;
    if (auth.status != AuthStatus.authenticated || !consent.canCollect) return;
    await _accidentPushRouter.handle(accident);
  }

  void _deliverPendingAccident() {
    final pending = _pendingAccidentOpen;
    if (pending != null) _openAccidentNotification(pending);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // 로그인(authenticated) 되면 FCM 초기화 + 토큰 등록을 1회 수행.
    // (로그인 전에는 백엔드 토큰 등록이 거부되므로 인증 후에 등록한다.)
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && !_pushWired) {
        _pushWired = true;
        ref.read(pushServiceProvider).initialize();
      }
      // 로그아웃 시 다음 로그인에서 다시 등록되도록 플래그 해제
      if (next.status == AuthStatus.unauthenticated) {
        _pushWired = false;
        _pendingAccidentOpen = null;
      }
      if (next.status == AuthStatus.authenticated) _deliverPendingAccident();
    });
    ref.listen<ConsentState>(consentControllerProvider, (prev, next) {
      if (next.status == ConsentLoadStatus.ready) _deliverPendingAccident();
    });

    return MaterialApp.router(
      title: 'DriveGuard AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      //darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
