import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../widgets/liquid_components.dart';
import '../../models/onboarding_data.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  PasswordStrength _passwordStrength = PasswordStrength.weak;
  bool _navigatedOnAuth = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final value = _passwordController.text;
    PasswordStrength strength = PasswordStrength.weak;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) score++;
    if (score <= 1)
      strength = PasswordStrength.weak;
    else if (score <= 2)
      strength = PasswordStrength.fair;
    else if (score == 3)
      strength = PasswordStrength.fair;
    else if (score == 4)
      strength = PasswordStrength.good;
    else
      strength = PasswordStrength.strong;
    setState(() {
      _passwordStrength = strength;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter an email');
      return;
    }
    if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return;
    }

    ref.read(authProvider.notifier).signUp(email, password);
  }

  Widget _buildPasswordStrengthBar() {
    final strengthName = _passwordStrength.toString().toLowerCase();
    Color fillColor = Colors.red;
    int filledBars = 1;
    if (strengthName.contains('weak')) {
      fillColor = Colors.red;
      filledBars = 1;
    } else if (strengthName.contains('fair')) {
      fillColor = Colors.orange;
      filledBars = 2;
    } else if (strengthName.contains('good')) {
      fillColor = Colors.blue;
      filledBars = 4;
    } else if (strengthName.contains('strong')) {
      fillColor = Colors.green;
      filledBars = 5;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (idx) {
            final filled = idx < filledBars;
            return Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: filled
                      ? fillColor
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          strengthName.contains('weak')
              ? 'Weak'
              : strengthName.contains('fair')
              ? 'Fair'
              : strengthName.contains('good')
              ? 'Good'
              : 'Strong',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bool isAuth = authState.isAuthenticated;
    if (!_navigatedOnAuth && isAuth) {
      _navigatedOnAuth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/onboarding');
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                padding: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create your account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 16),
                    GlassInput(
                      controller: _emailController,
                      hint: 'Email',
                    ).animate().fadeIn(duration: 520.ms),
                    if (_emailError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _emailError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GlassInput(
                      controller: _passwordController,
                      hint: 'Password',
                      isPassword: true,
                    ).animate().fadeIn(duration: 540.ms),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _passwordError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildPasswordStrengthBar(),
                    if (authState.error != null &&
                        authState.error!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        authState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    LiquidButton(
                      text: 'Get Started',
                      isLoading: authState.isLoading,
                      onTap: _onSubmit,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Continue with Google',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 14),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Already have an account? Log in',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }
}
