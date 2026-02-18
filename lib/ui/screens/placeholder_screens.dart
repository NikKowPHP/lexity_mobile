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
import '../../utils/constants.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';

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
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // Add padding to bottom to avoid nav bar overlap
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 100 : 24, 60, 24, 20),
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
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Helper to launch URLs (Placeholder for url_launcher)
  Future<void> _launchURL(String urlString) async {
    // Implement using url_launcher package:
    // final Uri url = Uri.parse(urlString);
    // if (!await launchUrl(url)) throw Exception('Could not launch $url');
    debugPrint("Launching URL: $urlString");
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return GlassScaffold(
      title: 'Settings',
      subtitle: 'Manage your profile and preferences',
      body: profileAsync.when(
        loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => SliverToBoxAdapter(child: Text("Error: $e")),
        data: (profile) {
          return SliverList(
            delegate: SliverChildListDelegate([
              const _SectionHeader(title: "Profile"),
              _ProfileForm(profile: profile),

              const SizedBox(height: 24),
              const _SectionHeader(title: "Goals"),
              _GoalsForm(profile: profile),

              const SizedBox(height: 24),
              const _SectionHeader(title: "Subscription"),
              _SubscriptionSection(profile: profile, onManage: _launchURL),

              const SizedBox(height: 24),
              const _SectionHeader(title: "Data & Onboarding"),
              _DataSection(
                onReset: () async {
                  await ref
                      .read(userProfileProvider.notifier)
                      .resetOnboarding();
                  // Navigate to home/path
                },
                onExport: () => _launchURL('$baseUrl/api/user/export'),
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: "Account"),
              _AccountSection(
                onLogout: () => ref.read(authProvider.notifier).logout(),
              ),

              const SizedBox(height: 40),
            ]),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerWidget {
  final UserProfile profile;
  const _ProfileForm({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(userProfileProvider.notifier);

    // Prepare languages logic
    final availableLanguages = AppConstants.supportedLanguages;
    final userLanguages = {
      ...profile.languageProfiles.map((lp) => lp.language),
      profile.defaultTargetLanguage,
    }.toList();

    return GlassCard(
      child: Column(
        children: [
          _ReadOnlyRow(label: "Email", value: profile.email),
          const SizedBox(height: 16),

          LiquidDropdown<String>(
            label: "Native Language",
            value: profile.nativeLanguage ?? "english",
            items: availableLanguages.map((l) => l['value']!).toList(),
            onChanged: (val) => notifier.updateInfo(nativeLanguage: val),
          ),
          const SizedBox(height: 16),

          LiquidDropdown<String>(
            label: "Target Language",
            value: profile.defaultTargetLanguage,
            items: userLanguages,
            onChanged: (val) => notifier.updateInfo(targetLanguage: val),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const _AddLanguageDialog(),
                );
              },
              child: const Text(
                "Add Language",
                style: TextStyle(color: LiquidTheme.primaryAccent),
              ),
            ),
          ),

          const SizedBox(height: 8),
          LiquidDropdown<String>(
            label: "Writing Style",
            value: profile.writingStyle ?? "Casual",
            items: AppConstants.writingStyles,
            onChanged: (val) => notifier.updateInfo(writingStyle: val),
          ),
          const SizedBox(height: 16),
          LiquidDropdown<String>(
            label: "Writing Purpose",
            value: profile.writingPurpose ?? "Personal",
            items: AppConstants.writingPurposes,
            onChanged: (val) => notifier.updateInfo(writingPurpose: val),
          ),
          const SizedBox(height: 16),
          LiquidDropdown<String>(
            label: "Proficiency",
            value: profile.selfAssessedLevel ?? "Beginner",
            items: AppConstants.proficiencyLevels,
            onChanged: (val) => notifier.updateInfo(selfAssessedLevel: val),
          ),
        ],
      ),
    );
  }
}

class _GoalsForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _GoalsForm({required this.profile});

  @override
  ConsumerState<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends ConsumerState<_GoalsForm> {
  late TextEditingController _dailyGoalController;
  late TextEditingController _maxNewController;
  late TextEditingController _maxReviewController;
  int _weeklyActivities = 3;

  @override
  void initState() {
    super.initState();
    final g = widget.profile.goals;
    _weeklyActivities = g?.weeklyActivities ?? 3;
    _dailyGoalController = TextEditingController(
      text: (g?.dailyStudyGoalInMinutes ?? 15).toString(),
    );
    _maxNewController = TextEditingController(
      text: (g?.maxNewPerDay ?? 20).toString(),
    );
    _maxReviewController = TextEditingController(
      text: (g?.maxReviewsPerDay ?? 50).toString(),
    );
  }

  void _saveGoals() {
    final newGoals = UserGoals(
      weeklyActivities: _weeklyActivities,
      dailyStudyGoalInMinutes: int.tryParse(_dailyGoalController.text) ?? 15,
      maxNewPerDay: int.tryParse(_maxNewController.text) ?? 20,
      maxReviewsPerDay: int.tryParse(_maxReviewController.text) ?? 50,
    );
    ref.read(userProfileProvider.notifier).updateGoals(newGoals);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Goals saved!")));
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiquidDropdown<int>(
            label: "Weekly Activities Goal",
            value: _weeklyActivities,
            items: const [3, 5, 7, 10],
            onChanged: (val) => setState(() => _weeklyActivities = val!),
          ),
          const SizedBox(height: 16),
          GlassInput(
            controller: _dailyGoalController,
            hint: "Daily Study Goal (mins)",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GlassInput(
                  controller: _maxNewController,
                  hint: "Max New Cards",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassInput(
                  controller: _maxReviewController,
                  hint: "Max Reviews",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LiquidButton(text: "Save Goals", onTap: _saveGoals),
        ],
      ),
    );
  }
}

class _SubscriptionSection extends ConsumerWidget {
  final UserProfile profile;
  final Function(String) onManage;
  const _SubscriptionSection({required this.profile, required this.onManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = profile.subscriptionTier != "FREE";
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Plan: ${profile.subscriptionTier}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (isPro) ...[
            Text(
              "Status: ${profile.subscriptionStatus}",
              style: const TextStyle(color: Colors.white70),
            ),
            if (profile.subscriptionPeriodEnd != null)
              Text(
                "Renews: ${profile.subscriptionPeriodEnd.toString().split(' ')[0]}",
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 16),
            LiquidButton(
              text: "Manage Subscription",
              onTap: () async {
                final url = await ref
                    .read(userProfileProvider.notifier)
                    .getManageSubscriptionUrl();
                if (url != null) onManage(url);
              },
            ),
          ] else ...[
            const Text(
              "Upgrade to Pro for unlimited features.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            LiquidButton(
              text: "Upgrade Now",
              onTap: () {
                /* Nav to pricing */
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onExport;
  const _DataSection({required this.onReset, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          _ActionRow(
            label: "Export My Data",
            icon: Icons.download,
            onTap: onExport,
          ),
          const Divider(color: Colors.white10),
          _ActionRow(
            label: "Restart Onboarding",
            icon: Icons.refresh,
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final VoidCallback onLogout;
  const _AccountSection({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          _ActionRow(label: "Log Out", icon: Icons.logout, onTap: onLogout),
          const Divider(color: Colors.white10),
          _ActionRow(
            label: "Delete Account",
            icon: Icons.delete_forever,
            color: Colors.redAccent,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.white70),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AddLanguageDialog extends ConsumerStatefulWidget {
  const _AddLanguageDialog();
  @override
  ConsumerState<_AddLanguageDialog> createState() => _AddLanguageDialogState();
}

class _AddLanguageDialogState extends ConsumerState<_AddLanguageDialog> {
  String? _selectedLanguage;
  @override
  Widget build(BuildContext context) {
    final profile = ref.read(userProfileProvider).value!;
    final existingLangs = {
      ...profile.languageProfiles.map((lp) => lp.language),
      if (profile.defaultTargetLanguage.isNotEmpty)
        profile.defaultTargetLanguage,
    };
    final availableToAdd = AppConstants.supportedLanguages
        .where((l) => !existingLangs.contains(l['value']))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Add New Language",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            if (availableToAdd.isEmpty)
              const Text(
                "All languages added!",
                style: TextStyle(color: Colors.white54),
              )
            else
              LiquidDropdown<String>(
                label: "Select Language",
                value: _selectedLanguage ?? availableToAdd.first['value']!,
                items: availableToAdd.map((l) => l['value']!).toList(),
                onChanged: (val) => setState(() => _selectedLanguage = val),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                LiquidButton(
                  text: "Add",
                  onTap: () {
                    if (_selectedLanguage != null) {
                      ref
                          .read(userProfileProvider.notifier)
                          .addLanguage(_selectedLanguage!);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            )
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
      setState(() {
        _sourceLang = profile?.nativeLanguage ?? "English";
        _targetLang = profile?.defaultTargetLanguage ?? "Spanish";
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

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

    // Helper to build the left column (Input & Main Translation)
    Widget buildMainContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language Selectors
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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: IconButton(
                  onPressed: _swapLanguages,
                  icon: const Icon(Icons.swap_horiz, color: Colors.white54),
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
          // Input Area
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
                    hintText: "Enter text...",
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
                        icon: const Icon(Icons.close, color: Colors.white38),
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
          const SizedBox(height: 16),
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
          if (state.fullTranslation.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              "TRANSLATION",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
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
          ],
        ],
      );
    }

    // Helper to build the right column (Breakdown)
    Widget buildBreakdownContent() {
      if (state.isBreakingDown) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Colors.white24),
          ),
        );
      }
      if (state.segments.isEmpty) {
        return Center(
          child: Opacity(
            opacity: 0.3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  "Analysis will appear here",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SENTENCE BREAKDOWN",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...state.segments.map(
            (seg) =>
                _SegmentCard(segment: seg, targetLanguage: effectiveTarget),
          ),
        ],
      );
    }

    return GlassScaffold(
      title: 'Translator',
      subtitle: 'Real-time AI analysis',
      body: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: buildMainContent()),
                    const SizedBox(width: 40),
                    Expanded(flex: 4, child: buildBreakdownContent()),
                  ],
                )
              : Column(
                  children: [
                    buildMainContent(),
                    const SizedBox(height: 40),
                    buildBreakdownContent(),
                  ],
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
