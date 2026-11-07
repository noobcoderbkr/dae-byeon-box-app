// lib/services/audio_recording_service.dart
//
// 담당 기능: 3.2 현장 음성 녹취 및 디지털 타임스탬프 (법적 증거력 확보)
//   - record 패키지로 AAC 녹음
//   - 녹음 완료 후 SHA-256 해시 생성 (위변조 방지)
//   - 녹음 시간 실시간 카운트
//
// 사용 패키지:
//   record: ^7.0.0
//   crypto: ^3.0.7
//   path_provider: ^2.1.5
//   permission_handler: ^11.4.0

import 'dart:async';
import 'dart:io' if (dart.library.html) '../utils/io_web_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// ── 녹음 상태 ────────────────────────────────────────────
class AudioRecordingState {
  final bool isRecording;
  final String? currentPath;
  final String? sha256Hash;
  final Duration elapsed;
  final DateTime? recordedAt;
  final int fileSizeBytes;
  final String? errorMessage;

  const AudioRecordingState({
    this.isRecording = false,
    this.currentPath,
    this.sha256Hash,
    this.elapsed = Duration.zero,
    this.recordedAt,
    this.fileSizeBytes = 0,
    this.errorMessage,
  });

  AudioRecordingState copyWith({
    bool? isRecording,
    String? currentPath,
    String? sha256Hash,
    Duration? elapsed,
    DateTime? recordedAt,
    int? fileSizeBytes,
    String? errorMessage,
  }) =>
      AudioRecordingState(
        isRecording: isRecording ?? this.isRecording,
        currentPath: currentPath ?? this.currentPath,
        sha256Hash: sha256Hash ?? this.sha256Hash,
        elapsed: elapsed ?? this.elapsed,
        recordedAt: recordedAt ?? this.recordedAt,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        errorMessage: errorMessage,
      );

  // 녹음 시간 포맷 (mm:ss)
  String get elapsedFormatted {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // 파일 크기 포맷
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── 녹음 Notifier ────────────────────────────────────────
class AudioRecordingNotifier extends StateNotifier<AudioRecordingState> {
  AudioRecordingNotifier() : super(const AudioRecordingState());

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;

  static String recordingFileName(String caseId, int timestamp) {
    if (!RegExp(r'^case_[0-9a-f]{32}$').hasMatch(caseId)) {
      throw ArgumentError.value(caseId, 'caseId', 'must be a backend case id');
    }
    return 'accident_${caseId}_$timestamp.m4a';
  }

  // ── 녹음 시작 ────────────────────────────────────────────
  Future<void> startRecording(String accidentId) async {
    // 웹: 녹취 저장(record + 로컬 파일) 미지원 — 결과 조회·표시 전용
    if (kIsWeb) {
      state = state.copyWith(errorMessage: '웹에서는 녹취 기능을 지원하지 않습니다.');
      return;
    }
    try {
      // ① 마이크 권한 요청
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        state = state.copyWith(
          errorMessage: '마이크 권한이 필요합니다. 설정에서 허용해 주세요.',
        );
        return;
      }

      // ② 녹음 가능 여부 확인
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(errorMessage: '녹음을 시작할 수 없습니다.');
        return;
      }

      // ③ 저장 경로 설정
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/${recordingFileName(accidentId, timestamp)}';

      // ④ 녹음 시작
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC-LC 코덱
          bitRate: 128000, // 128kbps
          sampleRate: 44100, // 44.1kHz
          numChannels: 1, // 모노 (파일 크기 절약)
        ),
        path: path,
      );

      // ⑤ 상태 갱신 + 타이머 시작
      state = AudioRecordingState(
        isRecording: true,
        currentPath: path,
        elapsed: Duration.zero,
        recordedAt: DateTime.now(),
      );

      _startTimer();
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        errorMessage: '녹음 시작 실패: $e',
      );
    }
  }

  // ── 타이머 시작 (녹음 시간 카운트) ──────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRecording) {
        _timer?.cancel();
        return;
      }
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });
  }

  // ── 녹음 중지 + SHA-256 해시 생성 ───────────────────────
  Future<String?> stopRecording() async {
    if (!state.isRecording) return null;

    try {
      _timer?.cancel();

      // ① 녹음 중지
      final path = await _recorder.stop();
      if (path == null) {
        state = state.copyWith(
          isRecording: false,
          errorMessage: '녹음 파일을 저장하지 못했습니다.',
        );
        return null;
      }

      // ② 파일 읽기
      final file = File(path);
      if (!await file.exists()) {
        state = state.copyWith(
          isRecording: false,
          errorMessage: '녹음 파일을 찾을 수 없습니다.',
        );
        return null;
      }

      final bytes = await file.readAsBytes();

      // ③ SHA-256 해시 계산 (디지털 타임스탬프)
      //    연구 문서 3.2절: "바이너리 데이터에 해시 시퀀스 기반
      //    디지털 타임스탬프를 적용하여 위변조 가능성을 원천 차단"
      final hash = sha256.convert(bytes).toString();

      // ④ 해시 정보를 별도 텍스트 파일로도 저장 (증거 보관용)
      final hashFile = File('$path.sha256.txt');
      await hashFile.writeAsString(
        '파일명: ${path.split('/').last}\n'
        '녹음 시각: ${state.recordedAt?.toIso8601String()}\n'
        '녹음 길이: ${state.elapsedFormatted}\n'
        '파일 크기: ${bytes.length} bytes\n'
        'SHA-256: $hash\n'
        '생성 시각: ${DateTime.now().toIso8601String()}\n',
      );

      state = state.copyWith(
        isRecording: false,
        currentPath: path,
        sha256Hash: hash,
        fileSizeBytes: bytes.length,
      );

      return hash;
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        errorMessage: '녹음 중지 실패: $e',
      );
      return null;
    }
  }

  // ── 녹음 취소 (파일 삭제) ────────────────────────────────
  Future<void> cancelRecording() async {
    _timer?.cancel();
    try {
      if (state.isRecording) {
        final path = await _recorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    } catch (_) {}
    state = const AudioRecordingState();
  }

  // ── 상태 초기화 ──────────────────────────────────────────
  void reset() {
    _timer?.cancel();
    state = const AudioRecordingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────
final audioRecordingProvider =
    StateNotifierProvider<AudioRecordingNotifier, AudioRecordingState>(
  (ref) => AudioRecordingNotifier(),
);
