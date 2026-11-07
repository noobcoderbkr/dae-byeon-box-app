// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'accident_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AccidentModel _$AccidentModelFromJson(Map<String, dynamic> json) {
  return _AccidentModel.fromJson(json);
}

/// @nodoc
mixin _$AccidentModel {
  String get id => throw _privateConstructorUsedError; // UUID
  DateTime get occurredAt => throw _privateConstructorUsedError; // 사고 발생 일시
  double get latitude => throw _privateConstructorUsedError; // GPS 위도
  double get longitude => throw _privateConstructorUsedError; // GPS 경도
  String get address => throw _privateConstructorUsedError; // 주소 (역지오코딩)
  AccidentStatus get status => throw _privateConstructorUsedError;
  String? get videoPath => throw _privateConstructorUsedError; // 블랙박스 영상 로컬 경로
  String? get audioPath => throw _privateConstructorUsedError; // 현장 녹음 파일 경로
  List<String>? get photoPaths =>
      throw _privateConstructorUsedError; // 현장 사진 경로 목록
  double? get faultRatio =>
      throw _privateConstructorUsedError; // AI 산정 과실 비율 (0.0~1.0, 나의 과실)
  String? get reportPdfPath =>
      throw _privateConstructorUsedError; // 생성된 PDF 리포트 경로
  String? get audioHash =>
      throw _privateConstructorUsedError; // 녹취 SHA-256 해시 (위변조 방지)
  double? get impactGForce => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AccidentModelCopyWith<AccidentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccidentModelCopyWith<$Res> {
  factory $AccidentModelCopyWith(
          AccidentModel value, $Res Function(AccidentModel) then) =
      _$AccidentModelCopyWithImpl<$Res, AccidentModel>;
  @useResult
  $Res call(
      {String id,
      DateTime occurredAt,
      double latitude,
      double longitude,
      String address,
      AccidentStatus status,
      String? videoPath,
      String? audioPath,
      List<String>? photoPaths,
      double? faultRatio,
      String? reportPdfPath,
      String? audioHash,
      double? impactGForce});
}

/// @nodoc
class _$AccidentModelCopyWithImpl<$Res, $Val extends AccidentModel>
    implements $AccidentModelCopyWith<$Res> {
  _$AccidentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? occurredAt = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? address = null,
    Object? status = null,
    Object? videoPath = freezed,
    Object? audioPath = freezed,
    Object? photoPaths = freezed,
    Object? faultRatio = freezed,
    Object? reportPdfPath = freezed,
    Object? audioHash = freezed,
    Object? impactGForce = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      occurredAt: null == occurredAt
          ? _value.occurredAt
          : occurredAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AccidentStatus,
      videoPath: freezed == videoPath
          ? _value.videoPath
          : videoPath // ignore: cast_nullable_to_non_nullable
              as String?,
      audioPath: freezed == audioPath
          ? _value.audioPath
          : audioPath // ignore: cast_nullable_to_non_nullable
              as String?,
      photoPaths: freezed == photoPaths
          ? _value.photoPaths
          : photoPaths // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      faultRatio: freezed == faultRatio
          ? _value.faultRatio
          : faultRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      reportPdfPath: freezed == reportPdfPath
          ? _value.reportPdfPath
          : reportPdfPath // ignore: cast_nullable_to_non_nullable
              as String?,
      audioHash: freezed == audioHash
          ? _value.audioHash
          : audioHash // ignore: cast_nullable_to_non_nullable
              as String?,
      impactGForce: freezed == impactGForce
          ? _value.impactGForce
          : impactGForce // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AccidentModelImplCopyWith<$Res>
    implements $AccidentModelCopyWith<$Res> {
  factory _$$AccidentModelImplCopyWith(
          _$AccidentModelImpl value, $Res Function(_$AccidentModelImpl) then) =
      __$$AccidentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime occurredAt,
      double latitude,
      double longitude,
      String address,
      AccidentStatus status,
      String? videoPath,
      String? audioPath,
      List<String>? photoPaths,
      double? faultRatio,
      String? reportPdfPath,
      String? audioHash,
      double? impactGForce});
}

