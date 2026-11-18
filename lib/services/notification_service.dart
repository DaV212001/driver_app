import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_config.dart';
import '../constants/pages.dart';
import '../controllers/driver_dashboard_controller.dart';
import '../firebase_options.dart';
import '../models/delivery_task.dart';
import '../models/incoming_job_offer.dart';
import '../screens/main_driver_navigation.dart';
import 'driver_order_service.dart';
import 'order_alert_service.dart';

@pragma("vm:entry-point")
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final logger = Logger();
  logger.i('🌙 FCM Background Message Received: [ID: ${message.messageId}]');
  logger.d('Title: ${message.notification?.title}');
  logger.d('Body: ${message.notification?.body}');
  logger.d('Data: ${message.data}');

  final rawTitle = message.notification?.title ?? message.data['title']?.toString();
  final rawBody = message.notification?.body ?? message.data['body']?.toString();
  final isOrder = NotificationService.isOrderNotification(message.data, rawTitle, rawBody);
  final isPromo = NotificationService.isPromotionNotification(message.data, rawTitle, rawBody);

  final title = rawTitle ?? (isOrder ? 'New Order Alert 🔔' : (isPromo ? 'AMN Special Promotion' : 'AMN Driver Update'));
  final body = rawBody ?? (isOrder ? 'New delivery order dispatch received.' : (isPromo ? 'Check out the latest promotion.' : 'You have a new notification.'));

  // 1. ORDER NOTIFICATIONS (Corporate, Courier, Normal delivery):
  // Must ring out immediately in the background without waiting for the app to open!
  if (isOrder && !isPromo) {
    // Suppress background notifications if driver is offline or has an active order
    try {
      final prefs = await SharedPreferences.getInstance();
      final isOnline = prefs.getBool('driver_is_online') ?? false;
      final activeOrderId = prefs.getString('driver_active_order_id');
      final hasActiveOrder = activeOrderId != null && activeOrderId.isNotEmpty;

      if (!isOnline || hasActiveOrder) {
        logger.i('🔇 Suppressing background order alert: isOnline=$isOnline, hasActiveOrder=$hasActiveOrder');
        return;
      }
    } catch (e) {
      logger.w('Notice checking driver state in background: $e');
    }

    final payloadMap = Map<String, String>.from(
      message.data.map((k, v) => MapEntry(k, v.toString())),
    );
    final sentTimeMs = message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    payloadMap.putIfAbsent('received_at', () => sentTimeMs.toString());
    payloadMap.putIfAbsent('duration_seconds', () => '120');

    // Save pending offer payload to SharedPreferences so if driver opens app from home screen, it resumes
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_pending_order_payload', jsonEncode(payloadMap));
    } catch (e) {
      logger.w('Notice saving pending offer to SharedPreferences: $e');
    }

    // 🔔 START RINGING IMMEDIATELY IN THE BACKGROUND
    // Order notifications (corporate, courier, or normal) MUST ring out without waiting for app to open!
    try {
      await OrderAlertService.instance.initialize();
      await OrderAlertService.instance.startRinging(autoStopAfter: const Duration(seconds: 120));
    } catch (e) {
      logger.w('Notice starting ringtone in background isolate: $e');
    }

    // Ensure notification channels are initialized
    await NotificationService.ensureAwesomeNotificationsInitialized();

    // Create high-priority full-screen alert notification with Accept/Dismiss buttons
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: NotificationService.orderAlertChannelKey,
        title: title,
        body: body,
        category: NotificationCategory.Call,
        wakeUpScreen: true,
        fullScreenIntent: true,
        payload: payloadMap,
        notificationLayout: NotificationLayout.Default,
        displayOnForeground: true,
        displayOnBackground: true,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'ACCEPT_ORDER',
          label: 'Accept Order',
          actionType: ActionType.Default,
          color: const Color(0xFF1E88E5),
        ),
        NotificationActionButton(
          key: 'DISMISS_ORDER',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
          isDangerousOption: true,
        ),
      ],
    );
    return;
  }

  // 2. PROMOTIONAL & GENERAL NOTIFICATIONS:
  // Must NOT trigger phone ringtone! Uses default notification sound only.
  // If the message came with a native notification payload, the Android system tray
  // already displayed it using the default notification channel.
  // Only display an AwesomeNotification if it was a data-only push without a system notification.
  if (message.notification == null && message.data.isNotEmpty) {
    final targetChannel = isPromo
        ? NotificationService.promoChannelKey
        : NotificationService.channelKey;

    final payloadMap = Map<String, String>.from(
      message.data.map((k, v) => MapEntry(k, v.toString())),
    );

    await NotificationService.ensureAwesomeNotificationsInitialized();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: targetChannel,
        title: title,
        body: body,
        category: NotificationCategory.Message,
        wakeUpScreen: false,
        fullScreenIntent: false,
        payload: payloadMap,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final Logger _logger = Logger();
  
  Dio? customDio;
  Dio get _dio => customDio ?? Dio();

  FirebaseMessaging? _customFcm;
  FirebaseMessaging get _fcm {
    if (_customFcm != null) return _customFcm!;
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase has not been initialized');
    }
    return FirebaseMessaging.instance;
  }

  static const String channelKey = 'driver_notifications';
  static const String orderAlertChannelKey = 'driver_order_alerts';
  static const String promoChannelKey = 'driver_promotions';
  static const String onlineServiceChannelKey = 'driver_online_service';
  static const String channelGroupKey = 'driver_channel_group';
  static const String notificationTokenEndpoint =
      'https://notification.amnplc.com/api/driver-tokens';

  /// Customer order status push endpoint
  static const String customerOrderStatusEndpoint =
      'https://notification.amnplc.com/api/push/customer-order-status';

  /// Store owner notification push endpoint
  static const String storeOwnerNotificationEndpoint =
      'https://notification.amnplc.com/api/push/Store-owner-notification';

  /// Checks whether a push notification data payload represents a promotional offer,
  /// marketing announcement, discount, bonus incentive, or general campaign.
  ///
  /// In the AMN backend architecture (well-known.zip):
  /// - Order notifications MUST contain an order data payload (via FcmService withData: type, order_id).
  /// - Promotional notifications sent via admin console do NOT contain an order payload.
  ///
  /// Promotional notifications MUST NOT trigger the phone ringtone or modal job offers.
  static bool isPromotionNotification(Map<String, dynamic> data, [String? title, String? body]) {
    final Map<String, dynamic> resolvedData = Map<String, dynamic>.from(data);
    if (resolvedData['data'] != null) {
      if (resolvedData['data'] is Map) {
        resolvedData.addAll(Map<String, dynamic>.from(resolvedData['data'] as Map));
      } else if (resolvedData['data'] is String) {
        try {
          final decoded = jsonDecode(resolvedData['data'] as String);
          if (decoded is Map) {
            resolvedData.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
    }

    final hasOrderId = (resolvedData['order_id'] != null && resolvedData['order_id'].toString().trim().isNotEmpty) ||
        (resolvedData['orderId'] != null && resolvedData['orderId'].toString().trim().isNotEmpty) ||
        (resolvedData['order_number'] != null && resolvedData['order_number'].toString().trim().isNotEmpty) ||
        (resolvedData['delivery_id'] != null && resolvedData['delivery_id'].toString().trim().isNotEmpty) ||
        (resolvedData['job_id'] != null && resolvedData['job_id'].toString().trim().isNotEmpty);

    // Rule 1: Backend architecture rule — promotional notifications do NOT contain an order payload.
    // If the data payload is empty (or has no order ID) and title/body is present, it is promotional.
    if (resolvedData.isEmpty && ((title != null && title.trim().isNotEmpty) || (body != null && body.trim().isNotEmpty))) {
      return true;
    }

    // 2. Explicit boolean or string flags in payload
    final isPromoFlag = resolvedData['is_promo'] ??
        resolvedData['is_promotion'] ??
        resolvedData['isPromotion'] ??
        resolvedData['isPromo'] ??
        resolvedData['promo'] ??
        resolvedData['is_broadcast'] ??
        resolvedData['is_announcement'];
    if (isPromoFlag == true || isPromoFlag == 'true' || isPromoFlag == 1 || isPromoFlag == '1') {
      return true;
    }

    // 3. Type / Event / Category field checks
    final type = (resolvedData['type'] ??
            resolvedData['event'] ??
            resolvedData['notification_type'] ??
            resolvedData['category'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    const promoTypes = [
      'promo',
      'promotion',
      'promotions',
      'promotional',
      'marketing',
      'campaign',
      'marketing_campaign',
      'discount',
      'discounts',
      'deal',
      'deals',
      'bonus',
      'bonuses',
      'incentive',
      'incentives',
      'reward',
      'rewards',
      'cashback',
      'voucher',
      'vouchers',
      'coupon',
      'coupons',
      'referral',
      'refer_a_friend',
      'ad',
      'advertisement',
      'advertising',
      'commercial',
      'banner',
      'broadcast',
      'broadcasts',
      'announcement',
      'announcements',
      'bulk',
      'general',
      'system',
      'news',
      'newsletter',
      'notice',
      'maintenance',
      'policy',
      'tip',
      'tips',
      'survey',
      'event',
      'greeting',
      'info',
      'informational',
    ];

    if (promoTypes.contains(type) ||
        type.startsWith('promo') ||
        type.startsWith('promotion') ||
        type.startsWith('bulk') ||
        type.startsWith('broadcast') ||
        type.startsWith('announce') ||
        type.startsWith('campaign') ||
        type.startsWith('discount') ||
        type.startsWith('bonus') ||
        type.startsWith('reward') ||
        type.startsWith('incentive')) {
      return true;
    }

    // 4. Text inspection of Title and Body
    final effectiveTitle = (title ?? resolvedData['title']?.toString() ?? '').toLowerCase();
    final effectiveBody = (body ?? resolvedData['body']?.toString() ?? '').toLowerCase();
    final combinedText = '$effectiveTitle $effectiveBody'.trim();

    if (combinedText.isNotEmpty) {
      const promoPhrases = [
        'promotion',
        'promotional',
        'promo code',
        'special promo',
        'weekend promo',
        'special offer',
        'exclusive offer',
        'limited time offer',
        'limited offer',
        'discount',
        'cashback',
        'earn bonus',
        'extra bonus',
        'weekend bonus',
        'weekly bonus',
        'driver incentive',
        'earn extra',
        'earn more',
        'win prize',
        'voucher',
        'coupon',
        'refer a friend',
        'referral bonus',
        'holiday offer',
        'announcement',
        'system maintenance',
        'terms of service',
        'policy update',
        'survey',
        'tip of the day',
      ];

      for (final phrase in promoPhrases) {
        if (combinedText.contains(phrase)) {
          if (!hasOrderId) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Checks whether a push notification data payload represents an incoming order dispatch
  /// (normal delivery, courier, or corporate order).
  ///
  /// In the AMN backend architecture (FcmService.php in well-known.zip), order notifications
  /// MUST contain a data payload with order identification (e.g. order_id, type: 'new_order', etc.),
  /// whereas promotional/broadcast notifications do NOT contain an order data payload.
  static bool isOrderNotification(Map<String, dynamic> data, [String? title, String? body]) {
    // 1. Order notifications MUST contain a non-empty data payload
    if (data.isEmpty) {
      return false;
    }

    // 2. If explicitly identified as promotional, it must NEVER be treated as an order dispatch!
    if (isPromotionNotification(data, title, body)) {
      return false;
    }

    // Unnest payload if wrapped in a 'data' key (standard FCM practice)
    final Map<String, dynamic> resolvedData = Map<String, dynamic>.from(data);
    if (resolvedData['data'] != null) {
      if (resolvedData['data'] is Map) {
        resolvedData.addAll(Map<String, dynamic>.from(resolvedData['data'] as Map));
      } else if (resolvedData['data'] is String) {
        try {
          final decoded = jsonDecode(resolvedData['data'] as String);
          if (decoded is Map) {
            resolvedData.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
    }

    // 3. Specific order identifier keys in payload (from backend FcmService withData: order_id)
    final hasOrderId = (resolvedData['order_id'] != null && resolvedData['order_id'].toString().trim().isNotEmpty) ||
        (resolvedData['orderId'] != null && resolvedData['orderId'].toString().trim().isNotEmpty) ||
        (resolvedData['order_number'] != null && resolvedData['order_number'].toString().trim().isNotEmpty) ||
        (resolvedData['orderNumber'] != null && resolvedData['orderNumber'].toString().trim().isNotEmpty) ||
        (resolvedData['delivery_id'] != null && resolvedData['delivery_id'].toString().trim().isNotEmpty) ||
        (resolvedData['deliveryId'] != null && resolvedData['deliveryId'].toString().trim().isNotEmpty) ||
        (resolvedData['job_id'] != null && resolvedData['job_id'].toString().trim().isNotEmpty) ||
        (resolvedData['jobId'] != null && resolvedData['jobId'].toString().trim().isNotEmpty);

    if (hasOrderId) {
      return true;
    }

    final type = (resolvedData['type'] ??
            resolvedData['event'] ??
            resolvedData['notification_type'] ??
            resolvedData['category'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final orderType = (resolvedData['order_type'] ??
            resolvedData['orderType'] ??
            resolvedData['delivery_type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    // 4. Check for explicit order type values (normal, courier, corporate)
    const orderTypes = [
      'new_order',
      'new_order_assigned',
      'order_assigned',
      'order_dispatch',
      'incoming_order',
      'job_offer',
      'new_job',
      'new_job_offer',
      'order_offer',
      'trip_offer',
      'new_trip',
      'delivery_assigned',
      'new_delivery_assigned',
      'courier_order',
      'new_courier_order',
      'courier_assigned',
      'new_courier_assigned',
      'courier_dispatch',
      'corporate_order',
      'new_corporate_order',
      'corporate_assigned',
      'new_corporate_assigned',
      'corporate_dispatch',
      'pickup_order',
      'order_request',
      'normal_order',
      'standard_order',
      'delivery_order',
    ];

    if (orderTypes.contains(type) ||
        type == 'order' ||
        type == 'dispatch' ||
        type == 'job' ||
        type == 'trip' ||
        type == 'courier' ||
        type == 'corporate' ||
        type == 'company' ||
        type.contains('order_assign') ||
        type.contains('new_order') ||
        type.contains('job_offer') ||
        type.contains('dispatch_offer') ||
        type.contains('courier_order') ||
        type.contains('corporate_order')) {
      return true;
    }

    // 5. Check for orderType flag (corporate, courier, normal / delivery) with locations
    if (orderType == 'courier' ||
        orderType == 'courirer' ||
        orderType == 'corporate' ||
        orderType == 'company' ||
        orderType == 'delivery' ||
        orderType == 'normal' ||
        orderType == 'standard' ||
        orderType == 'pickup') {
      final hasLocations = resolvedData.containsKey('pickup_name') ||
          resolvedData.containsKey('pickup_address') ||
          resolvedData.containsKey('dropoff_name') ||
          resolvedData.containsKey('dropoff_address') ||
          resolvedData.containsKey('from_latitude') ||
          resolvedData.containsKey('customer_name') ||
          resolvedData.containsKey('receiver_name') ||
          resolvedData.containsKey('reciver_name');

      if (hasLocations) {
        return true;
      }
    }

    // 6. Check for order details (pickup/dropoff coordinates or addresses with fare)
    final hasFare = resolvedData.containsKey('fare') ||
        resolvedData.containsKey('fare_amount') ||
        resolvedData.containsKey('total_price') ||
        resolvedData.containsKey('total_km_price');
    final hasLocations = resolvedData.containsKey('pickup_name') ||
        resolvedData.containsKey('pickup_address') ||
        resolvedData.containsKey('dropoff_name') ||
        resolvedData.containsKey('dropoff_address') ||
        resolvedData.containsKey('from_latitude') ||
        resolvedData.containsKey('customer_name') ||
        resolvedData.containsKey('receiver_name') ||
        resolvedData.containsKey('reciver_name');

    if (hasFare && hasLocations) {
      return true;
    }

    // Payload contains no valid order information
    return false;
  }

  /// Holds pending incoming offer for cold starts or inactive taps
  static IncomingJobOffer? pendingIncomingOffer;

  /// Observable device token that immediately notifies listeners upon initialization and refresh
  final Rx<String?> fcmToken = Rx<String?>(null);
  final RxBool isFetchingToken = false.obs;

  /// Register driver FCM token to Samuel's AMN notification server
  Future<bool> registerDriverTokenToServer({
    String? token,
    dynamic driverId,
  }) async {
    try {
      final effectiveToken = token ?? fcmToken.value ?? await getDeviceToken();
      if (effectiveToken == null || effectiveToken.isEmpty) {
        _logger.w('⚠️ Cannot register FCM token: token is empty');
        return false;
      }

      final rawDriverId = driverId?.toString() ?? StorageConfig.getDriverId();
      final driverIdNum = int.tryParse(rawDriverId ?? '');
      if (driverIdNum == null || driverIdNum <= 0) {
        _logger.d('ℹ️ Deferred FCM token registration: driver not logged in yet (driver_id: $rawDriverId)');
        return false;
      }

      final platformStr = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'android');

      _logger.i('📤 Registering driver FCM token with $notificationTokenEndpoint for driver_id: $driverIdNum ($platformStr)');

      final dio = Dio();
      final response = await dio.post(
        notificationTokenEndpoint,
        data: {
          'driver_id': driverIdNum,
          'fcm_token': effectiveToken,
          'platform': platformStr,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('✅ Driver FCM token successfully registered with notification service: ${response.data}');
        return true;
      } else {
        _logger.w('⚠️ Notification server returned status: ${response.statusCode}');
        return false;
      }
    } catch (e, stack) {
      _logger.e('❌ Failed to register FCM token with notification service', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Tracks last dispatched status per orderId to avoid duplicate network calls
  final Map<String, String> _lastDispatchedCustomerStatus = {};
  final Set<String> _dispatchedStoreOwnerOrders = {};

  /// Sends customer push notification on order status change.
  /// POST https://notification.amnplc.com/api/push/customer-order-status
  /// Status codes:
  /// '0': Order Placed
  /// '1': Accepted
  /// '2': Driver on the way to shop
  /// '3': Driver on the way to you
  /// '4': Deliverd
  /// '5': Cancelled
  Future<bool> sendCustomerOrderStatusNotification({
    required dynamic customerId,
    required dynamic orderId,
    required String status,
  }) async {
    try {
      final cleanOrderId = int.tryParse(orderId.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? orderId;
      final cleanCustId = int.tryParse(customerId.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? customerId;

      _logger.i('📤 Sending customer push notification to $customerOrderStatusEndpoint: '
          '{customer_id: $cleanCustId, order_id: $cleanOrderId, status: "$status"}');

      final response = await _dio.post(
        customerOrderStatusEndpoint,
        data: {
          'customer_id': cleanCustId,
          'order_id': cleanOrderId,
          'status': status.toString(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('✅ Customer order status push sent successfully: ${response.data}');
        return true;
      } else {
        _logger.w('⚠️ Customer order status push returned ${response.statusCode}: ${response.data}');
        return false;
      }
    } catch (e, stack) {
      _logger.e('❌ Failed to send customer order status notification', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Sends store owner push notification when order is accepted (status '1').
  /// POST https://notification.amnplc.com/api/push/Store-owner-notification
  Future<bool> sendStoreOwnerNotification({
    required dynamic ownerId,
    required dynamic orderId,
    required String status,
    String? propertyName,
  }) async {
    try {
      final cleanOrderId = int.tryParse(orderId.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? orderId;
      final cleanOwnerId = int.tryParse(ownerId.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? ownerId;

      _logger.i('📤 Sending store owner push notification to $storeOwnerNotificationEndpoint: '
          '{owner_id: $cleanOwnerId, order_id: $cleanOrderId, status: "$status"}');

      final response = await _dio.post(
        storeOwnerNotificationEndpoint,
        data: {
          'owner_id': cleanOwnerId,
          'order_id': cleanOrderId,
          'status': status.toString(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('✅ Store owner push notification sent successfully: ${response.data}');
        return true;
      } else {
        _logger.w('⚠️ Store owner push notification returned ${response.statusCode}: ${response.data}');
        return false;
      }
    } catch (e, stack) {
      _logger.e('❌ Failed to send store owner notification', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Dispatches push notifications for order status transitions.
  /// Automatically queries `/my_order_detail/{order_id}` if owner_id or customer_id is missing.
  Future<void> notifyOrderStatusChanged({
    required dynamic orderId,
    required String status,
    DeliveryTask? task,
    dynamic customerId,
    dynamic ownerId,
    String? propertyName,
  }) async {
    final cleanId = orderId.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanId.isEmpty) {
      _logger.w('⚠️ Cannot dispatch order status push: invalid orderId "$orderId"');
      return;
    }

    if (task != null && task.lastReportedNotificationStatus == status && _lastDispatchedCustomerStatus[cleanId] == status) {
      _logger.d('ℹ️ Skipping duplicate push notification for order #$cleanId (already at status $status)');
      return;
    }

    dynamic resolvedCustomerId = customerId ?? task?.customerId;
    dynamic resolvedOwnerId = ownerId ?? task?.ownerId;
    String? resolvedPropertyName = propertyName ?? task?.propertyName ?? task?.storeName;

    final needsFetch = resolvedCustomerId == null || (status == '1' && resolvedOwnerId == null);

    if (needsFetch) {
      try {
        final orderDetails = await DriverOrderService.fetchOrderDetailRaw(cleanId, orderType: task?.orderType);
        if (orderDetails != null) {
          resolvedCustomerId ??= orderDetails['customer_id'] ??
              orderDetails['customerId'] ??
              orderDetails['user_id'] ??
              orderDetails['userId'] ??
              orderDetails['sender_user_id'] ??
              orderDetails['client_id'] ??
              orderDetails['customer']?['id'] ??
              orderDetails['user']?['id'] ??
              orderDetails['order_status']?['customer_id'] ??
              orderDetails['order_status']?['user_id'] ??
              orderDetails['data']?['customer_id'] ??
              orderDetails['data']?['user_id'];

          resolvedOwnerId ??= orderDetails['owner_id'] ??
              orderDetails['ownerId'] ??
              orderDetails['store_owner_id'] ??
              orderDetails['vendor_id'] ??
              orderDetails['merchant_id'] ??
              orderDetails['property_owner_id'] ??
              orderDetails['store']?['owner_id'] ??
              orderDetails['property']?['owner_id'] ??
              orderDetails['property']?['user_id'] ??
              orderDetails['store']?['user_id'] ??
              orderDetails['order_status']?['owner_id'] ??
              orderDetails['order_status']?['store_owner_id'] ??
              orderDetails['data']?['owner_id'] ??
              orderDetails['data']?['store_owner_id'];

          final fetchedProp = orderDetails['property']?.toString() ??
              orderDetails['property_name']?.toString() ??
              orderDetails['store_name']?.toString();
          if (fetchedProp != null && fetchedProp.trim().isNotEmpty) {
            resolvedPropertyName = fetchedProp.trim();
          }

          if (task != null) {
            task.customerId ??= resolvedCustomerId;
            task.ownerId ??= resolvedOwnerId;
            task.propertyName ??= resolvedPropertyName;
          }
        }
      } catch (e) {
        _logger.w('Notice: Error fetching raw order detail for push metadata: $e');
      }

      if (resolvedCustomerId == null || (status == '1' && resolvedOwnerId == null)) {
        try {
          final fetchedTask = await DriverOrderService.fetchOrderDetail(cleanId, orderType: task?.orderType);
          if (fetchedTask != null) {
            resolvedCustomerId ??= fetchedTask.customerId;
            resolvedOwnerId ??= fetchedTask.ownerId;
            resolvedPropertyName ??= fetchedTask.propertyName ?? fetchedTask.storeName;
            if (task != null) {
              task.customerId ??= resolvedCustomerId;
              task.ownerId ??= resolvedOwnerId;
              task.propertyName ??= resolvedPropertyName;
            }
          }
        } catch (_) {}
      }
    }

    // 1. Notify Customer for status changes (1, 2, 3, 4, 5, etc.)
    if (resolvedCustomerId != null) {
      if (_lastDispatchedCustomerStatus[cleanId] != status) {
        await sendCustomerOrderStatusNotification(
          customerId: resolvedCustomerId,
          orderId: cleanId,
          status: status,
        );
        _lastDispatchedCustomerStatus[cleanId] = status;
      }
    } else {
      _logger.w('⚠️ Skipping customer push notification: customer_id could not be resolved for order #$cleanId');
    }

    // 2. If setting status to '1' (Accepted), also notify Store Owner
    if (status == '1') {
      if (resolvedOwnerId != null) {
        if (!_dispatchedStoreOwnerOrders.contains(cleanId)) {
          final finalPropName = (resolvedPropertyName != null && resolvedPropertyName.isNotEmpty)
              ? resolvedPropertyName
              : 'AMN Partner Store';
          await sendStoreOwnerNotification(
            ownerId: resolvedOwnerId,
            orderId: cleanId,
            status: '1',
            propertyName: finalPropName,
          );
          _dispatchedStoreOwnerOrders.add(cleanId);
        }
      } else {
        _logger.w('⚠️ Skipping store owner push notification: owner_id could not be resolved for order #$cleanId');
      }
    }

    if (task != null) {
      task.lastReportedNotificationStatus = status;
    }
  }

  /// Safely parse and route incoming push/notification data to DriverDashboardController
  static void dispatchIncomingOffer(Map<String, dynamic> data) {
    try {
      if (data.isEmpty) return;

      // Validate that payload represents an actual order (and is not promotional)
      if (isPromotionNotification(data) || !isOrderNotification(data)) {
        Logger().i('ℹ️ Skipping incoming job offer: payload is promotional or does not contain order information');
        return;
      }

      // Suppress incoming order offer if driver is offline or has an active order
      final isOnline = StorageConfig.getIsOnline();
      final hasActiveOrder = StorageConfig.hasActiveOrder();
      if (!isOnline || hasActiveOrder) {
        Logger().i('🔇 Skipping incoming job offer: isOnline=$isOnline, hasActiveOrder=$hasActiveOrder');
        return;
      }

      // Extract nested data payload if present (e.g. from FCM or backend wrapping)
      final payload = Map<String, dynamic>.from(data);
      if (payload['data'] != null) {
        if (payload['data'] is Map) {
          payload.addAll(Map<String, dynamic>.from(payload['data'] as Map));
        } else if (payload['data'] is String) {
          try {
            final decoded = jsonDecode(payload['data'] as String);
            if (decoded is Map) {
              payload.addAll(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        }
      }

      // Preserve or stamp received_at timestamp so countdown resumption calculates elapsed time accurately
      if (!payload.containsKey('received_at')) {
        payload['received_at'] = DateTime.now().millisecondsSinceEpoch;
      }
      payload.putIfAbsent('duration_seconds', () => 120);

      final offer = IncomingJobOffer.fromNotificationPayload(payload);

      // Check if offer expired (> 2 minutes elapsed since dispatch/notification)
      if (offer.isExpired) {
        Logger().i('⌛ Order offer ${offer.orderNumber} expired (${offer.elapsedSeconds}s > ${offer.totalDurationSeconds}s)');
        pendingIncomingOffer = null;
        OrderAlertService.instance.stopRinging();
        if (Get.isRegistered<DriverDashboardController>()) {
          Get.find<DriverDashboardController>().dismissIncomingOffer(isTimeout: true);
        } else if (!Get.testMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
          Get.snackbar(
            'Offer Timed Out',
            'This delivery order dispatch reached the 2-minute limit and was passed to another driver.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF1E293B),
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(12),
            borderRadius: 8,
            icon: const Icon(Icons.timer_off_rounded, color: Colors.orangeAccent),
          );
        }
        return;
      }

      pendingIncomingOffer = offer;

      // Ensure navigation routes to dashboard
      routeToDashboard();

      // Trigger the offer on controller immediately or retry when mounted
      _triggerOfferOnController(offer);
    } catch (e) {
      Logger().e('Failed to process incoming order offer from payload: $e');
    }
  }

  /// Ensure the app navigates back to the Dashboard tab so the bottom sheet is visible
  static void routeToDashboard() {
    try {
      // 1. Pop any modal dialogs or sub-screens if open
      while (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        Get.back();
      }

      if (Get.key.currentState != null && Get.key.currentState!.canPop()) {
        Get.until((route) => route.settings.name == Pages.mainNavigation || route.isFirst);
      }

      // 2. Ensure main navigation selects the Dashboard tab (index 0)
      if (Get.isRegistered<MainDriverNavigationController>()) {
        Get.find<MainDriverNavigationController>().returnToDashboard();
      } else if (StorageConfig.isLoggedIn()) {
        Get.offAllNamed(Pages.mainNavigation);
      }
    } catch (e) {
      Logger().w('Navigation routing to dashboard notice: $e');
    }
  }

  /// Safely trigger the offer on the DriverDashboardController
  static void _triggerOfferOnController(IncomingJobOffer offer) {
    void tryTrigger() {
      if (Get.isRegistered<DriverDashboardController>()) {
        final ctrl = Get.find<DriverDashboardController>();
        if (!ctrl.isOnline.value || ctrl.hasActiveAcceptedOrder) {
          pendingIncomingOffer = null;
          return;
        }
        routeToDashboard();
        ctrl.triggerIncomingOffer(offer);
        pendingIncomingOffer = null;
      }
    }

    tryTrigger();
    // Also retry after delays to allow cold-start / activity resume to settle
    Future.delayed(const Duration(milliseconds: 250), tryTrigger);
    Future.delayed(const Duration(milliseconds: 600), tryTrigger);
    Future.delayed(const Duration(milliseconds: 1200), tryTrigger);
  }

  /// Ensures AwesomeNotifications channels are initialized (safe for both main & background isolates)
  static Future<void> ensureAwesomeNotificationsInitialized() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/res_app_icon',
      [
        // Dedicated persistent background service channel for active online status
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: onlineServiceChannelKey,
          channelName: 'AMN Driver Online Status',
          channelDescription: 'Persistent status notification indicating driver is online and tracking location for dispatch.',
          defaultColor: const Color(0xFF1E88E5),
          ledColor: Colors.white,
          importance: NotificationImportance.Low,
          channelShowBadge: false,
          playSound: false,
          enableVibration: false,
        ),
        // Dedicated high-priority channel for incoming order requests with phone ringing sound & vibration
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: orderAlertChannelKey,
          channelName: 'Incoming Order Alerts',
          channelDescription: 'High-priority incoming order dispatches with phone ringtone and vibration.',
          defaultColor: const Color(0xFF1E88E5),
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 600, 1000, 600, 1000, 600, 1000]),
          defaultRingtoneType: DefaultRingtoneType.Ringtone,
          criticalAlerts: true,
        ),
        // Dedicated channel for promotions and marketing offers (standard notification sound, NO ringtone)
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: promoChannelKey,
          channelName: 'Promotions & Offers',
          channelDescription: 'Promotional deals, driver incentives, discount campaigns, and special offers.',
          defaultColor: const Color(0xFF1E88E5),
          ledColor: Colors.white,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
          defaultRingtoneType: DefaultRingtoneType.Notification,
          criticalAlerts: false,
        ),
        // General driver updates, announcements, and status notifications
        NotificationChannel(
          channelGroupKey: channelGroupKey,
          channelKey: channelKey,
          channelName: 'AMN Driver Notifications',
          channelDescription: 'Announcements, bulk updates, and general notifications for drivers.',
          defaultColor: const Color(0xFF1E88E5),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
          defaultRingtoneType: DefaultRingtoneType.Notification,
          criticalAlerts: false,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: channelGroupKey,
          channelGroupName: 'Delivery Order Alerts',
        ),
      ],
      debug: false,
    );
  }

  /// Initialize Awesome Notifications and Firebase Messaging
  Future<void> initialize() async {
    // 1. Initialize Awesome Notifications with all dedicated channels
    await ensureAwesomeNotificationsInitialized();

    // Initialize Order Alert Service (ringtone & vibration preferences)
    await OrderAlertService.instance.initialize();

    // 2. Request Permissions
    await requestPermissions();

    // 3. Register Background and Foreground FCM Handlers if Firebase is ready
    if (Firebase.apps.isNotEmpty) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('🔔 FCM Foreground Message Received: ${message.messageId}');
        _logger.d('Title: ${message.notification?.title}');
        _logger.d('Body: ${message.notification?.body}');
        _logger.d('Data: ${message.data}');

        final rawTitle = message.notification?.title ?? message.data['title']?.toString();
        final rawBody = message.notification?.body ?? message.data['body']?.toString();
        final isOrder = isOrderNotification(message.data, rawTitle, rawBody);
        final isPromo = isPromotionNotification(message.data, rawTitle, rawBody);

        final title = rawTitle ?? (isOrder ? 'Delivery Alert' : (isPromo ? 'AMN Special Promotion' : 'AMN Driver Notification'));
        final body = rawBody ?? (isOrder ? 'New delivery notification received.' : (isPromo ? 'Check out the latest promotion.' : 'New notification received.'));

        // If promotional or non-order: display on default notification sound channel, NEVER ring or show order sheet
        if (isPromo || !isOrder) {
          final targetChannel = isPromo ? promoChannelKey : channelKey;
          final payloadMap = Map<String, String>.from(
            message.data.map((k, v) => MapEntry(k, v.toString())),
          );

          AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: targetChannel,
              title: title,
              body: body,
              category: NotificationCategory.Message,
              wakeUpScreen: false,
              fullScreenIntent: false,
              payload: payloadMap,
              notificationLayout: NotificationLayout.Default,
            ),
          );
          return;
        }

        // Suppress foreground order notification if driver is offline or has an active order in progress
        final isOnline = StorageConfig.getIsOnline();
        final hasActiveOrder = StorageConfig.hasActiveOrder();
        if (!isOnline || hasActiveOrder) {
          _logger.i('🔇 Suppressing foreground order alert: isOnline=$isOnline, hasActiveOrder=$hasActiveOrder');
          return;
        }

        final payloadMap = Map<String, String>.from(
          message.data.map((k, v) => MapEntry(k, v.toString())),
        );
        final sentTimeMs = message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
        payloadMap.putIfAbsent('received_at', () => sentTimeMs.toString());
        payloadMap.putIfAbsent('duration_seconds', () => '120');

        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: orderAlertChannelKey,
            title: title,
            body: body,
            category: NotificationCategory.Call,
            wakeUpScreen: true,
            fullScreenIntent: true,
            payload: payloadMap,
            notificationLayout: NotificationLayout.Default,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'ACCEPT_ORDER',
              label: 'Accept Order',
              actionType: ActionType.Default,
              color: const Color(0xFF1E88E5),
            ),
            NotificationActionButton(
              key: 'DISMISS_ORDER',
              label: 'Dismiss',
              actionType: ActionType.DismissAction,
              isDangerousOption: true,
            ),
          ],
        );

        // Immediately trigger Incoming Job Offer Sheet & Ringtone ONLY for active order dispatches!
        dispatchIncomingOffer(payloadMap);
      });

      // Background / Inactive app opened via FCM notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.i('📱 FCM Message Opened App (from background/inactive): ${message.data}');
        final title = message.notification?.title ?? message.data['title']?.toString();
        final body = message.notification?.body ?? message.data['body']?.toString();
        if (isOrderNotification(message.data, title, body) && !isPromotionNotification(message.data, title, body)) {
          final payloadMap = Map<String, dynamic>.from(message.data);
          final sentTimeMs = message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
          payloadMap.putIfAbsent('received_at', () => sentTimeMs);
          payloadMap.putIfAbsent('duration_seconds', () => 120);
          dispatchIncomingOffer(payloadMap);
        }
      });

      // Cold start from terminated state via FCM notification tap
      _fcm.getInitialMessage().then((RemoteMessage? initialMessage) {
        if (initialMessage != null && initialMessage.data.isNotEmpty) {
          _logger.i('🚀 App cold-started from FCM notification: ${initialMessage.data}');
          final title = initialMessage.notification?.title ?? initialMessage.data['title']?.toString();
          final body = initialMessage.notification?.body ?? initialMessage.data['body']?.toString();
          if (isOrderNotification(initialMessage.data, title, body) && !isPromotionNotification(initialMessage.data, title, body)) {
            final payloadMap = Map<String, dynamic>.from(initialMessage.data);
            final sentTimeMs = initialMessage.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
            payloadMap.putIfAbsent('received_at', () => sentTimeMs);
            payloadMap.putIfAbsent('duration_seconds', () => 120);
            dispatchIncomingOffer(payloadMap);
          }
        }
      });
    }

    // 4. Setup Action Stream Listener for Notification Interactions
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    // Cold start from terminated state via Awesome Notifications action tap
    try {
      final initialAction = await AwesomeNotifications().getInitialNotificationAction();
      if (initialAction != null && initialAction.payload != null && initialAction.payload!.isNotEmpty) {
        _logger.i('🚀 App cold-started from AwesomeNotification action: ${initialAction.payload}');
        if (isOrderNotification(initialAction.payload!) && !isPromotionNotification(initialAction.payload!)) {
          dispatchIncomingOffer(initialAction.payload!);
        }
      }
    } catch (e) {
      _logger.w('Initial notification action check notice: $e');
    }

    // 5. Log and store Initial Device FCM Token
    await refreshDeviceToken();

    // 6. Monitor token refresh and automatically update reactive token & sync to server
    if (Firebase.apps.isNotEmpty) {
      // ignore: deprecated_member_use
      _fcm.onTokenRefresh.listen((newToken) {
        _logger.i('🔄 FCM Device Token Refreshed: $newToken');
        fcmToken.value = newToken;
        registerDriverTokenToServer(token: newToken);
      });

      // Subscribe to driver broadcast topics
      try {
        await _fcm.subscribeToTopic('drivers');
        await _fcm.subscribeToTopic('driver_orders');
        await _fcm.subscribeToTopic('orders');
        _logger.i('📡 Subscribed to driver FCM topics: drivers, driver_orders, orders');
      } catch (e) {
        _logger.w('FCM topic subscription note: $e');
      }
    }

    // 7. If driver is already logged in on startup, register token with notification server
    if (StorageConfig.isLoggedIn()) {
      registerDriverTokenToServer(token: fcmToken.value);
    }
  }

  /// Request permissions for both Awesome Notifications and FCM
  Future<void> requestPermissions() async {
    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      if (Firebase.apps.isNotEmpty) {
        final settings = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        _logger.i('FCM Permission Status: ${settings.authorizationStatus}');

        if (Platform.isIOS) {
          final apnsToken = await _fcm.getAPNSToken();
          _logger.d('APNs Token: $apnsToken');
        }
      }
    } catch (e, stack) {
      _logger.e('Error requesting notification permissions', error: e, stackTrace: stack);
    }
  }

  /// Explicitly query and update the FCM device registration token
  Future<String?> refreshDeviceToken() async {
    try {
      isFetchingToken.value = true;
      if (Firebase.apps.isEmpty) {
        return null;
      }
      // ignore: deprecated_member_use
      final token = await _fcm.getToken();
      _logger.i('📲 FCM Device Token: $token');
      fcmToken.value = token;
      if (token != null && token.isNotEmpty && StorageConfig.isLoggedIn()) {
        registerDriverTokenToServer(token: token);
      }
      return token;
    } catch (e, stack) {
      _logger.e('Failed to get FCM device token', error: e, stackTrace: stack);
      return null;
    } finally {
      isFetchingToken.value = false;
    }
  }

  /// Get current FCM registration token
  Future<String?> getDeviceToken() async {
    if (fcmToken.value != null && fcmToken.value!.isNotEmpty) {
      return fcmToken.value;
    }
    return await refreshDeviceToken();
  }

  static const int kOnlineNotificationId = 8888;

  /// Shows an ongoing, persistent notification in the status bar while the driver is online.
  Future<void> showOnlinePersistentNotification() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: kOnlineNotificationId,
          channelKey: onlineServiceChannelKey,
          title: 'AMN Driver Active 🟢',
          body: 'Online and sharing live location with dispatch',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Service,
          icon: 'resource://drawable/res_app_icon',
          autoDismissible: false,
          locked: true,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
      );
      _logger.i('🟢 Persistent online notification posted to status bar');
    } catch (e) {
      _logger.w('Could not post online persistent notification: $e');
    }
  }

  /// Cancels and removes the persistent online notification when going offline.
  Future<void> removeOnlinePersistentNotification() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await AwesomeNotifications().cancel(kOnlineNotificationId);
      _logger.i('⚪ Persistent online notification removed');
    } catch (e) {
      _logger.w('Could not remove online notification: $e');
    }
  }

  /// Retrieves and dispatches any incoming order offer saved while the app was in the background
  static Future<void> checkPendingOfferFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('driver_pending_order_payload');
      if (raw != null && raw.isNotEmpty) {
        await prefs.remove('driver_pending_order_payload');
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (isOrderNotification(map) && !isPromotionNotification(map)) {
            dispatchIncomingOffer(map);
          }
        }
      }
    } catch (e) {
      Logger().w('Notice checking pending offer from storage: $e');
    }
  }

  // Action callback hooks required by Awesome Notifications v0.10+
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    Logger().i('👆 Notification tapped / action pressed [${receivedAction.buttonKeyPressed}]: ${receivedAction.payload}');
    // Immediately silence ringtone and vibration when user acts on notification
    await OrderAlertService.instance.stopRinging();

    // Clear any pending order from prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('driver_pending_order_payload');
    } catch (_) {}

    if (receivedAction.buttonKeyPressed == 'DISMISS_ORDER') {
      if (Get.isRegistered<DriverDashboardController>()) {
        Get.find<DriverDashboardController>().dismissIncomingOffer();
      }
      return;
    }

    if (receivedAction.buttonKeyPressed == 'ACCEPT_ORDER') {
      if (receivedAction.payload != null &&
          receivedAction.payload!.isNotEmpty &&
          isOrderNotification(receivedAction.payload!) &&
          !isPromotionNotification(receivedAction.payload!)) {
        dispatchIncomingOffer(receivedAction.payload!);
      }
      if (Get.isRegistered<DriverDashboardController>()) {
        Get.find<DriverDashboardController>().acceptIncomingOffer();
      }
      return;
    }

    if (receivedAction.payload != null &&
        receivedAction.payload!.isNotEmpty &&
        isOrderNotification(receivedAction.payload!) &&
        !isPromotionNotification(receivedAction.payload!)) {
      dispatchIncomingOffer(receivedAction.payload!);
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    Logger().d('Notification created: ${receivedNotification.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    Logger().d('Notification displayed: ${receivedNotification.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    Logger().d('Notification dismissed: ${receivedAction.id}');
    // Silence alert if notification is swiped away
    await OrderAlertService.instance.stopRinging();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('driver_pending_order_payload');
    } catch (_) {}
    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().dismissIncomingOffer();
    }
  }
}
