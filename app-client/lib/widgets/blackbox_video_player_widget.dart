// lib/widgets/blackbox_video_player_widget.dart
//
// 다운로드된 로컬 영상 파일을 재생하는 위젯
//
// 사용 패키지: video_player: ^2.11.1

import 'dart:io' if (dart.library.html) '../utils/io_web_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/theme.dart';

class BlackboxVideoPlayerWidget extends StatefulWidget {
  final String? localPath;
  final String? networkUrl;

  const BlackboxVideoPlayerWidget({
    super.key,
    this.localPath,
    this.networkUrl,
  }) : assert(localPath != null || networkUrl != null);

  @override
  State<BlackboxVideoPlayerWidget> createState() =>
      _BlackboxVideoPlayerWidgetState();
}

class _BlackboxVideoPlayerWidgetState
    extends State<BlackboxVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.networkUrl != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.networkUrl!),
        );
      } else if (!kIsWeb && widget.localPath != null) {
        _controller =
            VideoPlayerController.file(File(widget.localPath!) as dynamic);
      } else {
        if (mounted) setState(() => _hasError = true);
        return;
      }
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorState();
    if (!_isInitialized) return _buildLoadingState();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _controller!.value.isPlaying
                          ? _controller!.pause()
                          : _controller!.play();
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _controller!.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        VideoProgressIndicator(
          _controller!,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: AppTheme.primaryBlue,
            bufferedColor: Color(0xFFDDE3F0),
            backgroundColor: Color(0xFFF0F2F8),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.bgGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.bgGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded,
                color: AppTheme.textHint, size: 36),
            const SizedBox(height: 8),
            Text('영상을 재생할 수 없습니다',
                style: AppTheme.body.copyWith(color: AppTheme.textSub)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
