import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/user_profile.dart';
import '../../../../providers/user_provider.dart';
import '../../../../theme/liquid_theme.dart';
import '../../../../utils/constants.dart';
import '../../../widgets/liquid_components.dart';

class ProfileForm extends ConsumerWidget {
  final UserProfile profile;
  const ProfileForm({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(userProfileProvider.notifier);

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
            ),
          ],
        ),
      ),
    );
  }
}
