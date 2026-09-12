import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/app_shell.dart';
import 'features/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/print_jobs_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => PrintJobsProvider()),
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
