// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'router/router.dart';
import 'theme/liquid_theme.dart';
import 'ui/widgets/liquid_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';
import 'services/sync_service.dart';
import 'services/hydration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    if (Platform.isWindows) {
      try {
        await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: 'inappwebviewdata',
          ),
        );
      } catch (e) {
        debugPrint("Error initializing WebView2: $e");
      }
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check auth status first to validate/refresh token before other providers fetch data
      ref.read(authProvider.notifier).checkAuthStatus();

      // Delay other sync operations to allow auth check to complete first
      Future.delayed(const Duration(milliseconds: 100), () {
        ref.read(syncServiceProvider).syncPendingMutations();
        ref.read(hydrationServiceProvider).performFullSync();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final router = ref.watch(routerProvider);

    // If not initialized, show a Glass loading screen
    if (!authState.isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LiquidTheme.darkTheme,
        home: Scaffold(
          body: LiquidBackground(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Lexity Mobile',
      debugShowCheckedModeBanner: false,
      theme: LiquidTheme.lightTheme,
      darkTheme: LiquidTheme.darkTheme,
      themeMode: ref.watch(themeProvider),
      routerConfig: router,
    );
  }
}
