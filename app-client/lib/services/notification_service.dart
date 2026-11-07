// lib/services/notification_service.dart
//
// 사용 패키지:
//   flutter_local_notifications: ^17.1.2
//   firebase_messaging: ^14.7.19

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── 초기화 (main.dart에서 호출) ──────────────────────────
  static Future<String?> initialize({
    required void Function(String caseId) onAccidentOpened,
  }) async {
    // 웹: 로컬 알림 미사용 (결과 조회·표시 전용)
    if (kIsWeb) return null;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final caseId = accidentCaseIdFromPayload(response.payload);
        if (caseId != null) onAccidentOpened(caseId);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp != true) return null;
    return accidentCaseIdFromPayload(launch?.notificationResponse?.payload);
  }

  static String? accidentCaseIdFromPayload(Object? payload) {
    if (payload is! String || !payload.startsWith('accident:')) return null;
    final caseId = payload.substring('accident:'.length);
    return RegExp(r'^case_[0-9a-f]{32}$').hasMatch(caseId) ? caseId : null;
  }

  // ── 충격 감지 긴급 알림 ──────────────────────────────────
  static Future<void> showImpactAlert({
    required String caseId,
    double? gForce,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'impact_channel',
      '충격 감지 알림',
      channelDescription: '사고 충격 감지 시 표시되는 긴급 알림',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,        // 잠금화면에서도 전체 화면으로 표시
      sound: RawResourceAndroidNotificationSound('emergency_alert'),
    );

    await _plugin.show(
      0,
      '사고가 나셨습니까?',
      gForce == null
          ? '충격이 감지되었습니다.'
          : '충격이 감지되었습니다. (G-Force: ${gForce.toStringAsFixed(1)}G)',
      const NotificationDetails(android: androidDetails),
      payload: 'accident:$caseId',
    );
  }

  // ── AI 분석 완료 알림 ────────────────────────────────────
  static Future<void> showAnalysisComplete({
    required String accidentId,
    required double faultRatio,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'analysis_channel',
      'AI 분석 알림',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      1,
      '📊 AI 과실 분석이 완료되었습니다',
      '예상 과실 비율: ${(faultRatio * 100).toStringAsFixed(0)}% | 리포트를 확인하세요',
      const NotificationDetails(android: androidDetails),
    );
  }
}
