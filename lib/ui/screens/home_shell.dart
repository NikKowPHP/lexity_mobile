// lib/ui/screens/home_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/liquid_components.dart';
import '../widgets/liquid_navigation.dart';
import '../../providers/connectivity_provider.dart';

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

            // Offline banner
            Consumer(
              builder: (context, ref, _) {
                final isOnline = ref.watch(connectivityProvider);
                if (isOnline) return const SizedBox.shrink();
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: const SafeArea(
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "Offline mode. Changes will sync when reconnected.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Pass the shell to the navigation widget to control switching
            LiquidNavigation(navigationShell: navigationShell),
          ],
        ),
      ),
    );
  }
}
