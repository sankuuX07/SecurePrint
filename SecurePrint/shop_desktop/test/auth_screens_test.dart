import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shop_desktop/core/config/app_config.dart';
import 'package:shop_desktop/features/auth/login_screen.dart';
import 'package:shop_desktop/features/auth/sign_up_screen.dart';
import 'package:shop_desktop/providers/auth_provider.dart';
import 'package:shop_desktop/services/auth_service_interface.dart';
import 'package:shop_desktop/models/user_model.dart';
import 'local_auth_test.dart';

class MockTestAuthService implements IAuthService {
  final Map<String, String> registeredUsers = {};

  @override
  Future<AuthResult> login(String email, String password) async {
    if (registeredUsers[email] == password) {
      return AuthResult(
        token: 'test_token',
        role: 'SHOP',
        isLocal: true,
        user: UserModel(
          id: 1,
          name: 'Test Owner',
          email: email,
          phone: '1234567890',
          role: 'SHOP',
          shopName: 'Test Shop',
        ),
      );
    }
    throw Exception('Incorrect email or password.');
  }

  @override
  Future<void> register(ShopRegistrationData data) async {
    registeredUsers[data.email] = data.password;
  }
}

Widget createTestApp({required AuthProvider authProvider, Widget? child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      home: child ?? const LoginScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.authMode = AuthenticationMode.localDevelopment;
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('LoginScreen displays branding, Welcome Back, fields, options and Sign Up link', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Check Branding & Headers
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to your shop account'), findsOneWidget);

      // Check Mode Badge
      expect(find.text('Local Development Mode (Offline)'), findsOneWidget);

      // Check Input Fields
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);

      // Check Visibility Toggle
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Check Checkboxes
      expect(find.text('Remember email'), findsOneWidget);
      expect(find.text('Stay signed in'), findsOneWidget);

      // Check Buttons & Links
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);

      // Verify no permanent server error is displayed
      expect(find.text('Unable to connect to SecurePrint server.'), findsNothing);
    });

    testWidgets('Empty fields show field-specific validation errors', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Click Sign In without entering anything
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('Invalid email format shows validation error', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(authProvider: authProvider));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'invalid-email');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'Password123!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Tapping Sign Up opens SignUpScreen and back returns to LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Tap Sign Up link
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Verify SignUpScreen is displayed
      expect(find.text('Create Shop Account'), findsOneWidget);
      expect(find.text('Register a local test account for development'), findsOneWidget);

      // Tap Back to Sign In
      final signInLink = find.widgetWithText(TextButton, 'Sign In');
      await tester.ensureVisible(signInLink);
      await tester.tap(signInLink);
      await tester.pumpAndSettle();

      // Back at LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });

  group('SignUpScreen Widget Tests', () {
    testWidgets('SignUpScreen displays all 8 fields and disclaimers', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(
        authProvider: authProvider,
        child: const SignUpScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Owner / Full Name *'), findsOneWidget);
      expect(find.text('Shop Name *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Phone Number *'), findsOneWidget);
      expect(find.text('Password *'), findsOneWidget);
      expect(find.text('Confirm Password *'), findsOneWidget);
      expect(find.text('Shop Address *'), findsOneWidget);
      expect(find.text('City *'), findsOneWidget);

      expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
    });

    testWidgets('SignUp validation detects empty fields', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(
        authProvider: authProvider,
        child: const SignUpScreen(),
      ));
      await tester.pumpAndSettle();

      final createAccountBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Owner name is required.'), findsOneWidget);
      expect(find.text('Shop name is required.'), findsOneWidget);
      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Phone number is required.'), findsOneWidget);
    });

    testWidgets('SignUp validation detects password mismatch', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockTestAuthService();
      final authProvider = AuthProvider(
        authService: mockAuth,
        secureStorage: InMemorySecureStorage(),
      );

      await tester.pumpWidget(createTestApp(
        authProvider: authProvider,
        child: const SignUpScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Owner / Full Name *'), 'John');
      await tester.enterText(find.widgetWithText(TextFormField, 'Shop Name *'), 'John Prints');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address *'), 'john@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number *'), '1234567890');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password *'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password *'), 'DifferentPassword123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Shop Address *'), '123 Street');
      await tester.enterText(find.widgetWithText(TextFormField, 'City *'), 'City');

      final createAccountBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });
}
