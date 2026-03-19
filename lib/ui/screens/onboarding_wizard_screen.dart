// lib/ui/screens/onboarding_wizard_screen.dart
// iOS 26 Style Onboarding Wizard - Fluid UI with physics-based transitions
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lexity_mobile/theme/liquid_theme.dart';
import 'package:lexity_mobile/ui/widgets/liquid_components.dart';
import 'package:lexity_mobile/utils/constants.dart';
import 'package:lexity_mobile/models/onboarding_data.dart';
import 'package:lexity_mobile/services/onboarding_service.dart';
import 'package:lexity_mobile/providers/journal_provider.dart';
import 'package:lexity_mobile/providers/user_provider.dart';
import 'package:lexity_mobile/providers/onboarding_provider.dart';

// Onboarding Wizard Screen - iOS 26 Fluid UI
class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  // STEP 1 fields
  String? _nativeLanguage;
  String? _targetLanguage;
  String? _writingStyle;
  String? _writingPurpose;
  String? _selfAssessedLevel;

  bool _journalWrote = false;
  Timer? _step3PollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Sync starting step based on existing data
    Future.microtask(() {
      final profile = ref.read(userProfileProvider).value;
      
      // Determine initial step from OnboardingStep enum
      final onboardingStep = ref.read(onboardingProvider);
      int startIndex = _mapStepToIndex(onboardingStep);
      
      setState(() {
        // If we already have a native language, start at step 1
        if (profile?.nativeLanguage != null && profile!.nativeLanguage!.isNotEmpty) {
          startIndex = 1;
        }
        // If we already wrote a journal, start at step 2
        final journals = ref.read(journalHistoryProvider).value ?? [];
        if (journals.isNotEmpty) {
          startIndex = 2;
          if (journals.first.analysis != null) {
            startIndex = 3;
          }
        }
        // If onboarding is already completed, redirect
        if (profile?.onboardingCompleted == true) {
          if (mounted) {
            context.go('/path');
          }
          return;
        }
        _currentIndex = startIndex;
        _pageController = PageController(initialPage: startIndex);
      });
    });
  }

  int _mapStepToIndex(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.profileSetup:
        return 0;
      case OnboardingStep.firstJournal:
        return 1;
      case OnboardingStep.viewAnalysis:
        return 2;
      case OnboardingStep.studyIntro:
        return 3;
      case OnboardingStep.completed:
        return 4; // Will redirect
      default:
        return 0;
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingWizardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex == 2 && _step3PollTimer == null) {
      _startStep3Polling();
    } else if (_currentIndex != 2) {
      _step3PollTimer?.cancel();
      _step3PollTimer = null;
    }
  }

  void _startStep3Polling() {
    _step3PollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final journals = ref.read(journalHistoryProvider).value ?? [];
      if (journals.isNotEmpty && journals.first.analysis != null) {
        timer.cancel();
        if (mounted) {
          _goToNextPage();
        }
      }
    });
    Future.delayed(const Duration(seconds: 30)).then((_) {
      if (mounted && _currentIndex == 2) {
        _goToNextPage();
      }
    });
  }

  void _goToNextPage() {
    if (_currentIndex < 3) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: 600.ms,
        curve: Curves.easeOutExpo, // iOS-like curve
      );
    }
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    _step3PollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Stack(
          children: [
            // Background Content (Slightly blurred)
            Center(
              child: Opacity(
                opacity: 0.15,
                child: AppLogo(width: 150).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 3.seconds,
                  curve: Curves.easeInOutSine,
                ).then().scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(0.85, 0.85),
                  duration: 3.seconds,
                  curve: Curves.easeInOutSine,
                ),
              ),
            ),
            
            // The iOS 26 Modal Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.82,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  child: GlassCard(
                    padding: 0,
                    borderRadius: 40,
                    child: Column(
                      children: [
                        _buildHandle(),
                        _buildProgressIndicator(),
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: _onPageChanged,
                            children: [
                              _StepLanguageSetup(
                                nativeLanguage: _nativeLanguage,
                                targetLanguage: _targetLanguage,
                                writingStyle: _writingStyle,
                                writingPurpose: _writingPurpose,
                                selfAssessedLevel: _selfAssessedLevel,
                                onNativeChanged: (v) => setState(() => _nativeLanguage = v),
                                onTargetChanged: (v) => setState(() => _targetLanguage = v),
                                onStyleChanged: (v) => setState(() => _writingStyle = v),
                                onPurposeChanged: (v) => setState(() => _writingPurpose = v),
                                onLevelChanged: (v) => setState(() => _selfAssessedLevel = v),
                                onContinue: _onStep1Continue,
                              ),
                              _StepJournalIntro(
                                targetLanguage: _targetLanguage,
                                journalWrote: _journalWrote,
                                onStartJournal: _onStartJournal,
                              ),
                              _StepAIAnalyzing(),
                              _StepGoalCompletion(
                                onSetGoals: () => context.go('/profile'),
                                onSkip: _onFinishOnboarding,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().slideY(begin: 1, end: 0, duration: 800.ms, curve: Curves.easeOutQuart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: 400.ms,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 3,
              decoration: BoxDecoration(
                color: isActive ? LiquidTheme.primaryAccent : Colors.white10,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive ? [
                  BoxShadow(color: LiquidTheme.primaryAccent.withOpacity(0.5), blurRadius: 8)
                ] : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  void _onStep1Continue() {
    if (_nativeLanguage != null && _targetLanguage != null) {
      final data = OnboardingData(
        nativeLanguage: _nativeLanguage!,
        targetLanguage: _targetLanguage!,
        writingStyle: _writingStyle ?? 'Casual',
        writingPurpose: _writingPurpose ?? 'Personal',
        selfAssessedLevel: _selfAssessedLevel ?? 'Beginner',
      );
      final svc = ref.read(onboardingServiceProvider);
      svc.submitOnboarding(data);
      _goToNextPage();
    }
  }

  void _onStartJournal() async {
    final result = await context.push<bool>(
      '/journal/new?topic=first-journal',
    );
    if (result == true || result == null) {
      setState(() {
        _journalWrote = true;
      });
      _goToNextPage();
    }
  }

  void _onFinishOnboarding() async {
    await ref.read(onboardingServiceProvider).completeOnboarding();
    if (mounted) {
      context.go('/path');
    }
  }
}

// Step 1: Language & Style Setup
class _StepLanguageSetup extends StatelessWidget {
  final String? nativeLanguage;
  final String? targetLanguage;
  final String? writingStyle;
  final String? writingPurpose;
  final String? selfAssessedLevel;
  final ValueChanged<String> onNativeChanged;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onPurposeChanged;
  final ValueChanged<String> onLevelChanged;
  final VoidCallback onContinue;

  const _StepLanguageSetup({
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.writingStyle,
    required this.writingPurpose,
    required this.selfAssessedLevel,
    required this.onNativeChanged,
    required this.onTargetChanged,
    required this.onStyleChanged,
    required this.onPurposeChanged,
    required this.onLevelChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final languages = AppConstants.supportedLanguages;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Setup your profile",
            style: LiquidTheme.darkTheme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().moveX(begin: -20, end: 0, duration: 500.ms),
          const SizedBox(height: 8),
          const Text(
            "Tailoring your Lexity experience.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ).animate().fadeIn(delay: 100.ms).moveX(begin: -20, end: 0, duration: 500.ms),
          const SizedBox(height: 32),
          
          // Modern Pill Dropdowns
          _SelectionTile(
            title: "Native Language",
            value: nativeLanguage ?? "Select",
            icon: Icons.language,
            onTap: () => _openLanguagePicker(context, languages, onNativeChanged),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          _SelectionTile(
            title: "Target Language",
            value: targetLanguage ?? "Select",
            icon: Icons.translate,
            onTap: () => _openLanguagePicker(context, languages, onTargetChanged),
          ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.easeOutBack),
          
          const SizedBox(height: 24),
          
          // Segment Rows with animations
          _buildSegmentRow(
            "Writing Style",
            ['Casual', 'Formal', 'Academic'],
            writingStyle,
            onStyleChanged,
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          _buildSegmentRow(
            "Writing Purpose",
            ['Personal', 'Professional', 'Creative'],
            writingPurpose,
            onPurposeChanged,
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          _buildSegmentRow(
            "Self-Assessed Level",
            ['Beginner', 'Intermediate', 'Advanced'],
            selfAssessedLevel,
            onLevelChanged,
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 40),
          LiquidButton(
            text: "Continue",
            onTap: (nativeLanguage != null && targetLanguage != null) ? onContinue : () {},
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  void _openLanguagePicker(
    BuildContext context, 
    List<dynamic> languages, 
    ValueChanged<String> onSelect,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1c23),
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: languages.map((lang) {
            final name = _languageDisplay(lang);
            return ListTile(
              title: Text(name, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(_languageCode(lang)),
            );
          }).toList(),
        );
      },
    ).then((selected) {
      if (selected != null) {
        onSelect(selected as String);
      }
    });
  }

  String _languageCode(dynamic lang) {
    if (lang is Map<String, dynamic>) return lang['code'] ?? lang['name'] ?? lang.toString();
    if (lang is String) return lang;
    return lang.toString();
  }

  String _languageDisplay(dynamic lang) {
    if (lang is Map<String, dynamic>) return lang['name'] ?? lang['code'] ?? lang.toString();
    if (lang is String) return lang;
    return lang.toString();
  }

  Widget _buildSegmentRow(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 10.0,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(opt);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? LiquidTheme.primaryAccent : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white24 : Colors.white10,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Step 2: First Journal Prompt
class _StepJournalIntro extends StatelessWidget {
  final String? targetLanguage;
  final bool journalWrote;
  final VoidCallback onStartJournal;

  const _StepJournalIntro({
    required this.targetLanguage,
    required this.journalWrote,
    required this.onStartJournal,
  });

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "You're all set!",
            style: LiquidTheme.darkTheme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().moveX(begin: -20, end: 0),
          const SizedBox(height: 8),
          const Text(
            "Let's write your first journal entry.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ).animate().fadeIn(delay: 100.ms).moveX(begin: -20, end: 0),
          const SizedBox(height: 32),
          
          GlassCard(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LiquidTheme.primaryAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: LiquidTheme.primaryAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Today's Prompt",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _languagePromptFor(targetLanguage),
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          
          const Spacer(),
          
          if (journalWrote)
            LiquidButton(text: "Continue", onTap: onStartJournal)
          else
            LiquidButton(text: "Start First Journal", onTap: onStartJournal),
          
        ].animate().fadeIn(delay: 300.ms),
      ),
    );
  }
}

// Step 3: AI Analysis Animation
class _StepAIAnalyzing extends StatelessWidget {
  const _StepAIAnalyzing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  LiquidTheme.primaryAccent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.psychology,
                size: 48,
                color: LiquidTheme.primaryAccent,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: 1.5.seconds,
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              begin: const Offset(1.1, 1.1),
              end: const Offset(0.9, 0.9),
              duration: 1.5.seconds,
              curve: Curves.easeInOut,
            ),
          
          const SizedBox(height: 32),
          Text(
            "Your journal is being analyzed...",
            style: LiquidTheme.darkTheme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          const Text(
            "Our AI is crafting personalized insights\njust for you.",
            style: TextStyle(color: Colors.white54, fontSize: 15),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          
          const Spacer(),
          
          // Animated dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidTheme.primaryAccent,
                ),
              ).animate(delay: (i * 150).ms, onPlay: (c) => c.repeat())
                .fadeIn(duration: 300.ms)
                .then()
                .fadeOut(duration: 300.ms),
            )),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// Step 4: Goal Completion
class _StepGoalCompletion extends StatelessWidget {
  final VoidCallback onSetGoals;
  final VoidCallback onSkip;

  const _StepGoalCompletion({
    required this.onSetGoals,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LiquidTheme.primaryAccent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.celebration,
              size: 64,
              color: LiquidTheme.primaryAccent,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          
          const SizedBox(height: 32),
          Text(
            "You're ready to start!",
            style: LiquidTheme.darkTheme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          const Text(
            "We will tailor a journey based on\nyour goals and journal insights.",
            style: TextStyle(color: Colors.white54, fontSize: 15),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
          
          const Spacer(),
          
          LiquidButton(text: "Set Your Goals", onTap: onSetGoals)
            .animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onSkip,
            child: Text(
              "Skip for now",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// Selection Tile Widget - Modern iOS 26 style
class _SelectionTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: LiquidTheme.primaryAccent, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: value == "Select" ? Colors.white54 : LiquidTheme.primaryAccent,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
