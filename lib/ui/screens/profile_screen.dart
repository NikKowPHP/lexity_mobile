import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_profile.dart';
import '../../theme/liquid_theme.dart';
import '../../utils/constants.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _launchURL(String urlString) async {
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
            child: Center(child: CircularProgressIndicator(color: Colors.white))),
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
              _DataSection(onReset: () async {
                 await ref.read(userProfileProvider.notifier).resetOnboarding();
                },
                onExport: () =>
                    _launchURL('${AppConstants.baseUrl}/api/user/export'),
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: "Account"),
              _AccountSection(onLogout: () => ref.read(authProvider.notifier).logout()),
              
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
      child: Text(title.toUpperCase(), 
        style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
    );
  }
}

class _ProfileForm extends ConsumerWidget {
  final UserProfile profile;
  const _ProfileForm({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(userProfileProvider.notifier);
    
    final availableLanguages = AppConstants.supportedLanguages;
    final userLanguages = {
      ...profile.languageProfiles.map((lp) => lp.language),
      profile.defaultTargetLanguage
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
           
           Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {
             showDialog(context: context, builder: (_) => const _AddLanguageDialog());
           }, child: const Text("Add Language", style: TextStyle(color: LiquidTheme.primaryAccent)))),
           
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
    _dailyGoalController = TextEditingController(text: (g?.dailyStudyGoalInMinutes ?? 15).toString());
    _maxNewController = TextEditingController(text: (g?.maxNewPerDay ?? 20).toString());
    _maxReviewController = TextEditingController(text: (g?.maxReviewsPerDay ?? 50).toString());
  }

  void _saveGoals() {
    final newGoals = UserGoals(
      weeklyActivities: _weeklyActivities,
      dailyStudyGoalInMinutes: int.tryParse(_dailyGoalController.text) ?? 15,
      maxNewPerDay: int.tryParse(_maxNewController.text) ?? 20,
      maxReviewsPerDay: int.tryParse(_maxReviewController.text) ?? 50,
    );
    ref.read(userProfileProvider.notifier).updateGoals(newGoals);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goals saved!")));
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
           GlassInput(controller: _dailyGoalController, hint: "Daily Study Goal (mins)"),
           const SizedBox(height: 16),
           Row(
             children: [
               Expanded(child: GlassInput(controller: _maxNewController, hint: "Max New Cards")),
               const SizedBox(width: 16),
               Expanded(child: GlassInput(controller: _maxReviewController, hint: "Max Reviews")),
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
          Text("Current Plan: ${profile.subscriptionTier}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (isPro) ...[
             Text("Status: ${profile.subscriptionStatus}", style: const TextStyle(color: Colors.white70)),
             if (profile.subscriptionPeriodEnd != null)
               Text("Renews: ${profile.subscriptionPeriodEnd.toString().split(' ')[0]}", style: const TextStyle(color: Colors.white70)),
             const SizedBox(height: 16),
             LiquidButton(text: "Manage Subscription", onTap: () async {
               final url = await ref.read(userProfileProvider.notifier).getManageSubscriptionUrl();
               if (url != null) onManage(url);
             }),
          ] else ...[
             const Text("Upgrade to Pro for unlimited features.", style: TextStyle(color: Colors.white70)),
             const SizedBox(height: 16),
             LiquidButton(text: "Upgrade Now", onTap: () { /* Nav to pricing */ }),
          ]
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
           _ActionRow(label: "Export My Data", icon: Icons.download, onTap: onExport),
           const Divider(color: Colors.white10),
           _ActionRow(label: "Restart Onboarding", icon: Icons.refresh, onTap: onReset),
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
            _ActionRow(label: "Delete Account", icon: Icons.delete_forever, color: Colors.redAccent, onTap: () {}),
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
         Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
  
  const _ActionRow({required this.label, required this.icon, required this.onTap, this.color});
  
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
            Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w500)),
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
      if (profile.defaultTargetLanguage.isNotEmpty) profile.defaultTargetLanguage
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
            const Text("Add New Language", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            if (availableToAdd.isEmpty)
              const Text("All languages added!", style: TextStyle(color: Colors.white54))
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                const SizedBox(width: 8),
                LiquidButton(text: "Add", onTap: () {
                   if (_selectedLanguage != null) {
                     ref.read(userProfileProvider.notifier).addLanguage(_selectedLanguage!);
                     Navigator.pop(context);
                   }
                }).animate(target: _selectedLanguage != null ? 1 : 0.5),
              ],
            )
          ],
        ),
      ),
    );
  }
}
