import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/translator_provider.dart';
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
  const TranslatorScreen({super.key});

  @override
  ConsumerState<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends ConsumerState<TranslatorScreen> {
  final _inputController = TextEditingController();
  String sourceLang = "English";

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translatorProvider);
    final targetLang = ref.watch(activeLanguageProvider);

    return GlassScaffold(
      title: 'Translator',
      subtitle: 'Real-time AI analysis',
      body: SliverList(
        delegate: SliverChildListDelegate([
          // 1. Language Selectors
          Row(
            children: [
              Expanded(child: _buildLangButton(sourceLang)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.white24,
                  size: 16,
                ),
              ),
              Expanded(child: _buildLangButton(targetLang)),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Input Area
          GlassCard(
            padding: 12,
            child: TextField(
              controller: _inputController,
              maxLines: 5,
              style: const TextStyle(fontSize: 18, color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Enter text...",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Action Button
          LiquidButton(
            text: "Translate",
            isLoading: state.isTranslating,
            onTap: () {
              if (_inputController.text.isNotEmpty) {
                ref
                    .read(translatorProvider.notifier)
                    .runTranslation(
                      _inputController.text,
                      sourceLang,
                      targetLang,
                    );
              }
            },
          ),
          const SizedBox(height: 30),

          // 4. Fast Output
          if (state.fullTranslation.isNotEmpty) ...[
            const Text(
              "Translation",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Text(
                state.fullTranslation,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 30),
          ],

          // 5. Detailed Breakdown
          if (state.isBreakingDown)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Colors.white24),
              ),
            )
          else if (state.segments.isNotEmpty) ...[
            const Text(
              "Sentence Breakdown",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 12),
            ...state.segments.map((seg) => _SegmentCard(segment: seg)),
          ],
        ]),
      ),
    );
  }

  Widget _buildLangButton(String label) {
    return GlassCard(
      padding: 12,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final TranslationSegment segment;
  const _SegmentCard({required this.segment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              segment.source,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              segment.translation,
              style: const TextStyle(
                color: LiquidTheme.primaryAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      segment.explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white54,
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
