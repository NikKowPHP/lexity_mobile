// lib/ui/screens/home_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/liquid_components.dart';
import '../widgets/liquid_navigation.dart';

class HomeShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: LiquidBackground(
        child: Stack(
          children: [
            // The active branch (page) content
            navigationShell,

            // Pass the shell to the navigation widget to control switching
            LiquidNavigation(navigationShell: navigationShell),
          ],
        ),
      ),
    );
  }
}
