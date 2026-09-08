import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop_desktop/main.dart';
import 'package:shop_desktop/core/config/app_config.dart';

void main() {
  testWidgets('App Shell loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SecurePrintShopApp());

    // Verify title and basic branding
    expect(find.text('SecurePrint Shop'), findsWidgets);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Print Jobs'), findsOneWidget);
    
    // Check configuration loaded correctly
    expect(AppConfig.version, '1.0.0');
    expect(AppConfig.currentEnvironment, Environment.development);
  });
}
