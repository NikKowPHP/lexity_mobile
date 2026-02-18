import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/translator_provider.dart';
import '../../providers/srs_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/translation_result.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';

// 1. Reusable Page Skeleton
class GlassScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? floatingActionButton;

  const GlassScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // Add padding to bottom to avoid nav bar overlap
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: body,
          ),
          // Spacer for Bottom Navigation Bar
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// 2. Learning Path Page (Modules)
class PathScreen extends StatelessWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Your Path',
      subtitle: 'Module 3: French Basics',
      body: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final isLocked = index > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                padding: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.white10 : LiquidTheme.primaryAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_outline : Icons.check,
                        color: isLocked ? Colors.white38 : LiquidTheme.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Unit ${index + 1}: Introductions",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isLocked ? Colors.white38 : Colors.white,
                          ),
                        ),
                        Text(
                          isLocked ? "Complete previous unit" : "In Progress • 80%",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
          childCount: 8,
        ),
      ),
    );
  }
}

// 4. Journal Page
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Journal',
      subtitle: 'Write freely or describe an image',
      body: SliverToBoxAdapter(
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Topic", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              const Text("Describe your favorite childhood memory.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(child: Text("Tap to start writing...", style: TextStyle(color: Colors.white38))),
              ),
              const SizedBox(height: 20),
              LiquidButton(text: "Submit Entry", onTap: () {})
            ],
          ),
        ),
      ),
    );
  }
}

