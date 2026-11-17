import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:driver_app/config/dio_config.dart';
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/constants/api_endpoints.dart';
import 'package:driver_app/constants/pages.dart';
import 'package:driver_app/controllers/driver_auth_controller.dart';
import 'package:driver_app/controllers/driver_dashboard_controller.dart';
import 'package:driver_app/controllers/earnings_controller.dart';
import 'package:driver_app/controllers/history_controller.dart';
import 'package:driver_app/controllers/profile_controller.dart';
import 'package:driver_app/services/driver_auth_service.dart';
import 'package:driver_app/services/driver_battery_service.dart';
import 'package:driver_app/services/driver_location_update_service.dart';
import 'package:driver_app/services/driver_order_service.dart';
import 'package:driver_app/services/driver_profile_service.dart';
import 'package:driver_app/services/notification_service.dart';
import 'package:driver_app/screens/wallet/payment_webview_screen.dart';
import 'package:driver_app/models/delivery_task.dart';
import 'package:driver_app/models/pickup_order_request.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late _MockDioAdapter mockAdapter;

  setUp(() async {
    DioConfig.isTestMode = true;
    SharedPreferences.setMockInitialValues({});
    mockAdapter = _MockDioAdapter();
    mockDio = Dio(BaseOptions(baseUrl: 'https://api.amnplc.com/api'));
    mockDio.httpClientAdapter = mockAdapter;

    // Reset DioConfig singleton to return our mock dio
    DioConfig.resetDio();
    final client = await DioConfig.dio();
    client.httpClientAdapter = mockAdapter;

    // Connect NotificationService to mockAdapter for deterministic test assertions
    final notifDio = Dio();
    notifDio.httpClientAdapter = mockAdapter;
    NotificationService.instance.customDio = notifDio;

    await StorageConfig.init();
    await StorageConfig.clearSession();
    Get.reset();

    // Default metadata mocks for registration
    mockAdapter.onGet(ApiEndpoints.vehicleType, (options) {
      return ResponseBody.fromString(
        jsonEncode({
          'message': 'Vechile Type',
          'data': [
            {
              'id': 1,
              'name': 'MoterBick',
              'image': 'https://api.amnplc.com/assets/images (78).jpeg',
              'status': '1',
            }
          ]
        }),
        200,
      );
    });

    mockAdapter.onGet(ApiEndpoints.city, (options) {
      return ResponseBody.fromString(
        jsonEncode({
          'message': 'City',
          'data': [
            {'id': 1, 'name': 'Addis Ababa', 'status': '1'}
          ]
        }),
        200,
      );
    });
  });

  tearDown(() {
    DioConfig.resetDio();
    Get.reset();
  });

  group('Driver Auth Endpoints Integration Tests (Postman Collections)', () {
    test('1. Driver Login (POST /driver-login)', () async {
      mockAdapter.onPost(ApiEndpoints.driverLogin, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['phone'], '251911058179');
        expect(data['password'], '1224');

        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Login successful',
            'token': 'mock_driver_token_abc123',
            'data': {
              'id': 1,
              'f_name': 'Amanuel',
              'l_name': 'Tilahun',
              'phone': '251911058179',
              'avatar': 'https://api.amnplc.com/storage/profile/1.jpg',
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      Map<String, dynamic>? successData;
      String? errorMsg;

      await DriverAuthService.driverLogin(
        phone: '0911058179',
        password: '1224',
        onSuccess: (data) => successData = data,
        onFailure: (err) => errorMsg = err,
      );

      expect(errorMsg, isNull);
      expect(successData, isNotNull);
      expect(successData!['id'], 1);
      expect(successData!['f_name'], 'Amanuel');
    });

    test('2. Driver Register (POST /driver-register) with vehicle_id and city_id', () async {
      mockAdapter.onPost(ApiEndpoints.driverRegister, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['f_name'], 'Amanuel');
        expect(data['l_name'], 'Tilahun');
        expect(data['phone'], '251911058179');
        expect(data['password'], '1234');
        expect(data['vehicle_id'], 1);
        expect(data['city_id'], 1);

        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Driver registered successfully',
            'data': {
              'id': 105,
              'f_name': 'Amanuel',
              'l_name': 'Tilahun',
              'phone': '251911058179',
              'vehicle_id': 1,
              'city_id': 1,
            }
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      Map<String, dynamic>? resultData;
      await DriverAuthService.driverRegister(
        firstName: 'Amanuel',
        lastName: 'Tilahun',
        phone: '251911058179',
        password: '1234',
        vehicleId: 1,
        cityId: 1,
        onSuccess: (data) => resultData = data,
        onFailure: (err) => fail(err),
      );

      expect(resultData, isNotNull);
      expect(resultData!['id'], 105);
    });

    test('2b. Driver Register (POST /driver-register) with plate_number and car_image', () async {
      mockAdapter.onPost(ApiEndpoints.driverRegister, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['f_name'], 'Dawit');
        expect(data['l_name'], 'Tadesse');
        expect(data['phone'], '251911058179');
        expect(data['password'], '1234');
        expect(data['vehicle_id'], 2);
        expect(data['city_id'], 1);
        expect(data['plate_number'], 'AA 3-99887');
        expect(data['car_image'], 'https://storage/car_image/bajaj_vehicle.jpg');

        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Driver registered successfully',
            'data': {
              'id': 106,
              'f_name': 'Dawit',
              'l_name': 'Tadesse',
              'phone': '251911058179',
              'vehicle_id': 2,
              'city_id': 1,
              'plate_number': 'AA 3-99887',
              'car_image': 'https://api.amnplc.com/public/storage/car_image/bajaj_vehicle.jpg',
            }
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      Map<String, dynamic>? resultData;
      await DriverAuthService.driverRegister(
        firstName: 'Dawit',
        lastName: 'Tadesse',
        phone: '251911058179',
        password: '1234',
        vehicleId: 2,
        cityId: 1,
        plateNumber: 'AA 3-99887',
        carImagePath: 'https://storage/car_image/bajaj_vehicle.jpg',
        onSuccess: (data) => resultData = data,
        onFailure: (err) => fail(err),
      );

      expect(resultData, isNotNull);
      expect(resultData!['id'], 106);
      expect(resultData!['plate_number'], 'AA 3-99887');
    });

    test('2c. Driver Register (POST /driver-register) with optional email field', () async {
      mockAdapter.onPost(ApiEndpoints.driverRegister, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['f_name'], 'Solomon');
        expect(data['l_name'], 'Bekele');
        expect(data['email'], 'solomon@amnplc.com');
        expect(data['phone'], '251911058179');
        expect(data['password'], '4321');
        expect(data['vehicle_id'], 1);
        expect(data['city_id'], 1);

        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Driver registered successfully',
            'data': {
              'id': 107,
              'f_name': 'Solomon',
              'l_name': 'Bekele',
              'email': 'solomon@amnplc.com',
              'phone': '251911058179',
              'vehicle_id': 1,
              'city_id': 1,
            }
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      Map<String, dynamic>? resultData;
      await DriverAuthService.driverRegister(
        firstName: 'Solomon',
        lastName: 'Bekele',
        email: 'solomon@amnplc.com',
        phone: '251911058179',
        password: '4321',
        vehicleId: 1,
        cityId: 1,
        onSuccess: (data) => resultData = data,
        onFailure: (err) => fail(err),
      );

      expect(resultData, isNotNull);
      expect(resultData!['id'], 107);
      expect(resultData!['email'], 'solomon@amnplc.com');
    });

    test('3. Driver Send OTP (POST /driver-send-otp)', () async {
      mockAdapter.onPost(ApiEndpoints.driverSendOtp, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['phone'], '251911058179');
        expect(data['otp'], '1224');

        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'OTP sent'}),
          200,
        );
      });

      bool succeeded = false;
      await DriverAuthService.driverSendOtp(
        phone: '0911058179',
        otp: '1224',
        onSuccess: () => succeeded = true,
        onFailure: (err) => fail(err),
      );

      expect(succeeded, true);
    });

    test('3b. Driver Send OTP (POST /driver-send-otp) handles 404 with error message', () async {
      mockAdapter.onPost(ApiEndpoints.driverSendOtp, (options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'phone number is not found'}),
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      String? failureMessage;
      await DriverAuthService.driverSendOtp(
        phone: '0911058179',
        otp: '1224',
        onSuccess: () => fail('Should have failed with 404'),
        onFailure: (err) => failureMessage = err,
      );

      expect(failureMessage, 'phone number is not found');
    });

    test('4. Driver Verify OTP (POST /driver-verify-otp)', () async {
      mockAdapter.onPost(ApiEndpoints.driverVerifyOtp, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['user_id'], '1');
        expect(data['otp'], '1224');

        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Driver OTP verified'}),
          200,
        );
      });

      bool verified = false;
      await DriverAuthService.driverVerifyOtp(
        userId: '1',
        otp: '1224',
        onSuccess: () => verified = true,
        onFailure: (err) => fail(err),
      );

      expect(verified, true);
    });

    test('5. Forget Driver Password (POST /driver-forget-password)', () async {
      mockAdapter.onPost(ApiEndpoints.driverForgetPassword, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['phone'], '251911058179');
        expect(data['password'], '1224');
        expect(data['password_confirmation'], '1224');

        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Password reset successfully'}),
          200,
        );
      });

      bool resetSuccess = false;
      await DriverAuthService.driverForgotPassword(
        phone: '0911058179',
        password: '1224',
        passwordConfirmation: '1224',
        onSuccess: () => resetSuccess = true,
        onFailure: (err) => fail(err),
      );

      expect(resetSuccess, true);
    });

    test('6. ChangeDriver Password (POST /driver-change-password)', () async {
      mockAdapter.onPost(ApiEndpoints.driverChangePassword, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['user_id'], 1);
        expect(data['password'], '12345');
        expect(data['password_confirmation'], '12345');

        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Password changed'}),
          200,
        );
      });

      bool changed = false;
      await DriverAuthService.driverChangePassword(
        userId: 1,
        password: '12345',
        passwordConfirmation: '12345',
        onSuccess: () => changed = true,
        onFailure: (err) => fail(err),
      );

      expect(changed, true);
    });

    test('7. Driver Logout (POST /driver-logout)', () async {
      mockAdapter.onPost(ApiEndpoints.driverLogout, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['user_id'], 1);

        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Successfully logged out'}),
          200,
        );
      });

      bool loggedOut = false;
      await DriverAuthService.driverLogout(
        userId: 1,
        onSuccess: () => loggedOut = true,
        onFailure: (err) => fail(err),
      );

      expect(loggedOut, true);
    });
  });

  group('Driver Orders & Profile Endpoints Tests', () {
    test('8. Fetch Active Orders (GET /my_active_order/1)', () async {
      mockAdapter.onGet(ApiEndpoints.activeOrders(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 8492,
                'status': '1',
                'property_name': 'Chanoly Noodles',
                'location': 'Bole Atlas, Addis Ababa',
                'total_price': '320.00',
                'total_item': 2,
                'payment_type': 'telebirr',
              }
            ]
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final orders = await DriverOrderService.fetchActiveOrders(1);
      expect(orders.length, 1);
      expect(orders.first.orderNumber, 'AMN-8492');
      expect(orders.first.storeName, 'Chanoly Noodles');
      expect(orders.first.status, DeliveryStatus.assigned);
    });

    test('8b. Fetch Active Orders via Driver Order History (GET /driver-order-history/...)', () async {
      mockAdapter.onGet(ApiEndpoints.driverOrderHistory('2026-10-23', '2026-10-25', 6), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Driver order history retrieved successfully',
            'data': [
              {
                'id': 48,
                'status': '1',
                'property_name': 'Boss Burger',
                'location': 'Bole Medhanealem, Addis Ababa',
                'total_price': '450.00',
                'total_item': 1,
                'created_at': '2026-10-24 14:30:00',
              },
              {
                'id': 49,
                'status': '4', // Delivered - should be excluded from active
                'property_name': 'Past Finished Burger',
                'location': 'Addis Ababa',
                'total_price': '200.00',
                'created_at': '2026-10-24 12:00:00',
              }
            ]
          }),
          200,
        );
      });

      final orders = await DriverOrderService.fetchActiveOrders(
        6,
        startDate: '2026-10-23',
        endDate: '2026-10-25',
      );
      expect(orders.length, 1);
      expect(orders.first.id, '48');
      expect(orders.first.status, DeliveryStatus.assigned);
      expect(orders.first.isActive, isTrue);
    });

    test('9. Fetch Driver Profile & Wallet (GET /driver-profile/1, /driver_my_wallet_amount/1)', () async {
      mockAdapter.onGet(ApiEndpoints.driverProfile(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'id': 1,
              'f_name': 'Amanuel',
              'l_name': 'Tilahun',
              'phone': '251911058179',
              'email': 'driver@amnplc.com',
            }
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.driverWalletAmount(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {'amount': 4850.50}
          }),
          200,
        );
      });

      final profileMap = await DriverProfileService.fetchProfile(1);
      expect(profileMap, isNotNull);
      expect(profileMap!['data']['f_name'], 'Amanuel');

      final balance = await DriverProfileService.fetchWalletAmount(1);
      expect(balance, 4850.50);
    });

    test('9b. Accept Order (POST /orders/48/accept-order)', () async {
      mockAdapter.onPost(ApiEndpoints.acceptOrder(48), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Driver assigned to order successfully!',
            'data': {
              'id': 48,
              'status': '1',
              'driver_id': 6,
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      bool callbackCalled = false;
      final ok = await DriverOrderService.acceptOrder(
        orderId: 48,
        driverId: 6,
        onSuccess: (data) {
          callbackCalled = true;
          expect(data['success'], isTrue);
          expect(data['data']['driver_id'], 6);
        },
      );
      expect(ok, isTrue);
      expect(callbackCalled, isTrue);
    });

    test('9c. Update Driver Online Status (POST /driver/6/update-online)', () async {
      int? capturedOnlineStatus;
      mockAdapter.onPost(ApiEndpoints.updateOnline(6), (options) {
        if (options.data is Map) {
          capturedOnlineStatus = options.data['online'] as int?;
        }
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Driver online status updated successfully',
            'data': {
              'driver_id': 6,
              'online': capturedOnlineStatus,
            }
          }),
          200,
        );
      });

      // 1. Go Online
      final onlineSuccess = await DriverProfileService.updateOnlineStatus(
        driverId: 6,
        isOnline: true,
      );
      expect(onlineSuccess, isTrue);
      expect(capturedOnlineStatus, 1);

      // 2. Go Offline
      final offlineSuccess = await DriverProfileService.updateOnlineStatus(
        driverId: 6,
        isOnline: false,
      );
      expect(offlineSuccess, isTrue);
      expect(capturedOnlineStatus, 0);
    });

    test('9d. DriverDashboardController toggleOnlineStatus syncs with update-online API', () async {
      int? lastOnlinePayload;
      mockAdapter.onPost(ApiEndpoints.updateOnline(6), (options) {
        if (options.data is Map) {
          lastOnlinePayload = options.data['online'] as int?;
        }
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Status updated',
          }),
          200,
        );
      });

      await StorageConfig.setDriverId('6');
      final dashController = DriverDashboardController();
      expect(dashController.isOnline.value, isFalse);

      // Toggle to online
      await dashController.setOnlineStatus(true, showSnackbar: false);
      expect(dashController.isOnline.value, isTrue);
      expect(StorageConfig.getIsOnline(), isTrue);
      expect(lastOnlinePayload, 1);

      // Toggle to offline
      await dashController.setOnlineStatus(false, showSnackbar: false);
      expect(dashController.isOnline.value, isFalse);
      expect(StorageConfig.getIsOnline(), isFalse);
      expect(lastOnlinePayload, 0);

      dashController.onClose();
    });

    test('9e. Fetch Driver Today Earning (GET /today_earning/6) parses string & integer amounts', () async {
      mockAdapter.onGet(ApiEndpoints.todayEarning(6), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Today Earning',
            'data': '565',
          }),
          200,
        );
      });

      final earning = await DriverProfileService.fetchTodayEarning(6);
      expect(earning, 565.0);

      // Verify with 0
      mockAdapter.onGet(ApiEndpoints.todayEarning(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Today Earning',
            'data': 0,
          }),
          200,
        );
      });

      final zeroEarning = await DriverProfileService.fetchTodayEarning(1);
      expect(zeroEarning, 0.0);
    });

    test('9f. Fetch Driver Wallet Amount (GET /driver_my_wallet_amount/9) parses string and null amounts', () async {
      mockAdapter.onGet(ApiEndpoints.driverWalletAmount(9), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Drvier Wallet Amount is',
            'data': '0',
          }),
          200,
        );
      });

      final walletZero = await DriverProfileService.fetchWalletAmount(9);
      expect(walletZero, 0.0);

      // Verify with null
      mockAdapter.onGet(ApiEndpoints.driverWalletAmount(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Drvier Wallet Amount is',
            'data': null,
          }),
          200,
        );
      });

      final walletNull = await DriverProfileService.fetchWalletAmount(1);
      expect(walletNull, 0.0);
    });

    test('9g. Dashboard & Earnings Controller Metrics Sync via APIs', () async {
      mockAdapter.onGet(ApiEndpoints.todayEarning(42), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Today Earning',
            'data': '1750.25',
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.driverWalletAmount(42), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Drvier Wallet Amount is',
            'data': '3420.50',
          }),
          200,
        );
      });

      await StorageConfig.setDriverId('42');
      final earningsCtrl = Get.put(EarningsController());
      final dashCtrl = Get.put(DriverDashboardController());

      await dashCtrl.fetchDashboardMetrics();

      expect(dashCtrl.todayEarnings.value, 1750.25);
      expect(dashCtrl.walletBalance.value, 3420.50);
      expect(earningsCtrl.earnings.value.todayEarnings, 1750.25);
      expect(earningsCtrl.earnings.value.availableBalance, 3420.50);

      dashCtrl.onClose();
    });

    test('9h. Create Pickup Order (POST /pickup-order)', () async {
      mockAdapter.onPost(ApiEndpoints.pickupOrder, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['from_latitude'], 9.02497);
        expect(data['from_longtude'], 38.74689);
        expect(data['to_latitude'], 8.98060);
        expect(data['to_longtude'], 38.75780);
        expect(data['sender_phone'], '251911058179');
        expect(data['car_type_id'], 1);
        expect(data['km_price'], 35.00);
        expect(data['total_price'], 250.00);
        expect(data['description'], 'Fragile electronics. Please call upon arrival.');
        expect(data['from_friendly_location'], 'bole');
        expect(data['to_friendly_location'], 'welosefer');

        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Pickup order created successfully',
            'data': {
              'id': 9,
              'sender_phone': '251911058179',
              'car_type_id': 1,
              'km_price': 35.00,
              'total_price': 250.00,
              'status': 1,
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      const req = PickupOrderRequest(
        fromLatitude: 9.02497,
        fromLongitude: 38.74689,
        toLatitude: 8.98060,
        toLongitude: 38.75780,
        senderPhone: '251911058179',
        carTypeId: 1,
        basePrice: 50.00,
        kmPrice: 35.00,
        totalKm: 5.71,
        totalPrice: 250.00,
        description: 'Fragile electronics. Please call upon arrival.',
        fromFriendlyLocation: 'bole',
        toFriendlyLocation: 'welosefer',
      );

      final result = await DriverOrderService.createPickupOrder(request: req);
      expect(result, isNotNull);
      expect(result!['data']['id'], 9);
      expect(result['data']['total_price'], 250.00);
    });

    test('9i. Update Pickup Order Status (POST /pickup-order/9/update-order)', () async {
      int? capturedStatus;
      mockAdapter.onPost(ApiEndpoints.updatePickupOrder(9), (options) {
        if (options.data is Map) {
          capturedStatus = options.data['status'] as int?;
        }
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Order status updated successfully',
            'data': {
              'id': 9,
              'status': capturedStatus,
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final success = await DriverOrderService.updatePickupOrderStatus(
        orderId: 9,
        status: 2,
      );
      expect(success, isTrue);
      expect(capturedStatus, 2);
    });

    test('9j. Driver Battery Percentage Report (POST /driver-battry-percent)', () async {
      Map<String, dynamic>? capturedBody;
      mockAdapter.onPost(ApiEndpoints.driverBatteryPercent, (options) {
        capturedBody = options.data as Map<String, dynamic>?;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Battery percent saved successfully',
            'data': capturedBody,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await StorageConfig.setDriverId('1');
      await StorageConfig.setDeviceId('test-device-uuid-1234');

      final batteryService = Get.put(DriverBatteryService());
      batteryService.mockBatteryPercent = 78;

      final success = await batteryService.sendBatteryPercent(reason: 'unit_test');
      expect(success, isTrue);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['driver_id'], 1);
      expect(capturedBody!['device_id'], 'test-device-uuid-1234');
      expect(capturedBody!['amount'], '78');
      expect(capturedBody!['date'], isNotEmpty);
      expect(batteryService.lastSentAt.value, isNotNull);
      expect(batteryService.lastReportedAmount.value, '78');
    });

    test('9k. Driver Order History (GET /driver-order-history/\$startDate/\$endDate/\$driverId)', () async {
      mockAdapter.onGet(
        ApiEndpoints.driverOrderHistory('2026-10-23', '2026-10-25', '6'),
        (options) {
          return ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'message': 'Driver Order History',
              'data': [
                {
                  'id': 101,
                  'order_number': 'AMN-DEL-101',
                  'location': 'Bole Atlas, Addis Ababa',
                  'total_price': 350.0,
                  'driver_fee': 120.0,
                  'status': 'delivered',
                  'created_at': '2026-10-24T14:30:00Z',
                  'updated_at': '2026-10-24T15:10:00Z',
                }
              ]
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      final orders = await DriverOrderService.fetchDriverOrderHistory(
        startDate: '2026-10-23',
        endDate: '2026-10-25',
        driverId: '6',
      );

      expect(orders.length, 1);
      expect(orders.first.orderNumber, 'AMN-DEL-101');
      expect(orders.first.customerAddress, 'Bole Atlas, Addis Ababa');
      expect(orders.first.payoutAmount, 120.0);
      expect(orders.first.isCorporate, isFalse);
      expect(orders.first.isPickup, isFalse);
      expect(orders.first.orderTypeLabel, 'Standard');
    });

    test('9l. Driver Corporate Order History (GET /driver-company-order-history/\$startDate/\$endDate/\$driverId)', () async {
      mockAdapter.onGet(
        ApiEndpoints.driverCompanyOrderHistory('2026-10-16', '2026-10-16', '3'),
        (options) {
          return ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'message': 'Driver Company Order History',
              'data': [
                {
                  'id': 202,
                  'order_number': 'AMN-CORP-202',
                  'company_name': 'Ethiopian Airlines HQ',
                  'location': 'Airport Cargo Terminal',
                  'total_price': 850.0,
                  'driver_fee': 280.0,
                  'status': 'delivered',
                  'created_at': '2026-10-16T09:00:00Z',
                }
              ]
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      final orders = await DriverOrderService.fetchDriverCompanyOrderHistory(
        startDate: '2026-10-16',
        endDate: '2026-10-16',
        driverId: '3',
      );

      expect(orders.length, 1);
      expect(orders.first.orderNumber, 'AMN-CORP-202');
      expect(orders.first.customerAddress, 'Airport Cargo Terminal');
      expect(orders.first.isCorporate, isTrue);
      expect(orders.first.orderTypeLabel, 'Corporate');
    });

    test('9m. Driver Pickup Order History (GET /driver-pickup-order-history/\$startDate/\$endDate/\$driverId)', () async {
      mockAdapter.onGet(
        ApiEndpoints.driverPickupOrderHistory('2026-10-16', '2026-10-16', '3'),
        (options) {
          return ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'message': 'Driver Pickup Order History',
              'data': [
                {
                  'id': 303,
                  'order_number': 'AMN-PKP-303',
                  'location': 'Kazanchis Commercial Hub',
                  'total_price': 180.0,
                  'driver_fee': 95.0,
                  'status': 'delivered',
                  'created_at': '2026-10-16T11:20:00Z',
                }
              ]
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      final orders = await DriverOrderService.fetchDriverPickupOrderHistory(
        startDate: '2026-10-16',
        endDate: '2026-10-16',
        driverId: '3',
      );

      expect(orders.length, 1);
      expect(orders.first.orderNumber, 'AMN-PKP-303');
      expect(orders.first.customerAddress, 'Kazanchis Commercial Hub');
      expect(orders.first.isPickup, isTrue);
      expect(orders.first.orderTypeLabel, 'Pickup');
    });

    test('9n. HistoryController multi-endpoint aggregation and category filtering', () async {
      const start = '2026-10-01';
      const end = '2026-10-27';

      mockAdapter.onGet(ApiEndpoints.driverOrderHistory(start, end, '1'), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {
                'id': 1001,
                'order_number': 'AMN-STD-1',
                'location': 'Sarbet',
                'total_price': 200.0,
                'driver_fee': 70.0,
                'status': 'delivered',
                'created_at': '2026-10-20T10:00:00Z',
              }
            ]
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.driverCompanyOrderHistory(start, end, '1'), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {
                'id': 2001,
                'order_number': 'AMN-CRP-1',
                'location': 'Kazanchis',
                'total_price': 500.0,
                'driver_fee': 150.0,
                'status': 'delivered',
                'created_at': '2026-10-22T12:00:00Z',
              }
            ]
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.driverPickupOrderHistory(start, end, '1'), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {
                'id': 3001,
                'order_number': 'AMN-PKP-1',
                'location': 'Bole Edna',
                'total_price': 150.0,
                'driver_fee': 60.0,
                'status': 'delivered',
                'created_at': '2026-10-25T15:00:00Z',
              }
            ]
          }),
          200,
        );
      });

      final historyCtrl = Get.put(HistoryController());
      historyCtrl.setCustomDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 27));

      await historyCtrl.fetchHistoryFromApi();

      expect(historyCtrl.historyTasks.length, 3);
      expect(historyCtrl.totalLifetimeTrips.value, 3);

      // Filter by Corporate
      historyCtrl.setOrderType('Corporate');
      expect(historyCtrl.filteredHistory.length, 1);
      expect(historyCtrl.filteredHistory.first.orderNumber, 'AMN-CRP-1');

      // Filter by Pickup
      historyCtrl.setOrderType('Pickup');
      expect(historyCtrl.filteredHistory.length, 1);
      expect(historyCtrl.filteredHistory.first.orderNumber, 'AMN-PKP-1');

      // Filter by Delivery
      historyCtrl.setOrderType('Delivery');
      expect(historyCtrl.filteredHistory.length, 1);
      expect(historyCtrl.filteredHistory.first.orderNumber, 'AMN-STD-1');

      // Filter by All
      historyCtrl.setOrderType('All');
      expect(historyCtrl.filteredHistory.length, 3);
    });

    test('9p. Continuous Driver Location Tracking (POST /driver-location)', () async {
      Map<String, dynamic>? capturedBody;
      mockAdapter.onPost(ApiEndpoints.driverLocation, (options) {
        capturedBody = options.data as Map<String, dynamic>?;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Location saved successfully',
            'data': capturedBody,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await StorageConfig.setDriverId('1');
      await StorageConfig.setDeviceId('b6c2e515-195e-498d-bdeb-af8f9dc63eb6');

      final locationService = Get.put(DriverLocationUpdateService());

      final success = await locationService.sendLocationUpdate(
        latitude: 8.9926529,
        longitude: 8.9926529,
        reason: 'unit_test',
        force: true,
      );

      expect(success, isTrue);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['agent_id'], 'b6c2e515-195e-498d-bdeb-af8f9dc63eb6');
      expect(capturedBody!['latitude'], '8.9926529');
      expect(capturedBody!['longitude'], '8.9926529');
      expect(capturedBody!['driver_id'], 1);
      expect(capturedBody!['date'], isNotEmpty);
      expect(locationService.lastLocationSentAt.value, isNotNull);
      expect(locationService.lastLatitude.value, 8.9926529);
      expect(locationService.lastLongitude.value, 8.9926529);
    });

    test('9q. Driver Wallet Top-up (POST /driver-wallet-payment) & In-App Payment WebView', () async {
      mockAdapter.onPost(ApiEndpoints.driverWalletPayment, (options) {
        final data = options.data as Map<String, dynamic>;
        expect(data['user_id'], 6);
        expect(data['amount'], 500.0);
        expect(data['date'], isNotEmpty);

        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Hosted Link',
            'status': 'success',
            'data': {
              'checkout_url': 'https://checkout.chapa.co/checkout/payment/amnp-tx-12345',
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      String? retrievedUrl;
      String? retrievedMsg;
      await DriverProfileService.topupWallet(
        driverId: 6,
        amount: 500.0,
        date: '2026-11-03',
        onSuccess: (checkoutUrl, message) {
          retrievedUrl = checkoutUrl;
          retrievedMsg = message;
        },
        onFailure: (err) {},
      );

      expect(retrievedUrl, 'https://checkout.chapa.co/checkout/payment/amnp-tx-12345');
      expect(retrievedMsg, 'Hosted Link');

      // Verify in-app WebView receipt URL detection for automatic pop and balance refresh
      expect(
        PaymentWebViewScreen.isReceiptUrl('https://api.amnplc.com/api/driver-wallet-payment-callback/ref-123/6'),
        isTrue,
      );
      expect(
        PaymentWebViewScreen.isReceiptUrl('https://checkout.chapa.co/checkout/payment/amnp-tx-12345/receipt'),
        isTrue,
      );
      expect(
        PaymentWebViewScreen.isReceiptUrl('https://checkout.chapa.co/checkout/payment/amnp-tx-12345'),
        isFalse,
      );
    });
  });

  group('DriverAuthController State & Session Flow', () {
    test('10. Controller login updates reactive session and StorageConfig', () async {
      mockAdapter.onPost(ApiEndpoints.driverLogin, (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'token': 'auth_token_xyz_999',
            'data': {
              'id': 42,
              'f_name': 'Dawit',
              'l_name': 'Tadesse',
              'phone': '251911058179',
            }
          }),
          200,
        );
      });

      final controller = Get.put(DriverAuthController());
      expect(controller.isLoggedIn, false);

      // Attempt login with invalid password (must be 4 digits)
      await controller.login('0911058179', 'invalid_pwd');
      expect(controller.isLoggedIn, false);

      // Valid 4-digit password succeeds
      await controller.login('0911058179', '1234');

      expect(controller.isLoggedIn, true);
      expect(StorageConfig.getToken(), 'auth_token_xyz_999');
      expect(StorageConfig.getDriverId(), '42');
      expect(StorageConfig.getDriverName(), 'Dawit Tadesse');
    });

    test('11. Fetch Vehicle Types and Cities from API', () async {
      mockAdapter.onGet(ApiEndpoints.vehicleType, (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Vechile Type',
            'data': [
              {
                'id': 1,
                'name': 'MoterBick',
                'image': 'https://api.amnplc.com/assets/images (78).jpeg',
                'status': '1',
              },
              {
                'id': 2,
                'name': 'Car',
                'image': 'https://api.amnplc.com/assets/images (79).jpeg',
                'status': '1',
              },
            ]
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.city, (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'City',
            'data': [
              {'id': 1, 'name': 'Addis Ababa', 'status': '1'},
              {'id': 2, 'name': 'Hawassa', 'status': '1'},
            ]
          }),
          200,
        );
      });

      final vehicles = await DriverAuthService.fetchVehicleTypes();
      expect(vehicles.length, 2);
      expect(vehicles.first.id, 1);
      expect(vehicles.first.name, 'MoterBick');
      expect(vehicles.first.image, contains('images (78).jpeg'));

      final cities = await DriverAuthService.fetchCities();
      expect(cities.length, 2);
      expect(cities.first.id, 1);
      expect(cities.first.name, 'Addis Ababa');
    });

    test('12. Controller loadRegistrationMetadata initializes vehicleTypes & cities', () async {
      mockAdapter.onGet(ApiEndpoints.vehicleType, (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Vechile Type',
            'data': [
              {
                'id': 10,
                'name': 'Van',
                'image': 'https://api.amnplc.com/assets/van.png',
                'status': '1',
              }
            ]
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.city, (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'City',
            'data': [
              {'id': 5, 'name': 'Dire Dawa', 'status': '1'}
            ]
          }),
          200,
        );
      });

      final controller = Get.put(DriverAuthController());
      await controller.loadRegistrationMetadata();

      expect(controller.vehicleTypes.length, 1);
      expect(controller.vehicleTypes.first.id, 10);
      expect(controller.selectedVehicleId.value, 10);

      expect(controller.cities.length, 1);
      expect(controller.cities.first.id, 5);
      expect(controller.selectedCityId.value, isNull);
    });

    test('12b. Fetch Delivery Price by car type and city ID determines pickup price correctly', () async {
      mockAdapter.onGet(ApiEndpoints.deliveryPriceByCarAndCity(1, 1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Delviery price by Car id List successfully',
            'data': [
              {
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
              }
            ]
          }),
          200,
        );
      });

      final price = await DriverOrderService.fetchDeliveryPrice(vehicleId: 1, cityId: 1);
      expect(price, isNotNull);
      expect(price!.carTypeId, 1);
      expect(price.cityId, 1);
      expect(price.pickupStartPrice, 168.66);
      expect(price.pickupKmPrice, 23.21);
      expect(price.courierStartPrice, 26.87);
      expect(price.courierKmPrice, 7.46);
      expect(price.propertyStartPrice, 136.57);
      expect(price.propertyKmPrice, 17.08);

      // Verify cached into StorageConfig
      expect(StorageConfig.getPickupKmPrice(), 23.21);
      expect(StorageConfig.getPickupStartPrice(), 168.66);

      // Verify DriverAuthService can also fetch delivery price
      final priceAuth = await DriverAuthService.fetchDeliveryPrice(vehicleId: 1, cityId: 1);
      expect(priceAuth, isNotNull);
      expect(priceAuth!.pickupKmPrice, 23.21);
    });

    test('13. Driver Registration stops and resets loading when driver-send-otp fails', () async {
      mockAdapter.onPost(ApiEndpoints.driverRegister, (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Driver registered successfully',
            'data': {
              'id': 106,
              'f_name': 'Test',
              'l_name': 'Driver',
              'phone': '251911999999',
              'vehicle_id': 1,
              'city_id': 1,
            }
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      mockAdapter.onPost(ApiEndpoints.driverSendOtp, (options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'phone number is not found'}),
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final controller = Get.put(DriverAuthController());
      await controller.register(
        firstName: 'Test',
        lastName: 'Driver',
        phone: '0911999999',
        password: '1234',
        vehicleId: 1,
        cityId: 1,
      );

      // Loading must be reset to false
      expect(controller.isLoading.value, false);
      // Route must not have navigated to OTP screen
      expect(Get.currentRoute, isNot(Pages.otp));
    });
  });

  group('Order Status Push Notifications & Order Detail Metadata Tests', () {
    test('Fetch raw order detail metadata (GET /my_order_detail/45)', () async {
      mockAdapter.onGet(ApiEndpoints.orderDetail(45), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Order Detail get successfully',
            'data': {
              'id': 79,
              'order_header_id': '45',
              'customer_id': '1',
              'owner_id': '2',
              'property': 'Bole Fresh Grocery',
              'location': 'Bole Atlas, Addis Ababa',
            }
          }),
          200,
        );
      });

      final raw = await DriverOrderService.fetchOrderDetailRaw(45);
      expect(raw, isNotNull);
      expect(raw!['customer_id'], '1');
      expect(raw['owner_id'], '2');
      expect(raw['property'], 'Bole Fresh Grocery');
    });

    test('DeliveryTask.fromApiOrderJson correctly parses customer_id, owner_id, and property', () {
      final json = {
        'id': 45,
        'order_header_id': '45',
        'customer_id': '1',
        'owner_id': '2',
        'property': 'Bole Fresh Grocery',
        'location': 'Bole Atlas, Addis Ababa',
        'status': '1',
      };

      final task = DeliveryTask.fromApiOrderJson(json);
      expect(task.id, '45');
      expect(task.customerId, '1');
      expect(task.ownerId, '2');
      expect(task.propertyName, 'Bole Fresh Grocery');
      expect(task.storeName, 'Bole Fresh Grocery');
    });

    test('sendCustomerOrderStatusNotification succeeds on 200 response', () async {
      mockAdapter.onPost(NotificationService.customerOrderStatusEndpoint, (options) {
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Notification sent to customer'}),
          200,
        );
      });
      final success = await NotificationService.instance.sendCustomerOrderStatusNotification(
        customerId: 1,
        orderId: 45,
        status: '2',
      );
      expect(success, isTrue);
    });

    test('sendStoreOwnerNotification succeeds on 200 response', () async {
      mockAdapter.onPost(NotificationService.storeOwnerNotificationEndpoint, (options) {
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Notification sent to owner'}),
          200,
        );
      });
      final success = await NotificationService.instance.sendStoreOwnerNotification(
        ownerId: 2,
        orderId: 45,
        status: '1',
        propertyName: 'Bole Fresh Grocery',
      );
      expect(success, isTrue);
    });

    test('POST https://notification.amnplc.com/api/push/Store-owner-notification sends exact requested payload and headers on acceptance', () async {
      Map<String, dynamic>? capturedBody;
      Map<String, dynamic>? capturedHeaders;

      mockAdapter.onPost(NotificationService.storeOwnerNotificationEndpoint, (options) {
        capturedBody = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : (options.data is String ? jsonDecode(options.data as String) : null);
        capturedHeaders = options.headers;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Notification sent to owner',
            'order_id': 45,
          }),
          200,
        );
      });

      final success = await NotificationService.instance.sendStoreOwnerNotification(
        ownerId: 1,
        orderId: 45,
        status: '1',
      );

      expect(success, isTrue);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['owner_id'], 1);
      expect(capturedBody!['order_id'], 45);
      expect(capturedBody!['status'], '1');
      expect(capturedHeaders?['Content-Type'], 'application/json');
      expect(capturedHeaders?['Accept'], 'application/json');
    });

    test('POST https://notification.amnplc.com/api/push/customer-order-status sends exact requested payload and headers on status change', () async {
      Map<String, dynamic>? capturedBody;
      Map<String, dynamic>? capturedHeaders;

      mockAdapter.onPost(NotificationService.customerOrderStatusEndpoint, (options) {
        capturedBody = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : (options.data is String ? jsonDecode(options.data as String) : null);
        capturedHeaders = options.headers;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'Notification sent to customer',
            'order_id': 45,
            'status': 2,
          }),
          200,
        );
      });

      final success = await NotificationService.instance.sendCustomerOrderStatusNotification(
        customerId: 1,
        orderId: 45,
        status: '2',
      );

      expect(success, isTrue);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['customer_id'], 1);
      expect(capturedBody!['order_id'], 45);
      expect(capturedBody!['status'], '2');
      expect(capturedHeaders?['Content-Type'], 'application/json');
      expect(capturedHeaders?['Accept'], 'application/json');
    });

    test('Status 1 triggers both Store-owner-notification and customer-order-status notifications', () async {
      bool ownerNotified = false;
      bool customerNotified = false;
      dynamic capturedOwnerPayload;
      dynamic capturedCustomerPayload;

      mockAdapter.onPost(NotificationService.storeOwnerNotificationEndpoint, (options) {
        ownerNotified = true;
        capturedOwnerPayload = options.data;
        return ResponseBody.fromString(jsonEncode({'success': true}), 200);
      });

      mockAdapter.onPost(NotificationService.customerOrderStatusEndpoint, (options) {
        customerNotified = true;
        capturedCustomerPayload = options.data;
        return ResponseBody.fromString(jsonEncode({'success': true}), 200);
      });

      final task = DeliveryTask(
        id: '201',
        orderNumber: 'AMN-201',
        storeName: 'Test Shop',
        storeCategory: 'Food',
        storeAddress: 'Bole',
        storeDistanceKm: 1.0,
        customerName: 'Abebe',
        customerPhone: '+251911111111',
        customerAddress: 'Bole',
        customerDistanceKm: 2.0,
        payoutAmount: 100.0,
        items: [],
        createdAt: DateTime.now(),
        customerId: 1,
        ownerId: 1,
      );

      await NotificationService.instance.notifyOrderStatusChanged(
        orderId: 201,
        status: '1',
        task: task,
      );

      expect(customerNotified, isTrue);
      expect(ownerNotified, isTrue);
      expect(capturedOwnerPayload['owner_id'], 1);
      expect(capturedOwnerPayload['order_id'], 201);
      expect(capturedOwnerPayload['status'], '1');
      expect(capturedCustomerPayload['customer_id'], 1);
      expect(capturedCustomerPayload['order_id'], 201);
      expect(capturedCustomerPayload['status'], '1');
    });

    test('Status changes to 2, 3, 4 trigger customer-order-status every time', () async {
      final customerStatusesReceived = <String>[];

      mockAdapter.onPost(NotificationService.customerOrderStatusEndpoint, (options) {
        final data = options.data is Map ? options.data as Map : jsonDecode(options.data.toString());
        customerStatusesReceived.add(data['status'].toString());
        return ResponseBody.fromString(jsonEncode({'success': true}), 200);
      });

      final task = DeliveryTask(
        id: '301',
        orderNumber: 'AMN-301',
        storeName: 'Test Shop',
        storeCategory: 'Food',
        storeAddress: 'Bole',
        storeDistanceKm: 1.0,
        customerName: 'Abebe',
        customerPhone: '+251911111111',
        customerAddress: 'Bole',
        customerDistanceKm: 2.0,
        payoutAmount: 100.0,
        items: [],
        createdAt: DateTime.now(),
        customerId: 1,
        ownerId: 1,
      );

      // Status 2
      await NotificationService.instance.notifyOrderStatusChanged(
        orderId: 301,
        status: '2',
        task: task,
      );
      // Status 3
      await NotificationService.instance.notifyOrderStatusChanged(
        orderId: 301,
        status: '3',
        task: task,
      );
      // Status 4
      await NotificationService.instance.notifyOrderStatusChanged(
        orderId: 301,
        status: '4',
        task: task,
      );

      expect(customerStatusesReceived, ['2', '3', '4']);
    });

    test('notifyOrderStatusChanged for status 1 queries my_order_detail when metadata is missing', () async {
      mockAdapter.onGet(ApiEndpoints.orderDetail(45), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Order Detail get successfully',
            'data': {
              'id': 79,
              'order_header_id': '45',
              'customer_id': '1',
              'owner_id': '2',
              'property': 'Bole Fresh Grocery',
            }
          }),
          200,
        );
      });

      final task = DeliveryTask(
        id: '45',
        orderNumber: 'AMN-45',
        storeName: 'AMN Partner Merchant',
        storeCategory: 'Food',
        storeAddress: 'Bole Road',
        storeDistanceKm: 1.2,
        customerName: 'Abebe',
        customerPhone: '+251911000000',
        customerAddress: 'Bole Atlas',
        customerDistanceKm: 2.5,
        payoutAmount: 100.0,
        tipAmount: 20.0,
        items: [],
        createdAt: DateTime.now(),
      );

      // Status 1 should query order detail and populate customerId, ownerId, propertyName
      await NotificationService.instance.notifyOrderStatusChanged(
        orderId: 45,
        status: '1',
        task: task,
      );

      expect(task.customerId, '1');
      expect(task.ownerId, '2');
      expect(task.propertyName, 'Bole Fresh Grocery');
      expect(task.lastReportedNotificationStatus, '1');
    });

    test('13. Driver Profile Real Data & Update Endpoints (GET /driver-profile/{id}, PUT /driver-profile/{id}, change-profile-image)', () async {
      mockAdapter.onGet(ApiEndpoints.driverProfile(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Driver Profile',
            'data': {
              'id': 1,
              'f_name': 'Abebe',
              'l_name': 'Bikila',
              'email': 'abebe.bikila@example.com',
              'phone': '251911223344',
              'wallet_amount': '450.50',
              'profile_picture': 'https://api.amnplc.com/public/storage/profileImage/123456.jpg',
              'rating': 4.9,
              'total_orders': 42,
            },
          }),
          200,
        );
      });

      mockAdapter.onGet(ApiEndpoints.driverWalletAmount(1), (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Drvier Wallet Amount is',
            'data': '450.50',
          }),
          200,
        );
      });

      mockAdapter.onPut(ApiEndpoints.driverProfile(1), (options) {
        final body = options.data is Map ? options.data as Map : jsonDecode(options.data.toString());
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Driver Profile Updated Succesfully',
            'data': {
              'id': 1,
              'f_name': body['f_name'],
              'l_name': body['l_name'],
              'email': body['email'],
              'phone': body['phone'],
            },
          }),
          200,
        );
      });

      // Initialize storage with driver ID 1
      await StorageConfig.setDriverId('1');

      final profileCtrl = ProfileController();
      Get.put<ProfileController>(profileCtrl);

      // Verify fetchProfileFromApi loads real data
      await profileCtrl.fetchProfileFromApi();

      expect(profileCtrl.profile.value.name, 'Abebe Bikila');
      expect(profileCtrl.profile.value.firstName, 'Abebe');
      expect(profileCtrl.profile.value.lastName, 'Bikila');
      expect(profileCtrl.profile.value.email, 'abebe.bikila@example.com');
      expect(profileCtrl.profile.value.phone, '251911223344');
      expect(profileCtrl.profile.value.walletAmount, 450.50);
      expect(profileCtrl.profile.value.rating, 4.9);
      expect(profileCtrl.profile.value.totalTrips, 42);
      expect(profileCtrl.profile.value.avatarUrl, 'https://api.amnplc.com/public/storage/profileImage/123456.jpg');

      // Test profile update
      final updateSuccess = await profileCtrl.updateProfileInfo(
        firstName: 'Haile',
        lastName: 'Gebrselassie',
        email: 'haile@example.com',
        phone: '251922334455',
      );

      expect(updateSuccess, isTrue);
      expect(profileCtrl.profile.value.name, 'Haile Gebrselassie');
      expect(profileCtrl.profile.value.firstName, 'Haile');
      expect(profileCtrl.profile.value.lastName, 'Gebrselassie');
      expect(profileCtrl.profile.value.email, 'haile@example.com');
      expect(profileCtrl.profile.value.phone, '251922334455');
      expect(StorageConfig.getDriverName(), 'Haile Gebrselassie');
      expect(StorageConfig.getDriverEmail(), 'haile@example.com');
      expect(StorageConfig.getDriverPhone(), '251922334455');

      Get.delete<ProfileController>();
    });
  });
}

class _MockDioAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions options)> _handlers = {};

  void onGet(String path, ResponseBody Function(RequestOptions options) handler) {
    _handlers['GET $path'] = handler;
  }

  void onPost(String path, ResponseBody Function(RequestOptions options) handler) {
    _handlers['POST $path'] = handler;
  }

  void onPut(String path, ResponseBody Function(RequestOptions options) handler) {
    _handlers['PUT $path'] = handler;
  }

  void onDelete(String path, ResponseBody Function(RequestOptions options) handler) {
    _handlers['DELETE $path'] = handler;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    final handler = _handlers[key];
    if (handler != null) {
      final res = handler(options);
      final headers = Map<String, List<String>>.from(res.headers);
      headers.putIfAbsent(Headers.contentTypeHeader, () => [Headers.jsonContentType]);
      return ResponseBody(
        res.stream,
        res.statusCode,
        headers: headers,
        statusMessage: res.statusMessage,
        isRedirect: res.isRedirect,
      );
    }

    // Default 404
    return ResponseBody.fromString(
      jsonEncode({'message': 'Endpoint $key not mocked'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
