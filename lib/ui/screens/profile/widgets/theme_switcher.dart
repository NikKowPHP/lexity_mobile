import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../theme/liquid_theme.dart';
import '../../../widgets/liquid_components.dart';

class ProfileThemeSwitcher extends ConsumerWidget {
  const ProfileThemeSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildThemeOption(
                  ref,
                  "Light",
                  ThemeMode.light,
                  currentMode == ThemeMode.light,
                  isDark,
                ),
                _buildThemeOption(
                  ref,
                  "Dark",
                  ThemeMode.dark,
                  currentMode == ThemeMode.dark,
                  isDark,
                ),
                _buildThemeOption(
                  ref,
                  "System",
                  ThemeMode.system,
                  currentMode == ThemeMode.system,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    WidgetRef ref,
    String label,
    ThemeMode mode,
    bool isActive,
    bool isDark,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? LiquidTheme.primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white38 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
