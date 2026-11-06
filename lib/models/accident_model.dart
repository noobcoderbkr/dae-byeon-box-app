// lib/models/accident_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'accident_model.freezed.dart';
part 'accident_model.g.dart';

/// 사고 상태 enum
enum AccidentStatus {
  detected,     // 충격 감지됨
  responding,   // 초동 대처 중
  uploading,    // 영상 업로드 중
  analyzing,    // AI 분석 중
  reported,     // 분석 리포트 완료
  consulting,   // 전문가 매칭 중
}

/// 사고 데이터 모델 (불변 - freezed)
@freezed
class AccidentModel with _$AccidentModel {
  const factory AccidentModel({
    required String id,                 // UUID
    required DateTime occurredAt,       // 사고 발생 일시
    required double latitude,           // GPS 위도
    required double longitude,          // GPS 경도
    required String address,            // 주소 (역지오코딩)
    @Default(AccidentStatus.detected) AccidentStatus status,
    String? videoPath,                  // 블랙박스 영상 로컬 경로
    String? audioPath,                  // 현장 녹음 파일 경로
    List<String>? photoPaths,           // 현장 사진 경로 목록
    double? faultRatio,                 // AI 산정 과실 비율 (0.0~1.0, 나의 과실)
    String? reportPdfPath,              // 생성된 PDF 리포트 경로
    String? audioHash,                  // 녹취 SHA-256 해시 (위변조 방지)
    double? impactGForce,               // 충격 시 G-Force 수치
  }) = _AccidentModel;

  factory AccidentModel.fromJson(Map<String, dynamic> json) =>
      _$AccidentModelFromJson(json);
}

/// 차량 정보 모델
@freezed
class VehicleModel with _$VehicleModel {
  const factory VehicleModel({
    required String licensePlate,       // 차량 번호
    required String vehicleType,        // 차종 (경차/SUV/대형 화물차 등)
    String? ownerName,                  // 소유자 성명
    String? licenseNumber,              // 운전면허 번호 (OCR 추출)
    String? insuranceCompany,           // 보험사
    String? insurancePolicyNumber,      // 보험 증권 번호
    @Default(false) bool isSharedVehicle,       // 공유 차량 여부 (카셰어링)
    List<String>? sharedUserIds,        // 공유 운전자 목록 (1:N)
  }) = _VehicleModel;

  factory VehicleModel.fromJson(Map<String, dynamic> json) =>
      _$VehicleModelFromJson(json);
}

/// 판례 데이터 모델
@freezed
class VerdictModel with _$VerdictModel {
  const factory VerdictModel({
    required String id,
    required String caseNumber,         // 사건 번호
    required String court,              // 법원명 (대법원/하급심)
    required DateTime decidedAt,        // 판결 일자
    required String summary,            // 판결 요지
    required List<String> tags,         // 키워드 태그 (#어린이보호구역 등)
    double? faultRatioPlaintiff,        // 원고 과실 비율
    double? faultRatioDefendant,        // 피고 과실 비율
    String? similarityScore,           // 내 사고와의 유사도 점수
  }) = _VerdictModel;

  factory VerdictModel.fromJson(Map<String, dynamic> json) =>
      _$VerdictModelFromJson(json);
}
