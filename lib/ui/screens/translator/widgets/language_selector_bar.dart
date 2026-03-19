import 'package:flutter/material.dart';
import '../../../widgets/liquid_components.dart';

/// Language selector bar with source/target dropdowns and swap button.
class LanguageSelectorBar extends StatelessWidget {
  final String? sourceLang;
  final String? targetLang;
  final List<String> availableLanguages;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onTargetChanged;
  final VoidCallback onSwap;

  const LanguageSelectorBar({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.availableLanguages,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LiquidDropdown<String>(
            label: "From",
            value: sourceLang ?? '',
            items: availableLanguages,
            onChanged: onSourceChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IconButton(
            onPressed: onSwap,
            icon: const Icon(Icons.swap_horiz, color: Colors.white54),
          ),
        ),
        Expanded(
          child: LiquidDropdown<String>(
            label: "To",
            value: targetLang ?? '',
            items: availableLanguages,
            onChanged: onTargetChanged,
          ),
        ),
      ],
    );
  }
}
