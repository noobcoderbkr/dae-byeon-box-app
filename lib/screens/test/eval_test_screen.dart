// lib/screens/test/eval_test_screen.dart
// 검증 시나리오(60개)를 백엔드에 보내 예상 과실비율과 실제 응답을 비교하는 개발용 화면
// (앱판 evaluate_events)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../utils/theme.dart';

// 백엔드 LAW 서버 주소 (law_analysis_service 와 동일)
const String _lawServerUrl = 'http://10.0.2.2:9000';
const String _lawApiToken = '';

class EvalCase {
  final String id;
  final String name;
  final String expectedRatio;
  final Map<String, dynamic> event;

  EvalCase({
    required this.id,
    required this.name,
    required this.expectedRatio,
    required this.event,
  });

  factory EvalCase.fromJson(Map<String, dynamic> j) => EvalCase(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        expectedRatio: j['expected_ratio_text'] as String? ?? '',
        event: (j['event'] as Map).cast<String, dynamic>(),
      );
}

class EvalResult {
  final EvalCase c;
  String actualRatio;
  bool? ok; // null=미실행, true=일치, false=불일치
  String? error;
  EvalResult(this.c, {this.actualRatio = '-', this.ok, this.error});
}

class EvalTestScreen extends StatefulWidget {
  const EvalTestScreen({super.key});

  @override
  State<EvalTestScreen> createState() => _EvalTestScreenState();
}

class _EvalTestScreenState extends State<EvalTestScreen> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _lawServerUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (_lawApiToken.isNotEmpty) 'X-API-Key': _lawApiToken,
      },
    ),
  );

  List<EvalResult> _results = [];
  bool _loading = true;
  bool _running = false;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/evaluation_events.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => EvalCase.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _results = list.map((c) => EvalResult(c)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      _done = 0;
      for (final r in _results) {
        r.ok = null;
        r.actualRatio = '-';
        r.error = null;
      }
    });

    for (final r in _results) {
      await _runOne(r);
      setState(() => _done++);
    }
    setState(() => _running = false);
  }

  Future<void> _runOne(EvalResult r) async {
    try {
      final ev = r.c.event;
      final body = {
        'event_id': ev['event_id'] ?? r.c.id,
        'occurred_at': ev['occurred_at'] ?? DateTime.now().toIso8601String(),
        'gps': ev['gps'] ?? {'latitude': 37.5665, 'longitude': 126.978},
        'accident_type': ev['accident_type'] ?? 'intersection',
        'keywords': ev['keywords'] ?? [],
        if (ev['facts'] != null) 'facts': ev['facts'],
      };
      final resp = await _dio.post(
        '/law/analyze-json',
        queryParameters: {'weather': 1},
        data: body,
      );
      final pred = (resp.data['prediction'] as Map?)?.cast<String, dynamic>();
      final actual = pred?['ratio_text'] as String? ?? '?';
      r.actualRatio = actual;
      r.ok = r.c.expectedRatio.isEmpty ? true : (actual == r.c.expectedRatio);
    } catch (e) {
      r.error = e is DioException ? (e.message ?? '네트워크 오류') : '$e';
      r.ok = false;
      r.actualRatio = 'ERR';
    }
  }

  int get _passCount => _results.where((r) => r.ok == true).length;
  int get _ranCount => _results.where((r) => r.ok != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSummary(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : _results.isEmpty
                      ? const Center(
                          child: Text('검증 데이터를 불러오지 못했습니다',
                              style: TextStyle(color: AppTheme.textSub)))
                      : _buildList(),
            ),
            _buildRunButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Colors.white),
          ),
          const Spacer(),
          const Text('과실 분석 검증',
              style: TextStyle(
                color: AppTheme.textSub,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
              )),
          const Spacer(),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final total = _results.length;
    final acc = _ranCount == 0 ? 0 : (_passCount / _ranCount * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _stat('정확도', _ranCount == 0 ? '-' : '$acc%'),
          _stat('통과', '$_passCount/$_ranCount'),
          _stat('전체', '$total'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w300)),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          Container(height: 0.5, color: AppTheme.divider),
      itemBuilder: (_, i) => _buildRow(_results[i]),
    );
  }

  Widget _buildRow(EvalResult r) {
    Color dot;
    IconData? icon;
    if (r.ok == null) {
      dot = AppTheme.textHint;
      icon = null;
    } else if (r.ok == true) {
      dot = AppTheme.successGreen;
      icon = Icons.check_rounded;
    } else {
      dot = AppTheme.errorRed;
      icon = Icons.close_rounded;
    }

    return GestureDetector(
      onTap: _running ? null : () => _runSingle(r),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // 상태
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: r.ok == null ? Colors.transparent : dot,
                shape: BoxShape.circle,
                border: Border.all(color: dot, width: 1),
              ),
              child: icon == null
                  ? null
                  : Icon(icon, size: 14, color: Colors.black),
            ),
            const SizedBox(width: 14),
            // 이름
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.c.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w300)),
                  if (r.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(r.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.errorRed, fontSize: 10)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 예상 → 실제
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(r.c.expectedRatio,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
                Text(r.actualRatio,
                    style: TextStyle(
                        color: r.ok == false ? AppTheme.errorRed : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runSingle(EvalResult r) async {
    setState(() {
      r.ok = null;
      r.actualRatio = '...';
      r.error = null;
    });
    await _runOne(r);
    setState(() {});
  }

  Widget _buildRunButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: GestureDetector(
        onTap: _running ? null : _runAll,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _running ? AppTheme.surfaceDark : AppTheme.pointWhite,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            child: Text(
              _running ? '실행 중... $_done/${_results.length}' : '전체 검증 실행',
              style: TextStyle(
                color: _running ? AppTheme.textSub : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
