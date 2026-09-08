import 'package:flutter/material.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const SecurePrintShopApp());
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
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
