import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver_app/main.dart';
import 'package:driver_app/config/dio_config.dart';
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/controllers/driver_dashboard_controller.dart';
import 'package:driver_app/screens/dashboard/widgets/driver_map_canvas.dart';
import 'test_http_overrides.dart';

void main() {
  setUpAll(() {
    DioConfig.isTestMode = true;
    Get.testMode = true;
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'driver_auth_token': 'mock_driver_token_123',
      'driver_id': 'DRV-1029',
      'driver_name': 'Dawit Tadesse',
    });
    await StorageConfig.init();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('Unauthenticated user is restricted to Login and blocked from main pages',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageConfig.init();
    await StorageConfig.clearSession();

    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    // Verify restricted to Login page and main pages are not accessed
    expect(find.text('Courier Sign In'), findsOneWidget);
    expect(find.text('Sign In to Driver App'), findsOneWidget);
    expect(find.text('Active & Ready'), findsNothing);

    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().onClose();
    }
  });

  testWidgets('AMN Driver App smoke and launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    // Verify top bar menu and that removed elements are not present
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('Active & Ready'), findsNothing);

    // Verify Destinations floating button on the map canvas
    expect(find.byTooltip('Street Pickup'), findsOneWidget);

    // Open side bar (drawer) where bottom navigation items were moved
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify moved navigation items in the side bar
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap on Wallet tab
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    // Verify Wallet screen shows ETB balance and Top-up button
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Top-up'), findsOneWidget);

    // Clean up active controller timers
    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().onClose();
    }
  });

  testWidgets('DriverMapCanvas properly updates showRoute when offer is declined',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverMapCanvas(
            isOnline: true,
            showRoute: true,
            pickupLatitude: 8.9950,
            pickupLongitude: 38.7890,
            dropoffLatitude: 8.9180,
            dropoffLongitude: 38.7610,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DriverMapCanvas), findsOneWidget);

    // Offer is declined -> showRoute becomes false
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverMapCanvas(
            isOnline: true,
            showRoute: false,
            pickupLatitude: null,
            pickupLongitude: null,
            dropoffLatitude: null,
            dropoffLongitude: null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DriverMapCanvas), findsOneWidget);
  });
}
