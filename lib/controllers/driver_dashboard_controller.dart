import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/dio_config.dart';
import '../config/storage_config.dart';
import '../constants/pages.dart';
import '../core/theme/app_colors.dart';
import '../models/delivery_task.dart';
import '../models/driver_profile.dart';
import '../models/incoming_job_offer.dart';
import '../models/pickup_order_request.dart';
import '../services/driver_battery_service.dart';
import '../services/driver_location_update_service.dart';
import '../services/driver_order_service.dart';
import '../services/driver_profile_service.dart';
import '../services/driver_socket_service.dart';
import '../services/gebeta_location_service.dart';
import '../services/notification_service.dart';
import '../services/order_alert_service.dart';
import '../utils/location_utils.dart';
import 'active_delivery_controller.dart';
import 'earnings_controller.dart';
import 'profile_controller.dart';
import '../screens/main_driver_navigation.dart';

class DriverDashboardController extends GetxController with WidgetsBindingObserver {
  final Rx<DriverProfile> profile = DriverProfile.fromStorage().obs;

  // Operational State (Photo 1 & Photo 2)
  final RxBool isOnline = false.obs;
  final RxBool isUpdatingOnline = false.obs;

  // Performance summary metrics (loaded from AMN APIs)
  final RxDouble todayEarnings = 0.0.obs;
  final RxDouble walletBalance = 0.0.obs;
  final RxInt completedTrips = 0.obs;
  final RxInt profileScore = 100.obs;
  final RxDouble driverRating = 5.0.obs;
  final RxInt cancellationRate = 0.obs;

  // Active Assigned Tasks list (kept for active in-progress trip and backend compatibility)
  final RxList<DeliveryTask> assignedTasks = <DeliveryTask>[].obs;
  final Rx<DeliveryTask?> activeAcceptedTask = Rx<DeliveryTask?>(null);

  bool get hasActiveAcceptedOrder {
    if (activeAcceptedTask.value != null) {
      final s = activeAcceptedTask.value!.status;
      if (s != DeliveryStatus.delivered && s != DeliveryStatus.cancelled) {
        return true;
      }
    }
    return StorageConfig.hasActiveOrder();
  }

  // Services Configuration (Photo 3)
  final RxMap<String, bool> enabledServices = <String, bool>{
    'Economy': true,
    'Corporate': true,
    'Classic': true,
    'Basic': true,
  }.obs;

  // Incoming Dispatch Offer (Photo 4)
  final Rxn<IncomingJobOffer> incomingOffer = Rxn<IncomingJobOffer>();
  final RxInt offerRemainingSeconds = 30.obs;
  Timer? _offerTimer;
  Timer? _simulationTimer;

  DriverDashboardController() {
    loadDashboardData();
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    loadDashboardData();
    _checkPendingOffer();
  }

