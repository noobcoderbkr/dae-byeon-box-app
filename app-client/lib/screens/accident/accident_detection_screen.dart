// lib/screens/accident/accident_detection_screen.dart
// 테슬라 미니멀 스타일 - 큰 카운트다운

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/case_service.dart';
import '../../services/sensor_service.dart';
import '../../utils/theme.dart';

class AccidentDetectionScreen extends ConsumerStatefulWidget {
  const AccidentDetectionScreen({super.key, this.caseId});

  final String? caseId;

  @override
  ConsumerState<AccidentDetectionScreen> createState() =>
      _AccidentDetectionScreenState();
}

class _AccidentDetectionScreenState
    extends ConsumerState<AccidentDetectionScreen> {
  int _countdown = 10;
  bool _resolvingCase = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _onAccident();
        return false;
      }
      return true;
    });
  }

  Future<void> _onAccident() async {
    if (!mounted || _resolvingCase) return;
    setState(() => _resolvingCase = true);
    try {
      final backendCase = await ref
          .read(caseServiceProvider)
          .resolveForAccident(caseId: widget.caseId);
      if (!mounted) return;
      ref.read(sensorProvider.notifier).dismissAlert();
      context.goNamed('first-response', extra: backendCase.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _resolvingCase = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _onDismiss() {
    ref.read(sensorProvider.notifier).dismissAlert();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // 상단 경고 라벨
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '충격 감지됨',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              // 중앙 큰 카운트다운
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: TextStyle(
                          color: _countdown <= 3
                              ? AppTheme.errorRed
                              : Colors.white,
                          fontSize: 160,
                          fontWeight: FontWeight.w100,
                          height: 1,
                          letterSpacing: -4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '사고가 감지되었습니다',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_countdown초 후 자동으로 초동 대처를 시작합니다',
                        style: const TextStyle(
                          color: AppTheme.textSub,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 버튼들
              GestureDetector(
                onTap: _resolvingCase ? null : _onAccident,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.pointWhite,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Text(
                      _resolvingCase ? '사고 사건 확인 중' : '지금 시작',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _onDismiss,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF3A3A3E)),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Center(
                    child: Text(
                      '오작동입니다',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
