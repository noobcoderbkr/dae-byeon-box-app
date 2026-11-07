// lib/services/pdf_report_service.dart
//
// 담당 기능: 사고 분석 디지털 리포트 PDF 생성 (흰 배경 미니멀 · 한글 폰트)
//   - 사고 개요 (일시 / 위치 / 사고 유형 / 날씨)
//   - 과실 분석 (비율 / 근거 출처 / 신뢰도 / 산정 근거)
//   - 법적 근거 (적용 법령 / 유사 판례)
//
// 사용 패키지: pdf, printing, path_provider

import 'dart:io' if (dart.library.html) '../utils/io_web_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'local_files.dart';
import 'consent_service.dart';

// ── 리포트 데이터 묶음 ────────────────────────────────────
class ReportPrecedent {
  final String name;
  final String caseNumber;
  final String court;
  final String? ratioText;
  const ReportPrecedent({
    required this.name,
    required this.caseNumber,
    required this.court,
    this.ratioText,
  });
}

class ReportData {
  // 사고 개요
  final String accidentId;
  final DateTime analyzedAt;
  final String address;
  final double? latitude;
  final double? longitude;
  final String accidentTypeText; // 사고 유형/객체
  final String weatherText; // 날씨 요약 (예: "맑음 24.1℃ · 강수 0mm")

  // 과실 분석
  final int rateBPct;
  final int rateAPct;
  final String sourceLabel; // 분석 근거 출처
  final int? confidencePct; // 모델이 제공한 경우에만 표시
  final String summary; // 산정 근거 / 사고 요약
  final String caveat; // 주의 문구

  // 법적 근거
  final List<String> appliedLaws; // 적용 법령/키워드
  final List<ReportPrecedent> precedents;
  final bool lawAvailable;

  const ReportData({
    required this.accidentId,
    required this.analyzedAt,
    required this.address,
    this.latitude,
    this.longitude,
    required this.accidentTypeText,
    required this.weatherText,
    required this.rateBPct,
    required this.rateAPct,
    required this.sourceLabel,
    required this.confidencePct,
    required this.summary,
    required this.caveat,
    required this.appliedLaws,
    required this.precedents,
    required this.lawAvailable,
  });
}

class PdfReportService {
  // ── 색상 팔레트 (흰 배경 미니멀) ─────────────────────────
  static const _black = PdfColor.fromInt(0xFF111111);
  static const _brand = PdfColor.fromInt(0xFF2BB3C6); // 로고 청록(흰 배경용으로 약간 진하게)
  static const _sub = PdfColor.fromInt(0xFF6B6B6B);
  static const _hint = PdfColor.fromInt(0xFF9A9A9A);
  static const _line = PdfColor.fromInt(0xFFE4E4E4);
  static const _fillLight = PdfColor.fromInt(0xFFF6F6F6);

