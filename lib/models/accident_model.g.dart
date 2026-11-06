// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accident_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccidentModelImpl _$$AccidentModelImplFromJson(Map<String, dynamic> json) =>
    _$AccidentModelImpl(
      id: json['id'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      status: $enumDecodeNullable(_$AccidentStatusEnumMap, json['status']) ??
          AccidentStatus.detected,
      videoPath: json['videoPath'] as String?,
      audioPath: json['audioPath'] as String?,
      photoPaths: (json['photoPaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      faultRatio: (json['faultRatio'] as num?)?.toDouble(),
      reportPdfPath: json['reportPdfPath'] as String?,
      audioHash: json['audioHash'] as String?,
      impactGForce: (json['impactGForce'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$AccidentModelImplToJson(_$AccidentModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'occurredAt': instance.occurredAt.toIso8601String(),
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'status': _$AccidentStatusEnumMap[instance.status]!,
      'videoPath': instance.videoPath,
      'audioPath': instance.audioPath,
      'photoPaths': instance.photoPaths,
      'faultRatio': instance.faultRatio,
      'reportPdfPath': instance.reportPdfPath,
      'audioHash': instance.audioHash,
      'impactGForce': instance.impactGForce,
    };

const _$AccidentStatusEnumMap = {
  AccidentStatus.detected: 'detected',
  AccidentStatus.responding: 'responding',
  AccidentStatus.uploading: 'uploading',
  AccidentStatus.analyzing: 'analyzing',
  AccidentStatus.reported: 'reported',
  AccidentStatus.consulting: 'consulting',
};

_$VehicleModelImpl _$$VehicleModelImplFromJson(Map<String, dynamic> json) =>
    _$VehicleModelImpl(
      licensePlate: json['licensePlate'] as String,
      vehicleType: json['vehicleType'] as String,
      ownerName: json['ownerName'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      insuranceCompany: json['insuranceCompany'] as String?,
      insurancePolicyNumber: json['insurancePolicyNumber'] as String?,
      isSharedVehicle: json['isSharedVehicle'] as bool? ?? false,
      sharedUserIds: (json['sharedUserIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$VehicleModelImplToJson(_$VehicleModelImpl instance) =>
    <String, dynamic>{
      'licensePlate': instance.licensePlate,
      'vehicleType': instance.vehicleType,
      'ownerName': instance.ownerName,
      'licenseNumber': instance.licenseNumber,
      'insuranceCompany': instance.insuranceCompany,
      'insurancePolicyNumber': instance.insurancePolicyNumber,
      'isSharedVehicle': instance.isSharedVehicle,
      'sharedUserIds': instance.sharedUserIds,
    };

_$VerdictModelImpl _$$VerdictModelImplFromJson(Map<String, dynamic> json) =>
    _$VerdictModelImpl(
      id: json['id'] as String,
      caseNumber: json['caseNumber'] as String,
      court: json['court'] as String,
      decidedAt: DateTime.parse(json['decidedAt'] as String),
      summary: json['summary'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      faultRatioPlaintiff: (json['faultRatioPlaintiff'] as num?)?.toDouble(),
      faultRatioDefendant: (json['faultRatioDefendant'] as num?)?.toDouble(),
      similarityScore: json['similarityScore'] as String?,
    );

Map<String, dynamic> _$$VerdictModelImplToJson(_$VerdictModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'caseNumber': instance.caseNumber,
      'court': instance.court,
      'decidedAt': instance.decidedAt.toIso8601String(),
      'summary': instance.summary,
      'tags': instance.tags,
      'faultRatioPlaintiff': instance.faultRatioPlaintiff,
      'faultRatioDefendant': instance.faultRatioDefendant,
      'similarityScore': instance.similarityScore,
    };
