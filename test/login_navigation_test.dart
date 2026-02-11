
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexity_mobile/providers/auth_provider.dart';
import 'package:lexity_mobile/ui/screens/home_screen.dart';
import 'package:lexity_mobile/ui/screens/login_screen.dart';
import 'package:lexity_mobile/services/auth_service.dart'; // Import AuthService
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart'; // Add annotations import

// Generate mocks
@GenerateNiceMocks([MockSpec<AuthService>()])
import 'login_navigation_test.mocks.dart';

void main() {
  testWidgets('LoginScreen navigates to HomeScreen on successful login', (WidgetTester tester) async {
    // mock auth service
    final mockAuthService = MockAuthService();
    
    // Setup the mock to return success
    when(mockAuthService.login(any, any)).thenAnswer((_) async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
        ],
        child: MaterialApp(
          home: const LoginScreen(),
        ),
      ),
    );

    // Enter text
    await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');

    // Tap login button
    await tester.tap(find.text('Sign In'));
    await tester.pump(); // Start animation
    
    // We expect the state to change. 
    // However, since we are mocking the service, the Notifier usually calls the service.
    // The real AuthNotifier calls the service. 
    // We need to ensure AuthNotifier is using our mock service. 
    // The provider override above does that.
    
    // Wait for async operations
    await tester.pump(const Duration(milliseconds: 100)); 

    // The listener in LoginScreen should trigger navigation.
    // Since we are in a test environment with a root MaterialApp, pushing a new route should be verifying by checking if HomeScreen is present.
    
    // NOTE: The real AuthNotifier updates state. 
    // If the mockAuthService.login returns, AuthNotifier updates state to isAuthenticated = true.
    // The listener checks next.isAuthenticated.
    
    // However, the AuthNotifier in the real code catches exceptions.
    // We need to make sure the mock doesn't throw. It returns Future<bool>. 
    
    // Wait for async operations and navigation
    // pumpAndSettle times out due to infinite animations in LiquidBackground
    // So we manually pump frames until we see the HomeScreen or timeout
    for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(HomeScreen).evaluate().isNotEmpty) {
            break;
        }
    }

    // Verification
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