  // ── 한글 폰트 로드 ───────────────────────────────────────
  static Future<({pw.Font regular, pw.Font bold})> _loadFonts() async {
    final regularData =
        await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf');
    return (
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }

  // ── PDF 문서 생성 (공통) ─────────────────────────────────
  static Future<pw.Document> _buildDoc(ReportData d) async {
    final fonts = await _loadFonts();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 44),
        build: (ctx) => [
          _header(fonts, d),
          pw.SizedBox(height: 28),
          _sectionTitle('사고 개요', fonts),
          pw.SizedBox(height: 12),
          _overviewTable(fonts, d),
          pw.SizedBox(height: 28),
          _sectionTitle('과실 분석 결과', fonts),
          pw.SizedBox(height: 12),
          _faultSection(fonts, d),
          pw.SizedBox(height: 20),
          _sourceRow(fonts, d),
          pw.SizedBox(height: 18),
          _summaryBlock(fonts, d),
          pw.SizedBox(height: 28),
          _sectionTitle('법적 근거', fonts),
          pw.SizedBox(height: 12),
          _lawsBlock(fonts, d),
          pw.SizedBox(height: 16),
          _precedentsBlock(fonts, d),
          pw.SizedBox(height: 32),
          _footer(fonts, d),
        ],
      ),
    );
    return pdf;
  }

  // ── 공유 (시스템 공유 시트) ──────────────────────────────
  static Future<void> generateAndShare(ReportData d) async {
    final pdf = await _buildDoc(d);
    final dt = d.analyzedAt;
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'Dae-Byeon-BOX_사고리포트_${dt.year}${_twoDigits(dt.month)}${_twoDigits(dt.day)}.pdf',
    );
  }

  // ── 로컬 저장 (내 리포트 목록용) ──────────────────────────
  static Future<String> saveToLocal(
    ReportData d, {
    required String ownerScope,
    Directory? directory,
  }) async {
    // 웹: 로컬 PDF 파일 저장 미지원 (미리보기·공유는 printing으로 가능)
    if (kIsWeb) {
      throw UnsupportedError('로컬 PDF 저장은 웹에서 지원되지 않습니다.');
    }
    final pdf = await _buildDoc(d);
    final dynamic dir = directory ?? await getApplicationDocumentsDirectory();
    final name = LocalAppFiles.scopedPdfName(
      ownerScope: ownerScope,
      caseId: d.accidentId,
      suffix: 'report_${d.analyzedAt.millisecondsSinceEpoch}',
    );
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // ════════════════════════════════════════════════════════
  //  위젯 빌더
  // ════════════════════════════════════════════════════════

  static pw.Widget _header(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(
                  text: pw.TextSpan(
                    style: pw.TextStyle(font: fonts.bold, fontSize: 18),
                    children: [
                      pw.TextSpan(text: 'D', style: const pw.TextStyle(color: _brand)),
                      pw.TextSpan(text: 'ae-', style: const pw.TextStyle(color: _black)),
                      pw.TextSpan(text: 'B', style: const pw.TextStyle(color: _brand)),
                      pw.TextSpan(text: 'yeon-', style: const pw.TextStyle(color: _black)),
                      pw.TextSpan(text: 'BOX', style: const pw.TextStyle(color: _brand)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('사고 분석 디지털 리포트',
                    style: pw.TextStyle(
                        font: fonts.regular, fontSize: 11, color: _sub)),
              ],
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line),
                borderRadius: pw.BorderRadius.circular(100),
              ),
              child: pw.Text('참고용 분석 문서',
                  style: pw.TextStyle(
                      font: fonts.regular, fontSize: 9, color: _sub)),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(height: 1, color: _black),
      ],
    );
  }

  static pw.Widget _sectionTitle(
      String title, ({pw.Font regular, pw.Font bold}) fonts) {
    return pw.Text(title.toUpperCase(),
        style: pw.TextStyle(
            font: fonts.bold, fontSize: 12, color: _black, letterSpacing: 1));
  }

  // 사고 개요 테이블
  static pw.Widget _overviewTable(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    final gps = (d.latitude != null && d.longitude != null)
        ? '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}'
        : '-';
    final rows = <List<String>>[
      ['분석 생성 시각', _fmtDateTime(d.analyzedAt)],
      ['사고 위치', d.address],
      ['GPS 좌표', gps],
      ['사고 유형', d.accidentTypeText.isEmpty ? '-' : d.accidentTypeText],
      ['사고 당시 날씨', d.weatherText.isEmpty ? '-' : d.weatherText],
      ['사고 ID', d.accidentId],
    ];

    return pw.Column(
      children: rows.map((r) {
        final isLast = r == rows.last;
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 9),
          decoration: pw.BoxDecoration(
            border: isLast
                ? null
                : const pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(r[0],
                    style: pw.TextStyle(
                        font: fonts.regular, fontSize: 10, color: _hint)),
              ),
              pw.Expanded(
                child: pw.Text(r[1],
                    style: pw.TextStyle(
                        font: fonts.regular, fontSize: 11, color: _black)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 실제 모델 당사자 비율 (역할을 임의로 해석하지 않음)
  static pw.Widget _faultSection(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    final rateB = d.rateBPct;
    final rateA = d.rateAPct;
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _faultSide(fonts, 'B측 과실', rateB, rateB >= rateA),
            pw.Container(width: 1, height: 60, color: _line),
            _faultSide(fonts, 'A측 과실', rateA, rateA > rateB),
          ],
        ),
        pw.SizedBox(height: 16),
        // 비율 바
        pw.ClipRRect(
          horizontalRadius: 3,
          verticalRadius: 3,
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: rateB == 0 ? 1 : rateB,
                child: pw.Container(height: 6, color: _black),
              ),
              pw.SizedBox(width: 2),
              pw.Expanded(
                flex: rateA == 0 ? 1 : rateA,
                child: pw.Container(height: 6, color: _line),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _faultSide(({pw.Font regular, pw.Font bold}) fonts,
      String who, int pct, bool strong) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(who,
              style:
                  pw.TextStyle(font: fonts.regular, fontSize: 11, color: _sub)),
          pw.SizedBox(height: 6),
          pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: '$pct',
                  style: pw.TextStyle(
                      font: fonts.bold,
                      fontSize: 40,
                      color: strong ? _black : _hint)),
              pw.TextSpan(
                  text: '%',
                  style: pw.TextStyle(
                      font: fonts.regular, fontSize: 18, color: _hint)),
            ]),
          ),
        ],
      ),
    );
  }

  // 분석 근거 출처 + 신뢰도
  static pw.Widget _sourceRow(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    return pw.Row(
      children: [
        _chip(fonts, d.sourceLabel.isEmpty ? '분석 근거' : d.sourceLabel),
        if (d.confidencePct != null) ...[
          pw.SizedBox(width: 8),
          _chip(fonts, '신뢰도 ${d.confidencePct}%'),
        ],
      ],
    );
  }

  static pw.Widget _chip(({pw.Font regular, pw.Font bold}) fonts, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _fillLight,
        borderRadius: pw.BorderRadius.circular(100),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(font: fonts.regular, fontSize: 9, color: _sub)),
    );
  }

  // 산정 근거 / 요약
  static pw.Widget _summaryBlock(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('산정 근거',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10, color: _hint)),
        pw.SizedBox(height: 8),
        pw.Text(d.summary.isEmpty ? '-' : d.summary,
            style: pw.TextStyle(
                font: fonts.regular,
                fontSize: 11,
                color: _black,
                lineSpacing: 4)),
      ],
    );
  }

  // 적용 법령
  static pw.Widget _lawsBlock(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    if (d.appliedLaws.isEmpty) {
      return pw.Text(
          d.lawAvailable ? 'LAW 상세 법령은 이 PDF에 포함되지 않았습니다.' : 'LAW 사용 불가',
          style: pw.TextStyle(font: fonts.regular, fontSize: 10, color: _hint));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('적용 법령 · 키워드',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10, color: _hint)),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: d.appliedLaws
              .map((l) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _line),
                      borderRadius: pw.BorderRadius.circular(100),
                    ),
                    child: pw.Text(l,
                        style: pw.TextStyle(
                            font: fonts.regular, fontSize: 9, color: _black)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // 유사 판례
  static pw.Widget _precedentsBlock(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    if (d.precedents.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _fillLight,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          d.lawAvailable
              ? 'LAW 제공자는 사용 가능하지만 상세 근거와 판례는 이 PDF에 포함되지 않았습니다.'
              : 'LAW 근거와 판례는 이 모델 보고서에서 사용할 수 없습니다.',
          style: pw.TextStyle(font: fonts.regular, fontSize: 10, color: _sub),
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('유사 판례',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10, color: _hint)),
        pw.SizedBox(height: 10),
        ...d.precedents.take(3).map((p) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(p.name.isEmpty ? '판례' : p.name,
                            style: pw.TextStyle(
                                font: fonts.bold, fontSize: 11, color: _black)),
                      ),
                      if (p.ratioText != null && p.ratioText!.isNotEmpty)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: _fillLight,
                            borderRadius: pw.BorderRadius.circular(100),
                          ),
                          child: pw.Text(p.ratioText!,
                              style: pw.TextStyle(
                                  font: fonts.bold,
                                  fontSize: 9,
                                  color: _black)),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    [p.caseNumber, p.court]
                        .where((s) => s.isNotEmpty)
                        .join('  ·  '),
                    style: pw.TextStyle(
                        font: fonts.regular, fontSize: 9, color: _hint),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  static pw.Widget _footer(
      ({pw.Font regular, pw.Font bold}) fonts, ReportData d) {
    return pw.Column(
      children: [
        pw.Container(height: 1, color: _line),
        pw.SizedBox(height: 10),
        if (d.caveat.isNotEmpty) ...[
          pw.Text(d.caveat,
              style: pw.TextStyle(
                  font: fonts.regular,
                  fontSize: 8,
                  color: _hint,
                  lineSpacing: 2)),
          pw.SizedBox(height: 8),
        ],
        pw.Text(
          legalReferenceWarning,
          style: pw.TextStyle(
            font: fonts.bold,
            fontSize: 8,
            color: _sub,
            lineSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Dae-Byeon-BOX · 사고 분석 리포트',
                style: pw.TextStyle(
                    font: fonts.regular, fontSize: 8, color: _hint)),
            pw.Text('생성일 ${_fmtDate(DateTime.now())}',
                style: pw.TextStyle(
                    font: fonts.regular, fontSize: 8, color: _hint)),
          ],
        ),
      ],
    );
  }

  // ── 포맷 유틸 ────────────────────────────────────────────
  static String _fmtDateTime(DateTime t) =>
      '${t.year}년 ${t.month}월 ${t.day}일 ${_twoDigits(t.hour)}:${_twoDigits(t.minute)}';
  static String _fmtDate(DateTime t) =>
      '${t.year}.${_twoDigits(t.month)}.${_twoDigits(t.day)}';
}
