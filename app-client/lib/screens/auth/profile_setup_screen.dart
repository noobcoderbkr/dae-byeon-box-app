import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../utils/theme.dart';

bool isOnboardingProfileComplete(UserProfile? profile) {
  if (profile == null) return false;
  return _isBoundedText(profile.insuranceCompany, 255) &&
      _isValidPhone(profile.insurancePhone) &&
      _isBoundedText(profile.licenseNumber, 64);
}

bool _isBoundedText(String? value, int maxLength) {
  final text = (value ?? '').trim();
  return text.isNotEmpty && text.length <= maxLength;
}

bool _isValidPhone(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty || text.length > 64) return false;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15;
}

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _insuranceCompany = TextEditingController();
  final _insurancePhone = TextEditingController();
  final _licenseNumber = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final profile = await ref.read(profileServiceProvider).fetchProfile();
    if (!mounted) return;
    if (isOnboardingProfileComplete(profile)) {
      context.go('/');
      return;
    }
    setState(() {
      _insuranceCompany.text = profile?.insuranceCompany ?? '';
      _insurancePhone.text = profile?.insurancePhone ?? '';
      _licenseNumber.text = profile?.licenseNumber ?? '';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      appBar: AppBar(title: const Text('운전자 정보 등록')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    const Text('보험 및 면허 정보', style: AppTheme.h1),
                    const SizedBox(height: 8),
                    const Text(
                      '사고 발생 시 바로 확인할 수 있도록 필수 정보를 등록합니다.',
                      style: TextStyle(color: AppTheme.textSub, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _insuranceCompany,
                      decoration: const InputDecoration(labelText: '보험사'),
                      validator: (value) => _boundedRequired(
                        value,
                        maxLength: 255,
                        tooLongMessage: '보험사는 255자 이하로 입력해 주세요.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _insurancePhone,
                      decoration: const InputDecoration(labelText: '보험사 연락처'),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          _isValidPhone(value) ? null : '유효한 연락처를 입력해 주세요.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _licenseNumber,
                      decoration: const InputDecoration(
                        labelText: '운전면허번호',
                        hintText: '면허증에 표시된 번호',
                      ),
                      validator: (value) => _boundedRequired(
                        value,
                        maxLength: 64,
                        tooLongMessage: '면허번호는 64자 이하로 입력해 주세요.',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(_isSaving ? '저장 중...' : '등록 완료'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String? _boundedRequired(
    String? value, {
    required int maxLength,
    required String tooLongMessage,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '필수 정보를 입력해 주세요.';
    return text.length <= maxLength ? null : tooLongMessage;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final auth = ref.read(authProvider);
    final displayName = (auth.name ?? '').trim().isNotEmpty
        ? auth.name!.trim()
        : (auth.email ?? '운전자').split('@').first;
    final saved = await ref.read(profileServiceProvider).saveProfile(
          displayName: displayName,
          licenseNumber: _licenseNumber.text.trim(),
          insuranceCompany: _insuranceCompany.text.trim(),
          insurancePhone: _insurancePhone.text.trim(),
        );
    if (!mounted) return;
    if (saved != null && isOnboardingProfileComplete(saved)) {
      context.go('/');
      return;
    }
    setState(() {
      _isSaving = false;
      _error = '저장에 실패했습니다. 다시 시도해 주세요.';
    });
  }

  @override
  void dispose() {
    _insuranceCompany.dispose();
    _insurancePhone.dispose();
    _licenseNumber.dispose();
    super.dispose();
  }
}
