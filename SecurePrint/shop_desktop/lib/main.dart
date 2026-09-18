import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/app_shell.dart';
import 'features/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/print_jobs_provider.dart';
import 'providers/document_access_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/print_execution_provider.dart';
import 'providers/shop_qr_provider.dart';
import 'providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Top-level Error Handling Boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    Logger.error('Flutter Framework Error', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.error('Uncaught Async Error', error, stack);
    return true; // Prevent default crash behavior
  };

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => PrintJobsProvider()),
        ChangeNotifierProvider(create: (_) => DocumentAccessProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => PrintExecutionProvider()),
        ChangeNotifierProvider(create: (_) => ShopQrProvider()),
      ],
      child: const SecurePrintShopApp(),
    ),
  );
}

class SecurePrintShopApp extends StatelessWidget {
  const SecurePrintShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecurePrint Shop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    "Something went wrong.",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "The application encountered an unexpected error.\nPlease navigate back or restart.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.state == AuthState.uninitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isAuthenticated) {
            return const AppShell();
          }
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
