// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'providers/auth_provider.dart';
import 'router/router.dart';
import 'theme/liquid_theme.dart';
import 'ui/widgets/liquid_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    if (Platform.isWindows) {
      try {
        await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(userDataFolder: 'inappwebviewdata')
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final router = ref.watch(routerProvider);

    // If not initialized, show a Glass loading screen
    if (!authState.isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LiquidTheme.theme,
        home: const Scaffold(
          body: LiquidBackground(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Lexity Mobile',
      debugShowCheckedModeBanner: false,
      theme: LiquidTheme.theme,
      routerConfig: router,
    );
  }
}