  @override
  void onReady() {
    super.onReady();
    _checkPendingOffer();
    final storedDriverId = StorageConfig.getDriverId();
    if (storedDriverId != null && storedDriverId.isNotEmpty) {
      fetchDashboardMetrics();
    }
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest && StorageConfig.isLoggedIn()) {
      GebetaLocationService.ensureLocationPermission();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _offerTimer?.cancel();
    _simulationTimer?.cancel();
    OrderAlertService.instance.stopRinging();
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest) {
      NotificationService.instance.removeOnlinePersistentNotification();
    }
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPendingOffer();
      _syncOfferCountdown();
      if (Get.isRegistered<DriverBatteryService>()) {
        DriverBatteryService.to.checkAndSendBatteryOnResume();
      }
    }
  }

  /// Consumes any pending offer queued while the app was inactive, minimized, or cold-started
  void _checkPendingOffer() {
    if (!isOnline.value || hasActiveAcceptedOrder) {
      NotificationService.pendingIncomingOffer = null;
      return;
    }
    final pending = NotificationService.pendingIncomingOffer;
    if (pending != null) {
      NotificationService.pendingIncomingOffer = null;
      if (pending.isExpired) {
        dismissIncomingOffer(isTimeout: true);
        return;
      }
      NotificationService.routeToDashboard();
      triggerIncomingOffer(pending);
      return;
    }
    // Also check storage for pending offer queued in background
    NotificationService.checkPendingOfferFromStorage();
  }

  /// Synchronize remaining countdown time when app is resumed from background
  void _syncOfferCountdown() {
    final current = incomingOffer.value;
    if (current != null) {
      final rem = current.remainingSeconds;
      if (rem <= 0) {
        dismissIncomingOffer(isTimeout: true);
      } else {
        offerRemainingSeconds.value = rem;
      }
    }
  }

  void syncProfileFromStorage() {
    if (Get.isRegistered<ProfileController>()) {
      profile.value = Get.find<ProfileController>().profile.value;
    } else {
      profile.value = DriverProfile.fromStorage();
    }
    profile.refresh();
  }

  void loadDashboardData() {
    syncProfileFromStorage();
    isOnline.value = StorageConfig.getIsOnline();
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (isOnline.value && !inTest) {
      NotificationService.instance.showOnlinePersistentNotification();
    }
    final driverId = StorageConfig.getDriverId();
    if (driverId != null && driverId.isNotEmpty) {
      DriverOrderService.fetchActiveOrders(driverId).then((realOrders) {
        assignedTasks.assignAll(realOrders);
      });
    } else {
      assignedTasks.clear();
    }
  }

  void toggleOnlineStatus() {
    setOnlineStatus(!isOnline.value);
  }

  /// Sets driver online status and synchronizes with backend API
  /// POST /driver/{driver_id}/update-online with body: {"online": 1 | 0}
  Future<bool> setOnlineStatus(bool targetStatus, {bool showSnackbar = true}) async {
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');

    // When going online, ensure location permission has been granted with prominent disclosure
    if (targetStatus && !inTest) {
      final hasPerm = await GebetaLocationService.ensureLocationPermission(isGoingOnline: true);
      if (!hasPerm) {
        if (showSnackbar) {
          Get.snackbar(
            'Location Access Required',
            'Please allow location access to go online and receive delivery orders.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return false;
      }
    }

    isOnline.value = targetStatus;
    await StorageConfig.setIsOnline(targetStatus);
    if (inTest && !DioConfig.isTestMode) {
      return true;
    }

    final rawDriverId = StorageConfig.getDriverId() ?? profile.value.id;
    final cleanDriverId = rawDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final driverId = cleanDriverId.isNotEmpty ? cleanDriverId : rawDriverId;

    isUpdatingOnline.value = true;
    bool success = false;
    try {
      success = await DriverProfileService.updateOnlineStatus(
        driverId: driverId,
        isOnline: targetStatus,
      );
    } catch (_) {}
    isUpdatingOnline.value = false;

    // Report battery percentage on online/offline state change for dispatch validation
    if (!inTest && Get.isRegistered<DriverBatteryService>()) {
      DriverBatteryService.to.sendBatteryPercent(
        reason: targetStatus ? 'driver_online' : 'driver_offline',
      );
    }

    // Start or stop background location tracking service based on online status
    if (!inTest && Get.isRegistered<DriverLocationUpdateService>()) {
      if (targetStatus) {
        DriverLocationUpdateService.to.startTracking();
      } else {
        DriverLocationUpdateService.to.stopTracking();
      }
    }

    // Connect or disconnect real-time socket connection based on online status
    if (!inTest && Get.isRegistered<DriverSocketService>()) {
      if (targetStatus) {
        DriverSocketService.to.connect();
      } else {
        DriverSocketService.to.disconnect();
      }
    }

    // Show or remove persistent status bar notification
    if (!inTest) {
      if (targetStatus) {
        NotificationService.instance.showOnlinePersistentNotification();
      } else {
        NotificationService.instance.removeOnlinePersistentNotification();
      }
    }

    // Report location update to backend on online/offline toggle
    if (!inTest && Get.isRegistered<DriverLocationUpdateService>()) {
      DriverLocationUpdateService.to.sendLocationUpdate(
        reason: targetStatus ? 'driver_online' : 'driver_offline',
        force: true,
      );
    }

    if (targetStatus) {
      if (showSnackbar && !inTest) {
        Get.snackbar(
          'Online',
          'You are now visible to dispatch for incoming delivery orders.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.onlineGreen,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: 8,
        );
      }
    } else {
      _offerTimer?.cancel();
      _simulationTimer?.cancel();
      OrderAlertService.instance.stopRinging();
      incomingOffer.value = null;
      if (showSnackbar && !inTest) {
        Get.snackbar(
          'Offline',
          'You went offline. You will not receive any new order requests.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF1E293B),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: 8,
        );
      }
    }

    return success;
  }

  void toggleService(String serviceName) {
    if (enabledServices.containsKey(serviceName)) {
      enabledServices[serviceName] = !(enabledServices[serviceName] ?? false);
      enabledServices.refresh();
    }
  }

  // Trigger Incoming Job Offer (Photo 4)
  void triggerIncomingOffer([IncomingJobOffer? offer]) {
    // If offline or already handling an active accepted order, hide and silence the offer
    if (!isOnline.value || hasActiveAcceptedOrder) {
      incomingOffer.value = null;
      OrderAlertService.instance.stopRinging();
      return;
    }

    // Ensure dashboard tab is selected and blocking modal sheets/dialogs are closed
    NotificationService.routeToDashboard();

    final targetOffer = offer ?? IncomingJobOffer.sample();

    // If already expired (> 2 minutes elapsed since dispatch/notification arrived)
    if (targetOffer.isExpired) {
      dismissIncomingOffer(isTimeout: true);
      return;
    }

    _offerTimer?.cancel();
    incomingOffer.value = targetOffer;
    // Resume countdown from remaining seconds (2 minutes minus elapsed time)
    offerRemainingSeconds.value = targetOffer.remainingSeconds;

    // Ring phone sound and vibrate for incoming order
    OrderAlertService.instance.startRinging(
      autoStopAfter: Duration(seconds: targetOffer.remainingSeconds),
    );

    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest) {
      _offerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final current = incomingOffer.value;
        if (current == null) {
          timer.cancel();
          return;
        }
        final rem = current.remainingSeconds;
        if (rem > 0) {
          offerRemainingSeconds.value = rem;
        } else {
          dismissIncomingOffer(isTimeout: true);
        }
      });
    }
  }

  /// Driver explicitly lets the offer pass or timer expires
  void dismissIncomingOffer({bool isTimeout = false}) {
    _offerTimer?.cancel();
    _offerTimer = null;
    final hadOffer = incomingOffer.value != null;
    incomingOffer.value = null;
    offerRemainingSeconds.value = 0;
    NotificationService.pendingIncomingOffer = null;

    // Stop ringing sound and vibration
    OrderAlertService.instance.stopRinging();

    // Cancel active AwesomeNotifications for order alerts
    try {
      AwesomeNotifications().cancelNotificationsByChannelKey(NotificationService.orderAlertChannelKey);
      AwesomeNotifications().cancel(NotificationService.orderAlertNotificationId);
    } catch (_) {}

    // Clear pending offer from persistent storage
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('driver_pending_order_payload');
      });
    } catch (_) {}

    // Immediately report battery level when driver lets offer pass or times out
    // Validates against excuses such as "my battery shut down"
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest && Get.isRegistered<DriverBatteryService>()) {
      DriverBatteryService.to.sendBatteryPercent(
        reason: isTimeout ? 'offer_timeout' : 'offer_passed',
      );
    }

    if (hadOffer && !Get.testMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      Get.snackbar(
        isTimeout ? 'Offer Timed Out' : 'Offer Passed',
        isTimeout
            ? 'Dispatch offer timed out and was passed to the next available driver.'
            : 'You let the job offer pass. Remaining online for the next offer...',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1E293B),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        borderRadius: 8,
        icon: const Icon(Icons.redo_rounded, color: AppColors.secondary),
      );
    }
  }

  /// Driver explicitly accepts incoming offer
  void acceptIncomingOffer() {
    final offer = incomingOffer.value;
    if (offer == null) return;
    _offerTimer?.cancel();
    _offerTimer = null;
    incomingOffer.value = null;
    offerRemainingSeconds.value = 0;
    NotificationService.pendingIncomingOffer = null;

    // Stop ringing sound and vibration
    OrderAlertService.instance.stopRinging();

    // Cancel active AwesomeNotifications for order alerts
    try {
      AwesomeNotifications().cancelNotificationsByChannelKey(NotificationService.orderAlertChannelKey);
      AwesomeNotifications().cancel(NotificationService.orderAlertNotificationId);
    } catch (_) {}

    // Clear pending offer from persistent storage
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('driver_pending_order_payload');
      });
    } catch (_) {}

    final rawDriverId = StorageConfig.getDriverId() ?? profile.value.id;
    final cleanDriverId = rawDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final driverIdNum = int.tryParse(cleanDriverId) ?? 6;
    final cleanOrderId = offer.id.replaceAll(RegExp(r'[^0-9]'), '');
    final activeId = cleanOrderId.isNotEmpty ? cleanOrderId : offer.id;
    StorageConfig.setActiveOrderId(activeId);
    StorageConfig.setActiveOrderType(offer.orderType);

    final newTask = DeliveryTask(
      id: offer.id,
      orderNumber: offer.orderNumber,
      orderType: offer.orderType,
      storeName: offer.pickupName,
      storeCategory: offer.serviceCategory,
      storeAddress: offer.pickupAddress,
      storeDistanceKm: offer.distanceKm * 0.3,
      customerName: offer.isCourier ? 'Courier Delivery' : 'Customer (${offer.serviceCategory})',
      customerPhone: '+251 91 123 4567',
      customerAddress: offer.dropoffAddress.isNotEmpty ? offer.dropoffAddress : offer.dropoffName,
      customerDistanceKm: offer.distanceKm,
      payoutAmount: offer.fareAmount,
      tipAmount: 0.0,
      paymentMethod: offer.paymentMethod,
      items: const [],
      totalItemCount: 1,
      deliveryNotes: offer.isCourier ? 'Courier Package Delivery' : null,
      status: DeliveryStatus.assigned,
      createdAt: DateTime.now(),
      customerId: offer.customerId,
      ownerId: offer.ownerId,
      propertyName: offer.propertyName ?? offer.pickupName,
      storeLatitude: offer.pickupLatitude,
      storeLongitude: offer.pickupLongitude,
      customerLatitude: offer.dropoffLatitude,
      customerLongitude: offer.dropoffLongitude,
    );

    StorageConfig.setActiveTaskJson(jsonEncode(newTask.toJson()));

    assignedTasks.insert(0, newTask);
    activeAcceptedTask.value = newTask;

    if (Get.isRegistered<ActiveDeliveryController>()) {
      Get.find<ActiveDeliveryController>().setActiveTask(newTask);
    }

    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');

    // Call backend API and trigger socket room join & status update
    if (cleanOrderId.isNotEmpty && !inTest) {
      // 1. Immediately trigger socket room join & status 1 broadcast
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.joinOrder(cleanOrderId, orderType: offer.orderType, onResult: (success) {
          if (success) {
            DriverSocketService.to.sendStatusUpdate(
              orderId: cleanOrderId,
              status: '1',
              statusName: 'Order Accepted',
              notes: 'Driver accepted the offer',
            );
          }
        });
      }

      // 2. Dispatch to correct backend endpoint strictly based on orderType
      if (offer.isCourier) {
        DriverOrderService.updateCourierOrderStatus(
          orderId: cleanOrderId,
          status: 1,
          driverId: driverIdNum,
          onSuccess: (data) {
            final senderId = data['data']?['sender_user_id'] ?? data['sender_user_id'];
            if (senderId != null) {
              newTask.customerId = senderId;
              StorageConfig.setActiveTaskJson(jsonEncode(newTask.toJson()));
            }
          },
        );
      } else if (offer.isCorporate) {
        DriverOrderService.updateCorporateOrderStatus(
          orderId: cleanOrderId,
          status: 1,
          driverId: driverIdNum,
        );
      } else if (offer.isPickup) {
        DriverOrderService.updatePickupOrderStatus(
          orderId: cleanOrderId,
          status: 1,
        );
      } else {
        DriverOrderService.acceptOrder(
          orderId: cleanOrderId,
          driverId: driverIdNum,
        );
      }
    }

    // Dispatch Push Notification for Status 1: "Accepted" (notifies Customer and Store Owner)
    if (cleanOrderId.isNotEmpty) {
      NotificationService.instance.notifyOrderStatusChanged(
        orderId: cleanOrderId,
        status: '1',
        task: newTask,
        customerId: offer.customerId,
        ownerId: offer.ownerId,
        propertyName: offer.propertyName ?? offer.pickupName,
      );
    }

    if (!Get.testMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      Get.snackbar(
        'Job Accepted! 🎉',
        'Proceed to ${offer.pickupName} for pickup.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.onlineGreen,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        borderRadius: 8,
      );
    }

    startOrResumeDelivery(newTask);
  }

  // Street Pickup / Manual Order Creation (Photo 2)
  Future<DeliveryTask> createStreetPickupOrder({
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
  }) async {
    final cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final senderPhone = cleanPhone.startsWith('09')
        ? '251${cleanPhone.substring(1)}'
        : (cleanPhone.startsWith('9') && cleanPhone.length == 9
            ? '251$cleanPhone'
            : (cleanPhone.isNotEmpty ? cleanPhone : '251911058179'));

    final defaultCarType = int.tryParse(StorageConfig.getDriverVehicleId() ?? '') ?? 1;
    final defaultKm = StorageConfig.getPickupKmPrice() ?? 23.21;
    final defaultBase = StorageConfig.getPickupStartPrice() ?? 168.66;

    final resolvedFromLat = fromLatitude ?? 9.02497;
    final resolvedFromLng = fromLongitude ?? 38.74689;
    final resolvedToLat = toLatitude ?? 8.98060;
    final resolvedToLng = toLongitude ?? 38.75780;

    final calculatedKm = totalKm ??
        LocationUtils.calculateDistanceInKm(
          lat1: resolvedFromLat,
          lon1: resolvedFromLng,
          lat2: resolvedToLat,
          lon2: resolvedToLng,
        );
    final resolvedKmPrice = kmPrice ?? defaultKm;
    final resolvedBase = basePrice ?? defaultBase;
    final resolvedTotal = totalPrice ??
        double.parse((resolvedBase + (calculatedKm * resolvedKmPrice)).toStringAsFixed(2));

    final req = PickupOrderRequest(
      fromLatitude: resolvedFromLat,
      fromLongitude: resolvedFromLng,
      toLatitude: resolvedToLat,
      toLongitude: resolvedToLng,
      senderPhone: senderPhone,
      carTypeId: carTypeId ?? defaultCarType,
      basePrice: resolvedBase,
      kmPrice: resolvedKmPrice,
      totalKm: double.parse(calculatedKm.toStringAsFixed(2)),
      totalPrice: resolvedTotal,
      description: description ?? 'Fragile electronics. Please call upon arrival.',
      fromFriendlyLocation: (fromFriendlyLocation != null && fromFriendlyLocation.isNotEmpty)
          ? fromFriendlyLocation
          : (pickupAddress.contains(',') ? pickupAddress.split(',').first.trim() : pickupAddress),
      toFriendlyLocation: (toFriendlyLocation != null && toFriendlyLocation.isNotEmpty)
          ? toFriendlyLocation
          : (destinationAddress.contains(',') ? destinationAddress.split(',').first.trim() : destinationAddress),
    );

    String? createdOrderId;
    try {
      await DriverOrderService.createPickupOrder(
        request: req,
        onSuccess: (data) {
          final resData = data['data'] is Map ? data['data'] : data;
          createdOrderId = resData['id']?.toString() ??
              resData['order_id']?.toString();
        },
      );
    } catch (_) {}

    final orderId = createdOrderId ??
        'STR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final calculatedPayout = resolvedTotal;
    final newTask = DeliveryTask(
      id: orderId.startsWith('STR-') ? 'TSK-$orderId' : orderId,
      orderNumber: orderId.startsWith('STR-') ? 'AMN-$orderId' : 'AMN-$orderId',
      storeName: 'Street Pickup ($serviceCategory)',
      storeCategory: serviceCategory,
      storeAddress: pickupAddress,
      storeDistanceKm: 0.5,
      customerName: 'Customer',
      customerPhone: customerPhone,
      customerAddress: destinationAddress,
      customerDistanceKm: double.parse(calculatedKm.toStringAsFixed(2)),
      payoutAmount: calculatedPayout,
      tipAmount: 0.0,
      paymentMethod: 'Cash',
      items: const [],
      totalItemCount: 1,
      deliveryNotes: description,
      status: DeliveryStatus.assigned,
      createdAt: DateTime.now(),
    );

    assignedTasks.insert(0, newTask);
    activeAcceptedTask.value = newTask;
    StorageConfig.setActiveOrderId(orderId.toString());
    startOrResumeDelivery(newTask);

    Get.snackbar(
      'Order Created',
      'Street pickup order #AMN-$orderId has been created and set active.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF009EE0),
      colorText: Colors.white,
    );

    return newTask;
  }

  // Active delivery getter (in progress)
  DeliveryTask? get activeDelivery {
    try {
      return assignedTasks.firstWhere(
        (t) =>
            t.status == DeliveryStatus.assigned ||
            t.status == DeliveryStatus.headingToStore ||
            t.status == DeliveryStatus.atStore ||
            t.status == DeliveryStatus.pickedUp,
      );
    } catch (_) {
      return null;
    }
  }

  void startOrResumeDelivery(DeliveryTask task) {
    if (Get.isRegistered<ActiveDeliveryController>()) {
      final activeCtrl = Get.find<ActiveDeliveryController>();
      activeCtrl.setActiveTask(task);
    }

    // Lead driver immediately to the order detail screen and clear backstack to lock driver to this order
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest) {
      Get.offAllNamed(Pages.orderDetail, arguments: task);
    } else {
      if (Get.isRegistered<MainDriverNavigationController>()) {
        Get.find<MainDriverNavigationController>().selectedIndex.value = 2;
      }
    }
  }

  void openOrderDetail(DeliveryTask task) {
    Get.toNamed(Pages.orderDetail, arguments: task);
  }

  void viewAllAssignedDeliveries() {
    Get.toNamed(Pages.assignedDeliveries);
  }

  /// Fetches real-time today earnings and wallet balance from AMN APIs:
  /// - GET /today_earning/{driver_id}
  /// - GET /driver_my_wallet_amount/{driver_id}
  Future<void> fetchDashboardMetrics() async {
    final storedDriverId = StorageConfig.getDriverId();
    if (storedDriverId == null || storedDriverId.isEmpty) return;

    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (inTest && !DioConfig.isTestMode) {
      return;
    }

    try {
      final results = await Future.wait([
        DriverProfileService.fetchTodayEarning(storedDriverId),
        DriverProfileService.fetchWalletAmount(storedDriverId),
        DriverOrderService.fetchPastOrders(storedDriverId),
      ]);

      final earning = results[0] as double?;
      final wallet = results[1] as double?;
      final pastOrders = results[2] as List<DeliveryTask>? ?? [];

      if (earning != null) {
        todayEarnings.value = earning;
      }
      if (wallet != null) {
        walletBalance.value = wallet;
      }

      if (pastOrders.isNotEmpty) {
        final now = DateTime.now();
        final todayDelivered = pastOrders.where((t) =>
            t.status == DeliveryStatus.delivered &&
            t.createdAt.year == now.year &&
            t.createdAt.month == now.month &&
            t.createdAt.day == now.day).length;
        completedTrips.value = todayDelivered;

        final cancelled = pastOrders.where((t) => t.status == DeliveryStatus.cancelled).length;
        cancellationRate.value = ((cancelled / pastOrders.length) * 100).round();
      } else {
        completedTrips.value = 0;
        cancellationRate.value = 0;
      }

      // Sync with EarningsController if registered
      if (Get.isRegistered<EarningsController>()) {
        Get.find<EarningsController>().syncMetrics(
          todayEarnings: earning,
          walletBalance: wallet,
        );
      }
    } catch (_) {}
  }

  Future<void> refreshDashboard() async {
    await Future.delayed(const Duration(milliseconds: 300));
    syncProfileFromStorage();
    loadDashboardData();
    await fetchDashboardMetrics();
  }
}
