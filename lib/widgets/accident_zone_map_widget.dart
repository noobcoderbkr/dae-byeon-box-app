// lib/widgets/accident_zone_map_widget.dart
//
// 사용 패키지: flutter_naver_map: ^1.1.0
// 연구 문서 2.2절: "공공 데이터 API를 연동하여 현재 GPS 기반 사고 다발 구역 안내"

import 'package:flutter/material.dart';

class AccidentZoneMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;

  const AccidentZoneMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // ── 실제 구현: NaverMap 위젯 ──────────────
            // NaverMap(
            //   options: NaverMapViewOptions(
            //     initialCameraPosition: NCameraPosition(
            //       target: NLatLng(latitude, longitude),
            //       zoom: 15,
            //     ),
            //   ),
            //   onMapReady: (controller) {
            //     // 사고 다발 구역 마커 추가
            //   },
            // ),

            // Mock 지도 표시
            Container(
              color: Colors.blue.shade50,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      '내 위치 기반 사고 다발 구역 지도\n(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'flutter_naver_map 연동 필요',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // 레이블
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: const Text(
                  '🔴 사고 다발 구역',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
