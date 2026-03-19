import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/screens/signup_screen_minimal.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    ],
  );
});
