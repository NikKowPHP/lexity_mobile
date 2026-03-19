import 'package:flutter/material.dart';

import '../../../../theme/liquid_theme.dart';

/// Callback when theme or font size changes
typedef OnSettingsChanged = void Function(String theme, double fontSize);

/// A bottom sheet widget for configuring reader appearance settings.
/// Allows users to select theme (light/dark/sepia) and font size.
class ReaderSettingsSheet extends StatelessWidget {
  final String currentTheme;
  final double currentFontSize;
  final OnSettingsChanged onSettingsChanged;

  const ReaderSettingsSheet({
    super.key,
    required this.currentTheme,
    required this.currentFontSize,
    required this.onSettingsChanged,
  });

  /// Shows the settings bottom sheet.
  static void show({
    required BuildContext context,
    required String currentTheme,
    required double currentFontSize,
    required OnSettingsChanged onSettingsChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ReaderSettingsSheet(
        currentTheme: currentTheme,
        currentFontSize: currentFontSize,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Appearance",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildThemeSelector(context, setModalState),
            const SizedBox(height: 32),
            _buildFontSizeSlider(context, setModalState),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, StateSetter setModalState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['light', 'dark', 'sepia'].map((theme) {
        return GestureDetector(
          onTap: () {
            onSettingsChanged(theme, currentFontSize);
            setModalState(() {});
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme == 'light'
                  ? Colors.white
                  : (theme == 'sepia'
                        ? const Color(0xFFf4ecd8)
                        : const Color(0xFF333333)),
              shape: BoxShape.circle,
              border: Border.all(
                color: currentTheme == theme
                    ? LiquidTheme.primaryAccent
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontSizeSlider(BuildContext context, StateSetter setModalState) {
    return Row(
      children: [
        const Icon(Icons.text_fields, size: 16, color: Colors.white70),
        Expanded(
          child: Slider(
            value: currentFontSize,
            min: 80,
            max: 200,
            activeColor: LiquidTheme.primaryAccent,
            onChanged: (v) {
              onSettingsChanged(currentTheme, v);
              setModalState(() {});
            },
          ),
        ),
        const Icon(Icons.text_fields, size: 24, color: Colors.white70),
      ],
    );
  }
}
