import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/models/delivery_price.dart';
import 'package:driver_app/screens/dashboard/widgets/street_pickup_bottom_sheet.dart';

void main() {
  setUp(() async {
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

  testWidgets('2. StreetPickupBottomSheet renders pickup rates and calculates price properly',
      (WidgetTester tester) async {
    double? capturedKmPrice;
    double? capturedTotalPrice;
    int? capturedCarTypeId;

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
              double? kmPrice,
              double? totalPrice,
              String? description,
              String? fromFriendlyLocation,
              String? toFriendlyLocation,
            }) {
              capturedKmPrice = kmPrice;
              capturedTotalPrice = totalPrice;
              capturedCarTypeId = carTypeId;
            },
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify KM Price displays 23.21 ETB
    expect(find.text('23.21 ETB'), findsOneWidget);

    // Verify Total Price displays base start price 168.66 ETB before destination is set
    expect(find.text('168.66 ETB'), findsOneWidget);

    // Verify helper label
    expect(find.textContaining('23.21 ETB/km'), findsOneWidget);
    expect(find.textContaining('168.66 ETB base start'), findsOneWidget);

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
  });
}
