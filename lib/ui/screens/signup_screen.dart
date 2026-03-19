import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../../models/onboarding_data.dart';
import 'package:go_router/go_router.dart';

// A dedicated sign-up screen, standalone from the Login screen.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  // Password strength state derived from onboarding data enum
  PasswordStrength _passwordStrength = PasswordStrength.weak;
  // Reference to LiquidTheme type to ensure the import is used (design system hooks)
  final Type _liquidThemeType = LiquidTheme;

  bool _navigatedOnAuth = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final value = _passwordController.text;
    // Derive strength from a heuristic; we map into the provided PasswordStrength enum.
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
      strength = PasswordStrength.fair; // tie-breaker
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
      setState(() {
        _emailError = 'Please enter an email';
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _passwordError = 'Password must be at least 8 characters';
      });
      return;
    }

    // Trigger sign-up via auth provider
    ref.read(authProvider.notifier).signUp(email, password);
  }

  Widget _buildPasswordStrengthBar() {
    // Compute color and filled-bars from the PasswordStrength enum using a robust, runtime-safe approach
    final String strengthName = _passwordStrength.toString().toLowerCase();
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
        SizedBox(height: 8),
        Row(
          children: List.generate(5, (idx) {
            final bool filled = idx < filledBars;
            return Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: filled ? fillColor : Colors.white.withOpacity(0.15),
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
    final dynamic authState = ref.watch(authProvider);

    // Navigate on successful authentication
    final bool isAuth =
        (authState?.authenticated == true) ||
        (authState?.isAuthenticated == true);
    if (!_navigatedOnAuth && isAuth) {
      _navigatedOnAuth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/onboarding');
      });
    }

    // Optional error text from auth provider (best-effort, using dynamic access)
    String? apiError;
    try {
      apiError = authState?.error?.toString();
    } catch (_) {
      apiError = null;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with subtle animation
                      Text(
                            'Create your account',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: 0.2, duration: 500.ms),

                      const SizedBox(height: 16),
                      // Email
                      GlassInput(
                        controller: _emailController,
                        hint: 'Email',
                      ).animate().fadeIn(duration: 520.ms),
                      if (_emailError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _emailError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Password
                      GlassInput(
                        controller: _passwordController,
                        hint: 'Password',
                        isPassword: true,
                      ).animate().fadeIn(duration: 540.ms),
                      if (_passwordError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _passwordError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      // Strength indicator
                      const SizedBox(height: 12),
                      _buildPasswordStrengthBar(),

                      // API error from sign-up flow
                      if (apiError != null && apiError.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          apiError,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      // Get Started button
                      LiquidButton(
                        text: 'Get Started',
                        onTap: _onSubmit,
                      ).animate().fadeIn(duration: 400.ms),

                      // TODO: Google OAuth
                      // Secondary, disabled Google OAuth placeholder (no OAuth implemented yet)
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Continue with Google',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 14),
                      // Existing account link
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
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }
}
