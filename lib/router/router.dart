// lib/router/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/home_shell.dart';
import '../ui/screens/path_screen.dart';
import '../ui/screens/study_screen.dart';
import '../ui/screens/journal_screen.dart';
import '../ui/screens/progress_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/translator_screen.dart';

// 1. Create a Key for the root navigator
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/path', // Default tab
    debugLogDiagnostics: true,
    
    // Refresh the router when auth state changes
    refreshListenable: _RiverpodRouterRefreshStream(ref),
    
    // 3. AUTO-REDIRECT LOGIC
    redirect: (context, state) {
      // If we haven't finished checking the disk yet, stay on current page
      if (!authState.isInitialized) return null;

      final isLoggedIn = authState.isAuthenticated;
      final path = state.uri.toString();
      
      // Allow the bubble route and login route even if not logged in
      if (!isLoggedIn && path != '/login' && path != '/bubble-translator') {
        return '/login';
      }
      
      if (isLoggedIn && (path == '/login')) {
        return '/path';
      }
      return null;
    },

    routes: [
      // LOGIN ROUTE
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // standalone STANDALONE ROUTE for the Bubble
      // This is OUTSIDE the StatefulShellRoute so it won't have the Bottom Bar
      GoRoute(
        path: '/bubble-translator',
        builder: (context, state) => const TranslatorScreen(isBubbleMode: true),
      ),

      // APPLICATION SHELL (The Liquid UI)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Learn/Path
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/path',
                pageBuilder: (context, state) => _buildFadePage(const PathScreen(), state),
              ),
            ],
          ),
          // Branch 1: Study
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                pageBuilder: (context, state) => _buildFadePage(const StudyScreen(), state),
              ),
            ],
          ),
          // Branch 2: Journal
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journal',
                pageBuilder: (context, state) => _buildFadePage(const JournalScreen(), state),
              ),
            ],
          ),
          // Branch 3: Progress
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                pageBuilder: (context, state) => _buildFadePage(const ProgressScreen(), state),
              ),
            ],
          ),
          // Branch 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => _buildFadePage(const ProfileScreen(), state),
              ),
            ],
          ),
          // Branch 5: Translator
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/translator',
                pageBuilder: (context, state) =>
                    _buildFadePage(const TranslatorScreen(), state),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Helper for sleek 2026 transitions
CustomTransitionPage _buildFadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

// This allows GoRouter to rebuild whenever the AuthState changes
class _RiverpodRouterRefreshStream extends ChangeNotifier {
  _RiverpodRouterRefreshStream(Ref ref) {
    _subscribe(ref);
  }

  void _subscribe(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}
