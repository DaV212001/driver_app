import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driver_app/main.dart';
import 'package:driver_app/config/dio_config.dart';
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/screens/dashboard/widgets/map_location_picker.dart';
import 'package:driver_app/screens/dashboard/widgets/street_pickup_bottom_sheet.dart';
import 'test_http_overrides.dart';

void main() {
  setUp(() async {
    DioConfig.isTestMode = true;
    Get.testMode = true;
    HttpOverrides.global = TestHttpOverrides();
    SharedPreferences.setMockInitialValues({
      'driver_auth_token': 'mock_token_abc',
      'driver_id': 'DRV-1029',
      'driver_name': 'Dawit Tadesse',
      'driver_is_online': true,
      'location_disclosure_agreed': true,
      'location_prominent_disclosure_agreed': true,
    });
    await StorageConfig.init();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('1. Bottom navigation bar items are moved to sidebar and bottom bar is removed',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    // Verify BottomNavigationBar is NOT present on Scaffold
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNull);

    // Verify Destinations / Street Pickup floating button IS present on the map canvas
    expect(find.byTooltip('Street Pickup'), findsOneWidget);

    // Open side bar (drawer)
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify moved items exist in the side bar
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Trip history'), findsOneWidget);

    // Destinations should NOT be in the sidebar drawer
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Destinations')),
      findsNothing,
    );
  });

  testWidgets('2. Destinations floating button opens street pickup bottom sheet with live reverse geocoded departure',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    // Tap Street Pickup floating button over the map
    await tester.tap(find.byTooltip('Street Pickup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify StreetPickupBottomSheet opened
    expect(find.byType(StreetPickupBottomSheet), findsOneWidget);

    // Verify departure location does NOT default to 'Bole'
    final pickupFinder = find.byType(TextField).first;
    final pickupField = tester.widget<TextField>(pickupFinder);
    expect(pickupField.controller?.text.toLowerCase().contains('bole'), isFalse);

    // Verify "Set on map" option exists for pickup
    expect(find.text('Set on map'), findsWidgets);
    expect(find.text('Current GPS'), findsOneWidget);
  });

  testWidgets('3. MapLocationPicker allows setting departure location interactively',
      (WidgetTester tester) async {
    MapLocationResult? selectedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selectedResult = await showModalBottomSheet<MapLocationResult>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => const MapLocationPicker(
                      title: 'Set Departure Location',
                      initialLocation: LatLng(9.0209, 38.7469),
                    ),
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open picker
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    // Verify MapLocationPicker header, instructions, and confirm button
    expect(find.text('Set Departure Location'), findsOneWidget);
    expect(find.text('Move map to select location'), findsOneWidget);
    expect(find.text('Confirm Location'), findsOneWidget);

    // Tap to simulate picking new location on map
    await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Confirm selection
    await tester.tap(find.text('Confirm Location'));
    await tester.pumpAndSettle();

    // Verify result was returned
    expect(selectedResult, isNotNull);
    expect(selectedResult?.latitude, isNotNull);
    expect(selectedResult?.longitude, isNotNull);
    expect(selectedResult?.address, isNotEmpty);
  });
}
