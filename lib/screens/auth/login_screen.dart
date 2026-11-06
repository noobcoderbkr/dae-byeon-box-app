// lib/screens/auth/login_screen.dart
// 로그인 / 회원가입 화면 (테슬라 미니멀 다크)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSignup = false; // false=로그인, true=회원가입
  String? _validationError;
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _pwController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              // 로고
              const BrandLogo(fontSize: 28),
              const SizedBox(height: 8),
              Text(
                _isSignup ? '회원가입' : '로그인',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 56),

              // 이메일
              _field('이메일', _emailController,
                  hint: 'example@email.com',
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 24),

              // 이름 (회원가입만)
              if (_isSignup) ...[
                _field('이름', _nameController, hint: '홍길동'),
                const SizedBox(height: 24),
              ],

              // 비밀번호
              _field('비밀번호', _pwController,
                  hint: _isSignup ? '8자 이상' : '', obscure: true),

              // 에러 메시지
              if (_validationError != null || auth.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _validationError ?? auth.error!,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // 로그인/가입 버튼
              GestureDetector(
                onTap: auth.isBusy ? null : _submit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: auth.isBusy
                        ? AppTheme.surfaceDark
                        : AppTheme.pointWhite,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: auth.isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.textSub),
                          )
                        : Text(
                            _isSignup ? '가입하기' : '로그인',
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
              const SizedBox(height: 20),

              // 로그인 <-> 회원가입 전환
              GestureDetector(
                onTap: auth.isBusy
                    ? null
                    : () => setState(() {
                          _isSignup = !_isSignup;
                          _validationError = null;
                        }),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _isSignup ? '이미 계정이 있나요? ' : '계정이 없나요? ',
                          style: const TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        TextSpan(
                          text: _isSignup ? '로그인' : '회원가입',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
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

  Widget _field(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textHint,
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.only(bottom: 10),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final pw = _pwController.text;
    final name = _nameController.text.trim();
    final validationError = _validate(
      email: email,
      name: name,
      password: pw,
    );

    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }
    if (_validationError != null) {
      setState(() => _validationError = null);
    }

    final notifier = ref.read(authProvider.notifier);
    if (_isSignup) {
      await notifier.signup(email: email, name: name, password: pw);
    } else {
      await notifier.login(email: email, password: pw);
    }
    // 인증 성공 시 라우터 redirect 가 자동으로 메인으로 보냄
  }

  String? _validate({
    required String email,
    required String name,
    required String password,
  }) {
    if (email.isEmpty) return '이메일을 입력해 주세요.';
    if (email.length > 320) return '이메일은 320자 이하로 입력해 주세요.';
    if (email.length < 3 ||
        email.split('@').length != 2 ||
        email.startsWith('@') ||
        email.endsWith('@')) {
      return '올바른 이메일 주소를 입력해 주세요.';
    }
    if (_isSignup && name.isEmpty) return '이름을 입력해 주세요.';
    if (_isSignup && name.length > 255) {
      return '이름은 255자 이하로 입력해 주세요.';
    }
    if (password.isEmpty) return '비밀번호를 입력해 주세요.';
    if (_isSignup && password.length < 8) {
      return '비밀번호는 8자 이상 입력해 주세요.';
    }
    if (password.length > 1024) {
      return '비밀번호는 1024자 이하로 입력해 주세요.';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _pwController.dispose();
    super.dispose();
  }
}
