import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driver_app/config/dio_config.dart';
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/models/delivery_price.dart';
import 'package:driver_app/models/pickup_order_request.dart';
import 'package:driver_app/screens/dashboard/widgets/street_pickup_bottom_sheet.dart';
import 'test_http_overrides.dart';

void main() {
  setUp(() async {
    DioConfig.isTestMode = true;
    HttpOverrides.global = TestHttpOverrides();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'driver_auth_token': 'mock_token_abc',
      'driver_id': 'DRV-1029',
      'driver_vehicle_id': '1',
      'driver_city_id': '1',
      'driver_pickup_km_price': 23.21,
      'driver_pickup_start_price': 168.66,
    });
    await StorageConfig.init();
  });

  tearDown(() {
    Get.reset();
  });

  test('1. DeliveryPriceModel correctly parses JSON with string numbers', () {
    final json = {
      'id': 1,
      'city_id': '1',
      'currency_id': '1',
      'car_type_id': '1',
      'property_start_price': '136.57',
      'property_km_price': '17.08',
      'courirer_start_price': '26.87',
      'courirer_km_price': '7.46',
      'pickup_start_price': '168.66',
      'pickup_km_price': '23.21',
      'created_at': '2026-10-05T10:00:00.000000Z',
      'updated_at': '2026-10-05T10:00:00.000000Z'
    };

    final model = DeliveryPriceModel.fromJson(json);
    expect(model.id, 1);
    expect(model.cityId, 1);
    expect(model.currencyId, 1);
    expect(model.carTypeId, 1);
    expect(model.pickupStartPrice, 168.66);
    expect(model.pickupKmPrice, 23.21);
    expect(model.courierStartPrice, 26.87);
    expect(model.courierKmPrice, 7.46);
    expect(model.propertyStartPrice, 136.57);
    expect(model.propertyKmPrice, 17.08);
  });

  test('1b. PickupOrderRequest includes base_price, km_price, total_km, total_price in payload', () {
    const request = PickupOrderRequest(
      fromLatitude: 9.02497,
      fromLongitude: 38.74689,
      toLatitude: 8.98060,
      toLongitude: 38.75780,
      senderPhone: '251911223344',
      carTypeId: 1,
      basePrice: 168.66,
      kmPrice: 23.21,
      totalKm: 5.4,
      totalPrice: 294.00,
      fromFriendlyLocation: 'Bole',
      toFriendlyLocation: 'Edna Mall',
    );

    final payload = request.toJson();
    expect(payload['base_price'], 168.66);
    expect(payload['km_price'], 23.21);
    expect(payload['total_km'], 5.4);
    expect(payload['total_price'], 294.00);
    expect(payload['from_latitude'], 9.02497);
    expect(payload['from_longtude'], 38.74689);
    expect(payload['to_latitude'], 8.98060);
    expect(payload['to_longtude'], 38.75780);
    expect(payload['sender_phone'], '251911223344');
    expect(payload['car_type_id'], 1);
    expect(payload['from_friendly_location'], 'Bole');
    expect(payload['to_friendly_location'], 'Edna Mall');

    final deserialized = PickupOrderRequest.fromJson(payload);
    expect(deserialized.basePrice, 168.66);
    expect(deserialized.kmPrice, 23.21);
    expect(deserialized.totalKm, 5.4);
    expect(deserialized.totalPrice, 294.00);
  });

  testWidgets('2. StreetPickupBottomSheet hides breakdown, inputs destination, shows total km & total price on Next',
      (WidgetTester tester) async {
    double? capturedKmPrice;
    double? capturedTotalPrice;
    int? capturedCarTypeId;
    double? capturedBasePrice;
    double? capturedTotalKm;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetPickupBottomSheet(
            initialFromLatitude: 9.02497,
            initialFromLongitude: 38.74689,
            initialPickupAddress: 'Bole, Addis Ababa',
            onCreateOrder: ({
              required String pickupAddress,
              required String destinationAddress,
              required String serviceCategory,
              required String customerPhone,
              double? fromLatitude,
              double? fromLongitude,
              double? toLatitude,
              double? toLongitude,
              int? carTypeId,
              double? basePrice,
              double? kmPrice,
              double? totalKm,
              double? totalPrice,
              String? description,
              String? fromFriendlyLocation,
              String? toFriendlyLocation,
            }) {
              capturedKmPrice = kmPrice;
              capturedTotalPrice = totalPrice;
              capturedCarTypeId = carTypeId;
              capturedBasePrice = basePrice;
              capturedTotalKm = totalKm;
            },
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify initial input step does NOT show pricing breakdown
    expect(find.text('KM Price'), findsNothing);
    expect(find.textContaining('ETB/km'), findsNothing);
    expect(find.textContaining('base start'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Create now'), findsNothing);

    // Enter destination and phone
    final destinationField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Destination address (e.g. Bole)',
    );
    expect(destinationField, findsOneWidget);
    await tester.enterText(destinationField, 'Edna Mall, Bole');

    final phoneField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText?.contains('234') ?? false),
    );
    expect(phoneField, findsOneWidget);
    await tester.enterText(phoneField, '911223344');
    await tester.pump();

    // Tap "Next" button
    final nextBtn = find.text('Next');
    expect(nextBtn, findsOneWidget);
    await tester.ensureVisible(nextBtn);
    await tester.tap(nextBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify summary step displays Total km and Total Price
    expect(find.text('Total km'), findsOneWidget);
    expect(find.text('Total Price'), findsOneWidget);
    expect(find.text('168.66 ETB'), findsOneWidget);

    // Strictly verify NO breakdown of per-km rate or base start price
    expect(find.text('KM Price'), findsNothing);
    expect(find.textContaining('ETB/km'), findsNothing);
    expect(find.textContaining('base start'), findsNothing);

    // Verify trip summary details
    expect(find.text('Trip Summary'), findsOneWidget);
    expect(find.text('Edna Mall, Bole'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    // Tap "Create now" button
    final createBtn = find.text('Create now');
    expect(createBtn, findsOneWidget);
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pump();

    // Verify submitted values
    expect(capturedKmPrice, 23.21);
    expect(capturedTotalPrice, 168.66);
    expect(capturedCarTypeId, 1);
    expect(capturedBasePrice, 168.66);
    expect(capturedTotalKm, isNotNull);
  });

  testWidgets('3. Back button returns to input form preserving entered details',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetPickupBottomSheet(
            initialFromLatitude: 9.02497,
            initialFromLongitude: 38.74689,
            initialPickupAddress: 'Bole, Addis Ababa',
            onCreateOrder: ({
              required String pickupAddress,
              required String destinationAddress,
              required String serviceCategory,
              required String customerPhone,
              double? fromLatitude,
              double? fromLongitude,
              double? toLatitude,
              double? toLongitude,
              int? carTypeId,
              double? basePrice,
              double? kmPrice,
              double? totalKm,
              double? totalPrice,
              String? description,
              String? fromFriendlyLocation,
              String? toFriendlyLocation,
            }) {},
          ),
        ),
      ),
    );

    await tester.pump();

    // Fill form
    final destinationField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Destination address (e.g. Bole)',
    );
    await tester.enterText(destinationField, 'Piazza, Addis Ababa');

    final phoneField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText?.contains('234') ?? false),
    );
    await tester.enterText(phoneField, '912345678');
    await tester.pump();

    // Tap Next
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Trip Summary'), findsOneWidget);
    expect(find.text('Piazza, Addis Ababa'), findsOneWidget);

    // Tap Back
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should be back on input step
    expect(find.text('Trip Summary'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Piazza, Addis Ababa'), findsOneWidget);
  });
}
