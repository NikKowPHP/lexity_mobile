import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/constants.dart';
import '../widgets/glass_scaffold.dart';
import 'profile/widgets/section_header.dart';
import 'profile/widgets/theme_switcher.dart';
import 'profile/widgets/profile_form.dart';
import 'profile/widgets/goals_form.dart';
import 'profile/widgets/subscription_section.dart';
import 'profile/widgets/data_section.dart';
import 'profile/widgets/account_section.dart';
import 'profile/widgets/sync_status_section.dart';

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
      showBackButton: true,
      body: profileAsync.when(
        loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => SliverToBoxAdapter(child: Text("Error: $e")),
        data: (profile) {
          return SliverList(
            delegate: SliverChildListDelegate([
              const ProfileSectionHeader(title: "Appearance"),
              const ProfileThemeSwitcher(),

              const SizedBox(height: 24),
              const ProfileSectionHeader(title: "Profile"),
              ProfileForm(profile: profile),

              const SizedBox(height: 24),
              const ProfileSectionHeader(title: "Goals"),
              GoalsForm(profile: profile),

              const SizedBox(height: 24),
              const ProfileSectionHeader(title: "Subscription"),
              ProfileSubscriptionSection(
                profile: profile,
                onManage: _launchURL,
              ),

              const SizedBox(height: 24),
              const ProfileSectionHeader(title: "Data & Onboarding"),
              ProfileDataSection(
                onReset: () async {
                  await ref
                      .read(userProfileProvider.notifier)
                      .resetOnboarding();
                },
                onExport: () =>
                    _launchURL('${AppConstants.baseUrl}/api/user/export'),
              ),

              const SizedBox(height: 24),
              const ProfileSectionHeader(title: "Sync Status"),
              const ProfileSyncStatusSection(),

              const SizedBox(height: 24),
              const ProfileSectionHeader(title: "Account"),
              ProfileAccountSection(
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
