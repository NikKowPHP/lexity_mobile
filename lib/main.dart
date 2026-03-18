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
import 'services/logger_service.dart';
import 'database/app_database.dart';
import 'providers/vocabulary_provider.dart';

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
  bool _startedInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _startedInBackground =
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).checkAuthStatus();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_startedInBackground) {
          _preloadLocalData();
        } else {
          ref.read(syncServiceProvider).syncPendingMutations();
          ref.read(hydrationServiceProvider).performFullSync();
        }
      });
    }
  }

  Future<void> _preloadLocalData() async {
    final db = ref.read(databaseProvider);
    final logger = ref.read(loggerProvider);

    logger.info('Preloading local data for background start...');

    try {
      final vocabLanguages = await db.getVocabularyLanguages();
      logger.info('Found ${vocabLanguages.length} languages with vocabulary');

      await ref
          .read(vocabularyProvider.notifier)
          .preloadVocabularyForLanguages(vocabLanguages);

      logger.info(
        'Vocabulary preloaded for ${vocabLanguages.length} languages',
      );
    } catch (e, st) {
      logger.error('Failed to preload vocabulary', e, st);
    }

    ref.read(syncServiceProvider).syncPendingMutations();
    _startedInBackground = false;
    logger.info('Local data preload complete, sync started');
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
