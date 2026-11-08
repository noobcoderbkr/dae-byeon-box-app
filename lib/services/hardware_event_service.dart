// lib/services/hardware_event_service.dart
//
// 블랙박스(하드웨어) 충격 알림 수신
//
// 구조: 블랙박스 → MQTT → 서버가 구독 → 앱은 계정 API를 조회
//   GET /api/v1/hardware-events?limit=20   (Authorization: Bearer <앱 로그인 토큰>)
//
// - 홈 화면이 보일 때만 1초 간격으로 조회한다. 이전 요청이 끝나기 전에는 다음 요청을 보내지 않는다.
// - 처음 조회한 이벤트는 '이미 본 것'으로 처리해, 앱을 켜자마자 예전 충격으로 화면이 뜨지 않게 한다.
// - 서버 시각 기준 2분보다 오래된 충격은 새 사고로 띄우지 않는다.
// - 중복 제거는 (device_id, event_id) 기준. (QoS 1 이라 같은 알림이 여러 번 올 수 있음)
// - 429 를 받으면 Retry-After 또는 지수 백오프로 쉰다.
// - 알림이 영상보다 먼저 오므로 case_id 는 처음에 null 일 수 있다. waitForCaseId 로 기다린다.
//
// 주의: device_id 는 계정에 등록된 서버 기기 ID(dev_...),
//       source_device_id 는 실제 블랙박스(Pi) ID(violet-dashcam-1 / -2)다.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'case_service.dart';

// ── 모델 ────────────────────────────────────────────────────
class HardwareEvent {
  const HardwareEvent({
    required this.eventId,
    required this.deviceId,
    required this.sourceDeviceId,
    required this.deviceName,
    required this.triggerUtc,
    required this.source,
    required this.testEvent,
    required this.impactG,
    required this.caseId,
  });

  final String eventId;
  final String deviceId; // 서버 기기 ID (dev_...)
  final String sourceDeviceId; // 실제 블랙박스 ID (violet-dashcam-1 / -2)
  final String deviceName;
  final DateTime triggerUtc;
  final String source;
  final bool testEvent;
  final double? impactG;
  final String? caseId;

  /// 중복 제거 키: (device_id, event_id)
  String get key => '$deviceId|$eventId';

  bool get isRear => sourceDeviceId == 'violet-dashcam-2';

  String get positionLabel {
    if (sourceDeviceId == 'violet-dashcam-1') return '전방 블랙박스';
    if (sourceDeviceId == 'violet-dashcam-2') return '후방 블랙박스';
    return deviceName.isEmpty ? sourceDeviceId : deviceName;
  }

  /// 충격 세기 표시 (없으면 '측정값 없음')
  String get impactLabel =>
      impactG == null ? '측정값 없음' : '${impactG!.toStringAsFixed(1)}G';

  static HardwareEvent? tryParse(Object? value) {
    if (value is! Map) return null;
    final m = Map<String, dynamic>.from(value);
    final eventId = m['event_id'];
    final deviceId = m['device_id'];
    final sourceDeviceId = m['source_device_id'];
    final trigger = m['trigger_utc'];
    if (eventId is! String || eventId.isEmpty) return null;
    if (deviceId is! String || deviceId.isEmpty) return null;
    if (sourceDeviceId is! String) return null;
    final triggerUtc = trigger is String ? DateTime.tryParse(trigger) : null;
    if (triggerUtc == null) return null;
    final impact = m['impact_g'];
    final caseId = m['case_id'];
    return HardwareEvent(
      eventId: eventId,
      deviceId: deviceId,
      sourceDeviceId: sourceDeviceId,
      deviceName: m['device_name'] is String ? m['device_name'] as String : '',
      triggerUtc: triggerUtc.toUtc(),
      source: m['source'] is String ? m['source'] as String : '',
      testEvent: m['test_event'] == true,
      impactG: impact is num ? impact.toDouble() : null,
      caseId: caseId is String && caseId.isNotEmpty ? caseId : null,
    );
  }
}

class HardwareEventPage {
  const HardwareEventPage({
    required this.events,
    required this.serverUtc,
    required this.sourceStatus,
  });
  final List<HardwareEvent> events;
  final DateTime serverUtc;
  final String sourceStatus; // ok / unavailable / not_configured
}

class HardwareEventRateLimited implements Exception {
  const HardwareEventRateLimited(this.retryAfter);
  final Duration? retryAfter;
}

// ── API ─────────────────────────────────────────────────────
class HardwareEventService {
  HardwareEventService({required Dio dio, required AccessTokenProvider accessToken})
      : _dio = dio,
        _accessToken = accessToken;

  final Dio _dio;
  final AccessTokenProvider _accessToken;

  Future<HardwareEventPage> fetch({int limit = 20}) async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) throw const CaseAuthenticationException();
    final response = await _dio.get(
      '/api/v1/hardware-events',
      queryParameters: {'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == 429) {
      final header = response.headers.value('retry-after');
      final seconds = header == null ? null : int.tryParse(header.trim());
      throw HardwareEventRateLimited(
          seconds == null ? null : Duration(seconds: seconds));
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CaseAuthenticationException();
    }
    if (response.statusCode != 200 || response.data is! Map) {
      throw CaseServiceException('충격 알림을 불러오지 못했습니다. (${response.statusCode})');
    }
    final data = (response.data as Map)['data'];
    if (data is! Map) {
      throw const CaseServiceException('서버의 충격 알림 응답이 올바르지 않습니다.');
    }
    final rawEvents = data['events'];
    final events = rawEvents is List
        ? rawEvents
            .map(HardwareEvent.tryParse)
            .whereType<HardwareEvent>()
            .toList()
        : <HardwareEvent>[];
    final server = data['server_utc'];
    return HardwareEventPage(
      events: events,
      serverUtc: (server is String ? DateTime.tryParse(server) : null)?.toUtc() ??
          DateTime.now().toUtc(),
      sourceStatus: data['source_status'] is String
          ? data['source_status'] as String
          : 'ok',
    );
  }
}

