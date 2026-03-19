// lib/router/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/signup_screen.dart';
import '../ui/screens/forgot_password_screen.dart';
import '../ui/screens/onboarding_wizard_screen.dart';
import '../ui/screens/home_shell.dart';
import '../ui/screens/path_screen.dart';
import '../ui/screens/study_screen.dart';

import '../ui/screens/progress_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/translator_screen.dart';
import '../ui/screens/journal_editor_screen.dart';
import '../ui/screens/journal_detail_screen.dart';
import '../ui/screens/module_detail_screen.dart';
import '../ui/screens/drill_screen.dart';
import '../ui/screens/study_material_screen.dart';
import '../ui/screens/reading_screen.dart';
import '../ui/screens/listening_screen.dart';
import '../ui/screens/library_screen.dart';
import '../ui/screens/book_reader_screen.dart';
import '../ui/screens/vocabulary_screen.dart';
import '../ui/screens/srs_items_screen.dart';
import '../ui/screens/more_screen.dart';

// 1. Create a Key for the root navigator
final _rootNavigatorKey = GlobalKey<NavigatorState>();

Widget _buildSignupScreen(BuildContext context, GoRouterState state) {
  // ignore: invalid_use_of_visible_for_testing_member
  return const SignupScreen();
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/path', // Default tab
    debugLogDiagnostics: true,

    // Refresh the router when auth state changes
    refreshListenable: _RiverpodRouterRefreshStream(ref),

    // 3. AUTO-REDIRECT LOGIC
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // If we haven't finished checking the disk yet, stay on current page
      if (!authState.isInitialized) return null;

      final isLoggedIn = authState.isAuthenticated;
      final path = state.uri.toString();

      // Allow public auth routes even if not logged in
      final publicRoutes = [
        '/login',
        '/signup',
        '/forgot-password',
        '/bubble-translator',
      ];
      if (!isLoggedIn && !publicRoutes.contains(path)) {
        return '/login';
      }

      if (isLoggedIn && (path == '/login' || path == '/signup')) {
        return '/path';
      }
      return null;
    },

    routes: [
      // LOGIN ROUTE
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => SignupScreen.new()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/billing-complete',
        builder: (context, state) {
          // This route is triggered by lexity://billing-complete
          // We don't need a UI here, just a trigger to refresh and redirect
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(userProfileProvider.notifier).refresh();
            context.go('/path');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Subscription updated successfully!"),
              ),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        },
      ),
      GoRoute(
        path: '/vocabulary',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VocabularyScreen(),
      ),
      GoRoute(
        path: '/srs-items',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SrsItemsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWizardScreen(),
      ),

      // standalone STANDALONE ROUTE for the Bubble
      // This is OUTSIDE the StatefulShellRoute so it won't have the Bottom Bar
      GoRoute(
        path: '/bubble-translator',
        builder: (context, state) => const TranslatorScreen(isBubbleMode: true),
      ),

      // STANDALONE JOURNAL ROUTES (Needed by modules but removed from main nav)
      GoRoute(
        path: '/journal/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => JournalEditorScreen(
          moduleId: state.uri.queryParameters['moduleId'],
          initialMode: state.uri.queryParameters['mode'],
          initialTopic: state.uri.queryParameters['topic'],
          initialImageUrl: state.uri.queryParameters['imageUrl'],
        ),
      ),
      GoRoute(
        path: '/journal/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            JournalDetailScreen(journalId: state.pathParameters['id']!),
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
                pageBuilder: (context, state) =>
                    _buildFadePage(const PathScreen(), state),
                routes: [
                  // NEW: Module Detail Route
                  GoRoute(
                    path: 'module/:moduleId',
                    parentNavigatorKey: _rootNavigatorKey, // Hide bottom nav
                    builder: (context, state) => ModuleDetailScreen(
                      moduleId: state.pathParameters['moduleId']!,
                    ),
                  ),
                  // NEW: Drill Route
                  GoRoute(
                    path: 'drill/:moduleId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => DrillScreen(
                      moduleId: state.pathParameters['moduleId']!,
                    ),
                  ),
                  // NEW: Study Material Route (Reading/Listening)
                  GoRoute(
                    path: 'material',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => StudyMaterialScreen(
                      moduleId: state.uri.queryParameters['moduleId'] ?? '',
                      mode: state.uri.queryParameters['mode'] ?? 'reading',
                      title:
                          state.uri.queryParameters['title'] ??
                          'Study Material',
                      content: state.uri.queryParameters['content'] ?? '',
                    ),
                  ),
                  // NEW: Reading Screen Route
                  GoRoute(
                    path: 'read',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ReadingScreen(
                      moduleId: state.uri.queryParameters['moduleId'],
                    ),
                  ),
                  // NEW: Listening Screen Route
                  GoRoute(
                    path: 'listen',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ListeningScreen(
                      moduleId: state.uri.queryParameters['moduleId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1: Study
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                pageBuilder: (context, state) =>
                    _buildFadePage(const StudyScreen(), state),
              ),
            ],
          ),
          // Branch 2: Library
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    _buildFadePage(const LibraryScreen(), state),
                routes: [
                  GoRoute(
                    path: 'book/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final progressStr =
                          state.uri.queryParameters['progress'] ?? '0.0';
                      final progress = double.tryParse(progressStr) ?? 0.0;
                      return BookReaderScreen(
                        bookId: id,
                        initialProgress: progress,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 3: Translator
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/translator',
                pageBuilder: (context, state) =>
                    _buildFadePage(const TranslatorScreen(), state),
              ),
            ],
          ),
          // Branch 4: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                pageBuilder: (context, state) =>
                    _buildFadePage(const MoreScreen(), state),
              ),
            ],
          ),
          // Branch 5: Progress (hidden in nav, accessed via More)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                pageBuilder: (context, state) =>
                    _buildFadePage(const ProgressScreen(), state),
              ),
            ],
          ),
          // Branch 6: Profile (hidden in nav, accessed via More)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    _buildFadePage(const ProfileScreen(), state),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Helper for iOS-style transitions
CustomTransitionPage _buildFadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: ValueKey(state.uri.toString()),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 300),
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
