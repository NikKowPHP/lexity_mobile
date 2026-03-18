// lib/ui/widgets/liquid_navigation.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LiquidNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const LiquidNavigation({super.key, required this.navigationShell});

  final List<({IconData icon, String label})> _items = const [
    (icon: LucideIcons.map, label: 'Path'),           // Index 0
    (icon: LucideIcons.brainCircuit, label: 'Study'), // Index 1
    (icon: LucideIcons.library, label: 'Library'),    // Index 2
    (icon: LucideIcons.barChart2, label: 'Progress'), // Index 3
    (icon: LucideIcons.user, label: 'Profile'),       // Index 4
    (icon: LucideIcons.languages, label: 'Translator'), // Index 5
   
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

    return isDesktop
        ? _buildSideRail(context, currentIndex)
        : _buildBottomBar(context, currentIndex);
  }

  Widget _buildBottomBar(BuildContext context, int currentIndex) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
        height: 85, // Taller to fit icon + text
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100), // Perfect stadium shape
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: _glassDecoration(),
              child: Row(
                children: _items.asMap().entries.map((entry) {
                  return Expanded(
                    child: _NavItem(
                      icon: entry.value.icon,
                      label: entry.value.label,
                      isActive: currentIndex == entry.key,
                      onTap: () => _onTap(context, entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideRail(BuildContext context, int currentIndex) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 30),
        width: 90, // Widened to accommodate text
        height: 550,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(45),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: _glassDecoration(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _items.asMap().entries.map((entry) {
                  return _NavItem(
                    icon: entry.value.icon,
                    label: entry.value.label,
                    isActive: currentIndex == entry.key,
                    onTap: () => _onTap(context, entry.key),
                    isVertical: true,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.05), // Frost tint
      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5), // Specular rim light
      borderRadius: BorderRadius.circular(100),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isVertical;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent, // Ensures the entire expanded area captures taps
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutExpo,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              // Active state has a soft white glowing fill, matching the "Command" button from the ref
              color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(30), // Pill shape for the active state
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    letterSpacing: -0.2,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
