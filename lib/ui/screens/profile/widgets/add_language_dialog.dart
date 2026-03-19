import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lexity_mobile/providers/user_provider.dart';
import 'package:lexity_mobile/utils/constants.dart';
import 'package:lexity_mobile/ui/widgets/liquid_components.dart';

class ProfileReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;
  const ProfileReadOnlyRow({required this.label, required this.value});

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

class ProfileActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const ProfileActionRow({
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

class AddLanguageDialog extends ConsumerStatefulWidget {
  const AddLanguageDialog();
  @override
  ConsumerState<AddLanguageDialog> createState() => AddLanguageDialogState();
}

class AddLanguageDialogState extends ConsumerState<AddLanguageDialog> {
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
                ).animate(target: _selectedLanguage != null ? 1 : 0.5),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
