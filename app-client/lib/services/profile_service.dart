// lib/services/profile_service.dart
//
// 백엔드 프로필 / 대시보드 연동
//   - GET /api/v1/profile          내 프로필 조회 (없으면 404)
//   - PUT /api/v1/profile          내 프로필 저장/수정 {display_name, phone?}
//   - GET /api/v1/dashboard        프로필 + 사고(case) 목록
//
// 모든 요청은 로그인 토큰(access_token)이 필요하며,
// auth_service 의 AuthNotifier.validAccessToken() 으로 유효 토큰을 얻어 사용한다.
// 응답은 {"data": {...}, "request_id": "..."} 형태로 감싸져 있다.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

// ══════════════════════════════════════════════════════════
// 모델
// ══════════════════════════════════════════════════════════
class UserProfile {
  final String? id;
  final String? displayName;
  final String? phone;
  final String? licenseNumber;
  final String? licensePlate;
  final String? insuranceCompany;
  final String? policyNumber;
  final String? insurancePhone;
  final String? vehicleType;

  const UserProfile({
    this.id,
    this.displayName,
    this.phone,
    this.licenseNumber,
    this.licensePlate,
    this.insuranceCompany,
    this.policyNumber,
    this.insurancePhone,
    this.vehicleType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String?,
        displayName: j['display_name'] as String?,
        phone: j['phone'] as String?,
        licenseNumber: j['license_number'] as String?,
        licensePlate: j['license_plate'] as String?,
        insuranceCompany: j['insurance_company'] as String?,
        policyNumber: j['policy_number'] as String?,
        insurancePhone: j['insurance_phone'] as String?,
        vehicleType: j['vehicle_type'] as String?,
      );
}

class CaseSummary {
  final String id;
  final String? title;
  final String? status;
  final double? lat;
  final double? lon;
  final String? capturedAt;
  final String? createdAt;

  const CaseSummary({
    required this.id,
    this.title,
    this.status,
    this.lat,
    this.lon,
    this.capturedAt,
    this.createdAt,
  });

