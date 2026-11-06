import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/auth_service.dart';
import '../../services/consent_service.dart';
import '../../services/profile_service.dart';
import 'profile_setup_screen.dart';
import '../../utils/theme.dart';

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consentControllerProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      appBar: AppBar(title: const Text('개인정보 및 AI 동의')),
      body: SafeArea(
        child: switch (state.status) {
          ConsentLoadStatus.idle ||
          ConsentLoadStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          ConsentLoadStatus.error => _ErrorState(
              message: state.error ?? '동의 정보를 불러오지 못했습니다.',
              onRetry: () =>
                  ref.read(consentControllerProvider.notifier).load(),
            ),
          ConsentLoadStatus.ready => _ConsentDocuments(state: state),
        },
      ),
    );
  }
}

class _ConsentDocuments extends ConsumerStatefulWidget {
  const _ConsentDocuments({required this.state});

  final ConsentState state;

  @override
  ConsumerState<_ConsentDocuments> createState() => _ConsentDocumentsState();
}

class _ConsentDocumentsState extends ConsumerState<_ConsentDocuments> {
  late final Map<ConsentDocument, bool> _draftGrants;
  bool _isSubmitting = false;
  bool _isRequestingLocation = false;
  String? _locationPermissionError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _draftGrants = {
      for (final document in ConsentDocument.values)
        document: widget.state.snapshot!.isGranted(document),
    };
  }

  @override
  Widget build(BuildContext context) {
    final policies = widget.state.policies!;
    final hasRequired = policies.documents
        .where((document) => document.required)
        .every((document) => _draftGrants[document.document] == true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        const Text('수집 및 처리 동의', style: AppTheme.h1),
        const SizedBox(height: 8),
        const Text(
          '필수 항목은 사고 자료 수집과 센서 시작에만 필요합니다. 외부 AI 선택 동의는 외부 AI의 채팅 텍스트 답변과 선택한 사진·추가 영상 분석에 필요합니다.',
          style: TextStyle(color: AppTheme.textSub, height: 1.55),
        ),
        const SizedBox(height: 24),
        for (final document in policies.documents) ...[
          _PolicyTile(
            document: document,
            granted: _draftGrants[document.document] == true,
            onChanged: _isSubmitting
                ? null
                : (value) => setState(
                      () => _draftGrants[document.document] = value,
                    ),
          ),
          const Divider(color: AppTheme.divider, height: 28),
        ],
        const Text('기기 위치 권한', style: AppTheme.label),
        const SizedBox(height: 8),
        const Text(
          '위치정보 처리 동의와 기기의 위치 권한은 별도입니다. 권한을 거부해도 동의 내용을 저장하고 계속할 수 있습니다.',
          style: TextStyle(color: AppTheme.textSub, height: 1.5),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isRequestingLocation || _isSubmitting
              ? null
              : _requestLocationPermission,
          icon: const Icon(Icons.location_on_outlined),
          label: Text(_isRequestingLocation ? '권한 확인 중...' : '위치 권한 요청'),
        ),
        if (_locationPermissionError != null) ...[
          const SizedBox(height: 8),
          Text(
            _locationPermissionError!,
            style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        if (_submitError != null) ...[
          Text(
            _submitError!,
            style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: hasRequired && !_isSubmitting ? _submit : null,
          child: Text(_isSubmitting ? '저장 중...' : '동의하고 계속'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : () => context.go('/my-reports'),
          icon: const Icon(Icons.history_rounded),
          label: const Text('기존 기록 보기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : () => context.go('/mypage'),
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('계정 관리 및 삭제'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('로그아웃'),
        ),
      ],
    );
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isRequestingLocation = true;
      _locationPermissionError = null;
    });
    try {
      await Permission.location.request();
    } on Object {
      if (mounted) {
        setState(() {
          _locationPermissionError = '위치 권한을 요청하지 못했습니다. 기기 설정에서 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final controller = ref.read(consentControllerProvider.notifier);
      try {
        for (final document in widget.state.policies!.documents) {
          final requested = _draftGrants[document.document] == true;
          if (document.required ||
              requested !=
                  widget.state.snapshot!.isGranted(document.document)) {
            await controller.setGrant(document.document, requested);
          }
        }
      } on Object {
        if (mounted) {
          setState(() {
            _submitError = '동의 저장에 실패했습니다. 다시 시도해 주세요.';
          });
        }
        return;
      }
      if (!mounted || !ref.read(consentControllerProvider).canCollect) return;

      final profile = await ref.read(profileServiceProvider).fetchProfile();
      if (!mounted) return;
      context.go(isOnboardingProfileComplete(profile) ? '/' : '/profile-setup');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({
    required this.document,
    required this.granted,
    required this.onChanged,
  });

  final PolicyDocument document;
  final bool granted;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: granted,
          onChanged:
              onChanged == null ? null : (value) => onChanged!(value ?? false),
          title: Text('${document.required ? '필수' : '선택'} · ${document.title}'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Text(
            document.text,
            style: const TextStyle(
              color: AppTheme.textSub,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
