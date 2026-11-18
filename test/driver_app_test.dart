import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/core/theme/theme_controller.dart';
import 'package:driver_app/constants/constants.dart';
import 'package:driver_app/constants/api_endpoints.dart';
import 'package:driver_app/config/dio_config.dart';
import 'package:driver_app/data/driver_mock_data.dart';
import 'package:driver_app/models/delivery_task.dart';
import 'package:driver_app/models/incoming_job_offer.dart';
import 'package:driver_app/services/notification_service.dart';
import 'package:driver_app/services/order_alert_service.dart';
import 'package:driver_app/controllers/driver_dashboard_controller.dart';
import 'package:driver_app/controllers/deliveries_controller.dart';
import 'package:driver_app/controllers/active_delivery_controller.dart';
import 'package:driver_app/controllers/history_controller.dart';
import 'package:driver_app/controllers/earnings_controller.dart';
import 'package:driver_app/controllers/profile_controller.dart';
import 'package:driver_app/controllers/driver_auth_controller.dart';
import 'package:driver_app/models/city.dart';
import 'package:driver_app/models/driver_profile.dart';
import 'package:driver_app/screens/dashboard/widgets/driver_app_drawer.dart';
import 'package:driver_app/screens/wallet/wallet_deposit_screen.dart';
import 'package:driver_app/screens/main_driver_navigation.dart';
import 'package:driver_app/main.dart';
import 'test_http_overrides.dart';

