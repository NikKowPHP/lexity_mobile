
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexity_mobile/router/router.dart';
import 'package:lexity_mobile/ui/screens/login_screen.dart';
import 'package:lexity_mobile/ui/screens/placeholder_screens.dart';
import 'package:lexity_mobile/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<AuthService>()])
import 'login_navigation_test.mocks.dart';

void main() {
  testWidgets(
    'LoginScreen redirects to PathScreen on successful login via GoRouter',
    (WidgetTester tester) async {
    final mockAuthService = MockAuthService();
    
    when(mockAuthService.login(any, any)).thenAnswer((_) async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
        ],
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
        ),
      ),
    );

      // Should start at login because not authenticated
      expect(find.byType(LoginScreen), findsOneWidget);

    // Enter text
    await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');

    // Tap login button
    await tester.tap(find.text('Sign In'));
      await tester.pump(); 
    
      // Wait for async operations and redirect
    for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(PathScreen).evaluate().isNotEmpty) {
            break;
        }
    }

    // Verification
      expect(find.byType(PathScreen), findsOneWidget);
  });
}
