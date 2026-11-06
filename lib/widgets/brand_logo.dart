// lib/widgets/brand_logo.dart
//
// 서비스 로고 "Dae-Byeon-BOX"
// D · B · BOX 는 청록색, 나머지는 흰색.

import 'package:flutter/material.dart';

const Color kBrandCyan = Color(0xFF63D5E4);
const Color kBrandWhite = Color(0xFFF3F4F6);

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fontSize = 18});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      height: 1.2,
    );
    final cyan = base.copyWith(color: kBrandCyan);
    final white = base.copyWith(color: kBrandWhite);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'D', style: cyan),
        TextSpan(text: 'ae-', style: white),
        TextSpan(text: 'B', style: cyan),
        TextSpan(text: 'yeon-', style: white),
        TextSpan(text: 'BOX', style: cyan),
      ]),
      textAlign: TextAlign.center,
      semanticsLabel: 'Dae-Byeon-BOX',
    );
  }
}