// 5. Progress Page
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Analytics',
      subtitle: 'Your fluency timeline',
      body: SliverToBoxAdapter(
        child: Column(
          children: [
            GlassCard(
              child: SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.show_chart, size: 100, color: LiquidTheme.primaryAccent)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: GlassCard(child: Column(children: [Text("🔥 12", style: TextStyle(fontSize: 24, color: Colors.white)), Text("Streak", style: TextStyle(color: Colors.white54))]))),
                SizedBox(width: 16),
                Expanded(child: GlassCard(child: Column(children: [Text("📚 450", style: TextStyle(fontSize: 24, color: Colors.white)), Text("Words", style: TextStyle(color: Colors.white54))]))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// 6. Profile Page
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return GlassScaffold(
      title: 'Profile',
      subtitle: 'Manage your learning identity',
      body: profileAsync.when(
        loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) =>
            SliverToBoxAdapter(child: Center(child: Text("Error: $e"))),
        data: (profile) => SliverList(
          delegate: SliverChildListDelegate([
            // User Header Card
            GlassCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: LiquidTheme.primaryAccent.withValues(
                      alpha: 0.2,
                    ),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        profile.subscriptionTier,
                        style: TextStyle(
                          color: LiquidTheme.primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings Section
            const Text(
              "Learning Settings",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Target Language Dropdown
            _ProfileDropdown(
              label: "Target Language",
              value: profile.defaultTargetLanguage,
              items: const ["Spanish", "French", "German", "English", "Polish"],
              onChanged: (val) =>
                  ref.read(userProfileProvider.notifier).updateInfo(lang: val),
            ),

            _ProfileDropdown(
              label: "Writing Style",
              value: profile.writingStyle ?? "Casual",
              items: const ["Casual", "Formal", "Academic"],
              onChanged: (val) =>
                  ref.read(userProfileProvider.notifier).updateInfo(style: val),
            ),

            const SizedBox(height: 40),
            LiquidButton(
              text: "Sign Out",
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {}, // Implement Delete Account
              child: const Text(
                "Delete Account",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Function(String) onChanged;

  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) => onChanged(val!),
            ),
          ],
        ),
      ),
    );
  }
}

// 7. Translator Screen
class TranslatorScreen extends ConsumerStatefulWidget {
  final bool isBubbleMode;
  const TranslatorScreen({super.key, this.isBubbleMode = false});

  @override
  ConsumerState<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends ConsumerState<TranslatorScreen> {
  final _inputController = TextEditingController();
  String? _sourceLang;
  String? _targetLang;


  @override
  void initState() {
    super.initState();
    // Initialize languages from provider state
    Future.microtask(() {
      final profile = ref.read(userProfileProvider).value;
      final activeTarget = ref.read(activeLanguageProvider);
      setState(() {
        _sourceLang = profile?.nativeLanguage ?? "English";
        _targetLang = activeTarget;
      });
    });
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _inputController.text = data!.text!;
      });
    }
  }

  void _discardText() {
    setState(() {
      _inputController.clear();
    });
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translatorProvider);
    final profileAsync = ref.watch(userProfileProvider);

    // 1. Ensure unique list and handle potential nulls/casing
    final List<String> availableLanguages = profileAsync.maybeWhen(
      data: (p) {
        final set = <String>{
          if (p.nativeLanguage != null && p.nativeLanguage!.isNotEmpty)
            p.nativeLanguage!,
          ...p.languageProfiles.map((lp) => lp.language).where((l) => l.isNotEmpty),
          if (p.defaultTargetLanguage.isNotEmpty) p.defaultTargetLanguage,
        };
        // Fallback if set is empty
        if (set.isEmpty) return ["English", "Spanish"];
        return set.toList();
      },
      orElse: () => ["English", "Spanish", "French", "German"],
    );

    // 2. Safety check: Ensure selected values exist in the current available list
    // This prevents the crash if the profile updates and a language is removed
    final effectiveSource = availableLanguages.contains(_sourceLang)
        ? _sourceLang!
        : availableLanguages.first;

    final effectiveTarget = availableLanguages.contains(_targetLang)
        ? _targetLang!
        : (availableLanguages.length > 1
            ? availableLanguages[1]
            : availableLanguages.first);

    return GlassScaffold(
      title: 'Translator',
      subtitle: 'Real-time AI analysis',
      body: SliverToBoxAdapter(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 1000,
            ), // Desktop width constraint
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Language Selectors
                Row(
                  children: [
                    Expanded(
                      child: LiquidDropdown<String>(
                        label: "From",
                        value: effectiveSource,
                        items: availableLanguages,
                        onChanged: (val) => setState(() => _sourceLang = val),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: IconButton(
                        onPressed: _swapLanguages,
                        icon: const Icon(
                          Icons.swap_horiz,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LiquidDropdown<String>(
                        label: "To",
                        value: effectiveTarget,
                        items: availableLanguages,
                        onChanged: (val) => setState(() => _targetLang = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Input Area
                Stack(
                  children: [
                    GlassCard(
                      padding: 16,
                      child: TextField(
                        controller: _inputController,
                        maxLines: 6,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Enter text to translate...",
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _inputController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white38,
                              ),
                              onPressed: _discardText,
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.content_paste,
                                color: Colors.white38,
                              ),
                              onPressed: _pasteFromClipboard,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Prominent Translate Button
                LiquidButton(
                  text: "Translate",
                  isLoading: state.isTranslating,
                  onTap: () {
                    if (_inputController.text.isNotEmpty) {
                      ref
                          .read(translatorProvider.notifier)
                          .runTranslation(
                            _inputController.text,
                            effectiveSource,
                            effectiveTarget,
                          );
                    }
                  },
                ),
                const SizedBox(height: 40),

                // 4. Output Section
                if (state.fullTranslation.isNotEmpty) ...[
                  const Text(
                    "TRANSLATION",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: 20,
                    child: Text(
                      state.fullTranslation,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],

                // 5. Sentence Breakdown Section
                if (state.isBreakingDown)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.white24),
                    ),
                  )
                else if (state.segments.isNotEmpty) ...[
                  const Text(
                    "SENTENCE BREAKDOWN",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...state.segments.map(
                    (seg) => _SegmentCard(
                      segment: seg,
                      targetLanguage: effectiveTarget,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentCard extends ConsumerStatefulWidget {
  final TranslationSegment segment;
  final String targetLanguage;
  const _SegmentCard({required this.segment, required this.targetLanguage});

  @override
  ConsumerState<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends ConsumerState<_SegmentCard> {
  bool _isAdding = false;
  bool _isAdded = false;

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);

    final success = await ref
        .read(srsProvider.notifier)
        .addToDeckFromTranslation(
          front: widget.segment.source,
          back: widget.segment.translation,
          language: widget.targetLanguage.toLowerCase(),
          explanation: widget.segment.explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) _isAdded = true;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Added to Study Deck",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: LiquidTheme.primaryAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.segment.source,
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: (_isAdded || _isAdding) ? null : _handleAddToDeck,
                  icon: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white24,
                          ),
                        )
                      : Icon(
                          _isAdded ? Icons.check_circle : Icons.add_circle,
                          color: _isAdded
                              ? Colors.greenAccent
                              : LiquidTheme.primaryAccent,
                          size: 24,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.segment.translation,
              style: const TextStyle(
                color: Color(0xFF6366F1), // Electric Indigo from screenshot
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.segment.explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
