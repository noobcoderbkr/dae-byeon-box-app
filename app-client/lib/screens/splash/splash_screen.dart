// lib/screens/splash/splash_screen.dart
// 앱 시작 시 로그인 토큰 확인 중 표시되는 로딩 화면 (테슬라 미니멀 다크)
//
// 라우터가 auth.status == unknown (토큰 확인 중)일 때 이 화면으로 보낸다.
// 확인이 끝나면( authenticated / unauthenticated ) 라우터가 자동으로
// 메인 또는 로그인 화면으로 다시 보낸다.

import 'package:flutter/material.dart';

import '../../utils/theme.dart';
import '../../widgets/brand_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            BrandLogo(fontSize: 26),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