/// @nodoc
class __$$AccidentModelImplCopyWithImpl<$Res>
    extends _$AccidentModelCopyWithImpl<$Res, _$AccidentModelImpl>
    implements _$$AccidentModelImplCopyWith<$Res> {
  __$$AccidentModelImplCopyWithImpl(
      _$AccidentModelImpl _value, $Res Function(_$AccidentModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? occurredAt = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? address = null,
    Object? status = null,
    Object? videoPath = freezed,
    Object? audioPath = freezed,
    Object? photoPaths = freezed,
    Object? faultRatio = freezed,
    Object? reportPdfPath = freezed,
    Object? audioHash = freezed,
    Object? impactGForce = freezed,
  }) {
    return _then(_$AccidentModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      occurredAt: null == occurredAt
          ? _value.occurredAt
          : occurredAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AccidentStatus,
      videoPath: freezed == videoPath
          ? _value.videoPath
          : videoPath // ignore: cast_nullable_to_non_nullable
              as String?,
      audioPath: freezed == audioPath
          ? _value.audioPath
          : audioPath // ignore: cast_nullable_to_non_nullable
              as String?,
      photoPaths: freezed == photoPaths
          ? _value._photoPaths
          : photoPaths // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      faultRatio: freezed == faultRatio
          ? _value.faultRatio
          : faultRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      reportPdfPath: freezed == reportPdfPath
          ? _value.reportPdfPath
          : reportPdfPath // ignore: cast_nullable_to_non_nullable
              as String?,
      audioHash: freezed == audioHash
          ? _value.audioHash
          : audioHash // ignore: cast_nullable_to_non_nullable
              as String?,
      impactGForce: freezed == impactGForce
          ? _value.impactGForce
          : impactGForce // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AccidentModelImpl implements _AccidentModel {
  const _$AccidentModelImpl(
      {required this.id,
      required this.occurredAt,
      required this.latitude,
      required this.longitude,
      required this.address,
      this.status = AccidentStatus.detected,
      this.videoPath,
      this.audioPath,
      final List<String>? photoPaths,
      this.faultRatio,
      this.reportPdfPath,
      this.audioHash,
      this.impactGForce})
      : _photoPaths = photoPaths;

  factory _$AccidentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccidentModelImplFromJson(json);

  @override
  final String id;
// UUID
  @override
  final DateTime occurredAt;
// 사고 발생 일시
  @override
  final double latitude;
// GPS 위도
  @override
  final double longitude;
// GPS 경도
  @override
  final String address;
// 주소 (역지오코딩)
  @override
  @JsonKey()
  final AccidentStatus status;
  @override
  final String? videoPath;
// 블랙박스 영상 로컬 경로
  @override
  final String? audioPath;
// 현장 녹음 파일 경로
  final List<String>? _photoPaths;
// 현장 녹음 파일 경로
  @override
  List<String>? get photoPaths {
    final value = _photoPaths;
    if (value == null) return null;
    if (_photoPaths is EqualUnmodifiableListView) return _photoPaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// 현장 사진 경로 목록
  @override
  final double? faultRatio;
// AI 산정 과실 비율 (0.0~1.0, 나의 과실)
  @override
  final String? reportPdfPath;
// 생성된 PDF 리포트 경로
  @override
  final String? audioHash;
// 녹취 SHA-256 해시 (위변조 방지)
  @override
  final double? impactGForce;

  @override
  String toString() {
    return 'AccidentModel(id: $id, occurredAt: $occurredAt, latitude: $latitude, longitude: $longitude, address: $address, status: $status, videoPath: $videoPath, audioPath: $audioPath, photoPaths: $photoPaths, faultRatio: $faultRatio, reportPdfPath: $reportPdfPath, audioHash: $audioHash, impactGForce: $impactGForce)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccidentModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.occurredAt, occurredAt) ||
                other.occurredAt == occurredAt) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.videoPath, videoPath) ||
                other.videoPath == videoPath) &&
            (identical(other.audioPath, audioPath) ||
                other.audioPath == audioPath) &&
            const DeepCollectionEquality()
                .equals(other._photoPaths, _photoPaths) &&
            (identical(other.faultRatio, faultRatio) ||
                other.faultRatio == faultRatio) &&
            (identical(other.reportPdfPath, reportPdfPath) ||
                other.reportPdfPath == reportPdfPath) &&
            (identical(other.audioHash, audioHash) ||
                other.audioHash == audioHash) &&
            (identical(other.impactGForce, impactGForce) ||
                other.impactGForce == impactGForce));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      occurredAt,
      latitude,
      longitude,
      address,
      status,
      videoPath,
      audioPath,
      const DeepCollectionEquality().hash(_photoPaths),
      faultRatio,
      reportPdfPath,
      audioHash,
      impactGForce);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AccidentModelImplCopyWith<_$AccidentModelImpl> get copyWith =>
      __$$AccidentModelImplCopyWithImpl<_$AccidentModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AccidentModelImplToJson(
      this,
    );
  }
}

