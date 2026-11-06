// lib/services/location_service.dart
//
// 담당 기능:
//   - GPS 좌표 취득 및 주소 변환
//   - 위치 권한 거부 시 Default 뷰 (전국 평균 사고 통계) 렌더링
//   - 사고 다발 구역 API 연동
//
// 사용 패키지:
//   geolocator: ^11.0.0         (pubspec.yaml dependencies)
//   geocoding: ^3.0.0
//   permission_handler: ^11.3.0

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationState {
  final bool isGranted;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isLoading;

  const LocationState({
    this.isGranted = false,
    this.latitude,
    this.longitude,
    this.address,
    this.isLoading = false,
  });

  LocationState copyWith({
    bool? isGranted,
    double? latitude,
    double? longitude,
    String? address,
    bool? isLoading,
  }) => LocationState(
    isGranted: isGranted ?? this.isGranted,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    address: address ?? this.address,
    isLoading: isLoading ?? this.isLoading,
  );
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  // ── 위치 권한 요청 및 좌표 취득 ─────────────────────────
  Future<void> requestLocationAndFetch() async {
    state = state.copyWith(isLoading: true);

    // permission_handler: 위치 권한 요청
    final status = await Permission.location.request();

    if (status.isGranted) {
      // geolocator: 현재 GPS 좌표 취득
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // geocoding: 좌표 → 한국어 주소 변환
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final place = placemarks.first;
      final address =
          '${place.administrativeArea ?? ''} ${place.locality ?? ''} '
          '${place.thoroughfare ?? ''} ${place.subThoroughfare ?? ''}'.trim();

      state = state.copyWith(
        isGranted: true,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        isLoading: false,
      );
    } else {
      // ── 예외 처리: 위치 권한 거부 변수 ───────────────────
      // 연구 문서 2.2절: "전국 평균 사고 통계 데이터를 Default 뷰로 렌더링"
      // → isGranted = false 상태에서 메인페이지가 전국 통계 뷰 표시
      state = state.copyWith(isGranted: false, isLoading: false);
    }
  }

  // ── 단순 현재 위치 반환 (사고 기록용) ───────────────────
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