  factory CaseSummary.fromJson(Map<String, dynamic> j) => CaseSummary(
        id: j['id'] as String,
        title: j['title'] as String?,
        status: j['status'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        capturedAt: j['captured_at'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

class DashboardData {
  final UserProfile? profile;
  final List<CaseSummary> cases;

  const DashboardData({this.profile, this.cases = const []});
}

class InsuranceDisplayData {
  const InsuranceDisplayData({
    required this.company,
    required this.phone,
    required this.isStale,
  });

  final String? company;
  final String? phone;
  final bool isStale;
}

class OwnerFencedInsuranceCache {
  const OwnerFencedInsuranceCache(this._store);

  static const _ownerKey = 'insurance_cache_owner';
  static const _companyKey = 'insurance_cache_company';
  static const _phoneKey = 'insurance_cache_phone';
  static const _generationKey = 'insurance_cache_generation';
  static int _writeSequence = 0;

  final AuthStore _store;

  Future<InsuranceDisplayData?> read(String owner) async {
    final normalized = owner.trim().toLowerCase();
    if (normalized.isEmpty || await _store.read(_ownerKey) != normalized) {
      return null;
    }
    return InsuranceDisplayData(
      company: await _store.read(_companyKey),
      phone: await _store.read(_phoneKey),
      isStale: true,
    );
  }

  Future<bool> write({
    required String owner,
    String? company,
    String? phone,
    bool Function()? isCurrentOwner,
  }) async {
    final normalized = owner.trim().toLowerCase();
    final isCurrent = isCurrentOwner ?? () => true;
    if (normalized.isEmpty || !isCurrent()) return false;
    final generation = '${++_writeSequence}\n$normalized';
    await _store.write(_generationKey, generation);
    if (!isCurrent()) return _discard(normalized, generation);
    await _store.write(_ownerKey, normalized);
    if (!isCurrent()) return _discard(normalized, generation);
    await _writeNullable(_companyKey, company);
    if (!isCurrent()) return _discard(normalized, generation);
    await _writeNullable(_phoneKey, phone);
    if (!isCurrent()) return _discard(normalized, generation);
    return true;
  }

  Future<bool> _discard(String owner, String generation) async {
    final storedGeneration = await _store.read(_generationKey);
    if (storedGeneration == generation || storedGeneration == null) {
      await _store.delete(_generationKey);
      await _store.delete(_ownerKey);
      await _store.delete(_companyKey);
      await _store.delete(_phoneKey);
    } else if (await _store.read(_ownerKey) == owner) {
      final separator = storedGeneration.indexOf('\n');
      if (separator >= 0) {
        await _store.write(
          _ownerKey,
          storedGeneration.substring(separator + 1),
        );
      }
    }
    return false;
  }

  Future<void> _writeNullable(String key, String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _store.delete(key);
    } else {
      await _store.write(key, trimmed);
    }
  }
}

// ══════════════════════════════════════════════════════════
// 서비스
// ══════════════════════════════════════════════════════════
class ProfileService {
  ProfileService({
    Ref? ref,
    Dio? dio,
    Future<String?> Function()? accessToken,
  })  : _ref = ref,
        _accessToken = accessToken {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
          validateStatus: (code) => code != null && code < 500,
        ));
  }

  final Ref? _ref;
  final Future<String?> Function()? _accessToken;
  late final Dio _dio;

  // ── 서버 연결 확인 (인증 불필요) ─────────────────────────
  // 백엔드 /health/live 는 토큰 없이 항상 열려 있어 연결 상태 확인에 사용.
  // true=서버 응답함, false=서버 꺼짐/네트워크 불가
  Future<bool> pingServer() async {
    try {
      final res = await _dio.get(
        '/health/live',
        options: Options(sendTimeout: const Duration(seconds: 4)),
      );
      return res.statusCode != null && res.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  // 로그인 토큰을 Authorization 헤더로 붙인 Options 생성
  Future<Options?> _authOptions() async {
    final token = await (_accessToken?.call() ??
        _ref!.read(authProvider.notifier).validAccessToken());
    if (token == null) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── 프로필 조회 (없으면 null) ────────────────────────────
  Future<UserProfile?> fetchProfile() async {
    final opts = await _authOptions();
    if (opts == null) return null;
    try {
      final res = await _dio.get('/api/v1/profile', options: opts);
      if (res.statusCode == 200) {
        final p = res.data['data']['profile'] as Map<String, dynamic>;
        return UserProfile.fromJson(p);
      }
      // 404 = 아직 프로필 미생성
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── 프로필 저장/수정 ─────────────────────────────────────
  // display_name 은 필수(공백 불가). phone 은 선택.
  static const _unset = Object();

  Future<UserProfile?> saveProfile({
    required String displayName,
    Object? phone = _unset,
    Object? licenseNumber = _unset,
    Object? licensePlate = _unset,
    Object? insuranceCompany = _unset,
    Object? policyNumber = _unset,
    Object? insurancePhone = _unset,
    Object? vehicleType = _unset,
  }) async {
    final opts = await _authOptions();
    if (opts == null) return null;
    final name = displayName.trim();
    if (name.isEmpty) return null;
    try {
      final res = await _dio.put(
        '/api/v1/profile',
        data: <String, dynamic>{
          'display_name': name,
          if (!identical(phone, _unset)) 'phone': _nullableText(phone),
          if (!identical(licenseNumber, _unset))
            'license_number': _nullableText(licenseNumber),
          if (!identical(licensePlate, _unset))
            'license_plate': _nullableText(licensePlate),
          if (!identical(insuranceCompany, _unset))
            'insurance_company': _nullableText(insuranceCompany),
          if (!identical(policyNumber, _unset))
            'policy_number': _nullableText(policyNumber),
          if (!identical(insurancePhone, _unset))
            'insurance_phone': _nullableText(insurancePhone),
          if (!identical(vehicleType, _unset))
            'vehicle_type': _nullableText(vehicleType),
        },
        options: opts,
      );
      if (res.statusCode == 200) {
        final p = res.data['data']['profile'] as Map<String, dynamic>;
        return UserProfile.fromJson(p);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _nullableText(Object? value) {
    if (value == null) return null;
    final text = (value as String).trim();
    return text.isEmpty ? null : text;
  }

  // ── 대시보드 (프로필 + 사고 목록) ────────────────────────
  Future<DashboardData> fetchDashboard() async {
    final opts = await _authOptions();
    if (opts == null) return const DashboardData();
    try {
      final res = await _dio.get('/api/v1/dashboard', options: opts);
      if (res.statusCode == 200) {
        final data = res.data['data'] as Map<String, dynamic>;
        final profileJson = data['profile'];
        final casesJson = (data['cases'] as List?) ?? const [];
        return DashboardData(
          profile: profileJson == null
              ? null
              : UserProfile.fromJson(
                  Map<String, dynamic>.from(profileJson as Map)),
          cases: casesJson
              .map((c) =>
                  CaseSummary.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList(),
        );
      }
      return const DashboardData();
    } catch (_) {
      return const DashboardData();
    }
  }
}

// ── Provider ──────────────────────────────────────────────
final profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService(ref: ref));
