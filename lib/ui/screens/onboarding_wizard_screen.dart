import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lexity_mobile/theme/liquid_theme.dart';
import 'package:lexity_mobile/ui/widgets/liquid_components.dart';
import 'package:lexity_mobile/utils/constants.dart';
import 'package:lexity_mobile/models/onboarding_data.dart';
import 'package:lexity_mobile/services/onboarding_service.dart';
import 'package:lexity_mobile/providers/user_provider.dart';
import 'package:lexity_mobile/providers/journal_provider.dart';

// Lightweight glass-styled card used across the wizard (stand-in for real app GlassCard)
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.white30),
      ),
      child: child,
    );
  }
}

// Simple glass-like button used by the wizard
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GlassButton({required this.label, this.onPressed, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onPressed != null ? Colors.white24 : Colors.white10,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Subtle pulsing dot used in the AI-analysis loader
class _PulseDot extends StatefulWidget {
  final int delayMs;
  const _PulseDot({this.delayMs = 0, Key? key}) : super(key: key);
  @override
  _PulseDotState createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Onboarding Wizard Screen
class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0; // 0..3

  // STEP 1 fields
  String? _nativeLanguage;
  String? _targetLanguage;
  String? _writingStyle;
  String? _writingPurpose;
  String? _selfAssessedLevel;

  // STEP 2: journal flow
  bool _journalStarted = false;
  bool _journalWrote = false;

  Timer? _step3FallbackTimer;
  bool _step3AutoAdvanced = false;

  @override
  void dispose() {
    _step3FallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard: ensure authenticated
    final user = ref.watch(userProvider);
    if (user == null || !user.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const SizedBox.shrink();
    }

    // Auto-advance if AI analysis is ready (polling via journal provider)
    final history = ref.watch(journalHistoryProvider);
    if (_currentStep == 2 && history != null && history.journals.isNotEmpty) {
      final first = history.journals.first;
      if (first.analysis != null && !_step3AutoAdvanced) {
        _step3AutoAdvanced = true;
        Future.microtask(() {
          if (mounted) setState(() => _currentStep = 3);
        });
      }
    }

    // Fallback after 3 seconds
    if (_currentStep == 2 &&
        _step3FallbackTimer == null &&
        !_step3AutoAdvanced) {
      _step3FallbackTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _currentStep = 3);
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 12),
                Expanded(child: _buildCurrentStep()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) => _buildStepDot(i)),
    );
  }

  Widget _buildStepDot(int index) {
    final Color color = index < _currentStep
        ? Colors.green
        : index == _currentStep
        ? LiquidTheme.primaryAccent
        : Colors.white10;
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1();
      case 1:
        return _step2();
      case 2:
        return _step3();
      case 3:
        return _step4();
      default:
        return _step1();
    }
  }

  // STEP 1: Language Setup
  Widget _step1() {
    final languages = AppConstants.supportedLanguages;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step 1 of 4: Language Setup',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 12),
            _buildLanguageSelectors(languages),
            const SizedBox(height: 12),
            _buildSegmentRow(
              'Writing Style',
              ['Casual', 'Formal', 'Academic'],
              _writingStyle,
              (v) => setState(() => _writingStyle = v),
            ),
            const SizedBox(height: 8),
            _buildSegmentRow(
              'Writing Purpose',
              ['Personal', 'Professional', 'Creative'],
              _writingPurpose,
              (v) => setState(() => _writingPurpose = v),
            ),
            const SizedBox(height: 8),
            _buildSegmentRow(
              'Self-Assessed Level',
              ['Beginner', 'Intermediate', 'Advanced'],
              _selfAssessedLevel,
              (v) => setState(() => _selfAssessedLevel = v),
            ),
            const SizedBox(height: 16),
            _buildStep1ContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelectors(List<dynamic> languages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassInputRow(
          label: 'Native Language',
          value: _nativeLanguage,
          onTap: () => _openLanguagePicker(languages, isNative: true),
        ),
        const SizedBox(height: 8),
        GlassInputRow(
          label: 'Target Language',
          value: _targetLanguage,
          onTap: () => _openLanguagePicker(languages, isNative: false),
        ),
      ],
    );
  }

  void _openLanguagePicker(List<dynamic> languages, {required bool isNative}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: languages.map((lang) {
            final code = _languageCode(lang);
            final name = _languageDisplay(lang);
            return ListTile(
              title: Text(name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop(code);
              },
            );
          }).toList(),
        );
      },
    ).then((selected) {
      if (selected != null) {
        setState(() {
          if (isNative)
            _nativeLanguage = selected as String?;
          else
            _targetLanguage = selected as String?;
        });
      }
    });
  }

  String _languageCode(dynamic lang) {
    if (lang is Map<String, dynamic>)
      return lang['code'] ?? lang['name'] ?? lang.toString();
    if (lang is String) return lang;
    return lang.toString();
  }

  String _languageDisplay(dynamic lang) {
    if (lang is Map<String, dynamic>)
      return lang['name'] ?? lang['code'] ?? lang.toString();
    if (lang is String) return lang;
    return lang.toString();
  }

  Widget _buildStep1ContinueButton() {
    final filled = _nativeLanguage != null && _targetLanguage != null;
    return GlassButton(
      label: 'Continue',
      onPressed: filled
          ? () {
              final data = OnboardingData(
                nativeLanguage: _nativeLanguage!,
                targetLanguage: _targetLanguage!,
                writingStyle: _writingStyle ?? 'Casual',
                writingPurpose: _writingPurpose ?? 'Personal',
                selfAssessedLevel: _selfAssessedLevel ?? 'Beginner',
              );
              final svc = ref.read(onboardingServiceProvider);
              svc.submitOnboarding(data);
              setState(() => _currentStep = 1);
            }
          : null,
    );
  }

  // STEP 2: First Journal Prompt
  Widget _step2() {
    final prompt = _languagePromptFor(_targetLanguage);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You're all set! Let's write your first journal entry.",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  prompt,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: _buildStep2Action()),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Action() {
    if (_journalWrote) {
      return GlassButton(
        label: 'Continue',
        onPressed: () => setState(() => _currentStep = 2),
      );
    }
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(
          context,
        ).pushNamed('/journal/new', arguments: {'topic': 'first-journal'});
        if (result == true) {
          setState(() {
            _journalWrote = true;
            _currentStep = 2;
          });
        }
      },
      child: GlassButton(label: 'Start First Journal'),
    );
  }

  String _languagePromptFor(String? lang) {
    final key = (lang ?? '').toLowerCase();
    const map = {
      'spanish': 'Write about your day in Spanish. What did you learn today?',
      'french': 'Écris sur ta journée. Qu\'as-tu appris aujourd\'hui?',
      'german': 'Schreib über deinen Tag. Was hast du heute gelernt?',
      'japanese': '今日のことを書いてください。今日は何を学びましたか？',
      'korean': '오늘 하루를 적어보세요. 오늘 무엇을 배웠나요?',
      'mandarin': '写一写你今天过得怎么样。今天学到了什么？',
      'portuguese': 'Escreva sobre o seu dia. O que você aprendeu hoje?',
      'italian': 'Scrivi della tua giornata. Cosa hai imparato oggi?',
      'russian': 'Напишите о своём дне. Что вы сегодня узнали?',
      'arabic': 'اكتب عن يومك. ماذا تعلمت اليوم؟',
      'hindi': 'अपने दिन के बारे में लिखें। आज आपने क्या सीखा?',
      'polish': 'Napisz o swoim dniu. Czego się dzisiaj nauczyłeś?',
      'english': 'Write about your day. What did you learn today?',
    };
    return map[key] ?? 'Write about your day. What did you learn today?';
  }

  // STEP 3: AI Analysis
  Widget _step3() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Your journal is being analyzed by AI...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulseDot(),
                const SizedBox(width: 6),
                _PulseDot(delayMs: 150),
                const SizedBox(width: 6),
                _PulseDot(delayMs: 300),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // STEP 4: Goal Setup
  Widget _step4() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You\'re ready to start your personalized learning path!',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            const Text(
              'We will tailor a journey based on your goals and journal insights.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            GlassButton(
              label: 'Set Your Goals',
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  ref.read(onboardingServiceProvider).completeOnboarding();
                  Navigator.of(context).pushReplacementNamed('/path');
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  List<Widget> _emptySpace(double height) => [SizedBox(height: height)];
}

// Lightweight glass-like glass input row (label + value)
class GlassInputRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const GlassInputRow({
    required this.label,
    this.value,
    required this.onTap,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(
                value ?? 'Select',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Top-level dot used in Step 3 loader (separate to avoid inner-class issues)
class _PulseDotTopLevel extends StatefulWidget {
  final int delayMs;
  const _PulseDotTopLevel({this.delayMs = 0, Key? key}) : super(key: key);
  @override
  _PulseDotTopLevelState createState() => _PulseDotTopLevelState();
}

class _PulseDotTopLevelState extends State<_PulseDotTopLevel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