abstract class _AccidentModel implements AccidentModel {
  const factory _AccidentModel(
      {required final String id,
      required final DateTime occurredAt,
      required final double latitude,
      required final double longitude,
      required final String address,
      final AccidentStatus status,
      final String? videoPath,
      final String? audioPath,
      final List<String>? photoPaths,
      final double? faultRatio,
      final String? reportPdfPath,
      final String? audioHash,
      final double? impactGForce}) = _$AccidentModelImpl;

  factory _AccidentModel.fromJson(Map<String, dynamic> json) =
      _$AccidentModelImpl.fromJson;

  @override
  String get id;
  @override // UUID
  DateTime get occurredAt;
  @override // 사고 발생 일시
  double get latitude;
  @override // GPS 위도
  double get longitude;
  @override // GPS 경도
  String get address;
  @override // 주소 (역지오코딩)
  AccidentStatus get status;
  @override
  String? get videoPath;
  @override // 블랙박스 영상 로컬 경로
  String? get audioPath;
  @override // 현장 녹음 파일 경로
  List<String>? get photoPaths;
  @override // 현장 사진 경로 목록
  double? get faultRatio;
  @override // AI 산정 과실 비율 (0.0~1.0, 나의 과실)
  String? get reportPdfPath;
  @override // 생성된 PDF 리포트 경로
  String? get audioHash;
  @override // 녹취 SHA-256 해시 (위변조 방지)
  double? get impactGForce;
  @override
  @JsonKey(ignore: true)
  _$$AccidentModelImplCopyWith<_$AccidentModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VehicleModel _$VehicleModelFromJson(Map<String, dynamic> json) {
  return _VehicleModel.fromJson(json);
}

/// @nodoc
mixin _$VehicleModel {
  String get licensePlate => throw _privateConstructorUsedError; // 차량 번호
  String get vehicleType =>
      throw _privateConstructorUsedError; // 차종 (경차/SUV/대형 화물차 등)
  String? get ownerName => throw _privateConstructorUsedError; // 소유자 성명
  String? get licenseNumber =>
      throw _privateConstructorUsedError; // 운전면허 번호 (OCR 추출)
  String? get insuranceCompany => throw _privateConstructorUsedError; // 보험사
  String? get insurancePolicyNumber =>
      throw _privateConstructorUsedError; // 보험 증권 번호
  bool get isSharedVehicle =>
      throw _privateConstructorUsedError; // 공유 차량 여부 (카셰어링)
  List<String>? get sharedUserIds => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VehicleModelCopyWith<VehicleModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VehicleModelCopyWith<$Res> {
  factory $VehicleModelCopyWith(
          VehicleModel value, $Res Function(VehicleModel) then) =
      _$VehicleModelCopyWithImpl<$Res, VehicleModel>;
  @useResult
  $Res call(
      {String licensePlate,
      String vehicleType,
      String? ownerName,
      String? licenseNumber,
      String? insuranceCompany,
      String? insurancePolicyNumber,
      bool isSharedVehicle,
      List<String>? sharedUserIds});
}

/// @nodoc
class _$VehicleModelCopyWithImpl<$Res, $Val extends VehicleModel>
    implements $VehicleModelCopyWith<$Res> {
  _$VehicleModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? licensePlate = null,
    Object? vehicleType = null,
    Object? ownerName = freezed,
    Object? licenseNumber = freezed,
    Object? insuranceCompany = freezed,
    Object? insurancePolicyNumber = freezed,
    Object? isSharedVehicle = null,
    Object? sharedUserIds = freezed,
  }) {
    return _then(_value.copyWith(
      licensePlate: null == licensePlate
          ? _value.licensePlate
          : licensePlate // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      ownerName: freezed == ownerName
          ? _value.ownerName
          : ownerName // ignore: cast_nullable_to_non_nullable
              as String?,
      licenseNumber: freezed == licenseNumber
          ? _value.licenseNumber
          : licenseNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      insuranceCompany: freezed == insuranceCompany
          ? _value.insuranceCompany
          : insuranceCompany // ignore: cast_nullable_to_non_nullable
              as String?,
      insurancePolicyNumber: freezed == insurancePolicyNumber
          ? _value.insurancePolicyNumber
          : insurancePolicyNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      isSharedVehicle: null == isSharedVehicle
          ? _value.isSharedVehicle
          : isSharedVehicle // ignore: cast_nullable_to_non_nullable
              as bool,
      sharedUserIds: freezed == sharedUserIds
          ? _value.sharedUserIds
          : sharedUserIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VehicleModelImplCopyWith<$Res>
    implements $VehicleModelCopyWith<$Res> {
  factory _$$VehicleModelImplCopyWith(
          _$VehicleModelImpl value, $Res Function(_$VehicleModelImpl) then) =
      __$$VehicleModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String licensePlate,
      String vehicleType,
      String? ownerName,
      String? licenseNumber,
      String? insuranceCompany,
      String? insurancePolicyNumber,
      bool isSharedVehicle,
      List<String>? sharedUserIds});
}

/// @nodoc
class __$$VehicleModelImplCopyWithImpl<$Res>
    extends _$VehicleModelCopyWithImpl<$Res, _$VehicleModelImpl>
    implements _$$VehicleModelImplCopyWith<$Res> {
  __$$VehicleModelImplCopyWithImpl(
      _$VehicleModelImpl _value, $Res Function(_$VehicleModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? licensePlate = null,
    Object? vehicleType = null,
    Object? ownerName = freezed,
    Object? licenseNumber = freezed,
    Object? insuranceCompany = freezed,
    Object? insurancePolicyNumber = freezed,
    Object? isSharedVehicle = null,
    Object? sharedUserIds = freezed,
  }) {
    return _then(_$VehicleModelImpl(
      licensePlate: null == licensePlate
          ? _value.licensePlate
          : licensePlate // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      ownerName: freezed == ownerName
          ? _value.ownerName
          : ownerName // ignore: cast_nullable_to_non_nullable
              as String?,
      licenseNumber: freezed == licenseNumber
          ? _value.licenseNumber
          : licenseNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      insuranceCompany: freezed == insuranceCompany
          ? _value.insuranceCompany
          : insuranceCompany // ignore: cast_nullable_to_non_nullable
              as String?,
      insurancePolicyNumber: freezed == insurancePolicyNumber
          ? _value.insurancePolicyNumber
          : insurancePolicyNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      isSharedVehicle: null == isSharedVehicle
          ? _value.isSharedVehicle
          : isSharedVehicle // ignore: cast_nullable_to_non_nullable
              as bool,
      sharedUserIds: freezed == sharedUserIds
          ? _value._sharedUserIds
          : sharedUserIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VehicleModelImpl implements _VehicleModel {
  const _$VehicleModelImpl(
      {required this.licensePlate,
      required this.vehicleType,
      this.ownerName,
      this.licenseNumber,
      this.insuranceCompany,
      this.insurancePolicyNumber,
      this.isSharedVehicle = false,
      final List<String>? sharedUserIds})
      : _sharedUserIds = sharedUserIds;

  factory _$VehicleModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$VehicleModelImplFromJson(json);

  @override
  final String licensePlate;
// 차량 번호
  @override
  final String vehicleType;
// 차종 (경차/SUV/대형 화물차 등)
  @override
  final String? ownerName;
// 소유자 성명
  @override
  final String? licenseNumber;
// 운전면허 번호 (OCR 추출)
  @override
  final String? insuranceCompany;
// 보험사
  @override
  final String? insurancePolicyNumber;
// 보험 증권 번호
  @override
  @JsonKey()
  final bool isSharedVehicle;
// 공유 차량 여부 (카셰어링)
  final List<String>? _sharedUserIds;
// 공유 차량 여부 (카셰어링)
  @override
  List<String>? get sharedUserIds {
    final value = _sharedUserIds;
    if (value == null) return null;
    if (_sharedUserIds is EqualUnmodifiableListView) return _sharedUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'VehicleModel(licensePlate: $licensePlate, vehicleType: $vehicleType, ownerName: $ownerName, licenseNumber: $licenseNumber, insuranceCompany: $insuranceCompany, insurancePolicyNumber: $insurancePolicyNumber, isSharedVehicle: $isSharedVehicle, sharedUserIds: $sharedUserIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VehicleModelImpl &&
            (identical(other.licensePlate, licensePlate) ||
                other.licensePlate == licensePlate) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.ownerName, ownerName) ||
                other.ownerName == ownerName) &&
            (identical(other.licenseNumber, licenseNumber) ||
                other.licenseNumber == licenseNumber) &&
            (identical(other.insuranceCompany, insuranceCompany) ||
                other.insuranceCompany == insuranceCompany) &&
            (identical(other.insurancePolicyNumber, insurancePolicyNumber) ||
                other.insurancePolicyNumber == insurancePolicyNumber) &&
            (identical(other.isSharedVehicle, isSharedVehicle) ||
                other.isSharedVehicle == isSharedVehicle) &&
            const DeepCollectionEquality()
                .equals(other._sharedUserIds, _sharedUserIds));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      licensePlate,
      vehicleType,
      ownerName,
      licenseNumber,
      insuranceCompany,
      insurancePolicyNumber,
      isSharedVehicle,
      const DeepCollectionEquality().hash(_sharedUserIds));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VehicleModelImplCopyWith<_$VehicleModelImpl> get copyWith =>
      __$$VehicleModelImplCopyWithImpl<_$VehicleModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VehicleModelImplToJson(
      this,
    );
  }
}

abstract class _VehicleModel implements VehicleModel {
  const factory _VehicleModel(
      {required final String licensePlate,
      required final String vehicleType,
      final String? ownerName,
      final String? licenseNumber,
      final String? insuranceCompany,
      final String? insurancePolicyNumber,
      final bool isSharedVehicle,
      final List<String>? sharedUserIds}) = _$VehicleModelImpl;

  factory _VehicleModel.fromJson(Map<String, dynamic> json) =
      _$VehicleModelImpl.fromJson;

  @override
  String get licensePlate;
  @override // 차량 번호
  String get vehicleType;
  @override // 차종 (경차/SUV/대형 화물차 등)
  String? get ownerName;
  @override // 소유자 성명
  String? get licenseNumber;
  @override // 운전면허 번호 (OCR 추출)
  String? get insuranceCompany;
  @override // 보험사
  String? get insurancePolicyNumber;
  @override // 보험 증권 번호
  bool get isSharedVehicle;
  @override // 공유 차량 여부 (카셰어링)
  List<String>? get sharedUserIds;
  @override
  @JsonKey(ignore: true)
  _$$VehicleModelImplCopyWith<_$VehicleModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VerdictModel _$VerdictModelFromJson(Map<String, dynamic> json) {
  return _VerdictModel.fromJson(json);
}

/// @nodoc
mixin _$VerdictModel {
  String get id => throw _privateConstructorUsedError;
  String get caseNumber => throw _privateConstructorUsedError; // 사건 번호
  String get court => throw _privateConstructorUsedError; // 법원명 (대법원/하급심)
  DateTime get decidedAt => throw _privateConstructorUsedError; // 판결 일자
  String get summary => throw _privateConstructorUsedError; // 판결 요지
  List<String> get tags =>
      throw _privateConstructorUsedError; // 키워드 태그 (#어린이보호구역 등)
  double? get faultRatioPlaintiff =>
      throw _privateConstructorUsedError; // 원고 과실 비율
  double? get faultRatioDefendant =>
      throw _privateConstructorUsedError; // 피고 과실 비율
  String? get similarityScore => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VerdictModelCopyWith<VerdictModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VerdictModelCopyWith<$Res> {
  factory $VerdictModelCopyWith(
          VerdictModel value, $Res Function(VerdictModel) then) =
      _$VerdictModelCopyWithImpl<$Res, VerdictModel>;
  @useResult
  $Res call(
      {String id,
      String caseNumber,
      String court,
      DateTime decidedAt,
      String summary,
      List<String> tags,
      double? faultRatioPlaintiff,
      double? faultRatioDefendant,
      String? similarityScore});
}

/// @nodoc
class _$VerdictModelCopyWithImpl<$Res, $Val extends VerdictModel>
    implements $VerdictModelCopyWith<$Res> {
  _$VerdictModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? caseNumber = null,
    Object? court = null,
    Object? decidedAt = null,
    Object? summary = null,
    Object? tags = null,
    Object? faultRatioPlaintiff = freezed,
    Object? faultRatioDefendant = freezed,
    Object? similarityScore = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      caseNumber: null == caseNumber
          ? _value.caseNumber
          : caseNumber // ignore: cast_nullable_to_non_nullable
              as String,
      court: null == court
          ? _value.court
          : court // ignore: cast_nullable_to_non_nullable
              as String,
      decidedAt: null == decidedAt
          ? _value.decidedAt
          : decidedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      faultRatioPlaintiff: freezed == faultRatioPlaintiff
          ? _value.faultRatioPlaintiff
          : faultRatioPlaintiff // ignore: cast_nullable_to_non_nullable
              as double?,
      faultRatioDefendant: freezed == faultRatioDefendant
          ? _value.faultRatioDefendant
          : faultRatioDefendant // ignore: cast_nullable_to_non_nullable
              as double?,
      similarityScore: freezed == similarityScore
          ? _value.similarityScore
          : similarityScore // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VerdictModelImplCopyWith<$Res>
    implements $VerdictModelCopyWith<$Res> {
  factory _$$VerdictModelImplCopyWith(
          _$VerdictModelImpl value, $Res Function(_$VerdictModelImpl) then) =
      __$$VerdictModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String caseNumber,
      String court,
      DateTime decidedAt,
      String summary,
      List<String> tags,
      double? faultRatioPlaintiff,
      double? faultRatioDefendant,
      String? similarityScore});
}

/// @nodoc
class __$$VerdictModelImplCopyWithImpl<$Res>
    extends _$VerdictModelCopyWithImpl<$Res, _$VerdictModelImpl>
    implements _$$VerdictModelImplCopyWith<$Res> {
  __$$VerdictModelImplCopyWithImpl(
      _$VerdictModelImpl _value, $Res Function(_$VerdictModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? caseNumber = null,
    Object? court = null,
    Object? decidedAt = null,
    Object? summary = null,
    Object? tags = null,
    Object? faultRatioPlaintiff = freezed,
    Object? faultRatioDefendant = freezed,
    Object? similarityScore = freezed,
  }) {
    return _then(_$VerdictModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      caseNumber: null == caseNumber
          ? _value.caseNumber
          : caseNumber // ignore: cast_nullable_to_non_nullable
              as String,
      court: null == court
          ? _value.court
          : court // ignore: cast_nullable_to_non_nullable
              as String,
      decidedAt: null == decidedAt
          ? _value.decidedAt
          : decidedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      faultRatioPlaintiff: freezed == faultRatioPlaintiff
          ? _value.faultRatioPlaintiff
          : faultRatioPlaintiff // ignore: cast_nullable_to_non_nullable
              as double?,
      faultRatioDefendant: freezed == faultRatioDefendant
          ? _value.faultRatioDefendant
          : faultRatioDefendant // ignore: cast_nullable_to_non_nullable
              as double?,
      similarityScore: freezed == similarityScore
          ? _value.similarityScore
          : similarityScore // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VerdictModelImpl implements _VerdictModel {
  const _$VerdictModelImpl(
      {required this.id,
      required this.caseNumber,
      required this.court,
      required this.decidedAt,
      required this.summary,
      required final List<String> tags,
      this.faultRatioPlaintiff,
      this.faultRatioDefendant,
      this.similarityScore})
      : _tags = tags;

  factory _$VerdictModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$VerdictModelImplFromJson(json);

  @override
  final String id;
  @override
  final String caseNumber;
// 사건 번호
  @override
  final String court;
// 법원명 (대법원/하급심)
  @override
  final DateTime decidedAt;
// 판결 일자
  @override
  final String summary;
// 판결 요지
  final List<String> _tags;
// 판결 요지
  @override
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

// 키워드 태그 (#어린이보호구역 등)
  @override
  final double? faultRatioPlaintiff;
// 원고 과실 비율
  @override
  final double? faultRatioDefendant;
// 피고 과실 비율
  @override
  final String? similarityScore;

  @override
  String toString() {
    return 'VerdictModel(id: $id, caseNumber: $caseNumber, court: $court, decidedAt: $decidedAt, summary: $summary, tags: $tags, faultRatioPlaintiff: $faultRatioPlaintiff, faultRatioDefendant: $faultRatioDefendant, similarityScore: $similarityScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VerdictModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.caseNumber, caseNumber) ||
                other.caseNumber == caseNumber) &&
            (identical(other.court, court) || other.court == court) &&
            (identical(other.decidedAt, decidedAt) ||
                other.decidedAt == decidedAt) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.faultRatioPlaintiff, faultRatioPlaintiff) ||
                other.faultRatioPlaintiff == faultRatioPlaintiff) &&
            (identical(other.faultRatioDefendant, faultRatioDefendant) ||
                other.faultRatioDefendant == faultRatioDefendant) &&
            (identical(other.similarityScore, similarityScore) ||
                other.similarityScore == similarityScore));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      caseNumber,
      court,
      decidedAt,
      summary,
      const DeepCollectionEquality().hash(_tags),
      faultRatioPlaintiff,
      faultRatioDefendant,
      similarityScore);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VerdictModelImplCopyWith<_$VerdictModelImpl> get copyWith =>
      __$$VerdictModelImplCopyWithImpl<_$VerdictModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VerdictModelImplToJson(
      this,
    );
  }
}

abstract class _VerdictModel implements VerdictModel {
  const factory _VerdictModel(
      {required final String id,
      required final String caseNumber,
      required final String court,
      required final DateTime decidedAt,
      required final String summary,
      required final List<String> tags,
      final double? faultRatioPlaintiff,
      final double? faultRatioDefendant,
      final String? similarityScore}) = _$VerdictModelImpl;

  factory _VerdictModel.fromJson(Map<String, dynamic> json) =
      _$VerdictModelImpl.fromJson;

  @override
  String get id;
  @override
  String get caseNumber;
  @override // 사건 번호
  String get court;
  @override // 법원명 (대법원/하급심)
  DateTime get decidedAt;
  @override // 판결 일자
  String get summary;
  @override // 판결 요지
  List<String> get tags;
  @override // 키워드 태그 (#어린이보호구역 등)
  double? get faultRatioPlaintiff;
  @override // 원고 과실 비율
  double? get faultRatioDefendant;
  @override // 피고 과실 비율
  String? get similarityScore;
  @override
  @JsonKey(ignore: true)
  _$$VerdictModelImplCopyWith<_$VerdictModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
