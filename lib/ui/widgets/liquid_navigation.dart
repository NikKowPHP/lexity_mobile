// lib/ui/widgets/liquid_navigation.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LiquidNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const LiquidNavigation({super.key, required this.navigationShell});

  final List<({IconData icon, String label})> _mainItems = const [
    (icon: LucideIcons.map, label: 'Path'),
    (icon: LucideIcons.brainCircuit, label: 'Study'),
    (icon: LucideIcons.library, label: 'Library'),
    (icon: LucideIcons.languages, label: 'Translator'),
  ];

  void _onTap(BuildContext context, int index) {
    if (index < navigationShell.route.branches.length) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return isDesktop
        ? _buildSideRail(context, currentIndex, isDark)
        : _buildBottomBar(context, currentIndex, isDark);
  }

  Widget _buildBottomBar(BuildContext context, int currentIndex, bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 34, left: 20, right: 20),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45), // Increased blur
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: _glassDecoration(isDark),
              child: Row(
                children: [
                  ..._mainItems.asMap().entries.map((entry) {
                    return Expanded(
                      child: _NavItem(
                        icon: entry.value.icon,
                        label: entry.value.label,
                        isActive: currentIndex == entry.key,
                        onTap: () => _onTap(context, entry.key),
                        isDark: isDark,
                      ),
                    );
                  }),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.more_horiz,
                      label: 'More',
                      isActive: currentIndex == 4,
                      onTap: () => _onTap(context, 4),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideRail(BuildContext context, int currentIndex, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 30),
        width: 90,
        height: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(45),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 30,
              offset: const Offset(10, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(45),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: _glassDecoration(isDark),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ..._mainItems.asMap().entries.map((entry) {
                    return _NavItem(
                      icon: entry.value.icon,
                      label: entry.value.label,
                      isActive: currentIndex == entry.key,
                      onTap: () => _onTap(context, entry.key),
                      isVertical: true,
                      isDark: isDark,
                    );
                  }),
                  _NavItem(
                    icon: Icons.more_horiz,
                    label: 'More',
                    isActive: currentIndex == 4,
                    onTap: () => _onTap(context, 4),
                    isVertical: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.white.withOpacity(
              0.6,
            ), // Brighter in light mode for contrast
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.8), // Vibrant rim light
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(40),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)]
            : [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.1)],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isVertical;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isVertical = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: Active items use primary accent, inactive use theme-aware grey/white
    final activeColor = Theme.of(context).primaryColor;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.5)
        : Colors.black45;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutExpo,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.5))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
