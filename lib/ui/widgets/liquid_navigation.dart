// lib/ui/widgets/liquid_navigation.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/liquid_theme.dart';

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
    (icon: LucideIcons.bookMarked, label: 'Vocab'),    // Index 6
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
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
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        height: 70,
        decoration: _glassDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _items.asMap().entries.map((entry) {
                return _NavItem(
                  icon: entry.value.icon,
                  label: entry.value.label,
                  isActive: currentIndex == entry.key,
                  onTap: () => _onTap(entry.key),
                );
              }).toList(),
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
        width: 80,
        height: 500,
        decoration: _glassDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _items.asMap().entries.map((entry) {
                return _NavItem(
                  icon: entry.value.icon,
                  label: entry.value.label,
                  isActive: currentIndex == entry.key,
                  onTap: () => _onTap(entry.key),
                  isVertical: true,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.all(12),
        decoration: isActive
            ? BoxDecoration(
                color: LiquidTheme.primaryAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: LiquidTheme.primaryAccent.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: -2,
                  )
                ],
              )
            : const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
          size: 24,
        ),
      ),
    );
  }
}
