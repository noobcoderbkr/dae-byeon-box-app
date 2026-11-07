// lib/services/law_analysis_service.dart
//
// 담당 기능: 백엔드 LAW 서버 연동
//   - 사고 정보 JSON을 서버로 전송 (POST /law/analyze-json)
//   - 과실 비율 + 날씨 + 판례를 한 번에 응답받음
//
// 백엔드 문서: ANDROID_INTEGRATION.md 기준
//
// 사용 패키지:
//   dio: ^5.9.2

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 백엔드 LAW 서버 설정 ──────────────────────────────────
// TODO: 백엔드/하드웨어 팀에게 받은 Cloudflare 터널 주소로 교체
//   - Cloudflare: https://xxxx.trycloudflare.com
//   - LAN 직접: http://라즈베리파이IP:9000
const String _lawServerUrl = 'http://10.0.2.2:9000';

// API 토큰 (백엔드에서 설정한 경우만, 없으면 빈 문자열)
const String _lawApiToken = '';

// ══════════════════════════════════════════════════════════
// 응답 모델
// ══════════════════════════════════════════════════════════

// ── 과실 예측 ────────────────────────────────────────────
class FaultPrediction {
  final String scenarioCode;   // 시나리오 코드
  final String scenarioLabel;  // 시나리오 설명 (예: "상대 신호위반 충돌")
  final String ratioText;      // 과실 비율 텍스트 (예: "0:100")
  final int egoFault;          // 내(블랙박스) 과실 정수 (0~100)
  final int opponentFault;     // 상대 과실 정수 (0~100)
  final double confidence;     // 신뢰도 (0.0 ~ 1.0)
  final String explanation;    // 산정 설명
  final String caveat;         // 주의/한계 문구

  FaultPrediction({
    required this.scenarioCode,
    required this.scenarioLabel,
    required this.ratioText,
    required this.egoFault,
    required this.opponentFault,
    required this.confidence,
    this.explanation = '',
    this.caveat = '',
  });

  factory FaultPrediction.fromJson(Map<String, dynamic> json) {
    // ego_fault / opponent_fault 가 있으면 우선 사용, 없으면 ratio_text 파싱
    final ratio = json['ratio_text'] as String? ?? '50:50';
    int ego = (json['ego_fault'] as num?)?.toInt() ?? -1;
    int opp = (json['opponent_fault'] as num?)?.toInt() ?? -1;
    if (ego < 0 || opp < 0) {
      final parts = ratio.split(':');
      ego = parts.length == 2 ? (int.tryParse(parts[0].trim()) ?? 50) : 50;
      opp = parts.length == 2 ? (int.tryParse(parts[1].trim()) ?? 50) : 50;
    }
    return FaultPrediction(
      scenarioCode: json['scenario_code'] as String? ?? 'unknown',
      scenarioLabel: json['scenario_label'] as String? ?? '',
      ratioText: ratio,
      egoFault: ego,
      opponentFault: opp,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String? ?? '',
      caveat: json['caveat'] as String? ?? '',
    );
  }

  double get myFaultRatio => egoFault / 100;
  double get opponentFaultRatio => opponentFault / 100;
}

// ── 날씨 정보 ────────────────────────────────────────────
class WeatherLookup {
  final bool ok;
  final String? matchedHour;
  final double? temperature;
  final double? precipitation;
  final List<String> keywords;

  WeatherLookup({
    required this.ok,
    this.matchedHour,
    this.temperature,
    this.precipitation,
    this.keywords = const [],
  });

  factory WeatherLookup.fromJson(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>?;
    return WeatherLookup(
      ok: json['ok'] as bool? ?? false,
      matchedHour: json['matched_hour'] as String?,
      temperature: (values?['temperature_2m'] as num?)?.toDouble(),
      precipitation: (values?['precipitation'] as num?)?.toDouble(),
      keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
    );
  }
}

// ── 판례 ─────────────────────────────────────────────────
class Precedent {
  final String judgmentName;  // 판결명 (case_name)
  final String caseNumber;    // 사건번호
  final String court;         // 법원
  final String? decisionDate; // 선고일
  final String? sourceUrl;    // 원문 링크
  final String? faultRatioText; // 판례에서 추출된 과실비율 (예: "70:30")
  final String? summary;      // 판례 요지

