import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lexity_mobile/theme/liquid_theme.dart';
import 'package:lexity_mobile/ui/widgets/liquid_components.dart';
import 'package:lexity_mobile/utils/constants.dart';
import 'package:lexity_mobile/models/onboarding_data.dart';
import 'package:lexity_mobile/models/user_profile.dart';
import 'package:lexity_mobile/services/onboarding_service.dart';
import 'package:lexity_mobile/providers/onboarding_provider.dart';
import 'package:lexity_mobile/providers/user_provider.dart';
import 'package:lexity_mobile/providers/topic_provider.dart';

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

  String? _nativeLanguage;
  String? _targetLanguage;
  String? _writingStyle;
  String? _writingPurpose;
  String? _selfAssessedLevel;

  @override
  void initState() {
    super.initState();

    // Initial setup (will likely be 0 on a cold boot/hard refresh)
    final initialStep = ref.read(onboardingProvider);
    _currentIndex = _mapStepToIndex(initialStep);
    _pageController = PageController(initialPage: _currentIndex);

    // Hydrate local state synchronously if profile is already cached
    _hydrateFromProfile(ref.read(userProfileProvider).value);
  }

  void _hydrateFromProfile(UserProfile? profile) {
    if (profile != null) {
      _nativeLanguage ??= profile.nativeLanguage;
      _targetLanguage ??= profile.defaultTargetLanguage;
      _writingStyle ??= profile.writingStyle ?? 'Casual';
      _writingPurpose ??= profile.writingPurpose ?? 'Personal';
      _selfAssessedLevel ??= profile.selfAssessedLevel ?? 'Beginner';
    }
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
      default:
        return 0;
    }
  }

  Future<void> _handleStep1Submit() async {
    if (_nativeLanguage == null || _targetLanguage == null) return;

    final data = OnboardingData(
      nativeLanguage: _nativeLanguage!,
      targetLanguage: _targetLanguage!,
      writingStyle: _writingStyle ?? 'Casual',
      writingPurpose: _writingPurpose ?? 'Personal',
      selfAssessedLevel: _selfAssessedLevel ?? 'Beginner',
    );

    // Optimistically advance UI for that smooth iOS feel
    setState(() => _currentIndex = 1);
    if (_pageController.hasClients) {
      _pageController.nextPage(duration: 600.ms, curve: Curves.easeOutExpo);
    }

    try {
      await ref.read(onboardingServiceProvider).submitOnboarding(data);
      // Invalidate so the provider catches up to the new state
      ref.invalidate(userProfileProvider);
    } catch (e) {
      // Fallback/Error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // THE FIX: Listeners to sync UI automatically after DB/Network loads
    // -------------------------------------------------------------------------

    // 1. Listen for Step changes (Jumps user to Journal step automatically if profile loads)
    ref.listen<OnboardingStep>(onboardingProvider, (previous, next) {
      final newIndex = _mapStepToIndex(next);
      if (newIndex != _currentIndex && _pageController.hasClients) {
        setState(() => _currentIndex = newIndex);

        // Jump instantly on app load, animate if progressing normally
        if (previous == OnboardingStep.inactive || previous == null) {
          _pageController.jumpToPage(newIndex);
        } else {
          _pageController.animateToPage(
            newIndex,
            duration: 600.ms,
            curve: Curves.easeOutExpo,
          );
        }
      }
    });

    // 2. Listen for Profile data to hydrate the form inputs
    ref.listen(userProfileProvider, (previous, next) {
      if (next.value != null && _nativeLanguage == null) {
        setState(() => _hydrateFromProfile(next.value));
      }
    });

    // -------------------------------------------------------------------------

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: Stack(
          children: [
            const Positioned.fill(
              child: Align(
                alignment: Alignment(0, -0.6),
                child: AppLogo(width: 120),
              ),
            ),

            // The iOS 26 Modal Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child:
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(44),
                    ),
                    child: BackdropFilter(
                      // High-density blur for that "Liquid Glass" look
                      filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.88,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          // Dark tint that isn't fully opaque, allowing underlying colors to bleed through
                          color: const Color(0xFF0D1117).withOpacity(0.75),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(44),
                          ),
                          border: Border.all(
                            // Specular highlight on the top edge
                            color: Colors.white.withOpacity(0.12),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 100,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildHandle(),
                            _buildProgressIndicator(),
                            Expanded(
                              child: PageView(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _buildStep1(),
                                  _buildStep2(),
                                  _buildStep3(),
                                  _buildStep4(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().slideY(
                    begin: 1,
                    end: 0,
                    duration: 900.ms,
                    curve: Curves
                        .easeOutBack, // Aggressive Apple-style entry with snap
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      width: 48,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(3),
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
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? LiquidTheme.primaryAccent : Colors.white10,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: LiquidTheme.primaryAccent.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- STEPS ---

  Widget _buildStep1() {
    final languages = AppConstants.supportedLanguages;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Setup your profile",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().moveX(begin: -20, end: 0),
          const SizedBox(height: 8),
          const Text(
            "Tailoring your Lexity experience.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 32),

          _buildSelectionTile(
            "Native Language",
            _nativeLanguage ?? "Select",
            Icons.language,
            () => _openLanguagePicker(languages, true),
          ),
          const SizedBox(height: 12),
          _buildSelectionTile(
            "Target Language",
            _targetLanguage ?? "Select",
            Icons.translate,
            () => _openLanguagePicker(languages, false),
          ),

          const SizedBox(height: 24),
          _buildSegmentRow(
            'Writing Style',
            ['Casual', 'Formal', 'Academic'],
            _writingStyle,
            (v) => setState(() => _writingStyle = v),
          ),
          const SizedBox(height: 12),
          _buildSegmentRow(
            'Writing Purpose',
            ['Personal', 'Professional', 'Creative'],
            _writingPurpose,
            (v) => setState(() => _writingPurpose = v),
          ),
          const SizedBox(height: 12),
          _buildSegmentRow(
            'Self-Assessed Level',
            ['Beginner', 'Intermediate', 'Advanced'],
            _selfAssessedLevel,
            (v) => setState(() => _selfAssessedLevel = v),
          ),

          const SizedBox(height: 40),
          LiquidButton(
            text: "Continue",
            onTap: (_nativeLanguage != null && _targetLanguage != null)
                ? _handleStep1Submit
                : () {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final topicsAsync = ref.watch(topicsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Choose a Topic",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().moveX(begin: -20, end: 0),
          const SizedBox(height: 8),
          const Text(
            "Pick something that inspires you, or write freely.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 12),

          // THE FADING LIST: Expands to fill space between header and buttons
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, // Top edge fade
                    Colors.black, // Opaque middle
                    Colors.black, // Opaque middle
                    Colors.transparent, // Bottom edge fade
                  ],
                  stops: [0.0, 0.08, 0.92, 1.0], // Fade range
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: topicsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: LiquidTheme.primaryAccent,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    "Error loading topics",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                data: (topics) {
                  return ListView.separated(
                    // Extra padding so items don't start/end under the fade
                    padding: const EdgeInsets.only(top: 24, bottom: 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: topics.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildTopicTile(topics[index], index),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // BOTTOM ACTION GROUP: Fixed at the bottom
          Column(
            children: [
              GestureDetector(
                onTap: () => context.push('/journal/new?topic=Free Write'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Or write freely",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.read(topicsProvider.notifier).refresh(),
                icon: const Icon(
                  Icons.refresh,
                  size: 14,
                  color: LiquidTheme.primaryAccent,
                ),
                label: const Text(
                  "Generate new topics",
                  style: TextStyle(
                    color: LiquidTheme.primaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// iOS 26 Style Topic Tile
  Widget _buildTopicTile(String topic, int index) {
    return GestureDetector(
      onTap: () =>
          context.push('/journal/new?topic=${Uri.encodeComponent(topic)}'),
      child:
          Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LiquidTheme.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: LiquidTheme.primaryAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        topic,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 20,
                    ),
                  ],
                ),
              )
              .animate(delay: (100 * index).ms)
              .fadeIn(duration: 400.ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
                Icons.auto_awesome,
                size: 60,
                color: LiquidTheme.primaryAccent,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                duration: 1.seconds,
              ),
          const SizedBox(height: 24),
          const Text(
            "Lexi is analyzing...",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Evaluating grammar, phrasing, and vocabulary.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "You're all set!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your personalized path is ready.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 32),
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.greenAccent),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Analysis complete. Your curriculum has been adjusted.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          LiquidButton(
            text: "Start Learning",
            onTap: () async {
              await ref.read(onboardingServiceProvider).completeOnboarding();
              if (mounted) context.go('/path');
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSelectionTile(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: LiquidTheme.primaryAccent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: LiquidTheme.primaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentRow(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () => onSelected(opt),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? LiquidTheme.primaryAccent
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? LiquidTheme.primaryAccent.withOpacity(0.5)
                        : Colors.white10,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _openLanguagePicker(List<dynamic> languages, bool isNative) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1c23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: languages.map((lang) {
                    final code =
                        lang['value'] ?? lang['code'] ?? lang.toString();
                    final name = lang['name'] ?? lang.toString();
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 4,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(code),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          if (isNative)
            _nativeLanguage = selected as String?;
          else
            _targetLanguage = selected as String?;
        });
      }
    });
  }
}
