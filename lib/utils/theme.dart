// lib/utils/theme.dart
// 미니멀 테슬라 스타일 다크모드 + 레드 포인트
import 'package:flutter/material.dart';

class AppTheme {
  // ── 컬러 팔레트 ─────────────────────────────────────────
  static const Color primaryBlue   = Color(0xFFFFFFFF); // 레거시 호환(흰색 포인트)
  static const Color teslaRed      = Color(0xFFFFFFFF); // 포인트를 흰색으로
  static const Color accentBlue    = Color(0xFFFFFFFF);
  static const Color bgGrey        = Color(0xFF0A0A0A); // 거의 검정 배경
  static const Color bgBlack       = Color(0xFF0A0A0A);
  static const Color cardWhite     = Color(0xFF141416); // 카드(거의 안 씀)
  static const Color cardDark      = Color(0xFF141416);
  static const Color surfaceDark   = Color(0xFF1F1F1F);
  static const Color textDark      = Color(0xFFFFFFFF); // 메인 흰색
  static const Color textSub       = Color(0xFF8E8E93); // 서브 회색
  static const Color textHint      = Color(0xFF5A5A5E); // 힌트(더 어두운 회색)
  static const Color divider       = Color(0xFF1F1F1F); // 아주 얇은 구분선
  static const Color errorRed      = Color(0xFFE82127); // 위험(신고 등)은 빨강 유지
  static const Color successGreen  = Color(0xFF32D74B);
  static const Color warningOrange = Color(0xFFFF9F0A);
  static const Color pointWhite    = Color(0xFFFFFFFF); // 명시적 흰색 포인트

  // ── 그림자 (거의 안 씀) ─────────────────────────────────
  static const List<BoxShadow> cardShadow = [];
  static const List<BoxShadow> buttonShadow = [];

  // ── 다크 테마 ────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgBlack,
    colorScheme: const ColorScheme.dark(
      primary: teslaRed,
      surface: cardDark,
      background: bgBlack,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textSub,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: textDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teslaRed,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100), // 알약형
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF3A3A3E), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: textHint, fontSize: 14),
    ),
  );

  // ── 텍스트 스타일 (얇게) ─────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w200, // 아주 얇게
    color: textDark, letterSpacing: 0.5, height: 1.2,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w300,
    color: textDark, letterSpacing: 0.3,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: textDark, letterSpacing: 0.2,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w300,
    color: textDark, height: 1.6,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: textDark,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w300,
    color: textSub, letterSpacing: 0.3,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: textHint, letterSpacing: 1.2, // 대문자 라벨용
  );

  // 큰 숫자 표시용 (테슬라 시그니처)
  static const TextStyle bigNumber = TextStyle(
    fontSize: 88, fontWeight: FontWeight.w200,
    color: textDark, letterSpacing: -2, height: 1.0,
  );
}