final hardwareEventServiceProvider = Provider<HardwareEventService>((ref) {
  return HardwareEventService(
    dio: ref.read(caseApiDioProvider),
    accessToken: () => ref.read(authProvider.notifier).validAccessToken(),
  );
});

// ── 조회기 (홈 화면에서 켜고 끈다) ──────────────────────────
class HardwareEventWatcher {
  HardwareEventWatcher(this._service);

  final HardwareEventService _service;

  static const pollInterval = Duration(seconds: 1);
  static const maxAge = Duration(minutes: 2);

  final _incidents = StreamController<HardwareEvent>.broadcast();
  final Set<String> _seen = {};
  final Map<String, HardwareEvent> _latest = {};
  bool _seeded = false;
  bool _running = false;
  bool _inFlight = false;
  int _loopId = 0;
  Duration _backoff = Duration.zero;
  String _sourceStatus = 'ok';

  /// 새 충격 (중복 제거 후)
  Stream<HardwareEvent> get incidents => _incidents.stream;

  /// 마지막 조회 기준 서버 블랙박스 연결 상태
  String get sourceStatus => _sourceStatus;

  bool get isRunning => _running;

  bool Function() _isActive = _always;
  static bool _always() => true;

  /// [isActive] 가 false 인 동안(다른 화면이 위에 있거나 앱이 백그라운드)은 조회하지 않는다.
  void start({bool Function()? isActive}) {
    _isActive = isActive ?? _always;
    if (_running) return;
    _running = true;
    final id = ++_loopId;
    _loop(id);
  }

  void stop() {
    _running = false;
    ++_loopId;
  }

  /// 로그아웃·계정 변경 시 초기화
  void reset() {
    stop();
    _seen.clear();
    _latest.clear();
    _seeded = false;
    _backoff = Duration.zero;
  }

  Future<void> _loop(int id) async {
    while (_running && id == _loopId) {
      if (_isActive()) await _pollOnce();
      if (!_running || id != _loopId) return;
      final wait = _backoff > Duration.zero ? _backoff : pollInterval;
      await Future<void>.delayed(wait);
    }
  }

  Future<void> _pollOnce() async {
    if (_inFlight) return; // 이전 요청이 끝나기 전에는 겹쳐 보내지 않는다
    _inFlight = true;
    try {
      final page = await _service.fetch();
      _backoff = Duration.zero;
      _sourceStatus = page.sourceStatus;
      for (final event in page.events) {
        _latest[event.key] = event;
      }
      if (!_seeded) {
        // 첫 조회: 이미 있던 충격은 새 사고로 띄우지 않는다
        _seen.addAll(page.events.map((e) => e.key));
        _seeded = true;
        return;
      }
      // 오래된 것부터 순서대로 알린다 (응답은 최신순)
      for (final event in page.events.reversed) {
        if (_seen.contains(event.key)) continue;
        _seen.add(event.key);
        final age = page.serverUtc.difference(event.triggerUtc);
        if (age > maxAge) continue;
        if (!_incidents.isClosed) _incidents.add(event);
      }
    } on HardwareEventRateLimited catch (error) {
      final next = error.retryAfter ??
          (_backoff == Duration.zero
              ? const Duration(seconds: 2)
              : _backoff * 2);
      _backoff = next > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : next;
    } catch (_) {
      // 네트워크 오류 등: 잠깐 쉬었다가 다시 조회
      _backoff = _backoff == Duration.zero
          ? const Duration(seconds: 2)
          : (_backoff * 2 > const Duration(seconds: 15)
              ? const Duration(seconds: 15)
              : _backoff * 2);
    } finally {
      _inFlight = false;
    }
  }

  /// 같은 기기·같은 이벤트에 case_id 가 연결될 때까지 기다린다.
  /// [isActive] 가 false 가 되면 null 을 돌려주고 멈춘다.
  Future<String?> waitForCaseId(
    HardwareEvent event, {
    required bool Function() isActive,
    Duration interval = const Duration(seconds: 2),
  }) async {
    if (event.caseId != null) return event.caseId;
    while (isActive()) {
      final known = _latest[event.key]?.caseId;
      if (known != null) return known;
      // 이 화면이 떠 있는 동안 홈 화면 조회는 멈춰 있으므로 직접 조회한다
      try {
        final page = await _service.fetch();
        for (final e in page.events) {
          _latest[e.key] = e;
          _seen.add(e.key);
        }
        final found = _latest[event.key]?.caseId;
        if (found != null) return found;
      } catch (_) {
        // 다음 주기에 다시 시도
      }
      if (!isActive()) return null;
      await Future<void>.delayed(interval);
    }
    return null;
  }

  void dispose() {
    stop();
    _incidents.close();
  }
}

final hardwareEventWatcherProvider = Provider<HardwareEventWatcher>((ref) {
  final watcher = HardwareEventWatcher(ref.read(hardwareEventServiceProvider));
  ref.listen<String?>(authProvider.select(authenticatedPrincipal),
      (previous, next) {
    if (previous != next) watcher.reset();
  });
  ref.onDispose(watcher.dispose);
  return watcher;
});