  Precedent({
    required this.judgmentName,
    required this.caseNumber,
    required this.court,
    this.decisionDate,
    this.sourceUrl,
    this.faultRatioText,
    this.summary,
  });

  factory Precedent.fromJson(Map<String, dynamic> json) {
    return Precedent(
      judgmentName: (json['judgment_name'] ?? json['case_name']) as String? ?? '',
      caseNumber: json['case_number'] as String? ?? '',
      court: json['court'] as String? ?? '',
      decisionDate:
          (json['decision_date'] ?? json['decision_label']) as String?,
      sourceUrl: (json['source_url'] ?? json['detail_link']) as String?,
      faultRatioText: json['extracted_fault_ratio_text'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

// ── 전체 분석 결과 ───────────────────────────────────────
class LawAnalysisResult {
  final String eventId;
  final String? occurredAt;
  final FaultPrediction prediction;
  final WeatherLookup? weather;
  final List<Precedent> precedents;
  final List<String> keywords; // 백엔드가 산출한 법률 키워드/용어

  LawAnalysisResult({
    required this.eventId,
    this.occurredAt,
    required this.prediction,
    this.weather,
    required this.precedents,
    this.keywords = const [],
  });

  factory LawAnalysisResult.fromJson(Map<String, dynamic> json) {
    return LawAnalysisResult(
      eventId: json['event_id'] as String? ?? '',
      occurredAt: json['occurred_at'] as String?,
      prediction: FaultPrediction.fromJson(
          json['prediction'] as Map<String, dynamic>? ?? {}),
      weather: json['weather_lookup'] != null
          ? WeatherLookup.fromJson(
              json['weather_lookup'] as Map<String, dynamic>)
          : null,
      precedents: (json['precedents'] as List?)
              ?.map((e) => Precedent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 분석 상태
// ══════════════════════════════════════════════════════════

enum LawAnalysisStatus { idle, analyzing, done, error }

class LawAnalysisState {
  final LawAnalysisStatus status;
  final LawAnalysisResult? result;
  final String? errorMessage;

  const LawAnalysisState({
    this.status = LawAnalysisStatus.idle,
    this.result,
    this.errorMessage,
  });

  LawAnalysisState copyWith({
    LawAnalysisStatus? status,
    LawAnalysisResult? result,
    String? errorMessage,
  }) =>
      LawAnalysisState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage,
      );
}

// ══════════════════════════════════════════════════════════
// Notifier
// ══════════════════════════════════════════════════════════

class LawAnalysisNotifier extends StateNotifier<LawAnalysisState> {
  LawAnalysisNotifier() : super(const LawAnalysisState());

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _lawServerUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (_lawApiToken.isNotEmpty) 'X-API-Key': _lawApiToken,
      },
    ),
  );

  // ── 사고 분석 요청 ───────────────────────────────────────
  // 백엔드 문서 기준: POST /law/analyze-json?weather=1
  Future<void> analyzeAccident({
    required String eventId,
    required DateTime occurredAt,
    required double latitude,
    required double longitude,
    required String accidentType,
    required List<String> keywords,
    Map<String, dynamic>? facts,
    String? videoPath,
    bool useWeather = true,
  }) async {
    state = state.copyWith(status: LawAnalysisStatus.analyzing);

    try {
      // 요청 JSON 구성 (문서 예시 형식)
      final requestBody = {
        'event_id': eventId,
        'occurred_at': occurredAt.toIso8601String(),
        'gps': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'accident_type': accidentType,
        'keywords': keywords,
        if (facts != null) 'facts': facts,
        if (videoPath != null) 'video_path': videoPath,
      };

      // POST /law/analyze-json?weather=1
      final response = await _dio.post(
        '/law/analyze-json',
        queryParameters: {'weather': useWeather ? 1 : 0},
        data: requestBody,
      );

      final result = LawAnalysisResult.fromJson(response.data);

      state = state.copyWith(
        status: LawAnalysisStatus.done,
        result: result,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        status: LawAnalysisStatus.error,
        errorMessage: '분석 요청 실패: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        status: LawAnalysisStatus.error,
        errorMessage: '오류가 발생했습니다: $e',
      );
    }
  }

  void reset() {
    state = const LawAnalysisState();
  }
}

// ── Provider ─────────────────────────────────────────────
final lawAnalysisProvider =
    StateNotifierProvider<LawAnalysisNotifier, LawAnalysisState>(
  (ref) => LawAnalysisNotifier(),
);
