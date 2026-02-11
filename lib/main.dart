// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/liquid_theme.dart';
import 'ui/screens/login_screen.dart';

void main() {
  // Make status bar transparent to let the liquid background shine through
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lexity Mobile',
      debugShowCheckedModeBanner: false,
      theme: LiquidTheme.theme,
      home: const LoginScreen(),
    );
  }
}