void main() {
  setUpAll(() {
    DioConfig.isTestMode = true;
    Get.testMode = true;
    HttpOverrides.global = TestHttpOverrides();
  });

  group('ETB Currency & Formatting Requirements', () {
    test('formatEtb formats Ethiopian Birr amounts correctly', () {
      expect(formatEtb(0), 'ETB 0.00');
      expect(formatEtb(150), 'ETB 150.00');
      expect(formatEtb(2450.5), 'ETB 2450.50');
      expect(formatEtb(12450.75), 'ETB 12450.75');
    });

    test('Currency constant is ETB', () {
      expect(kCurrency, 'ETB');
    });
  });

  group('DriverDashboardController Tests', () {
    late DriverDashboardController controller;

    setUp(() {
      Get.reset();
      controller = DriverDashboardController();
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Initial dashboard state verifies driver profile and active metrics in ETB', () {
      expect(controller.todayEarnings.value, 0.0);
      expect(controller.completedTrips.value, 0);
      expect(controller.walletBalance.value, 0.0);
      expect(controller.profileScore.value, 100);
      expect(controller.driverRating.value, 5.0);
      expect(controller.cancellationRate.value, 0);
    });

    test('Assigned deliveries queue loads and detects active delivery', () {
      controller.assignedTasks.assignAll(DriverMockData.initialAssignedTasks);
      expect(controller.assignedTasks.isNotEmpty, true);
      expect(controller.assignedTasks.length, 4);
      expect(controller.activeDelivery, isNotNull);
      expect(controller.activeDelivery?.orderNumber, 'AMN-8492');
    });
  });

  group('DeliveriesController Tests', () {
    late DeliveriesController controller;

    setUp(() {
      Get.reset();
      controller = DeliveriesController();
      controller.assignedTasks.assignAll(DriverMockData.initialAssignedTasks);
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Filtering assigned tasks by status tabs works correctly', () {
      expect(controller.allCount, 4);
      expect(controller.activeCount, 1);

      // Select Active tab
      controller.selectTab(1);
      expect(controller.filteredTasks.length, 1);
      expect(controller.filteredTasks.first.orderNumber, 'AMN-8492');

      // Select Pending tab
      controller.selectTab(3);
      expect(controller.filteredTasks.length, 3);
    });

    test('Search query filters assigned deliveries', () {
      controller.searchQuery.value = 'FreshMart';
      expect(controller.filteredTasks.length, 1);
      expect(controller.filteredTasks.first.storeName, 'FreshMart Organics');
    });
  });

  group('HistoryController Tests', () {
    late HistoryController controller;

    setUp(() {
      Get.reset();
      controller = HistoryController();
      controller.historyTasks.assignAll(DriverMockData.completedHistoryTasks);
      controller.totalLifetimeTrips.value = controller.historyTasks.length;
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('History loads past completed deliveries and groups by date', () {
      expect(controller.historyTasks.isNotEmpty, true);
      expect(controller.groupedHistory.isNotEmpty, true);
      expect(controller.totalLifetimeTrips.value, 6);
    });

    test('Filter chips filter history log', () {
      controller.setFilter('Completed');
      expect(controller.filteredHistory.every((t) => t.status == DeliveryStatus.delivered), true);
    });

    test('ApiEndpoints.pastOrders uses the same endpoint pattern as delivery_app (/my_past_order/{id})', () {
      expect(ApiEndpoints.pastOrders(42), '/my_past_order/42');
      expect(ApiEndpoints.pastOrders('driver_99'), '/my_past_order/driver_99');
    });

    test('DeliveryTask.fromApiOrderJson parses past orders payload matching delivery_app format', () {
      final pastOrderJson = {
        'id': '789',
        'status': '4',
        'destination_friendly_location': 'Bole Atlas, House #402',
        'location': 'Addis Ababa',
        'payment_amount': '350.00',
        'total_price': '350.00',
        'total_item': 2,
        'property_name': 'Chanoly Noodles',
        'property_logo': 'https://api.amnplc.com/images/chanoly.png',
        'date': '2026-10-24 12:30:00',
        'total_km_price': '95.00',
        'tip': '30.00',
        'payment_type': 'telebirr',
      };

      final task = DeliveryTask.fromApiOrderJson(pastOrderJson);
      expect(task.id, '789');
      expect(task.orderNumber, 'AMN-789');
      expect(task.status, DeliveryStatus.delivered);
      expect(task.customerAddress, 'Bole Atlas, House #402');
      expect(task.storeName, 'Chanoly Noodles');
      expect(task.payoutAmount, 95.00);
      expect(task.tipAmount, 30.00);
      expect(task.totalPayout, 125.00);
      expect(task.completedAt, isNotNull);
    });

    test('DeliveryTask.fromApiOrderJson handles cancelled status correctly', () {
      final cancelledOrderJson = {
        'id': '790',
        'status': '5',
        'location': 'Sarbet, Addis Ababa',
        'payment_amount': '200.00',
        'property_name': 'Injoy Burger',
      };

      final task = DeliveryTask.fromApiOrderJson(cancelledOrderJson);
      expect(task.id, '790');
      expect(task.status, DeliveryStatus.cancelled);
      expect(task.customerAddress, 'Sarbet, Addis Ababa');
      expect(task.storeName, 'Injoy Burger');
    });

    test('DeliveryTask.fromApiOrderJson handles status 0 (Order Placed) before driver accepts', () {
      final placedOrderJson = {
        'id': '791',
        'status': '0',
        'location': 'Gerji, Addis Ababa',
        'payment_amount': '210.00',
        'property_name': 'Fresh Mart',
      };

      final task = DeliveryTask.fromApiOrderJson(placedOrderJson);
      expect(task.id, '791');
      expect(task.status, DeliveryStatus.placed);
      expect(task.statusLabel, 'Order Placed');
      expect(task.statusCode, '0');
    });
  });

  group('ActiveDeliveryController Workflow Tests', () {
    late ActiveDeliveryController deliveryController;

    setUp(() {
      Get.reset();
      deliveryController = Get.put(ActiveDeliveryController());
      deliveryController.setActiveTask(DriverMockData.activeDeliveryTask);
    });

    tearDown(() {
      Get.reset();
    });

    test('Progression through 3-step delivery workflow', () {
      deliveryController.setActiveTask(DriverMockData.activeDeliveryTask);
      expect(deliveryController.currentStep.value, 0);

      // Advance: Arrived at store
      deliveryController.markArrivedAtStore();
      expect(deliveryController.currentStep.value, 1);
      expect(deliveryController.currentTask.value?.status, DeliveryStatus.atStore);

      // Advance: Pick up items and depart for customer
      deliveryController.confirmPickupAndDepart();
      expect(deliveryController.currentStep.value, 2);
      expect(deliveryController.currentTask.value?.status, DeliveryStatus.pickedUp);
    });

    test('Item checklist verification can be toggled', () {
      final initialChecked = deliveryController.currentTask.value?.items[0].isChecked ?? false;
      deliveryController.toggleItem(0);
      expect(deliveryController.currentTask.value?.items[0].isChecked, !initialChecked);
    });
  });

  group('EarningsController Tests', () {
    late EarningsController earningsController;

    setUp(() {
      Get.reset();
      earningsController = EarningsController();
      earningsController.earnings.value = DriverMockData.mockEarnings;
    });

    tearDown(() {
      Get.reset();
    });

    test('Earnings balance and daily breakdown are stored in ETB', () {
      expect(earningsController.earnings.value.availableBalance, 4850.00);
      expect(earningsController.earnings.value.todayEarnings, 1420.50);
      expect(earningsController.earnings.value.todayDeliveries, 8);
      expect(earningsController.earnings.value.weeklyBreakdown.length, 7);
      expect(earningsController.earnings.value.weeklyBreakdown.first.amount, 1100.00);
    });

    test('Completing delivery credits ETB balance and records transaction', () {
      final initialBalance = earningsController.earnings.value.availableBalance;
      final task = DriverMockData.activeDeliveryTask;
      earningsController.recordCompletedDelivery(task);

      expect(
        earningsController.earnings.value.availableBalance,
        initialBalance + task.totalPayout,
      );
      expect(earningsController.earnings.value.recentCompleted.first.orderNumber, task.orderNumber);
    });

    test('depositToWallet rejects invalid or zero amounts', () async {
      final resZero = await earningsController.depositToWallet(amount: 0);
      expect(resZero, false);
      final resNeg = await earningsController.depositToWallet(amount: -50);
      expect(resNeg, false);
    });

    testWidgets('WalletDepositScreen renders Chapa payment UI without Ebirr or CBE', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: WalletDepositScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Aligned with delivery_app: Top-up Wallet, Quick amounts, Custom amount, Secured with Chapa
      expect(find.text('Top-up Wallet'), findsWidgets);
      expect(find.text('Choose an amount to add to your balance:'), findsOneWidget);
      expect(find.text('+100 Br'), findsOneWidget);
      expect(find.text('+250 Br'), findsOneWidget);
      expect(find.text('+500 Br'), findsOneWidget);
      expect(find.text('+1000 Br'), findsOneWidget);
      expect(find.text('Custom Amount'), findsOneWidget);
      expect(find.text('Secured with Chapa Payment Gateway'), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsOneWidget);

      // Verify no obsolete Ebirr, CBEBirr, Telebirr options exist
      expect(find.text('EBIRR-Kaafi'), findsNothing);
      expect(find.text('CBEBirr'), findsNothing);
      expect(find.text('Enter PIN'), findsNothing);
    });

    testWidgets('showTopUpDialog launches Chapa modal dialog aligned with delivery_app', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EarningsController.showTopUpDialog(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Top-up Wallet'), findsOneWidget);
      expect(find.text('Choose an amount to add to your balance:'), findsOneWidget);
      expect(find.text('+100 Br'), findsOneWidget);
      expect(find.text('Secured with Chapa Payment Gateway'), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsOneWidget);

      // Verify selecting quick amount chips updates the custom amount text field
      await tester.tap(find.text('+500 Br'));
      await tester.pumpAndSettle();
      expect(find.text('500'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Top-up Wallet'), findsNothing);
    });
  });

  group('ProfileController Tests', () {
    late ProfileController profileController;

    setUp(() {
      Get.reset();
      profileController = ProfileController();
    });

    tearDown(() {
      Get.reset();
    });

    test('Navigation provider selection updates profile state', () {
      expect(profileController.profile.value.navigationApp, 'Google Maps');
      profileController.setNavigationApp('Waze');
      expect(profileController.profile.value.navigationApp, 'Waze');
    });

    test('Auto-accept toggle updates profile', () {
      final initial = profileController.profile.value.autoAcceptOrders;
      profileController.toggleAutoAccept(!initial);
      expect(profileController.profile.value.autoAcceptOrders, !initial);
    });
  });

  group('ThemeController Tests', () {
    late ThemeController themeController;

    setUp(() {
      Get.reset();
      themeController = ThemeController();
      Get.put(themeController);
    });

    tearDown(() {
      Get.reset();
    });

    test('Default theme is light mode', () {
      expect(themeController.themeMode, ThemeMode.light);
      expect(themeController.isDarkMode, false);
    });

    test('toggleTheme switches between light and dark mode', () {
      expect(themeController.isDarkMode, false);
      themeController.toggleTheme();
      expect(themeController.isDarkMode, true);
      expect(themeController.themeMode, ThemeMode.dark);

      themeController.toggleTheme();
      expect(themeController.isDarkMode, false);
      expect(themeController.themeMode, ThemeMode.light);
    });

    test('setDarkMode updates theme accurately', () {
      themeController.setDarkMode(true);
      expect(themeController.isDarkMode, true);
      expect(themeController.themeMode, ThemeMode.dark);
      themeController.setDarkMode(false);
      expect(themeController.isDarkMode, false);
      expect(themeController.themeMode, ThemeMode.light);
    });
  });

  testWidgets('AMN Driver full UI navigation & ETB badge check', (WidgetTester tester) async {
    addTearDown(() => Get.reset());
    SharedPreferences.setMockInitialValues({
      'driver_auth_token': 'mock_driver_token_123',
      'driver_id': 'DRV-1029',
      'driver_name': 'Dawit Tadesse',
      'driver_is_online': true,
    });
    await StorageConfig.init();

    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    // Verify Active & Ready badge is removed
    expect(find.text('Active & Ready'), findsNothing);

    // Verify ETB metrics cards
    expect(find.text('ETB 0.00'), findsOneWidget);
    expect(find.text("Today's Earnings"), findsOneWidget);

    // Verify Destinations floating button on map canvas
    expect(find.byTooltip('Street Pickup'), findsOneWidget);

    // Open side bar (drawer) where bottom navigation items were moved
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify Navigation Items moved to side bar
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Incoming Job Offer on-demand notification flow: Accept vs Let Pass', (WidgetTester tester) async {
    addTearDown(() => Get.reset());
    SharedPreferences.setMockInitialValues({
      'driver_auth_token': 'mock_driver_token_123',
      'driver_id': 'DRV-1029',
      'driver_name': 'Dawit Tadesse',
      'driver_is_online': true,
    });
    await StorageConfig.init();

    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    final dashCtrl = Get.find<DriverDashboardController>();

    // Trigger incoming offer notification
    dashCtrl.triggerIncomingOffer();
    await tester.pumpAndSettle();

    // Verify Incoming Job Offer Sheet (Photo 4)
    expect(find.text('Incoming Dispatch Offer'), findsOneWidget);
    expect(find.text('Accept job'), findsOneWidget);
    expect(find.text('Let it pass'), findsOneWidget);
    expect(find.textContaining('High demand'), findsOneWidget);

    // Test "Let it pass" action
    await tester.tap(find.text('Let it pass'));
    await tester.pumpAndSettle();

    // Confirm offer is dismissed and driver is returned to map
    expect(find.text('Incoming Dispatch Offer'), findsNothing);
    expect(find.text('Accept job'), findsNothing);
    expect(dashCtrl.incomingOffer.value, isNull);

    // Trigger offer again to test "Accept job"
    dashCtrl.triggerIncomingOffer();
    await tester.pumpAndSettle();
    expect(find.text('Accept job'), findsOneWidget);

    await tester.tap(find.text('Accept job'));
    await tester.pumpAndSettle();

    // Confirm offer accepted and transitioned
    expect(dashCtrl.incomingOffer.value, isNull);
  });

  testWidgets('AMN Driver narrow screen responsiveness check (320px width)', (WidgetTester tester) async {
    addTearDown(() => Get.reset());
    SharedPreferences.setMockInitialValues({
      'driver_auth_token': 'mock_driver_token_123',
      'driver_id': 'DRV-1029',
      'driver_name': 'Dawit Tadesse',
      'driver_is_online': true,
    });
    await StorageConfig.init();

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AmnDriverApp());
    await tester.pumpAndSettle();

    // Confirm dashboard layout without any overflow
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Open drawer and switch to Settings (Driver profile and operations)
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('DRIVER SETTINGS'), findsOneWidget);

    // Go back and open Wallet from drawer
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Driver drawer Contact Support dialog shows hotline 8896 and info@amnplc.com without Telegram', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          drawer: DriverAppDrawer(profile: DriverProfile.fromStorage()),
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              child: const Text('Open Drawer'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    // Tap Contact us in drawer
    final contactFinder = find.text('Contact us');
    expect(contactFinder, findsOneWidget);
    await tester.tap(contactFinder);
    await tester.pumpAndSettle();

    // Verify hotline 8896 and email info@amnplc.com
    expect(find.text('Phone Hotline: 8896'), findsOneWidget);
    expect(find.text('info@amnplc.com'), findsOneWidget);

    // Verify Telegram is removed
    expect(find.textContaining('Telegram'), findsNothing);
    expect(find.textContaining('@AMNDriverSupport'), findsNothing);

    // Dismiss dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Phone Hotline: 8896'), findsNothing);
  });

  group('IncomingJobOffer Notification Payload & Token Registration Tests', () {
    setUp(() {
      Get.reset();
      StorageConfig.setActiveOrderId(null);
      StorageConfig.setIsOnline(true);
    });

    tearDown(() {
      StorageConfig.setActiveOrderId(null);
      Get.reset();
    });
    test('IncomingJobOffer.fromNotificationPayload correctly parses order dispatch data', () {
      final payload = {
        'id': '45',
        'order_id': '45',
        'order_number': 'AMN-45',
        'property_name': 'Bole Fresh Grocery',
        'location': 'Bole Atlas, Addis Ababa',
        'total_km_price': '65',
        'payment_type': '0',
        'service_category': 'Economy',
        'property_latitude': '8.996878',
        'property_longitude': '38.772777',
        'customer_latitude': '9.0054',
        'customer_longitude': '38.7636',
      };

      final offer = IncomingJobOffer.fromNotificationPayload(payload);
      expect(offer.id, '45');
      expect(offer.orderNumber, 'AMN-45');
      expect(offer.pickupName, 'Bole Fresh Grocery');
      expect(offer.dropoffName, 'Bole Atlas, Addis Ababa');
      expect(offer.fareAmount, 65.0);
      expect(offer.paymentMethod, 'Cash');
      expect(offer.serviceCategory, 'Economy');
      expect(offer.pickupLatitude, 8.996878);
      expect(offer.pickupLongitude, 38.772777);
      expect(offer.dropoffLatitude, 9.0054);
      expect(offer.dropoffLongitude, 38.7636);
    });

    test('IncomingJobOffer.fromNotificationPayload handles partial or fallback payloads', () {
      final emptyPayload = <String, dynamic>{};
      final fallbackOffer = IncomingJobOffer.fromNotificationPayload(emptyPayload);
      expect(fallbackOffer.pickupName, 'Bole Fresh Grocery');
      expect(fallbackOffer.fareAmount, 65.0);
      expect(fallbackOffer.paymentMethod, 'Cash');
    });

    test('IncomingJobOffer.fromNotificationPayload correctly parses Courier orders and strips currency text', () {
      final courierPayload = <String, dynamic>{
        'order_id': 14,
        'title': 'New Courirre Order',
        'payment': '174 Birr',
        'from': 'Bole Medhanealem',
        'to': 'Kality Menaharia',
        'sender_user_id': 2,
        'reciver_name': 'Abel',
        'from_latitude': '9.0178',
        'from_longtude': '38.6712',
        'to_latitude': '8.9815',
        'to_longtude': '38.6976',
      };

      final offer = IncomingJobOffer.fromNotificationPayload(courierPayload);
      expect(offer.id, '14');
      expect(offer.orderNumber, 'AMN-14');
      expect(offer.orderType, 'courier');
      expect(offer.isCourier, isTrue);
      expect(offer.fareAmount, 174.0);
      expect(offer.customerId, 2);
      expect(offer.pickupName, 'Bole Medhanealem');
      expect(offer.dropoffName, 'Abel');
    });

    test('Accepting a courier job offer sets task orderType to courier and persists active state without collision', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final dashCtrl = Get.put<DriverDashboardController>(DriverDashboardController());
      dashCtrl.isOnline.value = true;
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId(null);

      final courierOffer = IncomingJobOffer(
        id: '14',
        orderNumber: 'AMN-14',
        orderType: 'courier',
        pickupName: 'Bole Medhanealem',
        pickupAddress: 'Bole, Addis Ababa',
        pickupLatitude: 9.0178,
        pickupLongitude: 38.6712,
        dropoffName: 'Kality Menaharia',
        dropoffAddress: 'Kality, Addis Ababa',
        dropoffLatitude: 8.9815,
        dropoffLongitude: 38.6976,
        fareAmount: 174.0,
        dropoffMinutes: 20,
        distanceKm: 8.5,
        customerId: 2,
      );

      dashCtrl.triggerIncomingOffer(courierOffer);
      expect(dashCtrl.incomingOffer.value, isNotNull);
      expect(dashCtrl.incomingOffer.value!.isCourier, isTrue);

      dashCtrl.acceptIncomingOffer();
      expect(dashCtrl.incomingOffer.value, isNull);
      expect(dashCtrl.activeAcceptedTask.value, isNotNull);
      expect(dashCtrl.activeAcceptedTask.value!.id, '14');
      expect(dashCtrl.activeAcceptedTask.value!.orderType, 'courier');
      expect(dashCtrl.activeAcceptedTask.value!.isCourier, isTrue);
      expect(dashCtrl.activeAcceptedTask.value!.customerId, 2);
      expect(StorageConfig.getActiveOrderType(), 'courier');
      expect(StorageConfig.getActiveOrderId(), '14');

      StorageConfig.setActiveOrderId(null);
      dashCtrl.activeAcceptedTask.value = null;
      dashCtrl.onClose();
    });

    test('NotificationService endpoint configuration is set to Samuel notification server', () {
      expect(
        NotificationService.notificationTokenEndpoint,
        'https://notification.amnplc.com/api/driver-tokens',
      );
      expect(
        NotificationService.customerOrderStatusEndpoint,
        'https://notification.amnplc.com/api/push/customer-order-status',
      );
      expect(
        NotificationService.storeOwnerNotificationEndpoint,
        'https://notification.amnplc.com/api/push/Store-owner-notification',
      );
    });

    test('When driver is offline, incoming order notifications and offers are silenced and hidden', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final dashCtrl = Get.put<DriverDashboardController>(DriverDashboardController());

      // Driver is offline
      dashCtrl.isOnline.value = false;
      StorageConfig.setIsOnline(false);

      final payload = {
        'order_id': '50',
        'from': 'Hilton Addis',
        'to': 'Bole Atlas',
        'payment': '380.00',
      };

      NotificationService.dispatchIncomingOffer(payload);

      // Offer must remain hidden and driver must remain offline
      expect(dashCtrl.incomingOffer.value, isNull);
      expect(dashCtrl.isOnline.value, isFalse);
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      dashCtrl.onClose();
    });

    test('Notification tap when app is online restores dashboard and presents IncomingJobOffer', () {
      final navCtrl = Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final dashCtrl = Get.put<DriverDashboardController>(DriverDashboardController());

      // Driver is online and navigating on another tab
      dashCtrl.isOnline.value = true;
      StorageConfig.setIsOnline(true);
      navCtrl.setIndex(1);
      expect(navCtrl.selectedIndex.value, 1);
      expect(dashCtrl.incomingOffer.value, isNull);

      // Notification arrives from Samuel's notification server
      final payload = {
        'order_id': '50',
        'from': 'Hilton Addis',
        'to': 'Bole Atlas',
        'payment': '380.00',
      };

      NotificationService.dispatchIncomingOffer(payload);

      // Verify dashboard was restored to tab 0
      expect(navCtrl.selectedIndex.value, 0);
      expect(dashCtrl.isOnline.value, true);
      // Verify incoming offer is set with payload data
      expect(dashCtrl.incomingOffer.value, isNotNull);
      expect(dashCtrl.incomingOffer.value?.id, '50');
      expect(dashCtrl.incomingOffer.value?.pickupName, 'Hilton Addis');
      expect(dashCtrl.incomingOffer.value?.dropoffName, 'Bole Atlas');
      expect(dashCtrl.incomingOffer.value?.fareAmount, 380.00);

      dashCtrl.onClose();
    });

    test('App lifecycle resume event consumes queued pendingIncomingOffer', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final dashCtrl = Get.put<DriverDashboardController>(DriverDashboardController());
      dashCtrl.isOnline.value = true;
      StorageConfig.setIsOnline(true);

      // Simulate offer queued while app was inactive/backgrounded
      final pendingOffer = IncomingJobOffer.fromNotificationPayload({
        'order_id': '51',
        'from': 'Radisson Blu',
        'to': 'Kazanchis Total',
        'payment': '420.00',
      });
      NotificationService.pendingIncomingOffer = pendingOffer;

      // App transitions from inactive back to resumed
      dashCtrl.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(NotificationService.pendingIncomingOffer, isNull);
      expect(dashCtrl.incomingOffer.value, isNotNull);
      expect(dashCtrl.incomingOffer.value?.id, '51');
      expect(dashCtrl.incomingOffer.value?.pickupName, 'Radisson Blu');

      dashCtrl.onClose();
    });

    test('NotificationService un-nests data payload correctly when received from FCM', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final dashCtrl = Get.put<DriverDashboardController>(DriverDashboardController());
      dashCtrl.isOnline.value = true;
      StorageConfig.setIsOnline(true);

      final nestedPayload = {
        'title': 'New Delivery Alert',
        'body': 'Tap to view details',
        'data': {
          'order_id': '52',
          'from': 'Sheraton Addis',
          'to': 'Piazza',
          'payment': '500.00',
        }
      };

      NotificationService.dispatchIncomingOffer(nestedPayload);

      expect(dashCtrl.incomingOffer.value, isNotNull);
      expect(dashCtrl.incomingOffer.value?.id, '52');
      expect(dashCtrl.incomingOffer.value?.pickupName, 'Sheraton Addis');
      expect(dashCtrl.incomingOffer.value?.dropoffName, 'Piazza');
      expect(dashCtrl.incomingOffer.value?.fareAmount, 500.00);

      dashCtrl.onClose();
    });
  });

  group('Order Notification Ringtone & Vibration Alert Tests', () {
    setUp(() {
      Get.reset();
      OrderAlertService.instance.stopRinging();
      StorageConfig.setActiveOrderId(null);
      StorageConfig.setIsOnline(true);
    });

    tearDown(() {
      OrderAlertService.instance.stopRinging();
      StorageConfig.setActiveOrderId(null);
      Get.reset();
    });

    test('OrderAlertService starts and stops ringing state reactively', () async {
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      await OrderAlertService.instance.startRinging();
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      await OrderAlertService.instance.stopRinging();
      expect(OrderAlertService.instance.isRinging.value, isFalse);
    });

    test('OrderAlertService toggling sound and vibration preferences works correctly', () async {
      await OrderAlertService.instance.setSoundEnabled(false);
      expect(OrderAlertService.instance.soundEnabled.value, isFalse);

      await OrderAlertService.instance.setSoundEnabled(true);
      expect(OrderAlertService.instance.soundEnabled.value, isTrue);

      await OrderAlertService.instance.setVibrationEnabled(false);
      expect(OrderAlertService.instance.vibrationEnabled.value, isFalse);

      await OrderAlertService.instance.setVibrationEnabled(true);
      expect(OrderAlertService.instance.vibrationEnabled.value, isTrue);
    });

    test('NotificationService order notification detection and dedicated channel key', () {
      expect(NotificationService.orderAlertChannelKey, 'driver_order_alerts');
      expect(NotificationService.promoChannelKey, 'driver_promotions');
      expect(NotificationService.channelKey, 'driver_notifications');

      // Test payload recognition for normal orders
      expect(
        NotificationService.isOrderNotification({'order_id': '101', 'fare': '250'}),
        isTrue,
      );
      expect(
        NotificationService.isOrderNotification({'type': 'new_order_assigned'}),
        isTrue,
      );
      expect(
        NotificationService.isOrderNotification({}, 'Incoming Delivery Order', 'New pickup request'),
        isFalse,
      );

      // Test payload recognition for courier orders
      expect(
        NotificationService.isOrderNotification({'order_id': '201', 'order_type': 'courier', 'receiver_name': 'Abebe'}),
        isTrue,
      );
      expect(
        NotificationService.isOrderNotification({'order_id': '202', 'type': 'courier_order'}),
        isTrue,
      );
      expect(
        NotificationService.isOrderNotification({}, 'New Courier Order Assigned', 'Package delivery from Bole to Piassa'),
        isFalse,
      );

      // Test payload recognition for corporate orders
      expect(
        NotificationService.isOrderNotification({'order_id': '301', 'order_type': 'corporate', 'company_name': 'Ethio Telecom'}),
        isTrue,
      );
      expect(
        NotificationService.isOrderNotification({'order_id': '302', 'type': 'corporate_order'}),
        isTrue,
      );
      expect(
        NotificationService.isOrderNotification({}, 'Corporate Order Dispatch', 'Deliver documents to Kazanchis office'),
        isFalse,
      );

      // Test bulk notifications and non-order payloads do NOT trigger as orders
      expect(
        NotificationService.isOrderNotification({'type': 'bulk', 'message': 'Announcement to all drivers'}),
        isFalse,
      );
      expect(
        NotificationService.isOrderNotification({'type': 'broadcast', 'title': 'Road Closure', 'body': 'Meskel Square closed'}),
        isFalse,
      );
      expect(
        NotificationService.isOrderNotification({'type': 'announcement', 'title': 'Weekly Bonus'}),
        isFalse,
      );
      expect(
        NotificationService.isOrderNotification({'type': 'general', 'title': 'Driver Guidelines'}),
        isFalse,
      );
      expect(
        NotificationService.isOrderNotification({'type': 'system', 'title': 'System Maintenance'}),
        isFalse,
      );
      expect(
        NotificationService.isOrderNotification({}, 'AMN Delivery Notice', 'Dear delivery driver, please submit renewed license.'),
        isFalse,
      );
      expect(
        NotificationService.isOrderNotification({}),
        isFalse,
      );
    });

    test('Promotional notifications are strictly separated and do NOT trigger as orders', () {
      // 1. Explicit promotion types
      expect(
        NotificationService.isPromotionNotification({'type': 'promotion', 'title': '20% off', 'body': 'Get discounts'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'type': 'promotions'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'type': 'promotional'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'type': 'promo', 'promo_code': 'SAVE100'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'type': 'campaign', 'title': 'Weekend incentive'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'type': 'discount', 'title': 'Fuel discount'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'type': 'bonus', 'title': 'Driver incentive'}),
        isTrue,
      );

      // 2. Explicit boolean flags in payload
      expect(
        NotificationService.isPromotionNotification({'is_promo': true, 'title': 'Special Event'}),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({'is_promotion': 'true'}),
        isTrue,
      );

      // 3. Text indicators in Title/Body
      expect(
        NotificationService.isPromotionNotification({}, 'Exclusive Promo Code', 'Use DRIVER50 for savings'),
        isTrue,
      );
      expect(
        NotificationService.isPromotionNotification({}, 'Weekend Bonus', 'Earn extra cash this weekend'),
        isTrue,
      );

      // 4. Promotional notifications that mention "orders" MUST NOT be recognized as orders!
      final promoWithOrderWords = {
        'type': 'promotion',
        'title': 'New Order Bonus Promotion!',
        'body': 'Complete 5 delivery orders today to earn a 500 ETB cash bonus!',
      };
      expect(NotificationService.isPromotionNotification(promoWithOrderWords), isTrue);
      expect(NotificationService.isOrderNotification(promoWithOrderWords), isFalse);

      final promoCourierWords = {
        'is_promo': true,
        'title': 'Courier Order Incentive Campaign',
        'body': 'Get double points on all courier orders this week!',
      };
      expect(NotificationService.isPromotionNotification(promoCourierWords), isTrue);
      expect(NotificationService.isOrderNotification(promoCourierWords), isFalse);
    });

    test('Bulk notifications and promotional offers do NOT trigger ringtone or incoming offer', () {
      Get.reset();
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId('');
      OrderAlertService.instance.stopRinging();

      final navCtrl = Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;

      // Simulate receiving a bulk notification without order info
      final bulkPayload = {
        'type': 'bulk',
        'title': 'AMN Delivery Notice',
        'body': 'Weekly bonuses will be disbursed tomorrow morning.',
      };

      NotificationService.dispatchIncomingOffer(bulkPayload);

      // Verify ringtone was NOT triggered and no incoming offer sheet was presented
      expect(OrderAlertService.instance.isRinging.value, isFalse);
      expect(controller.incomingOffer.value, isNull);
      expect(NotificationService.pendingIncomingOffer, isNull);

      // Simulate receiving a promotional notification with order words
      final promoPayload = {
        'type': 'promotion',
        'title': 'New Order Promotion',
        'body': 'Complete your new orders to earn 200 ETB extra.',
      };

      NotificationService.dispatchIncomingOffer(promoPayload);

      expect(OrderAlertService.instance.isRinging.value, isFalse);
      expect(controller.incomingOffer.value, isNull);
      expect(NotificationService.pendingIncomingOffer, isNull);

      navCtrl.onClose();
      controller.onClose();
      Get.reset();
    });

    test('Courier and Corporate order notifications trigger incoming offer and ringtone', () {
      Get.reset();
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId('');
      OrderAlertService.instance.stopRinging();

      final navCtrl = Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;

      // 1. Dispatch Courier Order
      final courierPayload = {
        'order_id': '9941',
        'order_number': 'AMN-CR-9941',
        'order_type': 'courier',
        'type': 'courier_order',
        'from_address': 'Bole, Addis Ababa',
        'to_address': 'Kazanchis, Addis Ababa',
        'receiver_name': 'Tadesse Gemechu',
        'fare_amount': '250.0',
        'total_price': '250.0',
        'distance_km': '6.4',
        'dropoff_minutes': '20',
      };

      NotificationService.dispatchIncomingOffer(courierPayload);

      expect(controller.incomingOffer.value, isNotNull);
      expect(controller.incomingOffer.value!.isCourier, isTrue);
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      // Dismiss courier offer -> stops ringing
      controller.dismissIncomingOffer();
      expect(OrderAlertService.instance.isRinging.value, isFalse);
      expect(controller.incomingOffer.value, isNull);

      // 2. Dispatch Corporate Order
      final corporatePayload = {
        'order_id': '8842',
        'order_number': 'AMN-CORP-8842',
        'order_type': 'corporate',
        'type': 'corporate_order',
        'pickup_name': 'Commercial Bank of Ethiopia',
        'pickup_address': 'Churchill Rd, Addis Ababa',
        'dropoff_name': 'Bole Medhanealem Branch',
        'dropoff_address': 'Bole, Addis Ababa',
        'fare_amount': '550.0',
        'total_price': '550.0',
        'distance_km': '8.2',
        'dropoff_minutes': '25',
      };

      NotificationService.dispatchIncomingOffer(corporatePayload);

      expect(controller.incomingOffer.value, isNotNull);
      expect(controller.incomingOffer.value!.isCorporate, isTrue);
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      // Dismiss corporate offer -> stops ringing
      controller.dismissIncomingOffer();
      expect(OrderAlertService.instance.isRinging.value, isFalse);
      expect(controller.incomingOffer.value, isNull);

      navCtrl.onClose();
      controller.onClose();
      Get.reset();
    });

    test('DriverDashboardController triggers ringtone and vibration on incoming offer, stops on accept/dismiss', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());

      expect(OrderAlertService.instance.isRinging.value, isFalse);

      // Trigger incoming job offer
      controller.triggerIncomingOffer();
      expect(controller.incomingOffer.value, isNotNull);
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      // Driver lets offer pass (dismiss) -> ringing must stop
      controller.dismissIncomingOffer();
      expect(controller.incomingOffer.value, isNull);
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      // Trigger again and accept -> ringing must stop
      controller.triggerIncomingOffer();
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      controller.acceptIncomingOffer();
      expect(controller.incomingOffer.value, isNull);
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      controller.onClose();
    });

    test('IncomingJobOffer defaults to 2 minutes (120 seconds) acceptance countdown', () {
      final offer = IncomingJobOffer.sample();
      expect(offer.totalDurationSeconds, 120);
      expect(offer.remainingSeconds, inInclusiveRange(119, 120));
      expect(offer.isExpired, isFalse);
    });

    test('Tapping notification within 2 minutes resumes countdown with remaining time', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId(null);

      // Simulate notification received 35 seconds ago
      final sentAt = DateTime.now().subtract(const Duration(seconds: 35));
      final payload = {
        'order_id': '88',
        'from': 'Bole Atlas Cafe',
        'to': 'Kazanchis',
        'payment': '350.00',
        'received_at': sentAt.millisecondsSinceEpoch.toString(),
        'duration_seconds': '120',
      };

      NotificationService.dispatchIncomingOffer(payload);

      expect(controller.incomingOffer.value, isNotNull);
      expect(controller.incomingOffer.value?.id, '88');
      expect(controller.incomingOffer.value?.totalDurationSeconds, 120);
      // Countdown should resume with elapsed time deducted (~85 seconds remaining, allowing for test execution variance)
      expect(controller.offerRemainingSeconds.value, inInclusiveRange(83, 85));

      controller.onClose();
    });

    test('Tapping notification after 2 minutes (> 120 seconds) treats offer as expired', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId(null);

      // Simulate notification received 130 seconds ago (expired)
      final sentAt = DateTime.now().subtract(const Duration(seconds: 130));
      final payload = {
        'order_id': '89',
        'from': 'Old Airport',
        'to': 'Bole Medhanialem',
        'payment': '280.00',
        'received_at': sentAt.millisecondsSinceEpoch.toString(),
        'duration_seconds': '120',
      };

      NotificationService.dispatchIncomingOffer(payload);

      // Offer must not be shown because 2 minutes have expired
      expect(controller.incomingOffer.value, isNull);
      expect(NotificationService.pendingIncomingOffer, isNull);

      controller.onClose();
    });

    test('Resuming app from background synchronizes active offer countdown based on real time elapsed', () {
      Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId(null);

      // Start offer received 10 seconds ago
      final receivedAt = DateTime.now().subtract(const Duration(seconds: 10));
      final offer = IncomingJobOffer.sample(receivedAt: receivedAt);
      controller.triggerIncomingOffer(offer);

      expect(controller.offerRemainingSeconds.value, inInclusiveRange(109, 110));

      // Simulate app was in background and 25 more seconds elapsed (35 total elapsed)
      final laterOffer = IncomingJobOffer.sample(
        receivedAt: DateTime.now().subtract(const Duration(seconds: 35)),
      );
      controller.incomingOffer.value = laterOffer;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(controller.offerRemainingSeconds.value, inInclusiveRange(83, 85));

      controller.onClose();
    });

    test('Once driver accepts an order, active order lock is set, tabs are locked, and subsequent offers are hidden', () {
      final navCtrl = Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId(null);

      // 1. Initial state: no active order lock
      expect(StorageConfig.hasActiveOrder(), isFalse);
      expect(controller.hasActiveAcceptedOrder, isFalse);

      // 2. Trigger and accept an offer
      controller.triggerIncomingOffer();
      expect(controller.incomingOffer.value, isNotNull);
      controller.acceptIncomingOffer();

      // 3. Active order lock is activated
      expect(StorageConfig.hasActiveOrder(), isTrue);
      expect(controller.hasActiveAcceptedOrder, isTrue);

      // 4. Tab switching is blocked while active order is in progress
      navCtrl.selectedIndex.value = 0;
      navCtrl.setIndex(1);
      // Index must remain 0 because tab switching is blocked
      expect(navCtrl.selectedIndex.value, 0);

      navCtrl.setIndex(2);
      expect(navCtrl.selectedIndex.value, 0);

      // 5. Subsequent incoming order notifications must be silenced and hidden
      final newOfferPayload = {
        'order_id': '999',
        'from': 'Another Restaurant',
        'to': 'Somewhere Else',
        'payment': '450.00',
      };
      NotificationService.dispatchIncomingOffer(newOfferPayload);
      expect(controller.incomingOffer.value, isNull);
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      // 6. Complete delivery unlocks driver
      StorageConfig.setActiveOrderId(null);
      controller.activeAcceptedTask.value = null;
      expect(StorageConfig.hasActiveOrder(), isFalse);
      expect(controller.hasActiveAcceptedOrder, isFalse);

      // Navigation is now unlocked
      navCtrl.setIndex(1);
      expect(navCtrl.selectedIndex.value, 1);

      controller.onClose();
    });

    test('Declining incoming offer clears directions and resets dashboard state', () {
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;

      controller.triggerIncomingOffer();
      expect(controller.incomingOffer.value, isNotNull);
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      // Decline offer
      controller.dismissIncomingOffer();
      expect(controller.incomingOffer.value, isNull);
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      controller.onClose();
    });

    test('checkPendingOfferFromStorage resumes order saved during background notification and starts alert', () async {
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      await StorageConfig.init();
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId('');
      OrderAlertService.instance.stopRinging();

      final navCtrl = Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;

      // Simulate background isolate saving pending order to SharedPreferences
      final pendingMap = {
        'order_id': '7789',
        'order_number': 'AMN-7789',
        'order_type': 'delivery',
        'type': 'new_order_assigned',
        'pickup_name': 'Pizza Hut Bole',
        'dropoff_name': 'Abebe',
        'fare_amount': '280.0',
        'distance_km': '5.0',
        'dropoff_minutes': '15',
        'received_at': DateTime.now().millisecondsSinceEpoch.toString(),
        'duration_seconds': '120',
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_pending_order_payload', jsonEncode(pendingMap));

      // Resume app or trigger checkPendingOfferFromStorage
      await NotificationService.checkPendingOfferFromStorage();

      expect(controller.incomingOffer.value, isNotNull);
      expect(controller.incomingOffer.value!.id, '7789');
      expect(OrderAlertService.instance.isRinging.value, isTrue);

      // Verify the storage key was cleaned up so it does not trigger again
      expect(prefs.getString('driver_pending_order_payload'), isNull);

      controller.dismissIncomingOffer();
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      navCtrl.onClose();
      controller.onClose();
      Get.reset();
    });

    test('Promotional notifications stored in pending storage are ignored and do NOT trigger alert', () async {
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      await StorageConfig.init();
      StorageConfig.setIsOnline(true);
      StorageConfig.setActiveOrderId('');
      OrderAlertService.instance.stopRinging();

      final navCtrl = Get.put<MainDriverNavigationController>(MainDriverNavigationController());
      final controller = Get.put<DriverDashboardController>(DriverDashboardController());
      controller.isOnline.value = true;

      final promoMap = {
        'type': 'promotion',
        'title': 'Driver Bonus Day!',
        'body': 'Deliver 3 orders today and get 300 ETB bonus!',
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_pending_order_payload', jsonEncode(promoMap));

      await NotificationService.checkPendingOfferFromStorage();

      // Must NOT ring and must NOT show incoming offer
      expect(controller.incomingOffer.value, isNull);
      expect(OrderAlertService.instance.isRinging.value, isFalse);

      navCtrl.onClose();
      controller.onClose();
      Get.reset();
    });
  });

  group('Operating City Dropdown & Registration Tests', () {
    test('CityModel maps backend response names without id field to canonical IDs', () {
      final rawBackendJson = {
        'name': 'Addis Ababa',
        'currency': 'ETB',
        'currency_id': '1',
      };
      final city = CityModel.fromJson(rawBackendJson);
      expect(city.id, 1);
      expect(city.name, 'Addis Ababa');

      final hawassa = CityModel.fromJson({'name': 'Hawassa'});
      expect(hawassa.id, 2);

      final adama = CityModel.fromJson({'name': 'Adama'});
      expect(adama.id, 15);

      final djibouti = CityModel.fromJson({'name': 'Djibouti'});
      expect(djibouti.id, 17);
    });

    test('selectedCityId starts as null with no default selection on loadRegistrationMetadata', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageConfig.init();
      Get.delete<DriverAuthController>(force: true);
      final authCtrl = Get.put<DriverAuthController>(DriverAuthController());

      expect(authCtrl.selectedCityId.value, isNull);

      await authCtrl.loadRegistrationMetadata();

      // Ensure no default selection is forced: it must remain null so hint shows
      expect(authCtrl.selectedCityId.value, isNull);
      expect(authCtrl.cities.isNotEmpty, isTrue);

      // Test selection of a city
      final firstCity = authCtrl.cities.first;
      authCtrl.selectedCityId.value = firstCity.id;
      expect(authCtrl.selectedCityId.value, greaterThan(0));

      authCtrl.onClose();
    });
  });
}
